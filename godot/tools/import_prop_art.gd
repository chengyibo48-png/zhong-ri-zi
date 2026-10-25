extends SceneTree
## Pack a reviewed transparent prop without changing original world/collision data.
func _initialize() -> void:
	var lease := "res://artifacts/art-import-frozen-until.txt"
	if FileAccess.file_exists(lease) and Time.get_unix_time_from_system() < float(FileAccess.get_file_as_string(lease)):
		printerr("Frozen regression: prop import deferred"); quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		printerr("Usage: -- <original-prop-kind> <absolute-master-path> <max-world-width> <max-world-height>"); quit(1); return
	var manifest_path := "res://data/world_art_manifest.json"
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var key := "props/" + args[0]
	if not manifest is Dictionary or not manifest.get("entries", {}).has(key):
		printerr("Unknown original prop identity"); quit(1); return
	var limits := Vector2(args[2].to_float(), args[3].to_float())
	if not limits.is_finite() or limits.x <= 0.0 or limits.y <= 0.0:
		printerr("Invalid prop display bounds"); quit(1); return
	var image := Image.load_from_file(args[1])
	if image == null or image.is_empty() or image.detect_alpha() == Image.ALPHA_NONE:
		printerr("Prop requires a real transparent image"); quit(1); return
	var size := image.get_size()
	for corner in [Vector2i.ZERO, Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), size - Vector2i.ONE]:
		if image.get_pixelv(corner).a >= 0.01:
			printerr("Opaque prop background corner"); quit(1); return
	var low := size
	var high := Vector2i(-1, -1)
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a > 0.125:
				if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
					printerr("Meaningful prop silhouette clipped at canvas edge"); quit(1); return
				low = low.min(Vector2i(x, y)); high = high.max(Vector2i(x, y))
	if high.x < 0:
		printerr("Empty prop silhouette"); quit(1); return
	var visible := Rect2i(low, high - low + Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO, size))
	image = image.get_region(visible)
	var factor := minf(limits.x / image.get_width(), limits.y / image.get_height())
	var world_size := Vector2(image.get_size()) * factor
	image.resize(256, maxi(1, roundi(256.0 * image.get_height() / image.get_width())), Image.INTERPOLATE_LANCZOS)
	var row: Dictionary = manifest.entries[key]
	var output := str(row.path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	if image.save_png(output) != OK:
		printerr("Cannot save prop PNG"); quit(1); return
	row.worldRect = [-world_size.x / 2.0, -world_size.y, world_size.x, world_size.y]
	row.sourceVisibleRect = [visible.position.x, visible.position.y, visible.size.x, visible.size.y]
	row.baseReady = true
	row.status = "partial"
	row.reviewed = ["material_detail"]
	row.verifiedChecks = []
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot update prop manifest"); quit(1); return
	file.store_string(JSON.stringify(manifest, "  ") + "\n"); file.close()
	print("PROP_BASE_IMPORTED: ", args[0], "; original placement and collisions preserved")
	quit(0)
