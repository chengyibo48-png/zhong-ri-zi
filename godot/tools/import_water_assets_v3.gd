extends SceneTree
func _initialize() -> void:call_deferred("run")
func bounds(image: Image) -> Rect2i:
	var bytes:=image.get_data();var w:=image.get_width();var h:=image.get_height()
	var left:=w;var right:=-1;var top:=h;var bottom:=-1
	for y: int in range(h):
		for x: int in range(w):
			if int(bytes[(y*w+x)*4+3])<48:continue
			left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
	if right<left:return Rect2i()
	return Rect2i(left,top,right-left+1,bottom-top+1).grow(2).intersection(Rect2i(0,0,w,h))
func gutter(image: Image, vertical: bool) -> int:
	var bytes:=image.get_data();var w:=image.get_width();var h:=image.get_height()
	var length:=w if vertical else h;var cross:=h if vertical else w
	var best:=-1;var distance:=length
	for at: int in range(int(length*.32),int(length*.70)):
		var empty:=true
		for other: int in range(cross):
			var index:=((other*w+at) if vertical else (at*w+other))*4+3
			if int(bytes[index])>=48:empty=false;break
		if empty and absi(at-int(length*.5))<distance:best=at;distance=absi(at-int(length*.5))
	assert(best>=0,"Seasonal cells need a transparent gutter")
	return best
func run() -> void:
	root.get_node("GameState").set_process(false)
	var base:=OS.get_environment("ZRZ_WATER_STAGE").replace("\\","/").trim_suffix("/")
	if base=="":base="res:/"
	var receipt: Array=[]
	for kind: String in ["lotus","reeds"]:
		var source:=Image.load_from_file(base+"/art/source/visual-water-v3/"+kind+"-master.png")
		source.convert(Image.FORMAT_RGBA8)
		var split:=gutter(source,true)
		var cells: Array[Image]=[null,null,null,null]
		var widest:=0;var tallest:=0
		for column: int in range(2):
			var strip:=source.get_region(Rect2i(0 if column==0 else split,0,split if column==0 else source.get_width()-split,source.get_height()))
			var row_split:=gutter(strip,false)
			for row: int in range(2):
				var cell:=strip.get_region(Rect2i(0,0 if row==0 else row_split,strip.get_width(),row_split if row==0 else strip.get_height()-row_split))
				var used:=bounds(cell);assert(used.has_area())
				cells[column+row*2]=cell.get_region(used)
				widest=maxi(widest,used.size.x);tallest=maxi(tallest,used.size.y)
		var factor:=minf(472.0/widest,440.0/tallest)
		var folder:=base+"/art/world/water-v3/"+kind+"/"
		DirAccess.make_dir_recursive_absolute(folder)
		for i: int in range(4):
			var pixels:=cells[i]
			pixels.resize(maxi(1,roundi(pixels.get_width()*factor)),maxi(1,roundi(pixels.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
			var frame:=Image.create(512,512,false,Image.FORMAT_RGBA8)
			frame.blit_rect(pixels,Rect2i(Vector2i.ZERO,pixels.get_size()),Vector2i(int((512-pixels.get_width())/2),480-pixels.get_height()))
			var path: String=folder+["spring","summer","autumn","winter"][i]+".png"
			assert(frame.save_png(path)==OK)
			receipt.append({"kind":kind,"season":i,"path":path,"sha256":FileAccess.get_sha256(path),"scale":factor,"anchor":[256,480]})
	var output:=OS.get_environment("ZRZ_WATER_IMPORT_RECEIPT")
	if output!="":FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
	print("WATER_ART_IMPORT ",receipt.size()," real seasonal textures; common within-family scale; original masters retained")
	await root.get_node("AudioService").prepare_exit();quit(0)
