extends RefCounted
## Resident identity and presentation are read-only; no rewards, schedules or save fields here.
static var profiles:Dictionary={}
static func all()->Dictionary:
	if profiles.is_empty():
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/resident_life_profiles.json"))
		if value is Dictionary:profiles=value
	return profiles
static func profile(id:String)->Dictionary:return all().get(id,{})
static func sample(id:String,clock:float,context:Dictionary={})->Dictionary:
	var p:Dictionary=profile(id)
	if p.is_empty():return {}
	var phase:float=fposmod(clock+float(p.phase),float(p.cycle));var duration:float=float(p.activeDuration)
	var gain:float=smoothstep(0,.28,phase)*(1.0-smoothstep(duration-.4,duration,phase))
	var moving:bool=bool(context.get("walking",false));var sleep:bool=str(context.get("key",""))=="night"
	if moving or sleep or bool(context.get("explicit",false)) or bool(context.get("reduced",false)):gain=0
	var active:bool=phase<duration;var wave:float=sin(clock*float(p.tempo)*2.2+float(p.phase))
	var kind:String=str(p.workKind);var hands:float=.035 if kind=="read" else .055 if kind=="pack" else .07 if kind=="steam" else .045
	return {"gain":gain,"head":float(p.headTilt)*wave*gain,"shoulder":wave*.20*gain,"arm_near":hands*sin(phase*2.4)*gain,"arm_far":-hands*.45*sin(phase*2.4-.2)*gain,"stance":float(p.stance),"label":"在家歇息" if sleep else str(p.idleLabel if active else p.restLabel),"stage":"prepare" if phase<.28 else "execute" if phase<duration-.4 else "recover" if phase<duration else "rest"}
static func station(state:Node,id:String,room:String,plan:Dictionary,clock:float)->Dictionary:
	if room!="home-"+id:return {}
	var p:Dictionary=profile(id)
	if p.is_empty():return {}
	var wanted:String=str(p.workStation);var key:String=str(plan.get("key",""))
	if key in ["night","evening"]:wanted="bed" if key=="night" else "table"
	elif key=="lunch":wanted="table"
	elif fposmod(clock+float(p.phase),60)>46:wanted="table"
	for row:Dictionary in state.system_catalog.interiors.layouts.get(room,{}).get("rows",[]):
		if str(row.kind)!=wanted:continue
		var point:Dictionary=row.get("point",{})
		if point.is_empty():continue
		return {"x":float(point.x),"y":float(point.y)+6,"look_x":float(row.x),"look_y":float(row.y)-3,"station":str(point.get("id","")),"kind":str(p.workKind),"rest":wanted in ["bed","table"],"wait":8+float(p.activeDuration)}
	return {}
