extends RefCounted
## Continuous actor lighting; cache lamp influence separately from the environment.
const GRID_SIZE:=12.0
const CACHE_LIMIT:=512
static var samples:Dictionary={}
static var lamps:Dictionary={}
static var stamp:=""
static var lamp_stamp:=""
static var building_source:Dictionary={}
static var environment:Dictionary={}
static var neutral:Dictionary={"ambient":Color.WHITE,"warm":0.0,"shadow":.8,"projection":Vector2(4,2)}
static func _bucket(at:Vector2)->Vector2i:return Vector2i(floori(at.x/128),floori(at.y/128))
static func _lamp(at:Vector2,room:String)->void:
	var key:=room+str(_bucket(at))
	if not lamps.has(key):lamps[key]=[]
	lamps[key].append(at)
static func refresh(state:Node)->void:
	var room:=str(state.current_interior)
	var registry:Script=preload("res://scripts/scene_lighting.gd")
	registry.refresh(state)
	var next_lamps:String=registry.stamp+"/"+str(registry.rebuilds)
	if next_lamps!=lamp_stamp or not is_same(building_source,state.building):
		building_source=state.building;lamp_stamp=next_lamps;samples.clear();lamps.clear()
		for source:Dictionary in registry.sources:
			var key:=str(source.room)+str(_bucket(source.ground))
			if not lamps.has(key):lamps[key]=[]
			lamps[key].append(source)
	var weather:Dictionary=state.weather_profile()
	var next:="%d/%d/%s/%s/%s"%[state.get_instance_id(),state.day,str(state.minutes),weather.get("rain",0),room]
	if next==stamp:return
	stamp=next
	var night:float=preload("res://scripts/world_art.gd").night_factor(float(state.minutes))
	var rain:=clampf(float(weather.get("rain",0)),0,1)
	var ambient:=Color.WHITE.lerp(Color(.92,.95,1.035),night*.7).lerp(Color(.96,.98,1.0),rain*.7)
	if room!="" and room!="ranch-meadow":ambient=Color(1.0,.985,.96)
	environment={"ambient":ambient,"shadow":.70 if room!="" and room!="ranch-meadow" else lerpf(1.0,.55,maxf(night,rain)),"projection":preload("res://scripts/scene_lighting.gd").sun(state.minutes),"lamp_strength":registry.strength(state.minutes,0,room)}
static func _grid_warm(cell:Vector2i,room:String)->float:
	var key:=room+str(cell)
	if samples.has(key):return float(samples[key])
	var at:=Vector2(cell)*GRID_SIZE
	var bucket:=_bucket(at)
	var warm:=0.0
	for y in range(-1,2):
		for x in range(-1,2):
			for lamp:Dictionary in lamps.get(room+str(bucket+Vector2i(x,y)),[]):
				warm=maxf(warm,(1.0-smoothstep(18,float(lamp.range),at.distance_to(lamp.ground)))*float(lamp.strength))
	while samples.size()>=CACHE_LIMIT:samples.erase(samples.keys()[0])
	samples[key]=warm
	return warm
static func sample(target:CanvasItem)->Dictionary:
	if not target is Node2D or not target.is_inside_tree():return neutral
	var state:Node=target.get_tree().root.get_node_or_null("GameState")
	if state==null:return neutral
	refresh(state)
	var result:=environment.duplicate()
	var strength:=float(result.lamp_strength)
	result.erase("lamp_strength")
	result.warm=0.0
	if strength<=0:return result
	var grid:Vector2=(target as Node2D).global_position/GRID_SIZE
	var cell:=Vector2i(floori(grid.x),floori(grid.y))
	var fraction:=grid-Vector2(cell)
	var room:=str(state.current_interior)
	# Blend shared corner samples instead of returning the first actor's color for
	# an entire spatial cell. Adjacent cells agree exactly at their shared edge.
	var top:=lerpf(_grid_warm(cell,room),_grid_warm(cell+Vector2i.RIGHT,room),fraction.x)
	var bottom:=lerpf(_grid_warm(cell+Vector2i.DOWN,room),_grid_warm(cell+Vector2i.ONE,room),fraction.x)
	result.warm=lerpf(top,bottom,fraction.y)*strength
	return result
static func apply(material:ShaderMaterial,light:Dictionary)->void:
	material.set_shader_parameter("actor_ambient",light.get("ambient",Color.WHITE))
	material.set_shader_parameter("actor_warm",float(light.get("warm",0)))
static func shadow(target:CanvasItem,light:Dictionary,feet:Array=[])->void:
	var projection:Vector2=light.get("projection",Vector2(4,2))
	var strength:=float(light.get("shadow",.8))
	_oval(target,projection*.5+Vector2(0,1),Vector2(20+projection.length(),5.5),.07*strength)
	if feet.is_empty():
		_oval(target,Vector2(-2.8,.4),Vector2(7,2.4),.14*strength)
		_oval(target,Vector2(2.8,.4),Vector2(7,2.4),.14*strength)
	else:
		for foot:Vector2 in feet:
			var contact:=1.0-smoothstep(.4,3.0,absf(foot.y))
			_oval(target,Vector2(foot.x,.4),Vector2(7,2.4),lerpf(.035,.14,contact)*strength)
static func _oval(target:CanvasItem,center:Vector2,size:Vector2,opacity:float)->void:
	for ring in range(3):
		var points:=PackedVector2Array()
		for i in range(24):points.append(center+Vector2(cos(i*TAU/24),sin(i*TAU/24))*size*(.5-ring*.09))
		target.draw_colored_polygon(points,Color(.20,.22,.17,opacity/3))
