extends SceneTree
const QUEUE := "res://artifacts/room-expansion-20261011/queue.json"
const MANIFEST := "res://data/world_art_manifest.json"

func _initialize() -> void:
	var queue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QUEUE))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for job: Dictionary in queue.rows:
		if str(job.get("status", "")) == "imported_not_gameplay_tested": continue
		var source: Image = Image.load_from_file(str(job.master))
		if source == null or source.is_empty():
			printerr("Unavailable art source: ", job.id)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var row: Dictionary = manifest.entries[str(job.id)]
		var output: String = str(row.path)
		if job.has("state"):
			var states: Dictionary = row.get("states", {})
			if str(job.state) == "idle": states["working"] = str(row.path)
			else: states["normal"] = str(row.path)
			output = str(row.path).trim_suffix(".png") + "-" + str(job.state) + ".png"
			states[str(job.state)] = output
			row["states"] = states
		var canvas: Image
		if str(job.id).begins_with("interiors/"):
			# Repack architectural wall/floor into the existing room's 95/405 px regions.
			var split: int = roundi(source.get_height() * 0.27)
			var wall: Image = source.get_region(Rect2i(0, 0, source.get_width(), split))
			var floor_image: Image = source.get_region(Rect2i(0, split, source.get_width(), source.get_height() - split))
			wall.resize(756, 95, Image.INTERPOLATE_LANCZOS)
			floor_image.resize(756, 405, Image.INTERPOLATE_LANCZOS)
			canvas = Image.create(756, 500, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(wall, Rect2i(0, 0, 756, 95), Vector2i.ZERO)
			canvas.blit_rect(floor_image, Rect2i(0, 0, 756, 405), Vector2i(0, 95))
		else:
			if source.detect_alpha() == Image.ALPHA_NONE:
				printerr("Transparent furniture/building source required: ", job.id)
				quit(1)
				return
			var low: Vector2i = source.get_size()
			var high := Vector2i(-1, -1)
			for y: int in source.get_height():
				for x: int in source.get_width():
					if source.get_pixel(x, y).a > 0.125:
						low = low.min(Vector2i(x, y))
						high = high.max(Vector2i(x, y))
			if high.x < 0:
				printerr("Empty art source: ", job.id)
				quit(1)
				return
			var box := Rect2i(low, high - low + Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO, source.get_size()))
			var cropped: Image = source.get_region(box)
			var dimensions := Vector2i(256, 160)
			if str(job.id).begins_with("buildings/"):
				var base: Image = Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
				dimensions = base.get_size()
				output = str(row.path).trim_suffix(".png") + "/" + str(job.season) + ".png"
			var factor: float = minf(float(dimensions.x - 4) / box.size.x, float(dimensions.y - 4) / box.size.y)
			var fitted := Vector2i(maxi(1, roundi(box.size.x * factor)), maxi(1, roundi(box.size.y * factor)))
			cropped.resize(fitted.x, fitted.y, Image.INTERPOLATE_LANCZOS)
			canvas = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(cropped, Rect2i(Vector2i.ZERO, fitted), Vector2i((dimensions.x - fitted.x) / 2, dimensions.y - fitted.y))
			job["sourceRect"] = [box.position.x, box.position.y, box.size.x, box.size.y]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
		if canvas.save_png(output) != OK:
			quit(1)
			return
		if str(job.id).begins_with("buildings/"):
			var seasons: Array = row.get("seasons", [str(row.path), "", "", ""])
			seasons[["spring", "summer", "autumn", "winter"].find(str(job.season))] = output
			row["seasons"] = seasons
		else:
			row["baseReady"] = true
			if str(job.get("state", "")) == "idle":
				row["path"] = output
				row["states"]["normal"] = output
		row["status"] = "partial"
		row["artBatch"] = "room-expansion-20261011"
		row["verification"] = "source art visually reviewed; no game tests or gameplay verification requested"
		job["runtimePath"] = output
		job["status"] = "imported_not_gameplay_tested"
		print("ROOM_EXPANSION_IMPORTED: ", job.id, " ", job.get("season", "normal"))
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	var receipt: FileAccess = FileAccess.open(QUEUE, FileAccess.WRITE)
	receipt.store_string(JSON.stringify(queue, "  ") + "\n")
	receipt.close()
	quit(0)
