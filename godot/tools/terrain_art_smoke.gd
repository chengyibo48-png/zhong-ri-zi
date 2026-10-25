extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func run() -> void:
	root.get_node("GameState").set_process(false)
	var old_text := FileAccess.get_file_as_string("res://artifacts/ground_tileset-before-handpainted.tres")
	var new_text := FileAccess.get_file_as_string("res://art/ground_tileset.tres")
	check(not old_text.is_empty() and new_text.replace("res://art/ground_tiles_handpainted.png","res://art/ground_tiles.svg")==old_text,"only TileSet texture binding changes; all authored metadata preserved")
	var reference: TileSet = load("res://artifacts/ground_tileset-before-handpainted.tres")
	var current: TileSet = load("res://art/ground_tileset.tres")
	check(current.tile_size==reference.tile_size and current.tile_size==Vector2i(32,32),"original tile size")
	check(current.get_source_count()==reference.get_source_count(),"original source count")
	var original := reference.get_source(0) as TileSetAtlasSource
	var painted := current.get_source(0) as TileSetAtlasSource
	check(painted.texture_region_size==original.texture_region_size,"original atlas-cell geometry")
	var original_image := original.texture.get_image()
	var image := painted.texture.get_image()
	original_image.convert(Image.FORMAT_RGBA8);image.convert(Image.FORMAT_RGBA8)
	check(image.get_size()==original_image.get_size() and image.get_size()==Vector2i(320,512),"original atlas dimensions")
	var packed_by_column: Dictionary = {}
	var names_by_column: Dictionary = {}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
	var ground_specs: Dictionary = manifest.get("groundAtlas", {})
	if ground_specs.is_empty():
		for old_family in {"grass":4,"stone_path":7}:
			ground_specs[old_family] = preload("res://scripts/world_art.gd").entries().get("terrain/"+old_family,{})
	for family in ground_specs:
		var entry: Dictionary = ground_specs[family]
		if not bool(entry.get("baseReady",false)):continue
		var packed := Image.load_from_file(ProjectSettings.globalize_path(str(entry.path)))
		check(packed!=null and packed.get_size()==Vector2i(128,128),"sixteen packed ground tiles: "+family)
		if packed==null:quit(1);return
		packed.convert(Image.FORMAT_RGBA8)
		var column: int = int(entry.atlasColumn)
		packed_by_column[column]=packed;names_by_column[column]=family
		check(str(entry.status)=="partial","base art does not falsely mark full terrain review complete: "+family)
	check(packed_by_column.has(4),"approved grass atlas remains available")
	if manifest.has("groundAtlas"):check(packed_by_column.size()==10,"all ten authored ground families independently packed")
	var hashes: Dictionary = {}
	for row in range(16):
		for column in range(10):
			var coordinates := Vector2i(column,row)
			check(painted.has_tile(coordinates)==original.has_tile(coordinates),"all original tile coordinates")
			var before := original.get_tile_data(coordinates,0)
			var after := painted.get_tile_data(coordinates,0)
			for key in ["surface_kind","season_index","variant"]:
				check(after.get_custom_data(key)==before.get_custom_data(key),"original typed metadata "+key)
			var area := Rect2i(column*32,row*32,32,32)
			if not packed_by_column.has(column):
				check(image.get_region(area).get_data()==original_image.get_region(area).get_data(),"every unchanged ground tile stays byte-identical")
				continue
			var tile := image.get_region(area)
			check(tile.get_data()==(packed_by_column[column] as Image).get_region(Rect2i(posmod(row,4)*32,floori(row/4.0)*32,32,32)).get_data(),"season/variant selects exact packed artwork")
			check(tile.detect_alpha()==Image.ALPHA_NONE,"opaque ground has no holes")
			var digest := HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(tile.get_data())
			var signature: String = str(names_by_column[column]) + ":" + digest.finish().hex_encode()
			check(not hashes.has(signature),"independent seasonal texture variants")
			hashes[signature]=true
	print("TERRAIN_ART_SMOKE: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)

