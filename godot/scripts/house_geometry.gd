extends RefCounted
## One authored source for the room shell, navigation, contact and camera.
static var _rooms:Dictionary={}
static func all()->Dictionary:
	if _rooms.is_empty():_rooms=JSON.parse_string(FileAccess.get_file_as_string("res://data/house_profiles.json")).rooms
	return _rooms
static func profile(id:String)->Dictionary:return all().get(id,{})
static func bounds(id:String)->Rect2:
	var r:Array=profile(id).get("bounds",[102,104,756,500]);return Rect2(r[0],r[1],r[2],r[3])
static func floor_rect(id:String)->Rect2:
	var r:=bounds(id);return Rect2(r.position+Vector2(10,96),r.size-Vector2(20,125))
static func walk_rect(id:String)->Rect2:
	var r:Array=profile(id).get("walkBounds",[113,205,734,397]);return Rect2(r[0],r[1],r[2],r[3])
static func walls(id:String)->Array[Rect2]:
	var r:=bounds(id);var gate:float=float(profile(id).get("exit",[480,590])[0])
	return [Rect2(r.position-Vector2(32,34),Vector2(r.size.x+64,34)),Rect2(r.position-Vector2(32,0),Vector2(34,r.size.y)),Rect2(r.end.x-2,r.position.y,34,r.size.y),Rect2(r.position.x-32,r.end.y-28,gate-35-r.position.x+32,34),Rect2(gate+35,r.end.y-28,r.end.x-gate-3,34)]
static func spawn(id:String)->Vector2:
	var p:Array=profile(id).get("spawn",[480,567]);return Vector2(p[0],p[1])
static func points(id:String)->Array:
	var c:=profile(id)
	if c.is_empty():return []
	var rows:Array=[]
	for kind:String in ["theme","seat","browse"]:
		var source:Dictionary=c.get({"theme":"activityPoint","seat":"seatPoint","browse":"browsePoint"}[kind],{})
		if source.is_empty():continue
		var point:=source.duplicate(true)
		point.merge({"id":id+":house:"+kind,"house":id,"kind":"house-activity","activity":kind,"name":c.title if kind=="theme" else "静静观察伙伴" if bool(c.barn) and kind=="seat" else "坐下歇一会儿" if kind=="seat" else "翻看与整理屋里的记录"},true)
		rows.append(point)
	rows.append_array(load("res://scripts/house_life.gd").points(Engine.get_main_loop().root.get_node("GameState"),id))
	return rows
static func resolve(id:String,point_id:String)->Dictionary:
	for p:Dictionary in points(id):
		if str(p.id)==point_id:return p
	return {}
static func recover(state:Node)->void:
	if state.current_interior=="" or profile(state.current_interior).is_empty():return
	var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(state)
	var p:Dictionary=state.player_navigation_position()
	if nav.blocked(state,state.current_interior,float(p.x),float(p.y)):
		var safe:Dictionary=nav.safe(state,state.current_interior,p)
		state.interior_position=Vector2(float(safe.x),float(safe.y))
