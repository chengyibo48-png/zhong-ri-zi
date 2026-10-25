extends Node2D
var water_id: String="river"
var spot_name: String=""
var spot_id: String=""
var fishing_state: String="idle"
var state_elapsed: float=0.0
var state_value: float=0.0
var animation_time: float=0.0
var point: Dictionary={}
func _ready() -> void:
	for at: Dictionary in GameState.system_catalog.fishing.spots:
		if str(at.id)==spot_id:point=at
func set_fishing_state(next_state: String, value: float=0.0) -> void:
	if fishing_state!=next_state:state_elapsed=0.0
	fishing_state="idle" if next_state=="cancel" else next_state;state_value=value;queue_redraw()
func _process(delta: float) -> void:
	animation_time+=minf(delta,0.1);state_elapsed+=minf(delta,0.1)
	if fishing_state in ["caught","released","miss"] and state_elapsed>1.3:fishing_state="idle"
	queue_redraw()
func _draw() -> void:
	if point.is_empty():return
	var reduced: bool=str(GameState.visual_fx.get("motion","full"))=="reduced"
	var time: float=0.0 if reduced else animation_time
	var water:=Vector2(float(point.waterX),float(point.waterY))-global_position
	var session: Dictionary=GameState.fishing_snapshot()
	if not session.is_empty() and str(session.p.id)==spot_id:
		var landing: Dictionary=session.get("landing",point.landings[clampi(int(session.plan.get("depth",1)),0,2)])
		water=Vector2(float(landing.x),float(landing.y))-global_position
	var hotspot: bool=preload("res://scripts/fishing_rules.gd").hotspot(GameState.system_catalog.fishing,GameState.day)==spot_id
	_ring(water,13+sin(time*1.3),Color("c4e0d3",0.55))
	if hotspot:
		_ring(water+Vector2(8,-3),19+sin(time*2)*2,Color("e5ebc6",0.72))
		if not reduced:_fish(water+Vector2(sin(time*1.4)*13,cos(time)*2),0.45)
	if fishing_state=="idle":return
	var origin: Vector2=GameState.player_position-global_position
	var direction: Vector2=(water-origin).normalized()
	var tip: Vector2=origin+Vector2(0,-20)+direction*25
	var bobber:=water+Vector2(0,sin(time*2.0))
	if fishing_state=="cast":
		var progress:=clampf(state_elapsed/0.55,0,1)
		bobber=tip.lerp(water,progress)+Vector2(0,-sin(progress*PI)*22)
	elif fishing_state=="bite":bobber.y+=3+absf(sin(time*13))*3
	elif fishing_state=="fight":
		bobber+=Vector2(sin(time*6)*3,cos(time*7)*2)
		if not reduced:_fish(water+Vector2(12+sin(time*5)*4,-3),0.8)
	if fishing_state in ["cast","waiting","bite","fight"]:
		var control:=tip.lerp(bobber,0.55)+Vector2(0,-9)
		draw_polyline(PackedVector2Array([tip,control,bobber]),Color("e4dec4"),1.2,true)
		draw_rect(Rect2(bobber+Vector2(-1.5,-6),Vector2(3,5)),Color("c76b50"))
		draw_rect(Rect2(bobber+Vector2(-1.5,-1),Vector2(3,4)),Color("eee4bd"))
		if fishing_state=="bite":
			draw_circle(bobber+Vector2(8,-18),6,Color("f0d17c"));draw_string(ThemeDB.fallback_font,bobber+Vector2(6,-15),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("604d36"))
	else:
		_ring(water,8+state_elapsed*12,Color("dce6c3",maxf(0,1-state_elapsed/1.3)))
		if fishing_state=="caught":
			var id:=str(GameState.fishing.get("pending",{}).get("fish","fish"))
			var texture: Texture2D=preload("res://scripts/item_art.gd").texture_for(id,"items")
			if texture!=null:draw_texture_rect(texture,Rect2(origin+Vector2(4,-50),Vector2(30,23)),false)
func _ring(at: Vector2, radius: float, color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(25):var angle:=TAU*i/24;points.append(at+Vector2(cos(angle)*radius,sin(angle)*radius*0.32))
	draw_polyline(points,color,1.0,true)
func _fish(at: Vector2, alpha: float) -> void:
	draw_circle(at,2.6,Color(0.31,0.42,0.35,alpha));draw_line(at,at+Vector2(8,1),Color(0.31,0.42,0.35,alpha),2)
