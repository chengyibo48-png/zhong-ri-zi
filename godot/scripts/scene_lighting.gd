extends RefCounted
## Shared light identities and projected ground positions; no gameplay writes.
static var sources:Array[Dictionary]=[]
static var stamp:=""
static var building_ref:Dictionary={}
static var world_ref:Dictionary={}
static var _glow:GradientTexture2D
static var rebuilds:=0
static func strength(minutes:float,rotation:int=0,room:String="")->float:
	return (.6 if room!="" else preload("res://scripts/world_art.gd").night_factor(minutes))*(.32 if posmod(rotation,4)==2 else 1.0)
static func sun(minutes:float)->Vector2:
	return Vector2(5,2).lerp(Vector2(-5,2),clampf((minutes-420)/720,0,1))
static func refresh(state:Node)->void:
	var next:="%d/%s/%s"%[state.get_instance_id(),state.building.get("revision",0),state.current_interior]
	next+="/"+str(state.get_meta("domain_revisions",{}).get("household",0))+"/"+str(state.interior_state.get("household",{}).get("homePreset",false))
	if next==stamp and is_same(building_ref,state.building) and is_same(world_ref,state.world_village):return
	stamp=next;building_ref=state.building;world_ref=state.world_village;sources.clear();rebuilds+=1
	for house:Dictionary in state.world_village.get("houses",[]):
		var door:Dictionary=house.get("door",{})
		if door.is_empty():continue
		var at:=Vector2(float(door.x),float(door.y))
		sources.append({"id":"house:"+str(house.get("id","")),"room":"","position":at+Vector2(0,-30),"ground":at,"direction":0,"strength":1.0,"range":112.0,"kind":"house"})
	sources.append({"id":"farm:hearth","room":"","position":Vector2(2793,1668),"ground":Vector2(2793,1698),"direction":0,"strength":1.0,"range":112.0,"kind":"hearth"})
	var zones:Dictionary=state.system_catalog.get("building",{}).get("zones",{})
	var defs:Dictionary=state.system_catalog.get("building",{}).get("defs",{})
	for piece:Dictionary in state.building.get("layout",[]):
		var kind:=str(piece.get("type",""))
		if kind not in ["lantern","stoneLantern"]:continue
		var zone:Dictionary=zones.get(str(piece.get("zone","")),{});var definition:Dictionary=defs.get(kind,{})
		if zone.is_empty() or definition.is_empty():continue
		var room:=""
		if str(piece.zone)=="home":
			room=str(state.current_interior)
			if room=="" or str(state.house_data(room).get("name",""))!="爷爷的老屋":continue
		var rotation:=posmod(int(piece.get("rotation",0)),4);var cell:=int(piece.get("cell",0));var size:=float(zone.size);var cols:=int(zone.cols)
		var w:=float(definition.get("w",1) if rotation%2==0 else definition.get("h",1));var h:=float(definition.get("h",1) if rotation%2==0 else definition.get("w",1))
		var at:=Vector2(float(zone.x)+(cell%cols+w*.5)*size,float(zone.y)+(floorf(float(cell)/cols)+h*.5)*size)
		var footprint:=Rect2(at-Vector2(w,h)*size*.5,Vector2(w,h)*size)
		var art:Script=load("res://scripts/built_furniture_art.gd");var rect:Rect2=art.sprite_rect(kind,rotation,footprint)
		var flame:Vector2=rect.position+rect.size*Vector2(.5,.56) if kind=="lantern" else art.lamp_window(rotation,rect)
		sources.append({"id":"furniture:"+str(piece.get("key",0)),"room":room,"position":flame,"ground":at,"direction":rotation,"strength":.32 if rotation==2 else 1.0,"range":112.0,"kind":kind})
	for f:Dictionary in load("res://scripts/house_life.gd").points(state,state.current_interior):
		if str(f.type)!="lamp" or not load("res://scripts/house_life.gd").state(state,state.current_interior,str(f.id)):continue
		var at:=Vector2(float(f.get("emitterX",f.contactX)),float(f.get("emitterY",f.contactY)))
		sources.append({"id":str(f.id),"room":state.current_interior,"position":at,"ground":Vector2(f.x,f.y-20),"direction":0,"strength":.65,"range":96.0,"kind":"house-lamp"})
static func glow_texture()->GradientTexture2D:
	if _glow==null:
		var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.25,.65,1]);gradient.colors=PackedColorArray([Color(1,.69,.26,.42),Color(1,.65,.22,.18),Color(1,.58,.16,.045),Color(1,.58,.16,0)])
		_glow=GradientTexture2D.new();_glow.gradient=gradient;_glow.width=64;_glow.height=64;_glow.fill=GradientTexture2D.FILL_RADIAL;_glow.fill_from=Vector2(.5,.5);_glow.fill_to=Vector2(1,.5)
	return _glow
