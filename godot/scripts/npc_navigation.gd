extends RefCounted
# Source village navigation: 24-pixel four-neighbor BFS and one-pixel line checks.
static var shared_caches: Dictionary = {}
static var metrics:Dictionary={"grid_builds":0,"grid_max_ms":0.0,"route_calls":0,"route_max_ms":0.0,"last_route_ms":0.0,"last_route_at_ms":0}
var traversal_profile:String="ground"
var caches: Dictionary = shared_caches
var geometry_cache: Dictionary = {}
var scope_stamp := ""
var _hot_geometry:Dictionary={}
var _hot_scope:=""
var _hot_room:=""
var _hot_legacy:=false
var _hot_state_id:=0
var spatial: Dictionary = {}
var spatial_stamp := ""

func refresh(state: Node) -> void:
	var revision:Dictionary=preload("res://scripts/navigation_revision.gd").sample(state)
	var world_stamp:String=revision.world
	if spatial_stamp != world_stamp:
		spatial.clear()
		spatial_stamp = world_stamp
	var next:String=revision.scope
	if next!=scope_stamp:geometry_cache.clear();_hot_geometry={}
	scope_stamp=next

func point(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y}

func distance(a: Dictionary, b: Dictionary) -> float:
	var dx := float(b.x) - float(a.x)
	var dy := float(b.y) - float(a.y)
	var scale:=maxf(absf(dx),absf(dy))
	if scale==0.0:return 0.0
	var x:=absf(dx)/scale
	var y:=absf(dy)/scale
	return sqrt(x*x+y*y)*scale

func contains(rect: Array, x: float, y: float) -> bool:
	return x > float(rect[0]) and x < float(rect[0]) + float(rect[2]) and y > float(rect[1]) and y < float(rect[1]) + float(rect[3])

func contains_building(rect: Array,x: float,y: float) -> bool:
	# Build.contains includes left/top edges; village static solids use strict edges.
	return x>=float(rect[0]) and y>=float(rect[1]) and x<float(rect[0])+float(rect[2]) and y<float(rect[1])+float(rect[3])

func geometry(state: Node, room: String, legacy: bool = false) -> Dictionary:
	if scope_stamp == "": refresh(state)
	if not _hot_geometry.is_empty() and _hot_scope==scope_stamp and _hot_room==room and _hot_legacy==legacy and _hot_state_id==state.get_instance_id():return _hot_geometry
	var key := "%d/%s/%s/%s" % [state.get_instance_id(), room, legacy, scope_stamp]
	if geometry_cache.has(key): return _remember_geometry(state,room,legacy,geometry_cache[key])
	var data: Dictionary = {"room": room, "rows": [], "fences": [], "pieces": {}, "zones": [], "home": false}
	var layouts: Dictionary = state.system_catalog.get("interiors", {}).get("layouts", {})
	var museum_house:Dictionary=state.system_catalog.get("museum",{}).get("house",{})
	if room!="" and room==str(museum_house.get("id","")):
		data.rows=[[167,260,156,88],[637,260,156,88],[167,400,156,88],[637,400,156,88],[404,432,152,58]]
		var level:=int(state.collection.get("level",0))
		if level>=1:data.rows.append([305,209,110,35])
		if level>=3:data.rows.append([540,247,90,40])
	elif layouts.has(room):
		for row in layouts[room].get("rows", []):
			if not bool(row.get("solid",true)):continue
			data.rows.append([float(row.x)-float(row.w)/2.0, float(row.y)-float(row.h), float(row.w), float(row.h)+18.0])
	elif room != "":
		var house: Dictionary = state.house_data(room)
		data.home = str(house.get("name", "")) == "爷爷的老屋" and not legacy
		if bool(data.home):
			data.rows.append([185.0, 231.0, 122.0, 56.0])
			var level := int(state.building.get("house", 0))
			if level >= 1: data.rows.append([608.0, 274.0, 109.0, 44.0])
			if level >= 2: data.rows.append([196.0, 432.0, 82.0, 38.0])
			if level >= 3: data.rows.append([786.0, 420.0, 52.0, 35.0])
		else:
			data.rows = [[164,254,160,37],[627,248,140,40],[658,443,144,38],[158,447,152,53],[380,328,140,41]]
	else:
		if spatial.is_empty():
			for group in ["solids", "houses", "corridors"]:
				var buckets: Dictionary = {}
				for object in state.world_village.get(group, []):
					var rect: Array
					if group == "solids": rect = [float(object[0])-6,float(object[1])-3,float(object[2])+12,float(object[3])+8]
					elif group == "houses": rect = [float(object.x)+2,float(object.y)+51,float(object.w)-4,float(object.h)-48]
					else: rect = [float(object.x)+7,float(object.y)+7,float(object.w)-14,float(object.h)-14]
					for by in range(floori(float(rect[1])/64.0),floori((float(rect[1])+float(rect[3]))/64.0)+1):
						for bx in range(floori(float(rect[0])/64.0),floori((float(rect[0])+float(rect[2]))/64.0)+1):
							var bucket := by*64+bx
							if not buckets.has(bucket): buckets[bucket] = []
							buckets[bucket].append(rect)
				spatial[group] = buckets
		for pen in state.system_catalog.get("forage", {}).get("pens", []):
			var x := float(pen.x); var y := float(pen.y); var w := float(pen.w); var h := float(pen.h); var gate := float(pen.gate)
			for rect in [[x,y,gate-44-x,7],[gate+44,y,x+w-gate-44,7],[x,y,7,h],[x+w-7,y,7,h],[x,y+h-7,w,7]]:
				data.fences.append([float(rect[0])-10.0,float(rect[1])-8.0,float(rect[2])+20.0,float(rect[3])+16.0])
	if room!="" and room!="ranch-meadow":
		for extra:Dictionary in load("res://scripts/house_life.gd").rows(state,room):
			if bool(extra.get("solid",true)):
				var r:Rect2=load("res://scripts/house_life.gd").footprint(extra);data.rows.append([r.position.x,r.position.y,r.size.x,r.size.y])
		for wall:Rect2 in preload("res://scripts/house_geometry.gd").walls(room):data.rows.append([wall.position.x,wall.position.y,wall.size.x,wall.size.y])
	if not legacy:
		var zones: Dictionary = state.system_catalog.get("building", {}).get("zones", {})
		var defs: Dictionary = state.system_catalog.get("building", {}).get("defs", {})
		for zone_id in zones:
			var zone: Dictionary = zones[zone_id]
			var open: bool = str(zone_id) == "home" or str(zone_id) == "court" and bool(state.upgrades.get("yard", false)) or str(zone_id) == "orchard" and bool(state.building.get("land", {}).get("orchard", false))
			if not open: continue
			if room == "" and str(zone_id) != "home": data.zones.append({"id": str(zone_id), "rect": [zone.x,zone.y,float(zone.cols)*float(zone.size),float(zone.rows)*float(zone.size)]})
			data.pieces[str(zone_id)] = []
		for piece in state.building.get("layout", []):
			var zone_id := str(piece.get("zone", ""))
			if not data.pieces.has(zone_id): continue
			var definition: Dictionary = defs.get(str(piece.get("type", "")), {})
			if not bool(definition.get("solid", false)): continue
			var zone: Dictionary = zones.get(zone_id, {})
			var size := float(zone.size); var cols := int(zone.cols); var cell := int(piece.get("cell", 0))
			var rotated := int(piece.get("rotation", 0)) % 2 != 0
			var rect := [float(zone.x)+(cell%cols)*size,float(zone.y)+floor(float(cell)/cols)*size,float(definition.get("h" if rotated else "w",1))*size,float(definition.get("w" if rotated else "h",1))*size]
			data.pieces[zone_id].append(rect)
	if geometry_cache.size() > 100: geometry_cache.clear()
	geometry_cache[key] = data
	return _remember_geometry(state,room,legacy,data)

func _remember_geometry(state:Node,room:String,legacy:bool,data:Dictionary)->Dictionary:
	_hot_state_id=state.get_instance_id();_hot_scope=scope_stamp;_hot_room=room;_hot_legacy=legacy;_hot_geometry=data
	return data

func blocked(state: Node, room: String, x: float, y: float, legacy: bool = false) -> bool:
	if room=="ranch-meadow":return preload("res://scripts/ranch_meadow.gd").blocked(x,y,traversal_profile)
	var data := geometry(state, room, legacy)
	if room != "":
		if not preload("res://scripts/house_geometry.gd").walk_rect(room).grow(.001).has_point(Vector2(x,y)):return true
		for rect in data.rows:
			if contains(rect, x, y): return true
		if bool(data.home):
			for rect in data.pieces.get("home", []):
				if contains_building(rect,x,y): return true
		return false
	for rect in data.fences:
		if contains(rect,x,y): return true
	for zone in data.zones:
		if contains_building(zone.rect,x,y):
			for rect in data.pieces.get(str(zone.id),[]):
				if contains_building(rect,x,y): return true
			return false
	if not is_finite(x) or not is_finite(y) or x < 24 or y < 38 or x > 3816 or y > 3816: return true
	var bucket := floori(y/64.0)*64+floori(x/64.0)
	var corridor := false
	for rect in spatial.get("corridors",{}).get(bucket,[]):
		if contains(rect,x,y): corridor = true; break
	if corridor:
		var house_block := false
		for rect in spatial.get("houses",{}).get(bucket,[]):
			if contains(rect,x,y): house_block = true; break
		if not house_block: return false
	for rect in spatial.get("solids",{}).get(bucket,[]):
		if contains(rect,x,y): return true
	return false

func safe(state: Node, room: String, p: Dictionary, legacy: bool = false) -> Dictionary:
	if not blocked(state,room,float(p.x),float(p.y),legacy): return p.duplicate()
	for radius in range(12,800,12):
		for angle in range(24):
			var q := {"x": float(p.x)+cos(float(angle)*PI/12.0)*radius, "y": float(p.y)+sin(float(angle)*PI/12.0)*radius, "direction": str(p.get("direction", "down"))}
			if not blocked(state,room,q.x,q.y,legacy): return q
	if room!="" and room!="ranch-meadow":
		var entry:Vector2=preload("res://scripts/house_geometry.gd").spawn(room)
		return {"x":entry.x,"y":entry.y,"direction":"up"}
	return {"x":1536.0,"y":1900.0,"direction":"up"} if room=="ranch-meadow" else {"x":2831.0,"y":1652.0,"direction":"down"}

func line_clear(state: Node, room: String, a: Dictionary, b: Dictionary, legacy: bool = false) -> bool:
	var count := ceili(distance(a,b)/(8.0 if room=="ranch-meadow" else 1.0))
	for i in range(1,count+1):
		if blocked(state,room,float(a.x)+(float(b.x)-float(a.x))*i/count,float(a.y)+(float(b.y)-float(a.y))*i/count,legacy): return false
	return true

func cell(state: Node, room: String, p: Dictionary, grid: PackedByteArray, cols: int, rows: int, legacy: bool = false) -> int:
	var cx := floori(float(p.x)/24.0); var cy := floori(float(p.y)/24.0)
	var best := -1; var best_distance := INF
	for yy in range(maxi(0,cy-2),mini(rows-1,cy+2)+1):
		for xx in range(maxi(0,cx-2),mini(cols-1,cx+2)+1):
			var index := yy*cols+xx; var q := point(xx*24.0+12.0,yy*24.0+12.0)
			if grid[index] == 255:
				grid[index] = 1 if blocked(state,room,q.x,q.y,legacy) else 0
			if grid[index] == 0:
				var d := distance(p,q)
				if d < best_distance and line_clear(state,room,p,q,legacy): best_distance = d; best = index
	return best

func route(state: Node, room: String, from: Dictionary, target: Dictionary, legacy: bool = false) -> Array:
	var started:=Time.get_ticks_usec()
	var result:Array=_route(state,room,from,target,legacy)
	metrics.route_calls+=1;metrics.last_route_ms=(Time.get_ticks_usec()-started)/1000.0;metrics.route_max_ms=maxf(metrics.route_max_ms,metrics.last_route_ms);metrics.last_route_at_ms=Time.get_ticks_msec()
	return result
func _route(state: Node, room: String, from: Dictionary, target: Dictionary, legacy: bool = false) -> Array:
	if blocked(state,room,float(target.x),float(target.y),legacy): return []
	if line_clear(state,room,from,target,legacy): return [point(float(target.x),float(target.y))]
	var cols := 158 if room=="ranch-meadow" else ceili(preload("res://scripts/house_geometry.gd").bounds(room).end.x/24.0)+4 if room != "" else 160
	var rows := 86 if room=="ranch-meadow" else ceili(preload("res://scripts/house_geometry.gd").bounds(room).end.y/24.0)+4 if room != "" else 160
	var size := cols*rows
	var key := "%s/%s/%s/%s/lazy-astar-v1" % [room,legacy,scope_stamp,traversal_profile]
	var cache: Dictionary = caches.get(key,{})
	if cache.is_empty():
		var grid_started:=Time.get_ticks_usec();metrics.grid_builds+=1
		var grid := PackedByteArray(); grid.resize(size)
		grid.fill(255)
		cache = {"grid":grid,"edges":{}}
		if caches.size()>50: caches.clear()
		caches[key] = cache
		metrics.grid_max_ms=maxf(metrics.grid_max_ms,(Time.get_ticks_usec()-grid_started)/1000.0)
	var a := cell(state,room,from,cache.grid,cols,rows,legacy)
	var b := cell(state,room,target,cache.grid,cols,rows,legacy)
	if a < 0 or b < 0: return []
	var prev := PackedInt32Array(); prev.resize(size); prev.fill(-2); prev[a] = -1
	var costs := PackedInt32Array(); costs.resize(size); costs.fill(2147483647); costs[a] = 0
	var closed := PackedByteArray(); closed.resize(size)
	var queue: Array[Vector3i] = []
	var serial := 0
	_heap_push(queue,Vector3i(absi(a%cols-b%cols)+absi(a/cols-b/cols),serial,a))
	var found := false
	while not queue.is_empty():
		var v := _heap_pop(queue).z
		if closed[v] != 0:continue
		closed[v] = 1
		if v == b: found = true; break
		for d in [-1,1,-cols,cols]:
			var n := v+int(d)
			if n < 0 or n >= size or absi(int(d)) == 1 and int(v/cols) != int(n/cols) or closed[n] != 0: continue
			if cache.grid[n] == 255:
				cache.grid[n] = 1 if blocked(state,room,(n%cols)*24.0+12.0,floor(float(n)/cols)*24.0+12.0,legacy) else 0
			if cache.grid[n] != 0 or costs[v]+1 >= costs[n]:continue
			var edge := mini(v,n)*size+maxi(v,n)
			if not cache.edges.has(edge):
				cache.edges[edge] = line_clear(state,room,point((v%cols)*24.0+12.0,floor(float(v)/cols)*24.0+12.0),point((n%cols)*24.0+12.0,floor(float(n)/cols)*24.0+12.0),legacy)
			if not bool(cache.edges[edge]): continue
			costs[n] = costs[v]+1; prev[n] = v; serial += 1
			var heuristic := absi(n%cols-b%cols)+absi(n/cols-b/cols)
			_heap_push(queue,Vector3i(costs[n]+heuristic,serial,n))
	if not found: return []
	var result: Array = [point(float(target.x),float(target.y))]
	var v := b
	while v != -1:
		result.append(point((v%cols)*24.0+12.0,floor(float(v)/cols)*24.0+12.0)); v = prev[v]
	result.reverse()
	var smooth: Array = []; var last := from; var i := 0
	while i < result.size():
		var next := mini(result.size()-1,i+10)
		while next > i and not line_clear(state,room,last,result[next],legacy): next -= 1
		smooth.append(result[next]); last = result[next]; i = next+1
	return smooth

func step(state: Node, p: Dictionary, target: Dictionary, delta: float, speed: float, runtime: Dictionary, room: String = "") -> bool:
	if blocked(state,room,float(target.x),float(target.y)): target = safe(state,room,target)
	if blocked(state,room,float(p.x),float(p.y)): p.merge(safe(state,room,p),true)
	if runtime.get("path",[]).is_empty(): runtime.path = route(state,room,p,target)
	if runtime.path.is_empty(): return false
	var budget := speed*delta
	while not runtime.path.is_empty() and budget > 0:
		var q: Dictionary = runtime.path[0]
		var dx := float(q.x)-float(p.x); var dy := float(q.y)-float(p.y); var d := sqrt(dx*dx+dy*dy)
		if d < 0.01: runtime.path.pop_front(); continue
		p.direction = ("right" if dx>0 else "left") if absf(dx)>absf(dy) else ("down" if dy>0 else "up")
		var amount := minf(d,budget); var nx := float(p.x)+dx/d*amount; var ny := float(p.y)+dy/d*amount
		if blocked(state,room,nx,ny): runtime.path = []; return false
		p.x = nx; p.y = ny; budget -= amount
		if d <= amount+0.01: runtime.path.pop_front()
	return true

# Stable insertion-order tie breaking. The heuristic is Manhattan distance on
# the unchanged four-neighbour grid; every accepted edge still passes line_clear.
func _heap_less(a: Vector3i,b: Vector3i) -> bool:
	return a.x < b.x or a.x == b.x and a.y < b.y
func _heap_push(heap: Array[Vector3i],entry: Vector3i) -> void:
	heap.append(entry)
	var index := heap.size()-1
	while index > 0:
		var parent := (index-1)/2
		if not _heap_less(entry,heap[parent]):break
		heap[index] = heap[parent]; index = parent
	heap[index] = entry
func _heap_pop(heap: Array[Vector3i]) -> Vector3i:
	var result: Vector3i = heap[0]
	var last: Vector3i = heap.pop_back()
	if heap.is_empty():return result
	var index := 0
	while index*2+1 < heap.size():
		var child := index*2+1
		if child+1 < heap.size() and _heap_less(heap[child+1],heap[child]):child += 1
		if not _heap_less(heap[child],last):break
		heap[index] = heap[child]; index = child
	heap[index] = last
	return result
