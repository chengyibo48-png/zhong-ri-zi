extends SceneTree
const BASE:="res://"
func _initialize() -> void:call_deferred("run")
func gutter(image: Image, vertical: bool) -> int:
	var bytes:=image.get_data();var w:=image.get_width();var h:=image.get_height()
	var length:=w if vertical else h;var cross:=h if vertical else w
	var best:=-1;var distance:=length
	for at: int in range(int(length*.32),int(length*.72)):
		var empty:=true
		for other: int in range(cross):
			var index:=((other*w+at) if vertical else (at*w+other))*4+3
			if int(bytes[index])>=48:empty=false;break
		if empty and absi(at-int(length*.5))<distance:best=at;distance=absi(at-int(length*.5))
	assert(best>=0,"Atlas props need a transparent separator")
	return best
func component_bounds(image: Image) -> Rect2i:
	var bytes:=image.get_data();var w:=image.get_width();var h:=image.get_height()
	var seen:=PackedByteArray();seen.resize(w*h)
	var components: Array[Dictionary]=[];var largest:=0
	for start: int in range(w*h):
		if seen[start]!=0 or int(bytes[start*4+3])<48:continue
		var queue:=PackedInt32Array([start]);seen[start]=1;var head:=0
		var left:=w;var right:=-1;var top:=h;var bottom:=-1
		while head<queue.size():
			var point:=queue[head];head+=1
			var x:=point%w;var y:=int(point/w)
			left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
			for dy: int in range(-1,2):
				for dx: int in range(-1,2):
					var nx:=x+dx;var ny:=y+dy
					if nx<0 or ny<0 or nx>=w or ny>=h:continue
					var next:=ny*w+nx
					if seen[next]!=0 or int(bytes[next*4+3])<48:continue
					seen[next]=1;queue.append(next)
		largest=maxi(largest,queue.size())
		components.append({"count":queue.size(),"rect":Rect2i(left,top,right-left+1,bottom-top+1)})
	var result:=Rect2i()
	for component: Dictionary in components:
		if int(component.count)<maxi(16,int(largest*.01)):continue
		result=result.merge(component.rect) if result.has_area() else component.rect
	return result.grow(3).intersection(Rect2i(0,0,w,h))
func extract_prop(image: Image, path: String) -> void:
	var region:=component_bounds(image)
	assert(region.has_area())
	var crop:=image.get_region(region)
	var factor:=minf(488.0/crop.get_width(),488.0/crop.get_height())
	crop.resize(maxi(1,roundi(crop.get_width()*factor)),maxi(1,roundi(crop.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	var tile:=Image.create(512,512,false,Image.FORMAT_RGBA8)
	tile.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(int((512-crop.get_width())/2),504-crop.get_height()))
	assert(tile.save_png(path)==OK)
func run() -> void:
	root.get_node("GameState").set_process(false)
	var folder:=BASE+"art/world/terrain/"
	DirAccess.make_dir_recursive_absolute(folder)
	var floor_image:=Image.load_from_file(BASE+"art/source/visual-20261026-v2/floor-master.png")
	floor_image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	assert(floor_image.save_png(folder+"oak-planks-v2.png")==OK)
	var bank:=Image.load_from_file(BASE+"art/source/visual-20261026-v2/riverbank-master.png")
	bank.convert(Image.FORMAT_RGBA8)
	var bytes:=bank.get_data();var w:=bank.get_width();var h:=bank.get_height()
	var top:=h;var bottom:=-1
	for y: int in range(h):
		for x: int in range(w):
			if int(bytes[(y*w+x)*4+3])>=48:top=mini(top,y);bottom=maxi(bottom,y);break
	assert(bottom>top,"Generated bank needs actual visible pixels")
	var crop:=bank.get_region(Rect2i(0,maxi(0,top-4),w,mini(h,bottom+5)-maxi(0,top-4)))
	crop.resize(1024,maxi(1,roundi(1024.0*crop.get_height()/w)),Image.INTERPOLATE_LANCZOS)
	assert(crop.save_png(folder+"riverbank-v2.png")==OK)
	print("V2_ASSETS oak ",floor_image.get_size(),"; bank ",crop.get_size(),"; alpha ",crop.detect_alpha())
	var interior:=Image.load_from_file(BASE+"art/source/visual-20261026-v2/interior-master.png")
	interior.convert(Image.FORMAT_RGBA8)
	var split:=gutter(interior,true)
	var details:=BASE+"art/world/interior_details/v2/"
	DirAccess.make_dir_recursive_absolute(details)
	for column: int in range(2):
		var strip:=interior.get_region(Rect2i(0 if column==0 else split,0,split if column==0 else interior.get_width()-split,interior.get_height()))
		var row_split:=gutter(strip,false)
		for row: int in range(2):
			var cell:=strip.get_region(Rect2i(0,0 if row==0 else row_split,strip.get_width(),row_split if row==0 else strip.get_height()-row_split))
			extract_prop(cell,details+["lantern","shelf","herbs","tea"][column+row*2]+".png")
	print("V2_INTERIOR 4 independent props extracted at transparent gutters")
	var materials:=Image.load_from_file(BASE+"art/source/visual-20261026-v2/floor-surfaces-master.png")
	for i: int in range(3):
		var left:=floori(float(materials.get_width())*i/3.0)
		var right:=floori(float(materials.get_width())*(i+1)/3.0)
		var tile:=materials.get_region(Rect2i(left,0,right-left,materials.get_height()))
		tile.resize(512,512,Image.INTERPOLATE_LANCZOS)
		assert(tile.save_png(folder+["blue-brick-v2.png","bamboo-mat-v2.png","terrazzo-v2.png"][i])==OK)
	print("V2_SURFACES 3 independent opaque floor textures")
	await root.get_node("AudioService").prepare_exit();quit(0)
