extends Node2D
const WATER=preload("res://scripts/water_geometry.gd")
var water_id:String="river"
var spot_name:String=""
var spot_id:String=""
var fishing_state:String="idle"
var state_elapsed:=0.0
var state_value:=0.0
var animation_time:=0.0
var point:Dictionary={}
var columns:Dictionary={}
var actor:Node
var last_landing:=Vector2.ZERO
var redraw_elapsed:=0.0
var last_tip:=Vector2.ZERO
var last_bobber:=Vector2.ZERO
var clipped_water_effects:=0
func _ready()->void:
	for at:Dictionary in GameState.system_catalog.fishing.spots:
		if str(at.id)==spot_id:point=at;last_landing=Vector2(float(at.waterX),float(at.waterY))
	var scene:Node=get_tree().current_scene
	if scene!=null and scene.get("ground_layer")!=null:columns=scene.ground_layer.get_meta("visual_columns",{})
func set_fishing_state(next_state:String,value:float=0.0)->void:
	var changed:bool=fishing_state!=next_state
	if changed:state_elapsed=0.0
	fishing_state="idle" if next_state=="cancel" else next_state;state_value=value
	var session:Dictionary=GameState.fishing_session.game
	if not session.is_empty() and str(session.p.id)==spot_id:
		var landing:Dictionary=session.get("landing",{})
		if landing.has("x"):last_landing=Vector2(float(landing.x),float(landing.y))
	if not is_instance_valid(actor):actor=get_tree().get_first_node_in_group("player")
	if changed:queue_redraw()
func _process(delta:float)->void:
	animation_time+=minf(delta,.1);state_elapsed+=minf(delta,.1);redraw_elapsed+=delta
	if fishing_state in ["caught","released","miss"] and state_elapsed>1.3:
		if fishing_state!="caught" or GameState.fishing.get("pending",{}).is_empty():
			if is_instance_valid(actor) and is_instance_valid(actor.character_visual):actor.character_visual.set_fishing_pose("idle",0)
		fishing_state="idle"
	if columns.is_empty():
		var scene:Node=get_tree().current_scene
		if scene!=null and scene.get("ground_layer")!=null:columns=scene.ground_layer.get_meta("visual_columns",{})
	var interval:float=.25 if fishing_state=="idle" else 1.0/24.0
	if redraw_elapsed>=interval:redraw_elapsed=0.0;queue_redraw()
func _safe(candidate:Vector2,origin:Vector2,radius:Vector2=Vector2(4,5))->Vector2:
	if columns.is_empty():return origin
	for weight:float in [1.0,.66,.33,0.0]:
		var at:Vector2=origin.lerp(candidate,weight)
		if WATER.clear_water(columns,at,radius):return at
	return origin
func _water_line(a:Vector2,b:Vector2,color:Color,width:float=1.0)->void:
	if columns.is_empty():return
	if WATER.is_water(columns,to_global(a)) and WATER.is_water(columns,to_global(b)) and WATER.is_water(columns,to_global((a+b)*.5)):draw_line(a,b,color,width,true)
	else:clipped_water_effects+=1
func _ring(world:Vector2,radius:float,color:Color)->void:
	var center:Vector2=to_local(world)
	for i:int in 20:
		var a:float=TAU*i/20.0;var z:float=TAU*(i+1)/20.0
		_water_line(center+Vector2(cos(a)*radius,sin(a)*radius*.33),center+Vector2(cos(z)*radius,sin(z)*radius*.33),color)
func _shadow(world:Vector2,angle:float,alpha:float)->void:
	if columns.is_empty() or not WATER.clear_water(columns,world,Vector2(12,8)):return
	var center:Vector2=to_local(world);var shape:=PackedVector2Array()
	for p:Vector2 in [Vector2(-7,0),Vector2(-3,-3),Vector2(5,-2),Vector2(9,0),Vector2(5,2),Vector2(-3,3)]:shape.append(center+p.rotated(angle))
	draw_colored_polygon(shape,Color(.18,.32,.28,alpha))
	var tail:=PackedVector2Array()
	for p:Vector2 in [Vector2(-6,0),Vector2(-11,4),Vector2(-11,-4)]:tail.append(center+p.rotated(angle))
	draw_colored_polygon(tail,Color(.18,.32,.28,alpha))
func _draw()->void:
	if point.is_empty():return
	var reduced:bool=str(GameState.visual_fx.get("motion","full"))=="reduced"
	var time:float=0.0 if reduced else animation_time
	if fishing_state=="idle":
		# This is an actionable bank location, not a decorative water ripple.
		# Keep it visible before a fishing session starts, without an interaction ring.
		var sign:=StyleBoxFlat.new()
		sign.bg_color=Color("f2e8d2");sign.border_color=Color("8a7958");sign.set_border_width_all(1);sign.set_corner_radius_all(3)
		draw_line(Vector2(0,-13),Vector2(0,2),Color("816442"),3)
		draw_style_box(sign,Rect2(-24,-35,48,22))
		draw_string(ThemeDB.fallback_font,Vector2(-24,-19),"钓鱼",HORIZONTAL_ALIGNMENT_CENTER,48,12,Color("354b40"))
		if not reduced and preload("res://scripts/fishing_rules.gd").hotspot(GameState.system_catalog.fishing,GameState.day)==spot_id:
			_shadow(_safe(last_landing+Vector2(sin(time*.7)*12,0),last_landing,Vector2(12,8)),sin(time*.4)*.2,.12)
		return
	var origin:Vector2=GameState.player_position;var water:Vector2=last_landing
	var direction:Vector2=(water-origin).normalized();var tip:Vector2=origin+Vector2(0,-20)+direction*25
	if is_instance_valid(actor) and is_instance_valid(actor.character_visual):
		var attachments:Dictionary=actor.character_visual.contact_attachments()
		if str(attachments.get("kind","")).begins_with("fish"):tip=Vector2(attachments.tip)
	var session:Dictionary=GameState.fishing_session.game
	var current:bool=not session.is_empty() and str(session.p.id)==spot_id
	if current:time=0.0 if reduced else float(session.time)
	if current and fishing_state=="fight":
		water=_safe(origin.lerp(last_landing,.42+.58*float(session.get("distance",1))),last_landing,Vector2(12,8))
	var elapsed:float=float(session.phaseTime) if current else state_elapsed
	var bobber:Vector2=_safe(water+Vector2(0,sin(time*2)*.7),water)
	if fishing_state=="cast":
		var progress:float=clampf(elapsed/.55,0,1);bobber=tip.lerp(water,progress)+Vector2(0,-sin(progress*PI)*34)
	elif fishing_state=="bite" or current and bool(session.get("nibble",false)):
		bobber=_safe(water+Vector2(0,4+absf(sin(time*12))*1.5 if fishing_state=="bite" else 1.3+sin(time*9)),water)
	elif fishing_state=="fight":
		var amplitude:float=1.0 if reduced else 3.0+state_value*3
		bobber=_safe(water+Vector2(sin(time*3)*amplitude,cos(time*4)*amplitude*.35),water)
		_shadow(_safe(water+direction*14+Vector2(sin(time*2)*7,0),water,Vector2(12,8)),direction.angle()+sin(time*2)*.3,.22)
		if current and str(session.get("fishPhase",""))=="surge":_ring(bobber,8+fmod(elapsed*10,10),Color(.78,.87,.78,.35))
	last_tip=tip;last_bobber=bobber
	if fishing_state in ["aim","cast","waiting","bite","fight"]:
		var a:Vector2=to_local(tip);var z:Vector2=to_local(bobber)
		var sag:float=lerpf(18.0,2.0,state_value) if fishing_state=="fight" else 12.0
		var control:Vector2=(a+z)*.5+Vector2(0,sag)
		var curve:=PackedVector2Array()
		for index:int in 21:
			var t:float=index/20.0;curve.append(a*(1-t)*(1-t)+control*2*t*(1-t)+z*t*t)
		if fishing_state=="aim":
			for index:int in range(0,20,2):draw_line(curve[index],curve[index+1],Color(.88,.87,.73,.35),1,true)
		else:draw_polyline(curve,Color(.89,.87,.74,.9),1.1,true)
		var tilt:float=sin(time*3)*.12 if not reduced else 0.0
		if fishing_state=="fight":tilt=sin(time*4)*.2+direction.x*state_value*.35
		draw_set_transform(z,tilt)
		draw_line(Vector2(0,-8),Vector2(0,-1),Color("b45b45"),2.8,true);draw_line(Vector2(0,-1),Vector2(0,4),Color("f1e5bc"),2.8,true)
		draw_circle(Vector2(0,-8),1.9,Color("e9c47e"));draw_set_transform(Vector2.ZERO)
		if fishing_state in ["waiting","bite","fight"]:_ring(bobber,6+fmod(time*2,3),Color(.77,.87,.77,.28))
		if fishing_state=="waiting" and elapsed<.7:_ring(water,4+elapsed*24,Color(.87,.92,.83,.55*(1-elapsed/.7)))
	else:
		_ring(water,7+state_elapsed*14,Color(.81,.89,.78,maxf(0,.65-state_elapsed*.5)))
		if fishing_state=="released":_shadow(_safe(water+direction*state_elapsed*16,water,Vector2(12,8)),direction.angle(),maxf(0,.28-state_elapsed*.2))
