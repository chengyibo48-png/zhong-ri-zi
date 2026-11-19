extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	var nav:RefCounted=preload("res://scripts/npc_navigation.gd").new();nav.refresh(s)
	var fixes:Array=[];var faults:Array=[]
	for room:String in preload("res://scripts/house_geometry.gd").all():
		s.current_interior=room
		var points:Array=preload("res://scripts/house_geometry.gd").points(room)
		points.append_array(s.system_catalog.interiors.layouts.get(room,{}).get("points",[]))
		for p:Dictionary in points:
			if not p.has("x"):continue
			var at:=Vector2(float(p.x),float(p.y))
			if not nav.blocked(s,room,at.x,at.y) and not nav.route(s,room,{"x":480,"y":567},{"x":at.x,"y":at.y}).is_empty():continue
			var fixed:Dictionary={}
			for radius:int in [8,16,24,32,40,48,56]:
				for direction:int in 16:
					var q:Vector2=at+Vector2.from_angle(direction*TAU/16)*radius
					if nav.blocked(s,room,q.x,q.y):continue
					if nav.route(s,room,{"x":480,"y":567},{"x":q.x,"y":q.y}).is_empty():continue
					fixed={"room":room,"id":str(p.id),"x":q.x,"y":q.y};break
				if not fixed.is_empty():break
			if fixed.is_empty():faults.append(str(p.id))
			else:fixes.append(fixed)
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/layout-corrections.json",FileAccess.WRITE);file.store_string(JSON.stringify({"fixes":fixes,"failures":faults},"\t"))
	print("Reachable corrections ",fixes.size()," / unresolved ",faults);quit(0 if faults.is_empty() else 1)
