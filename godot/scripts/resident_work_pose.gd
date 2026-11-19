extends RefCounted
## Only actual authored workstations can supply a contact target.
static func describe(state:Node,id:String,at:Vector2,room:String,runtime:Dictionary)->Dictionary:
	var identity:Dictionary=preload("res://scripts/resident_life.gd").profile(id)
	if identity.is_empty() or room!="home-"+id or bool(runtime.get("listening",false)) or bool(runtime.get("walking",false)) or str(runtime.get("plan",{}).get("key","")) not in ["work","morning","shelter","housework"]:return {}
	var rows:Array=state.system_catalog.interiors.layouts.get(room,{}).get("rows",[])
	for row:Dictionary in rows:
		if str(row.get("kind",""))!=str(identity.workStation) or row.get("point",{}).is_empty():continue
		var surface:=Vector2(float(row.x),float(row.y)-3)
		if at.distance_to(surface)>64:return {}
		return {"kind":str(identity.workKind),"target":surface,"station":str(row.point.get("id","")),"existing_prop":true,"weight":1.0}
	return {}
