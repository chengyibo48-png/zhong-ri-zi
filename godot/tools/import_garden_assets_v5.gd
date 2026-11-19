extends SceneTree
func _initialize() -> void:
	var base := ProjectSettings.globalize_path("res://art/furniture/")
	var manifest: Dictionary = {}
	for id: String in ["flowerbed", "trellis", "well", "stoneLantern"]:
		var image := Image.load_from_file(base + "source/" + id + "-four-views.png")
		var w := image.get_width()
		var h := image.get_height()
		var split_x := separator(image,true)
		var split_y := separator(image,false)
		var regions := [Rect2i(0,0,split_x,split_y), Rect2i(split_x,0,w-split_x,split_y), Rect2i(0,split_y,split_x,h-split_y), Rect2i(split_x,split_y,w-split_x,h-split_y)]
		manifest[id] = []
		for rotation in range(4):
			var cell := image.get_region(regions[rotation])
			var used := silhouette_bounds(cell)
			var cropped := cell.get_region(used)
			var extent := maxi(cropped.get_width(),cropped.get_height())
			if extent > 512:
				var ratio := 512.0 / extent
				cropped.resize(maxi(1,roundi(cropped.get_width()*ratio)),maxi(1,roundi(cropped.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
			assert(cropped.save_png(base + "models/%s_%d.png" % [id,rotation]) == OK)
			manifest[id].append({"view":rotation,"width":cropped.get_width(),"height":cropped.get_height(),"crop":[regions[rotation].position.x+used.position.x,regions[rotation].position.y+used.position.y,used.size.x,used.size.y]})
	var out := FileAccess.open(base + "garden-models-v5.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(manifest,"\t"))
	print("SLICED 16 native transparent direction sprites")
	quit()

func separator(image: Image, vertical: bool) -> int:
	var extent := image.get_width() if vertical else image.get_height()
	var across := image.get_height() if vertical else image.get_width()
	var low := int(extent * (0.46 if vertical else 0.43))
	var high := int(extent * (0.76 if vertical else 0.57))
	var run_start := -1
	var longest := 0
	var middle := -1
	for coordinate in range(low,high+1):
		var clear := coordinate < high
		if clear:
			for other in range(across):
				var alpha := image.get_pixel(coordinate,other).a if vertical else image.get_pixel(other,coordinate).a
				if alpha > 0.06:
					clear = false; break
		if clear and run_start < 0: run_start = coordinate
		if not clear and run_start >= 0:
			var length := coordinate - run_start
			if length > longest:
				longest = length; middle = int((coordinate+run_start)*0.5)
			run_start = -1
	assert(longest >= 3,"A safe transparent gutter is required")
	return middle
func silhouette_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(),image.get_height())
	var maximum := Vector2i.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a <= 0.06: continue
			minimum.x = mini(minimum.x,x); minimum.y = mini(minimum.y,y)
			maximum.x = maxi(maximum.x,x+1); maximum.y = maxi(maximum.y,y+1)
	assert(maximum.x > minimum.x and maximum.y > minimum.y,"Model silhouette cannot be empty")
	# Only choose a robust crop; keep original alpha and its soft border intact.
	return Rect2i(minimum-Vector2i(3,3),maximum-minimum+Vector2i(6,6)).intersection(Rect2i(0,0,image.get_width(),image.get_height()))
