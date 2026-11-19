extends Node2D
## Window light, wall details and directional floor shadows stay below furniture.
var world: Node2D
var beam_material: ShaderMaterial
var beams: Array[MeshInstance2D]=[]
var light: Dictionary={}
var home:=false
var barn:=false

static func profile(minutes: float, weather: Dictionary) -> Dictionary:
	var daylight:=sin(PI*clampf((minutes-360.0)/720.0,0.0,1.0))
	if int(weather.get("rain",0))>0:daylight*=.35
	if bool(weather.get("extreme",false)):daylight*=.45
	return {"sun":maxf(0.0,daylight),"night":preload("res://scripts/world_art.gd").night_factor(minutes),"offset":lerpf(-44.0,70.0,clampf((minutes-420.0)/600.0,0.0,1.0))}

func _ready() -> void:
	name="InteriorAtmosphere"
	home=str(GameState.interior_house().get("id",""))=="building-farm-12"
	barn=str(GameState.interior_house().get("id","")).begins_with("ranch-")
	beam_material=ShaderMaterial.new();beam_material.shader=preload("res://art/shaders/window_light.gdshader")
	if not barn:
		for i: int in range(2):
			var beam:=MeshInstance2D.new();beam.material=beam_material;add_child(beam);beams.append(beam)
	GameState.clock_changed.connect(refresh)
	GameState.domain_changed.connect(func(domain:String):
		if domain=="household":refresh())
	GameState.world_changed.connect(refresh)
	refresh()

func refresh() -> void:
	light=profile(GameState.minutes,GameState.weather_profile())
	beam_material.set_shader_parameter("strength",float(light.sun)*.17)
	for i: int in range(beams.size()):
		var x:=230.0 if i==0 else 715.0
		var slide:=float(light.offset)
		var vertices:=PackedVector2Array([Vector2(x-37,200),Vector2(x+37,200),Vector2(clampf(x+100+slide,112,848),423),Vector2(clampf(x-34+slide,112,848),423)])
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		beams[i].mesh=mesh
		beams[i].visible=true
		for f:Dictionary in preload("res://scripts/house_geometry.gd").profile(GameState.current_interior).get("fixtures",[]):
			if str(f.type)=="curtain" and int(f.get("window",1))==i and load("res://scripts/house_life.gd").state(GameState,GameState.current_interior,str(f.id)):beams[i].visible=false
	queue_redraw()

func _draw() -> void:
	if light.is_empty():return
	# Darken the wall/floor joint; it anchors the shell without occupying floor cells.
	for ring: int in range(8):
		draw_rect(Rect2(112,200+ring*1.2,736,1.3),Color(.20,.17,.13,.09*(1.0-float(ring)/8.0)))
	if not barn:
		for furniture: Node2D in world.furniture_visuals:
			var row: Dictionary=furniture.row
			var width:=float(row.get("w",64.0))*.72
			var length:=24.0 if str(row.get("kind",""))=="shelf" else 12.0
			var point:=furniture.position
			var offset:=Vector2(float(light.offset)*.18,length)
			for ring: int in range(3):
				var spread:=float(ring)*1.5
				var polygon:=PackedVector2Array([point+Vector2(-width*.5-spread,-2),point+Vector2(width*.5+spread,-2),point+offset+Vector2(width*.43+spread,4),point+offset+Vector2(-width*.43-spread,4)])
				draw_colored_polygon(polygon,Color(.19,.16,.12,.023*float(light.sun)))
	if home:
		preload("res://scripts/interior_details.gd").draw(self,"shelf",Rect2(406,151,128,44),float(light.night))
		preload("res://scripts/interior_details.gd").draw(self,"herbs",Rect2(550,147,24,43),float(light.night))
		preload("res://scripts/interior_details.gd").draw(self,"lantern",Rect2(783,144,22,48),float(light.night))
		if float(light.night)>.01:
			for ring: int in range(12):
				var size:=1.0-float(ring)/12.0
				var points:=PackedVector2Array()
				for j: int in range(32):
					var angle:=TAU*j/32.0
					points.append(Vector2(794,224)+Vector2(cos(angle)*72.0,sin(angle)*28.0)*size)
				draw_colored_polygon(points,Color(1,.66,.27,.018*float(light.night)))
