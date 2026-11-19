extends RefCounted
## Authored physical furniture and optional home additions share one geometry source.
const G=preload("res://scripts/house_geometry.gd")
static func footprint(row:Dictionary)->Rect2:
	return Rect2(float(row.x)-float(row.w)*.5,float(row.y)-float(row.h),float(row.w),float(row.h)+18)
static func enabled(s:Node,room:String)->bool:
	return room!="building-farm-12" or bool(s.interior_state.get("household",{}).get("homePreset",false))
static func blocked_by_player(s:Node,row:Dictionary)->bool:
	var zone:Dictionary=s.system_catalog.building.zones.home;var defs:Dictionary=s.system_catalog.building.defs
	var size:float=float(zone.size);var cols:int=int(zone.cols);var area:Rect2=footprint(row).grow(10)
	# Rugs stay below furniture; volumetric player objects always take priority.
	for piece:Dictionary in s.building.get("layout",[]):
		if str(piece.get("zone",""))!="home" or str(piece.get("type","")) in ["rug","path"]:continue
		var d:Dictionary=defs.get(str(piece.type),{});var rotate:bool=posmod(int(piece.get("rotation",0)),2)==1;var cell:int=int(piece.cell)
		var r:=Rect2(float(zone.x)+(cell%cols)*size,float(zone.y)+floorf(float(cell)/cols)*size,float(d.get("h" if rotate else "w",1))*size,float(d.get("w" if rotate else "h",1))*size)
		if area.intersects(r):return true
	return false
static func rows(s:Node,room:String,preview:bool=false)->Array:
	if not preview and not enabled(s,room):return []
	var stamp:String="%s/%s/%s/%s"%[room,preview,s.building.get("revision",0),s.interior_state.get("household",{}).get("homePreset",false)]
	var cache:Dictionary=s.get_meta("house_life_rows",{})
	if cache.get("stamp")==stamp and is_same(cache.get("building"),s.building):return cache.rows
	var result:Array=[]
	for row:Dictionary in G.profile(room).get("furnishings",[]):
		if room=="building-farm-12" and blocked_by_player(s,row):continue
		result.append(row)
	s.set_meta("house_life_rows",{"stamp":stamp,"building":s.building,"rows":result})
	return result
static func fixture(room:String,id:String)->Dictionary:
	for f:Dictionary in G.profile(room).get("fixtures",[]):
		if str(f.id)==id:return f
	return {}
static func state(s:Node,room:String,id:String)->bool:
	var f:=fixture(room,id)
	return bool(s.interior_state.get("household",{}).get("fixtureStates",{}).get(id,f.get("default",false)))
static func points(s:Node,room:String)->Array:
	var result:Array=[];var visible:Array=[]
	for row:Dictionary in rows(s,room):visible.append(str(row.id))
	for f:Dictionary in G.profile(room).get("fixtures",[]):
		if room=="building-farm-12" and str(f.type)!="preset" and str(f.get("furniture","")) not in visible:continue
		var point:Dictionary=f.duplicate(true);point.kind="house-fixture";point.house=room;result.append(point)
	return result
static func condition(s:Node,p:Dictionary)->Dictionary:
	var room:String=str(p.get("house",s.current_interior));var f:=fixture(room,str(p.get("id","")));var reason:String=""
	if f.is_empty() or room!=s.current_interior:reason="物件已不在这间屋里。"
	elif not points(s,room).any(func(q:Dictionary)->bool:return str(q.id)==str(f.id)):reason="这里由你摆放的家具优先使用。"
	elif s.interior_position.distance_to(Vector2(float(f.x),float(f.y)))>56:reason="走到物件旁，再轻轻动手。"
	else:
		for id:String in s.interior_npc_positions:
			if Vector2(s.interior_npc_positions[id]).distance_to(Vector2(f.x,f.y))<16:reason="有人正在使用这里，稍等一会儿。";break
	return {"ready":reason=="","reason":reason,"fixture":f,"room":room}
static func preview(s:Node)->Dictionary:
	var proposed:Array=G.profile("building-farm-12").get("furnishings",[]);var accepted:Array=rows(s,"building-farm-12",true)
	return {"rows":accepted,"added":accepted.size(),"skipped":proposed.size()-accepted.size(),"active":enabled(s,"building-farm-12")}
