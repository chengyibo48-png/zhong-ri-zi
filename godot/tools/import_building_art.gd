extends SceneTree
func _initialize() -> void:
	var lease := "res://artifacts/art-import-frozen-until.txt"
	if FileAccess.file_exists(lease) and Time.get_unix_time_from_system()<float(FileAccess.get_file_as_string(lease)):
		printerr("Frozen regression: building import deferred"); quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: printerr("Usage: -- <building-id> <absolute-master-path>"); quit(1); return
	var manifest_path := "res://data/world_art_manifest.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary: quit(1); return
	var key := "buildings/" + args[0]
	if not parsed.entries.has(key): printerr("Unknown original building identity"); quit(1); return
	var image := Image.load_from_file(args[1])
	if image == null or image.is_empty() or image.detect_alpha() == Image.ALPHA_NONE:
		printerr("Building needs real transparent PNG"); quit(1); return
	for corner in [Vector2i.ZERO, Vector2i(image.get_width()-1, 0), Vector2i(0, image.get_height()-1), image.get_size()-Vector2i.ONE]:
		if image.get_pixelv(corner).a >= 0.01: printerr("Opaque background corner"); quit(1); return
	var low := image.get_size()
	var high := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.125:
				low = low.min(Vector2i(x, y)); high = high.max(Vector2i(x, y))
	if high.x < 0: printerr("Empty meaningful building silhouette"); quit(1); return
	var visible := Rect2i(low, high - low + Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image = image.get_region(visible)
	var world: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var original: Array = parsed.entries[key].worldRect
	for house in world.village.houses:
		if str(house.id) == args[0]: original = [-float(house.w) * 0.5, -float(house.h), float(house.w), float(house.h)]; break
	var scale := minf(float(original[2]) / image.get_width(), float(original[3]) / image.get_height())
	var world_size := Vector2(image.get_width(), image.get_height()) * scale
	var target_width := 512
	image.resize(target_width, maxi(1, roundi(target_width * world_size.y / world_size.x)), Image.INTERPOLATE_LANCZOS)
	var output: String = str(parsed.entries[key].path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	if image.save_png(output) != OK: quit(1); return
	parsed.entries[key].worldRect = [-world_size.x * 0.5, -world_size.y, world_size.x, world_size.y]
	parsed.entries[key].sourceVisibleRect = [visible.position.x, visible.position.y, visible.size.x, visible.size.y]
	parsed.entries[key].baseReady = true
	parsed.entries[key].status = "partial"
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed, "  ") + "\n"); file.close()
	print("BUILDING_BASE_IMPORTED: ", args[0], " complete building status remains partial")
	quit(0)
