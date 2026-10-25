extends SceneTree
## Structural atlas packing: separate poses at real transparent gutters, align feet.
func bands(image: Image, area: Rect2i, vertical: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := -1
	var size := area.size.y if vertical else area.size.x
	for axis in range(size):
		var occupied := false
		for cross in range(area.size.x if vertical else area.size.y):
			var p := area.position + (Vector2i(cross, axis) if vertical else Vector2i(axis, cross))
			if image.get_pixelv(p).a > 0.125: occupied = true; break
		if occupied and start < 0: start = axis
		if not occupied and start >= 0: result.append(Vector2i(start, axis)); start = -1
	if start >= 0: result.append(Vector2i(start, size))
	return result
func _initialize() -> void:
	var freeze_path := "res://artifacts/art-import-frozen-until.txt"
	if FileAccess.file_exists(freeze_path) and Time.get_unix_time_from_system() < float(FileAccess.get_file_as_string(freeze_path)):
		printerr("Frozen regression: animal art import deferred"); quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or args.size() > 5:
		printerr("Usage: -- <actor> <clip> <absolute-sheet-path> [source-directions] [source-feet-json]"); quit(1); return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
	if not data is Dictionary: quit(1); return
	var spec: Dictionary = data.get("entries", {}).get("animals/" + args[0], {})
	if spec.is_empty(): printerr("Unknown animal"); quit(1); return
	var source := Image.load_from_file(args[2])
	if source == null or source.is_empty() or source.detect_alpha() == Image.ALPHA_NONE:
		printerr("Character sheet needs real transparent alpha"); quit(1); return
	var columns := int(spec.frames)
	var rows: int = spec.directions.size()
	var source_directions: Array = args[3].split(",") if args.size() >= 4 else spec.directions
	if source_directions.size() != rows: printerr("Direction count mismatch"); quit(1); return
	var authored_feet: Dictionary = {}
	if args.size()==5:
		var parsed_feet: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[4]))
		if not parsed_feet is Dictionary or parsed_feet.get("sourceDirections",[])!=source_directions or not parsed_feet.get("frames") is Array or parsed_feet.frames.size()!=rows:
			printerr("Invalid authored source feet"); quit(1); return
		for points in parsed_feet.frames:
			if not points is Array or points.size()!=columns: printerr("Source feet count mismatch"); quit(1); return
		authored_feet=parsed_feet
	var row_bands := bands(source, Rect2i(Vector2i.ZERO, source.get_size()), true)
	if row_bands.size() != rows:
		printerr("Expected ", rows, " separate pose rows; got ", row_bands.size()); quit(1); return
	var bounds: Array[Rect2i] = []
	var max_height := 0
	var direction_heights: Array[int] = []
	for row in range(rows):
		direction_heights.append(0)
		var strip := Rect2i(0, row_bands[row].x, source.get_width(), row_bands[row].y - row_bands[row].x)
		var column_bands := bands(source, strip, false)
		if column_bands.size() != columns:
			printerr("Expected ", columns, " distinct poses in row ", row, "; got ", column_bands.size()); quit(1); return
		for column in range(columns):
			var bound := Rect2i(column_bands[column].x, strip.position.y, column_bands[column].y - column_bands[column].x, strip.size.y)
			var trimmed := source.get_region(bound).get_used_rect()
			bound = Rect2i(bound.position + trimmed.position, trimmed.size)
			if bound.position.x < 2 or bound.position.y < 2 or bound.end.x > source.get_width() - 2 or bound.end.y > source.get_height() - 2:
				printerr("Pose touches outer image edge; regenerate clipped pose: ", row, ":", column); quit(1); return
			bounds.append(bound); max_height = maxi(max_height, bound.size.y)
			direction_heights[row] = maxi(direction_heights[row], bound.size.y)
	var common_ratio := 108.0 / float(max_height)
	var target_cell := Vector2i(int(spec.frameSize[0]), int(spec.frameSize[1]))
	var anchor := Vector2i(int(spec.anchor[0]), int(spec.anchor[1]))
	var atlas := Image.create(target_cell.x * columns, target_cell.y * rows, false, Image.FORMAT_RGBA8)
	for row in range(rows):
		var target_row: int = spec.directions.find(source_directions[row])
		var ratio := 108.0 / float(direction_heights[row]) if bool(authored_feet.get("directionHeightNormalization", false)) else common_ratio
		if target_row < 0: printerr("Unknown source direction"); quit(1); return
		for column in range(columns):
			var bound := bounds[row * columns + column]
			var padded := bound.grow(2)
			var tile := source.get_region(padded)
			tile.resize(maxi(1, roundi(tile.get_width() * ratio)), maxi(1, roundi(tile.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
			var feet := Vector2i(roundi(tile.get_width() * 0.5), roundi((bound.size.y + 2) * ratio))
			if not authored_feet.is_empty():
				var point: Variant=authored_feet.frames[row][column]
				if not point is Array or point.size()!=2 or not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):
					printerr("Invalid source foot point"); quit(1); return
				var source_feet := Vector2(float(point[0]),float(point[1]))
				if not is_finite(source_feet.x) or not is_finite(source_feet.y) or source_feet.x<bound.position.x or source_feet.x>bound.end.x or source_feet.y<bound.position.y or source_feet.y>bound.end.y:
					printerr("Authored feet leave source pose"); quit(1); return
				feet=Vector2i(roundi((source_feet.x-padded.position.x)*ratio),roundi((source_feet.y-padded.position.y)*ratio))
			# Calibrate the ground after resampling; faint alpha fringes are not hooves.
			var visible_sole := -1
			for pixel_y in range(tile.get_height()-1,-1,-1):
				for pixel_x in range(tile.get_width()):
					if tile.get_pixel(pixel_x,pixel_y).a>=0.5: visible_sole=pixel_y+1; break
				if visible_sole>=0: break
			if visible_sole<0: printerr("Resampled pose has no visible hoof"); quit(1); return
			feet.y=visible_sole
			var offset := anchor - feet
			if not Rect2i(Vector2i.ZERO, target_cell).encloses(Rect2i(offset, tile.get_size())):
				printerr("Aligned pose would leave the target cell"); quit(1); return
			var frame := Image.create(target_cell.x, target_cell.y, false, Image.FORMAT_RGBA8)
			frame.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), offset)
			atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, target_cell), Vector2i(column, target_row) * target_cell)
	var output := ProjectSettings.globalize_path(str(spec.path))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if atlas.save_png(output) != OK: quit(1); return
	# One imported clip does not mark an actor's whole art set complete.
	print("ANIMAL_ATLAS_IMPORTED: ", args[0], "/", args[1], " -> ", output)
	quit(0)
