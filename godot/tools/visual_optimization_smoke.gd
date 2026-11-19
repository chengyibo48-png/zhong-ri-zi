extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value: passed+=1
	else: failed+=1;push_error(label)
func contiguous_pose_rows(image: Image) -> bool:
	if image.is_compressed():image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var bytes:=image.get_data();var width:=image.get_width()
	var seen:=false;var gap:=0
	for y: int in range(image.get_height()):
		var opaque:=0
		for x: int in range(width):
			if int(bytes[(y*width+x)*4+3])>=48:opaque+=1
		if opaque>1:
			if seen and gap>3:return false
			seen=true;gap=0
		elif seen:gap+=1
	return seen
func run() -> void:
	var s: Node=root.get_node("GameState");s.set_process(false)
	var baseline: Dictionary=s._make_save_data().duplicate(true)
	var art:=preload("res://scripts/world_art.gd")
	var rabbit: Dictionary=art.entries()["buildings/ranch-rabbitry"]
	check(rabbit.seasons.size()==4,"Rabbit hutch has four actual season resources")
	check(rabbit.door=={"x":2590.0,"y":2520.0},"Rabbit hutch retains its own authored door")
	var hashes: Dictionary={}
	for path: String in rabbit.seasons:
		var tex: Texture2D=preload("res://scripts/character_art.gd").texture(path)
		check(tex!=null and tex.get_size()==Vector2(512,300),"Rabbit season texture loads: "+path)
		check(not path.contains("poultry"),"Rabbit identity is independent of poultry")
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(tex.get_image().get_data())
		hashes[digest.finish().hex_encode()]=true
		check(absf((float(rabbit.worldRect[2])/tex.get_width())/(float(rabbit.worldRect[3])/tex.get_height())-1.0)<.01,"Rabbit rendering preserves original aspect")
	check(hashes.size()==4,"Four season variants are distinct files")
	var animal_art:=preload("res://scripts/animal_art.gd")
	for species: String in ["hen","duck","cow","sheep","goat","pig","rabbit"]:
		var a: Dictionary={"type":species,"breed":"local"}
		for direction: String in ["down","left","right","up"]:
			for state: String in ["eat","sleep"]:
				var view: Dictionary={"direction":direction,"walking":false,"young":false,"eating":state=="eat","sleepy":state=="sleep"}
				var frame: Dictionary=animal_art.frame(a,view,0)
				check(not frame.is_empty(),"Pose descriptor exists: "+species+direction+state)
				if frame.is_empty():continue
				check(frame.texture.get_size()==Vector2(1024,256),"Actual state atlas selected instead of standing image")
				check(frame.source.position.y==(0 if state=="eat" else 128),"Right state row selected")
				check(frame.source.position.x==["down","left","right","up"].find(direction)*256,"Correct facing column selected")
				var pixels: Image=frame.texture.get_image().get_region(Rect2i(frame.source))
				check(pixels.get_used_rect().has_area() and pixels.get_used_rect().end.y<=118 and contiguous_pose_rows(pixels),"Pose shares the foot baseline and has no detached row fragments: "+species+direction+state)
	var flora:=preload("res://scripts/scenery_profile.gd")
	var tree: Array=flora.rectangle({"kind":"tree","x":960,"y":700},[-24,-56,48,56])
	check(float(tree[3])>90 and float(tree[3])<145,"Mature trees have a human-relative scale")
	check(tree==flora.rectangle({"kind":"tree","x":960,"y":700},[-24,-56,48,56]),"Visual scale is deterministic across save/reload")
	check(s.inventory==baseline.inventory and s.money==baseline.money and s.plots==baseline.plots,"Reading new art does not change inventory, economy or crops")
	check(s.load_game_data(baseline),"Current save remains loadable")
	print("Visual optimization: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
