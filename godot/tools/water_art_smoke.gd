extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL: ",label)
func run() -> void:
	var state: Node=root.get_node("GameState");state.set_process(false)
	var saved: Dictionary=state._make_save_data().duplicate(true)
	var definitions: Dictionary=state.system_catalog.fishing.duplicate(true)
	var geometry: Script=load("res://scripts/water_geometry.gd")
	var columns: Dictionary={}
	for y: int in range(9):
		for x: int in range(9):columns[Vector2i(x,y)]=8 if x>0 and x<8 and y>0 and y<8 else 4
	var original:=columns.duplicate(true)
	var depth: Image=geometry.depth_image(columns,Vector2i(9,9))
	check(depth.get_pixel(4,4).r>depth.get_pixel(1,4).r,"Deep water is darker than the near-bank cell")
	check(depth.get_pixel(0,0).r==0.0,"Land has zero visual water depth")
	for y: int in range(1,8):columns[Vector2i(4,y)]=9
	check(geometry.depth_image(columns,Vector2i(9,9)).get_data()==depth.get_data(),"Bridges do not create a false shallow-water halo")
	check(not geometry.is_water(columns,Vector2(4*32+16,4*32+16)),"Wood bridge is excluded from reflective water")
	check(not geometry.is_water(columns,Vector2(-1,10)),"Map exterior is excluded")
	check(not geometry.clear_water(columns,Vector2(4*32-2,4*32+16),Vector2(12,8)),"Wave segments crossing the bridge are rejected")
	var farm: Node2D=load("res://scripts/farm_world.gd").new()
	farm.world_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	farm._create_ground_layer()
	var actual: Dictionary=farm.ground_layer.get_meta("visual_columns")
	var before_hash:=hash(actual)
	var effects: Node2D=load("res://scripts/world_effects.gd").new()
	root.add_child(effects);effects.set_process(false)
	effects.configure(farm.world_data)
	check(effects.water_columns.is_empty() and not effects.water_rects.is_empty(),"Legacy one-argument ambience configuration remains valid")
	effects.configure(farm.world_data,farm.ground_layer)
	check(effects.water_columns==actual,"Native ambience shares the actual water lookup")
	effects.queue_free();await process_frame
	var excluded: Array[Vector2]=[]
	for spot: Dictionary in definitions.spots:
		excluded.append(Vector2(float(spot.waterX),float(spot.waterY)))
		for landing: Dictionary in spot.get("landings",[]):excluded.append(Vector2(float(landing.x),float(landing.y)))
	for slot: Dictionary in definitions.trapSlots:excluded.append(Vector2(float(slot.waterX),float(slot.waterY)))
	var plants: Array=geometry.plant_layout(farm.world_data,actual,excluded)
	check(not plants.is_empty(),"Authored lotus ponds now receive actual plant models")
	check(plants==geometry.plant_layout(farm.world_data,actual,excluded),"Plant layout is stable across reloads")
	var lotus:=0;var reeds:=0
	for plant: Dictionary in plants:
		check(geometry.is_water(actual,plant.at),"Plant root is in real water")
		check(not geometry.excluded(plant.at,excluded,geometry.FISHING_CLEARANCE),"Fishing landings and traps retain visual clearance")
		check(geometry.clear_water(actual,plant.at,Vector2(18,13) if plant.kind=="lotus" else Vector2(18,9)),"Plant footprint avoids bridge decks and shore corners")
		if plant.kind=="lotus":
			lotus+=1
			check(plant.region!="river" and plant.region!="mountain","Lotus only appears in authored lotus ponds")
		else:reeds+=1
	check(lotus>0 and lotus<=36 and reeds<=32,"Vegetation has a bounded density")
	check(hash(actual)==before_hash,"Water layout generation never modifies the ground lookup")
	var art: Script=load("res://scripts/character_art.gd")
	for kind: String in ["lotus","reeds"]:
		var hashes: Dictionary={}
		for season: String in ["spring","summer","autumn","winter"]:
			var texture: Texture2D=art.texture("res://art/world/water-v3/"+kind+"/"+season+".png")
			check(texture!=null and texture.get_size()==Vector2(512,512),"Seasonal sprite is actually loadable "+kind+season)
			if texture==null:continue
			var pixels:=texture.get_image()
			check(pixels.detect_alpha()!=Image.ALPHA_NONE and pixels.get_pixel(0,0).a==0,"Sprite keeps genuine alpha padding "+kind+season)
			var used:=pixels.get_used_rect()
			check(used.has_area() and used.position.y>=16 and used.end.y<=483,"Seasonal model fits its common waterline anchor "+kind+season)
			var hashing:=HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(pixels.get_data());hashes[hashing.finish().hex_encode()]=true
		check(hashes.size()==4,"Seasons contain four different paintings "+kind)
	var reflected: Rect2=geometry.reflected_box(Rect2(-30,-100,60,100))
	check(reflected.position==Vector2(-30,0) and reflected.size==Vector2(60,70),"Reflection starts at the source ground anchor")
	farm.free()
	check(state.system_catalog.fishing==definitions,"Fishing definitions are unchanged")
	check(state.inventory==saved.inventory and state.money==saved.money and state.plots==saved.plots,"Water art preserves inventory, money and cultivated state")
	print("WATER_ART: %d passed, %d failed; %d lotus clusters, %d reed tufts"%[passed,failed,lotus,reeds])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
