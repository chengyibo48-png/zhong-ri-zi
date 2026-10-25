extends SceneTree
## Structural packing only: keep all original tiles and replace the farm-grass column.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 2:
		printerr("Usage: -- <absolute-4x4-master> [preview]"); quit(1); return
	var preview := args.size() == 2 and args[1] == "preview"
	var lease := "res://artifacts/art-import-frozen-until.txt"
	if not preview and FileAccess.file_exists(lease) and Time.get_unix_time_from_system() < float(FileAccess.get_file_as_string(lease)):
		printerr("Frozen regression: terrain import deferred"); quit(1); return
	var master := Image.load_from_file(args[0])
	if master == null or master.is_empty() or master.get_width() != master.get_height() or master.get_width() < 512:
		printerr("Expected a square 4x4 terrain master of at least 512 pixels"); quit(1); return
	master.convert(Image.FORMAT_RGBA8)
	var packed := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var tiles: Array[Image] = []
	var hashes: Dictionary = {}
	for season in range(4):
		for variant in range(4):
			var begin := Vector2i(roundi(variant * master.get_width() / 4.0), roundi(season * master.get_height() / 4.0))
			var end := Vector2i(roundi((variant + 1) * master.get_width() / 4.0), roundi((season + 1) * master.get_height() / 4.0))
			var tile := master.get_region(Rect2i(begin, end - begin))
			tile.resize(32, 32, Image.INTERPOLATE_LANCZOS)
			for y in range(32):
				for x in range(32):
					if tile.get_pixel(x, y).a < 0.99:
						printerr("Opaque ground texture contains an alpha hole"); quit(1); return
			var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(tile.get_data())
			var signature := digest.finish().hex_encode()
			if hashes.has(signature):
				printerr("Duplicate seasonal terrain tile"); quit(1); return
			hashes[signature] = true
			tiles.append(tile)
			packed.blit_rect(tile, Rect2i(0, 0, 32, 32), Vector2i(variant, season) * 32)
	var source_set: TileSet = load("res://art/ground_tileset.tres")
	var source_atlas := source_set.get_source(0) as TileSetAtlasSource
	if source_atlas == null or source_atlas.texture == null:
		printerr("Missing original ground atlas"); quit(1); return
	var combined := source_atlas.texture.get_image()
	if combined == null or combined.get_size() != Vector2i(320, 512):
		printerr("Original 10x16 ground geometry changed"); quit(1); return
	combined.convert(Image.FORMAT_RGBA8)
	for index in range(16):
		combined.blit_rect(tiles[index], Rect2i(0, 0, 32, 32), Vector2i(4 * 32, index * 32))
	var directory := "res://artifacts/terrain-preview" if preview else "res://art/world/terrain"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if packed.save_png(directory + "/grass.png") != OK:
		printerr("Could not save packed grass"); quit(1); return
	var combined_path := "res://artifacts/terrain-preview/ground.png" if preview else "res://art/ground_tiles_handpainted.png"
	if combined.save_png(combined_path) != OK:
		printerr("Could not save ground atlas"); quit(1); return
	if not preview:
		var resource_path := "res://art/ground_tileset.tres"
		var resource_text := FileAccess.get_file_as_string(resource_path)
		var resource := FileAccess.open(resource_path, FileAccess.WRITE)
		resource.store_string(resource_text.replace("res://art/ground_tiles.svg", combined_path)); resource.close()
		var manifest_path := "res://data/world_art_manifest.json"
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not manifest is Dictionary:
			printerr("Invalid terrain manifest"); quit(1); return
		var row: Dictionary = manifest.entries["terrain/grass"]
		row.baseReady = true; row.status = "partial"
		row.seasonalVariants = [4, 4]; row.tileSize = [32, 32]
		row.visualReview = "pending_seams_legibility_and_performance"
		var file := FileAccess.open(manifest_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, "  ") + "\n"); file.close()
	print("GRASS_ATLAS_PACKED: 16 unique tiles; original 160 tile coordinates preserved; preview=", preview)
	quit(0)

