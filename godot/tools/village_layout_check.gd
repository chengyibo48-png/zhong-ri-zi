extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	var nav:RefCounted=preload("res://scripts/npc_navigation.gd").new();nav.refresh(s)
	var faults:Array=[];var count:int=0;var anchors:Array=[]
	for room:String in preload("res://scripts/house_geometry.gd").all():
		s.current_interior=room
		var points:Array=preload("res://scripts/house_geometry.gd").points(room)
		points.append_array(s.system_catalog.interiors.layouts.get(room,{}).get("points",[]))
		for p:Dictionary in points:
			if not p.has("x"):continue
			count+=1;var target:Dictionary={"x":p.x,"y":p.y}
			if nav.blocked(s,room,p.x,p.y) or nav.route(s,room,{"x":480,"y":567},target).is_empty():faults.append({"room":room,"id":p.id,"x":p.x,"y":p.y})
			if str(p.get("kind",""))=="house-fixture" and p.get("type")!="preset":
				if Vector2(p.x,p.y).distance_to(Vector2(p.contactX,p.contactY))>42:anchors.append(p.id)
	var result:Dictionary={"points":count,"unreachable":faults,"unreachableHands":anchors}
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/village-layout-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if faults.is_empty() and anchors.is_empty() else 1)
