extends RefCounted
## Read-only visual water topology; no collision, fishing or save-state writes.
const FISHING_CLEARANCE:=56.0
static func is_water(columns: Dictionary, point: Vector2) -> bool:
	return int(columns.get(Vector2i(floori(point.x/32.0),floori(point.y/32.0)),-1))==8

static func clear_water(columns: Dictionary, point: Vector2, half_size: Vector2) -> bool:
	for offset: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(-1,0),Vector2(1,0),Vector2(-1,1),Vector2(0,1),Vector2(1,1)]:
		if not is_water(columns,point+offset*half_size):return false
	return true

static func depth_image(columns: Dictionary, size: Vector2i=Vector2i(120,120)) -> Image:
	var distances:=PackedInt32Array();distances.resize(size.x*size.y)
	for y: int in range(size.y):
		for x: int in range(size.x):
			var kind:=int(columns.get(Vector2i(x,y),-1))
			# Wood bridges are above the water and must not create a shallow sand halo.
			distances[y*size.x+x]=128 if kind in [8,9] else 0
	for y: int in range(size.y):
		for x: int in range(size.x):
			var i:=y*size.x+x
			if x>0:distances[i]=mini(distances[i],distances[i-1]+1)
			if y>0:distances[i]=mini(distances[i],distances[i-size.x]+1)
	for y: int in range(size.y-1,-1,-1):
		for x: int in range(size.x-1,-1,-1):
			var i:=y*size.x+x
			if x<size.x-1:distances[i]=mini(distances[i],distances[i+1]+1)
			if y<size.y-1:distances[i]=mini(distances[i],distances[i+size.x]+1)
	var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	for y: int in range(size.y):
		for x: int in range(size.x):
			var depth:=clampf((float(distances[y*size.x+x])-.5)*32.0/128.0,0.0,1.0)
			image.set_pixel(x,y,Color(depth,0,0,1))
	return image

static func excluded(point: Vector2, exclusions: Array[Vector2], radius: float) -> bool:
	for other: Vector2 in exclusions:
		if point.distance_squared_to(other)<radius*radius:return true
	return false

static func plant_layout(world: Dictionary, columns: Dictionary, exclusions: Array[Vector2]) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var village: Dictionary=world.get("village",{})
	for region: String in village.get("maps",{}):
		var offset: Dictionary=village.get("offsets",{}).get(region,{})
		for water: Dictionary in village.maps[region].get("water",[]):
			if not bool(water.get("lotus",false)):continue
			var area:=Rect2(float(water.x)+float(offset.get("x",0)),float(water.y)+float(offset.get("y",0)),float(water.w),float(water.h)).grow(-23.0)
			var candidates: Array[Dictionary]=[]
			for y: int in range(ceili(area.position.y/42.0),floori(area.end.y/42.0)+1):
				for x: int in range(ceili(area.position.x/46.0),floori(area.end.x/46.0)+1):
					var seed_value:=posmod(x*73+y*137,997)
					if seed_value%4==0:continue
					var at:=Vector2(x*46.0+float(seed_value%11)-5,y*42.0+float(seed_value%9)-4)
					if not area.has_point(at) or not clear_water(columns,at,Vector2(18,13)) or excluded(at,exclusions,FISHING_CLEARANCE):continue
					candidates.append({"kind":"lotus","at":at,"seed":seed_value,"region":region})
			candidates.sort_custom(func(a: Dictionary,b: Dictionary):return int(a.seed)<int(b.seed))
			for i: int in range(mini(9,candidates.size())):result.append(candidates[i])
	var keys: Array=columns.keys()
	keys.sort_custom(func(a: Vector2i,b: Vector2i):return a.y<b.y if a.y!=b.y else a.x<b.x)
	var reed_count:=0
	for cell: Vector2i in keys:
		if int(columns[cell])!=8:continue
		var seed_value:=posmod(cell.x*73+cell.y*137,997)
		if seed_value%17!=0 or reed_count>=32:continue
		for side: Vector2i in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			if int(columns.get(cell+side,-1)) not in [2,3,4,5]:continue
			var at:=Vector2(cell)*32.0+Vector2(16,16)+Vector2(side)*5.0
			if not clear_water(columns,at,Vector2(18,9)) or excluded(at,exclusions,FISHING_CLEARANCE):continue
			result.append({"kind":"reeds","at":at,"seed":seed_value,"region":"bank"});reed_count+=1;break
	return result

static func reflected_box(rectangle: Rect2) -> Rect2:
	return Rect2(rectangle.position.x,-rectangle.end.y*.70,rectangle.size.x,rectangle.size.y*.70)
