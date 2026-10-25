extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func check_alpha_gutter(image: Image, label: String) -> void:
	var clear := true
	for offset in range(128):
		for band in range(4):
			for pixel in [Vector2i(band,offset),Vector2i(127-band,offset),Vector2i(offset,band),Vector2i(offset,127-band)]:
				if image.get_pixelv(pixel).a >= 0.01:clear=false
	check(clear,"four-pixel clear icon gutter "+label)
	check(not image.get_used_rect().size==Vector2i.ZERO,"nonempty icon "+label)
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	await process_frame
	var art: Script = preload("res://scripts/item_art.gd")
	var state := root.get_node("GameState")
	state.set_process(false)
	var seen_paths: Dictionary = {}
	var pixels: Dictionary = {}
	var completed := 0
	for id in state.item_catalog:
		var key: String = art.key_for(str(id), "items")
		check(art.manifest().has(key), "registry " + str(id))
		var row: Dictionary = art.manifest().get(key, {})
		var path: String = str(row.get("path", ""))
		check(not seen_paths.has(path), "independent path " + str(id))
		seen_paths[path] = id
		var texture: Texture2D = art.texture_for(str(id), "items")
		if str(row.get("status", "")) == "ready":
			completed += 1
			check(texture != null, "real ready asset " + str(id))
			if texture == null: continue
			var image := texture.get_image()
			check(image.get_size() == Vector2i(128, 128), "128px " + str(id))
			check(image.detect_alpha() != Image.ALPHA_NONE, "transparent " + str(id))
			for corner in [Vector2i(0, 0), Vector2i(127, 0), Vector2i(0, 127), Vector2i(127, 127)]:
				check(image.get_pixelv(corner).a < 0.01, "clear corner " + str(id))
			check_alpha_gutter(image,str(id))
			image.convert(Image.FORMAT_RGBA8)
			var hash_context := HashingContext.new()
			hash_context.start(HashingContext.HASH_SHA256)
			hash_context.update(image.get_data())
			var digest: String = hash_context.finish().hex_encode()
			check(not pixels.has(digest), "unique actual pixels " + str(id))
			pixels[digest] = id
			check(art.texture_for(str(id)) == texture, "cached texture " + str(id))
		else: check(texture == null, "missing not counted as completed " + str(id))
	# Supplementary categories use the same real-image and unique-pixel contract.
	for key in art.manifest():
		if str(key).begins_with("items/"):continue
		var row: Dictionary = art.manifest()[key]
		var texture: Texture2D = art.texture_for(str(key).get_slice("/",1),str(key).get_slice("/",0))
		if str(row.get("status","missing"))!="ready":
			check(texture==null,"unfinished supplemental icon not completed "+str(key));continue
		check(texture!=null,"real supplemental icon "+str(key))
		if texture==null:continue
		var image:=texture.get_image()
		check(image.get_size()==Vector2i(128,128),"128px supplemental icon "+str(key))
		check_alpha_gutter(image,str(key))
		image.convert(Image.FORMAT_RGBA8)
		var hashing:=HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(image.get_data())
		var digest:=hashing.finish().hex_encode()
		check(not pixels.has(digest),"supplemental icon has independent pixels "+str(key));pixels[digest]=key
	check(completed == 190, "every existing item has its own ready bitmap")
	check(state.item_catalog.size() == 190, "all 190 catalog IDs audited")
	check(art.key_for("hoe", "tools") == "tools/hoe", "namespaced tool")
	check(art.texture_for("unknown-missing-icon") == null, "no generic bitmap substituted")
	var character_art: Script = preload("res://scripts/character_art.gd")
	check(character_art.data().actors.size() == 25, "player and 24 residents registered")
	check(character_art.portrait("unknown", "calm") == null, "missing portrait safe")
	print("ART_COVERAGE: %d/190 real item icons; %d missing" % [completed, 190 - completed])
	print("ITEM_ART: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
