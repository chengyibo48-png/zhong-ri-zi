extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	await process_frame
	var art: Script = preload("res://scripts/character_art.gd")
	var state := root.get_node("GameState")
	state.set_process(false)
	var frames_checked := 0
	for actor in art.data().actors:
		var entry: Dictionary = art.data().actors[actor]
		for clip in entry.clips:
			var spec: Dictionary = entry.clips[clip]
			if not art.has_clip(str(actor), str(clip)): continue
			var texture: Texture2D = art.texture(str(spec.path))
			check(texture != null, "approved clip has a real PNG " + str(actor) + "/" + str(clip))
			if texture == null: continue
			var image := texture.get_image()
			var columns := int(spec.frames)
			var rows: int = spec.directions.size()
			var cell:=Vector2i(int(spec.frameSize[0]),int(spec.frameSize[1]))
			check(image.get_size() == Vector2i(columns * cell.x, rows * cell.y), "declared atlas cells")
			for row in range(rows):
				for column in range(columns):
					var frame := image.get_region(Rect2i(column*cell.x,row*cell.y,cell.x,cell.y))
					var used := frame.get_used_rect()
					check(not used.size == Vector2i.ZERO, "nonempty pose")
					check(used.position.x > 0 and used.position.y > 0 and used.end.x < cell.x and used.end.y < cell.y, "no clipping or frame bleed")
					if spec.has("sourceFrames") and spec.sourceFrames[row*columns+column].has("foot"):
						var receipt:Dictionary=spec.sourceFrames[row*columns+column]
						check(Vector2i(int(receipt.foot[0])+int(receipt.offset[0]),int(receipt.foot[1])+int(receipt.offset[1]))==Vector2i(int(spec.anchor[0]),int(spec.anchor[1])),"native source soles align to declared anchor")
						var has_sole:=false
						for sole_x in range(maxi(0,int(spec.anchor[0])-45),mini(cell.x,int(spec.anchor[0])+45)):
							for sole_y in range(int(spec.anchor[1])-3,int(spec.anchor[1])+1):
								var sole_color:=frame.get_pixel(sole_x,sole_y)
								if sole_color.a>=.5 and sole_color.r<.61 and sole_color.g<.57 and sole_color.b<.51:has_sole=true
						check(has_sole,"actual dark shoes at declared planted sole")
					elif bool(spec.get("toolCanvas",false)):
						check(Vector2(float(spec.anchor[0]),float(spec.anchor[1]))==Vector2(96,168) and cell==Vector2i(192,192),"large tool canvas uses explicit reviewed shoe anchor")
					else:check(used.end.y >= 112 and used.end.y <= 120, "feet align with anchor")
					for corner in [Vector2i.ZERO,Vector2i(cell.x-1,0),Vector2i(0,cell.y-1),cell-Vector2i.ONE]:
						check(frame.get_pixelv(corner).a < 0.01, "transparent frame corner")
					frames_checked += 1

	# A watering stream must not move the planted shoe anchor during the action.
	if art.has_clip("player","water"):
		var water_image: Image=art.texture(str(art.data().actors.player.clips.water.path)).get_image()
		for row in range(4):
			for column in range(6):
				var frame := water_image.get_region(Rect2i(column*128,row*128,128,128))
				var shoes: Array[Vector2i] = []
				var bottom := -1
				for y in range(98,124):
					for x in range(128):
						var color := frame.get_pixel(x,y)
						var r := roundi(color.r*255);var green := roundi(color.g*255);var b := roundi(color.b*255)
						if color.a>=0.5 and r>=green+8 and green>=b+8 and (r+green+b)/3.0<155:
							shoes.append(Vector2i(x,y));bottom=maxi(bottom,y)
				check(not shoes.is_empty(),"watering frame includes actual brown shoes")
				if shoes.is_empty():continue
				var min_x := 128;var max_x := -1
				for point in shoes:
					if point.y<bottom-3:continue
					min_x=mini(min_x,point.x);max_x=maxi(max_x,point.x)
				check(absf((min_x+max_x+1)/2.0-64.0)<=3.0 and absi(bottom+1-116)<=2,"water stream does not shift the shoe anchor")

	var portrait_hashes: Dictionary = {}
	for actor in art.data().actors:
		var entry: Dictionary = art.data().actors[actor]
		for emotion in entry.get("portraitReady", {}):
			if not bool(entry.portraitReady[emotion]): continue
			var portrait: Texture2D = art.portrait(str(actor),str(emotion))
			check(portrait!=null,"approved portrait exists: "+str(actor)+"/"+str(emotion))
			if portrait==null:continue
			var image:=portrait.get_image()
			check(image.get_size()==Vector2i(256,320),"portrait fitted without distortion")
			check(image.detect_alpha()!=Image.ALPHA_NONE,"portrait has true transparent alpha")
			for corner in [Vector2i.ZERO,Vector2i(255,0),Vector2i(0,319),Vector2i(255,319)]:
				check(image.get_pixelv(corner).a<0.01,"transparent portrait corner")
			var hashing:=HashingContext.new()
			hashing.start(HashingContext.HASH_SHA256);hashing.update(image.get_data())
			var digest:=hashing.finish().hex_encode()
			check(not portrait_hashes.has(digest),"portraits are independent images")
			portrait_hashes[digest]=str(actor)+"/"+str(emotion)
	check(frames_checked >= 32, "eight idle and twenty-four walk poses")
	check(not art.has_clip("player", "unknown_action"), "unknown action cannot become ready")
	for kind in preload("res://scripts/action_rules.gd").CATALOG:
		check(art.data().actors.player.clips.has(kind), "every runtime action tracked: " + str(kind))
	check(not bool(art.data().actors.player.ready), "partial player art not full character completion")
	var buildings: Dictionary = preload("res://scripts/world_art.gd").entries()
	var count := 0
	for house in state.world_village.houses:
		var key: String = preload("res://scripts/world_art.gd").key_for(house)
		check(key == "buildings/" + str(house.id), "unique building identity")
		var prop: Dictionary = house.duplicate(true); prop.erase("id")
		check(preload("res://scripts/world_art.gd").key_for(prop) == key, "legacy prop resolves by original position")
		check(buildings.has(key), "every building has tracked art readiness")
		count += 1
	check(count == 47, "all original buildings tracked")
	print("CHARACTER_ART: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)

