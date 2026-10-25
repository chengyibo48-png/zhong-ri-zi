extends RefCounted
# Source village navigation: 24-pixel four-neighbor BFS and one-pixel line checks.
static var shared_caches: Dictionary = {}
var caches: Dictionary = shared_caches
var geometry_cache: Dictionary = {}
var scope_stamp := ""
var spatial: Dictionary = {}
var spatial_stamp := ""

func refresh(state: Node) -> void:
	var world_stamp := str(hash(state.world_village))
	if spatial_stamp != world_stamp:
		spatial.clear()
		spatial_stamp = world_stamp
	scope_stamp = "%s/%s/%s/%s" % [world_stamp, hash(state.building), hash(state.upgrades),int(state.collection.get("level",0))]

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
	var key := "%d/%s/%s/%s" % [state.get_instance_id(), room, legacy, scope_stamp]
	if geometry_cache.has(key): return geometry_cache[key]
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
	return data

func blocked(state: Node, room: String, x: float, y: float, legacy: bool = false) -> bool:
	var data := geometry(state, room, legacy)
	if room != "":
		if x < 113 or x > 847 or y < 205 or y > 602: return true
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
	return {"x":2831.0,"y":1652.0,"direction":"down"}

func line_clear(state: Node, room: String, a: Dictionary, b: Dictionary, legacy: bool = false) -> bool:
	var count := ceili(distance(a,b))
	for i in range(1,count+1):
		if blocked(state,room,float(a.x)+(float(b.x)-float(a.x))*i/count,float(a.y)+(float(b.y)-float(a.y))*i/count,legacy): return false
	return true

func cell(state: Node, room: String, p: Dictionary, grid: PackedByteArray, cols: int, rows: int, legacy: bool = false) -> int:
	var cx := floori(float(p.x)/24.0); var cy := floori(float(p.y)/24.0)
	var best := -1; var best_distance := INF
	for yy in range(maxi(0,cy-2),mini(rows-1,cy+2)+1):
		for xx in range(maxi(0,cx-2),mini(cols-1,cx+2)+1):
			var index := yy*cols+xx; var q := point(xx*24.0+12.0,yy*24.0+12.0)
			if grid[index] == 0 and line_clear(state,room,p,q,legacy):
				var d := distance(p,q)
				if d < best_distance: best_distance = d; best = index
	return best

func route(state: Node, room: String, from: Dictionary, target: Dictionary, legacy: bool = false) -> Array:
	if blocked(state,room,float(target.x),float(target.y),legacy): return []
	if line_clear(state,room,from,target,legacy): return [point(float(target.x),float(target.y))]
	var cols := 40 if room != "" else 160
	var rows := 28 if room != "" else 160
	var size := cols*rows
	var key := "%s/%s/%s" % [room,legacy,scope_stamp]
	var cache: Dictionary = caches.get(key,{})
	if cache.is_empty():
		var grid := PackedByteArray(); grid.resize(size)
		for i in range(size):
			grid[i] = 1 if blocked(state,room,(i%cols)*24.0+12.0,floor(float(i)/cols)*24.0+12.0,legacy) else 0
		cache = {"grid":grid,"edges":{}}
		if caches.size()>50: caches.clear()
		caches[key] = cache
	var a := cell(state,room,from,cache.grid,cols,rows,legacy)
	var b := cell(state,room,target,cache.grid,cols,rows,legacy)
	if a < 0 or b < 0: return []
	var prev := PackedInt32Array(); prev.resize(size); prev.fill(-2); prev[a] = -1
	var queue := PackedInt32Array(); queue.resize(size); queue[0] = a
	var tail := 1; var found := false; var head := 0
	while head < tail:
		var v := int(queue[head]); head += 1
		if v == b: found = true; break
		for d in [-1,1,-cols,cols]:
			var n := v+int(d)
			if n < 0 or n >= size or absi(int(d)) == 1 and int(v/cols) != int(n/cols) or cache.grid[n] != 0 or prev[n] != -2: continue
			var edge := mini(v,n)*size+maxi(v,n)
			if not cache.edges.has(edge):
				cache.edges[edge] = line_clear(state,room,point((v%cols)*24.0+12.0,floor(float(v)/cols)*24.0+12.0),point((n%cols)*24.0+12.0,floor(float(n)/cols)*24.0+12.0),legacy)
			if not bool(cache.edges[edge]): continue
			prev[n] = v; queue[tail] = n; tail += 1
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
