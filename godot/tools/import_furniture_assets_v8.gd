extends SceneTree
var BASE:=ProjectSettings.globalize_path("res://art/furniture/")
func _initialize()->void:
	DirAccess.make_dir_recursive_absolute(BASE+"models")
	var records:Dictionary={}
	for id:String in ["pot","fence","orchard","photo","waterbed","scarecrow","greenhouse","lantern","sign","seedrack","path","rug"]:
		var image:=Image.load_from_file(BASE+"source/"+id+"-v8-master.png")
		assert(image!=null and not image.is_empty())
		var regions:Array[Rect2i]=[]
		if id in ["path","rug"]:regions.append(Rect2i(Vector2i.ZERO,image.get_size()))
		else:
			var x:=separator(image,true);var w:=image.get_width();var h:=image.get_height()
			var left_y:=separator(image.get_region(Rect2i(0,0,x,h)),false)
			var right_y:=separator(image.get_region(Rect2i(x,0,w-x,h)),false)
			regions=[Rect2i(0,0,x,left_y),Rect2i(x,0,w-x,right_y),Rect2i(0,left_y,x,h-left_y),Rect2i(x,right_y,w-x,h-right_y)]
		records[id]=[]
		for rotation in range(4):
			var region:Rect2i=regions[0] if regions.size()==1 else regions[rotation]
			var cell:=image.get_region(region)
			var used:=Rect2i(Vector2i.ZERO,cell.get_size()) if id=="path" else silhouette_bounds(cell)
			var result:=cell.get_region(used)
			var extent:=maxi(result.get_width(),result.get_height())
			if extent>512:
				var ratio:=512.0/extent
				result.resize(maxi(1,roundi(result.get_width()*ratio)),maxi(1,roundi(result.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
			if regions.size()==1:
				for turn in rotation:result.rotate_90(CLOCKWISE)
			assert(result.save_png(BASE+"models/%s_%d.png"%[id,rotation])==OK)
			records[id].append({"view":rotation,"width":result.get_width(),"height":result.get_height(),"crop":[region.position.x+used.position.x,region.position.y+used.position.y,used.size.x,used.size.y]})
	var file:=FileAccess.open(BASE+"models-v8.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"))
	print("V8_IMPORT: 48 textures, 12 retained masters, native alpha-aware crops and floor rotations")
	quit()
func separator(image:Image,vertical:bool)->int:
	var extent:=image.get_width() if vertical else image.get_height()
	var across:=image.get_height() if vertical else image.get_width()
	var low:=int(extent*.43);var high:=int(extent*.76) if vertical else int(extent*.58)
	var start:=-1;var longest:=0;var middle:=-1
	for coordinate in range(low,high+1):
		var clear:=coordinate<high
		if clear:
			for other in across:
				if (image.get_pixel(coordinate,other).a if vertical else image.get_pixel(other,coordinate).a)>.06:clear=false;break
		if clear and start<0:start=coordinate
		if not clear and start>=0:
			if coordinate-start>longest:longest=coordinate-start;middle=int((coordinate+start)*.5)
			start=-1
	assert(longest>=3,"No safe atlas gutter; source must be repaired")
	return middle
func silhouette_bounds(image:Image)->Rect2i:
	var minimum:=image.get_size();var maximum:=Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a<=.06:continue
			minimum.x=mini(minimum.x,x);minimum.y=mini(minimum.y,y);maximum.x=maxi(maximum.x,x+1);maximum.y=maxi(maximum.y,y+1)
	assert(maximum.x>minimum.x and maximum.y>minimum.y)
	return Rect2i(minimum-Vector2i(3,3),maximum-minimum+Vector2i(6,6)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
