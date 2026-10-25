extends SceneTree
## Art processing only. Existing spring art, world rects and game rules are retained.
const QUEUE := "res://artifacts/building-seasons-20261011/queue.json"
const MANIFEST := "res://data/world_art_manifest.json"
const BUILDINGS := ["building-farm-12", "building-town-1", "building-farm-13"]
const SEASONS := ["summer", "autumn", "winter"]

func _initialize() -> void:
	var queue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QUEUE))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for id: String in BUILDINGS:
		var row: Dictionary = manifest.entries["buildings/" + id]
		var base: Image = Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
		var variants: Array = [str(row.path)]
		var frames: Array = []
		for season: String in SEASONS:
			var source: Dictionary = {}
			for job: Dictionary in queue.rows:
				if str(job.id) == id and str(job.season) == season:
					source = job
					break
			if source.is_empty():
				printerr("Missing seasonal source: ", id, "/", season)
				quit(1)
				return
			var image: Image = Image.load_from_file(str(source.master))
			if image == null or base == null or image.detect_alpha() == Image.ALPHA_NONE:
				printerr("Transparent source is required: ", id, "/", season)
				quit(1)
				return
			var low: Vector2i = image.get_size()
			var high := Vector2i(-1, -1)
			for y: int in image.get_height():
				for x: int in image.get_width():
					if image.get_pixel(x, y).a > 0.125:
						low = low.min(Vector2i(x, y))
						high = high.max(Vector2i(x, y))
			if high.x < 0:
				printerr("Empty source: ", id, "/", season)
				quit(1)
				return
			var box := Rect2i(low, high - low + Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			var tile: Image = image.get_region(box)
			var factor: float = minf(float(base.get_width() - 4) / box.size.x, float(base.get_height() - 4) / box.size.y)
			var dimensions := Vector2i(maxi(1, roundi(box.size.x * factor)), maxi(1, roundi(box.size.y * factor)))
			tile.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
			var offset := Vector2i((base.get_width() - dimensions.x) / 2, base.get_height() - dimensions.y)
			var canvas: Image = Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
			canvas.blit_rect(tile, Rect2i(Vector2i.ZERO, dimensions), offset)
			var output: String = "res://art/world/buildings/" + id + "/" + season + ".png"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
			if canvas.save_png(output) != OK:
				quit(1)
				return
			variants.append(output)
			frames.append({"season": season, "sourceSha256": source.sha256, "sourceRect": [box.position.x, box.position.y, box.size.x, box.size.y], "packedSize": [dimensions.x, dimensions.y], "packedPosition": [offset.x, offset.y]})
			source["status"] = "imported_not_gameplay_tested"
			source["runtimePath"] = output
			print("CORE_BUILDING_SEASON_IMPORTED: ", id, "/", season)
		row["seasons"] = variants
		row["seasonSourceFrames"] = frames
		row["status"] = "partial"
		row["seasonReview"] = "source art reviewed; gameplay and exact seasonal roof/window registration not tested this batch at user request"
		row["seasonBatch"] = "2026-10-11 core buildings"
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	var queue_file: FileAccess = FileAccess.open(QUEUE, FileAccess.WRITE)
	queue_file.store_string(JSON.stringify(queue, "  ") + "\n")
	queue_file.close()
	quit(0)
