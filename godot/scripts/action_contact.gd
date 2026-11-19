extends RefCounted
## Shared local contact geometry for the rig, particles and precise approach.
const KINDS := ["hoe","dig","chop","cut","water","seed","harvest","gather"]
static func supports(kind: String) -> bool:return kind in KINDS
static func stand_distance(kind:String)->float:return 12.0 if kind in ["harvest","gather"] else 16.0 if kind in ["hoe","dig","chop","cut"] else 20.0
static func describe(action: Dictionary) -> Dictionary:
	if action.has("houseContact"):
		var h:Dictionary=action.houseContact;var at:=Vector2(float(h.x),float(h.y))
		return {"kind":"gather","identity":str(action.get("targetId","")),"surface":at,"target":at,"phase":float(action.get("progress",0))}
	var kind:=str(action.get("kind",""))
	if not supports(kind) and not kind.begins_with("fish"):return {}
	var target:=Vector2(float(action.get("x",0)),float(action.get("y",0)))
	if kind.begins_with("fish") and action.has("waterX"):target=Vector2(float(action.waterX),float(action.waterY))
	var radius:=12.0 if kind in ["hoe","dig","water","seed"] else 5.0
	var surface:=target-target.normalized()*minf(radius,target.length())
	surface.y-=float({"chop":12.0,"cut":14.0,"harvest":14.0,"gather":12.0}.get(kind,0.0))
	return {"kind":kind,"identity":str(action.get("targetKind",""))+"/"+str(action.get("targetId",action.get("index",""))),"surface":surface,"phase":float(action.get("progress",0)),"target":target}

static func align(frame:Dictionary,contact:Dictionary,direction:String,components:Callable)->void:
	if contact.is_empty():return
	var kind:=str(contact.kind);var p:=clampf(float(contact.phase),0,1)
	var surface:Vector2=contact.surface
	var weight:=smoothstep(.36,.50,p)*(1.0-smoothstep(.62,.88,p))
	if kind=="seed":weight=smoothstep(.05,.20,p)*(1.0-smoothstep(.80,1.0,p))
	var tool:Dictionary={};var near:Dictionary={};var far:Dictionary={}
	for row:Dictionary in frame.commands:
		match str(row.get("role","")):
			"tool":tool=row
			"near_arm":near=row
			"far_arm":far=row
	var shoulder:Vector2=frame.sockets.shoulder_near
	var hand:Vector2=frame.sockets.hand
	var tip:=Vector2(.5,.95)
	var size:=Vector2.ZERO
	var offset:=Vector2.ZERO
	var rigid:=kind in ["hoe","dig","chop","cut"] and not tool.is_empty()
	if not tool.is_empty():
		var part:Dictionary=components.call(str(tool.pack),str(tool.key),direction)
		var region:Rect2=part.region
		size=region.size*minf(float(tool.size.x)/region.size.x,float(tool.size.y)/region.size.y)
		if kind=="chop":tip=Vector2(.1,.1)
		elif kind=="cut":tip=Vector2(.1,.12)
		elif kind.begins_with("fish"):tip=Vector2(.5,.02)
		offset=(tip-Vector2(tool.pivot))*size
	if weight>0 and (rigid or kind in ["harvest","gather","seed"]):
		var reach:=15.8
		var distance:=shoulder.distance_to(surface)
		var extra:=maxf(0.0,distance-reach-offset.length()+.2)
		var shift:Vector2=(surface-shoulder).normalized()*minf(6.0,extra)
		shift*=weight
		if shift.length_squared()>.00001:
			for row:Dictionary in frame.commands:
				if str(row.get("role","")) in ["torso","head","hair","hat","hood","bag"]:row.at+=shift
			shoulder+=shift;frame.sockets.shoulder_near=shoulder;frame.sockets.shoulder_far+=shift
			frame.sockets.chest+=shift;frame.sockets.head+=shift;frame.sockets.secondary_hand+=shift
			if not far.is_empty():
				far.at+=shift
				if far.has("joints"):
					for i in far.joints.size():far.joints[i]+=shift
		var desired:Vector2=surface
		if kind=="seed":desired=shoulder+Vector2(-6 if direction=="left" else 6 if direction=="right" else -3,12)
		if rigid:desired=preload("res://scripts/player_rig.gd").elbow(shoulder,surface,reach,maxf(1,offset.length()),-1 if direction=="left" else 1)
		if desired.distance_to(shoulder)>16.5:desired=shoulder+(desired-shoulder).normalized()*16.5
		hand=hand.lerp(desired,weight)
		frame.sockets.hand=hand
		if rigid:
			tool.at=hand;tool.angle=lerp_angle(float(tool.angle),(surface-hand).angle()-offset.angle(),weight)
		var near_axis:Vector2=(hand-shoulder).normalized()
		if not near.is_empty():
			var wrist:=hand-near_axis*1.9
			near.joints=PackedVector2Array([shoulder,preload("res://scripts/player_rig.gd").elbow(shoulder,wrist,7.2,7.0,.55 if direction=="left" else -.55),wrist,hand+near_axis*.6])
		if rigid and not far.is_empty():
			var secondary:=hand+Vector2(0,2.5*(1.0 if kind=="chop" else -1.0)).rotated(float(tool.angle))
			var start:Vector2=frame.sockets.shoulder_far;var axis:Vector2=(secondary-start).normalized();var wrist:=secondary-axis*1.9
			frame.sockets.secondary_hand=secondary
			far.joints=PackedVector2Array([start,preload("res://scripts/player_rig.gd").elbow(start,wrist,7.2,7.0,-.5 if direction=="left" else .5),wrist,secondary+axis*.6])
	var emitter:=hand
	var impact:=hand
	if not tool.is_empty():
		impact=Vector2(tool.at)+offset.rotated(float(tool.angle))
		if kind=="water":
			var mouth:=Vector2(.02,.30) if direction=="left" else Vector2(.98,.30) if direction=="right" else Vector2(.5,.65)
			emitter=Vector2(tool.at)+((mouth-Vector2(tool.pivot))*size).rotated(float(tool.angle))
	frame.contact=contact.duplicate(true);frame.contact.emitter=emitter;frame.contact.impact=impact;frame.contact.error=impact.distance_to(surface)

static func draw_effects(canvas:CanvasItem,frame:Dictionary)->void:
	var c:Dictionary=frame.get("contact",{})
	if c.is_empty():return
	var p:=float(c.phase);var kind:=str(c.kind)
	var from:Vector2=c.emitter;var to:Vector2=c.surface
	if kind=="water" and p>.25 and p<.80:
		var stream:=PackedVector2Array()
		for i in range(13):
			var t:=float(i)/12.0
			stream.append(from.lerp(to,t)+Vector2(0,5*t*(1.0-t)))
		canvas.draw_polyline(stream,Color(.64,.82,.86,.72),1.25,true)
	elif kind=="seed" and p>.35 and p<.78:
		for i in range(5):
			var t:=fposmod(p*3+float(i)*.19,1.0)
			canvas.draw_circle(from.lerp(to+Vector2((i-2)*2,0),t)+Vector2(0,-sin(t*PI)*3),.7,Color("d7bd7b"))
	elif kind in ["hoe","dig","chop","cut"] and p>.50 and p<.64 and float(c.error)<4 and load("res://scripts/life_presentation.gd").animate():
		for i in range(4):
			var t:=(p-.50)/.14
			canvas.draw_circle(to+Vector2((i-1.5)*6*t,-sin(t*PI)*(3+i)),maxf(.3,1-t),Color("b79c72"))
