extends Node2D
## Pure presentation: no input, collision, saves or state writes.
const LAYOUT := preload("res://scripts/farm_layout.gd")
const SOIL_SHADER := preload("res://art/shaders/cultivated_soil.gdshader")
const EARTH := preload("res://art/world/terrain/cultivated_earth.png")
const TINTS := {"loam":Color(1.0,1.0,1.0),"sand":Color(1.12,1.08,1.0),"clay":Color(1.02,0.94,0.88),"humus":Color(0.86,0.90,0.84),"wetland":Color(0.90,0.95,0.92)}
var index := 0
var snapshot: Dictionary = {}
var soil_material: ShaderMaterial
func _ready() -> void:
	soil_material = ShaderMaterial.new()
	soil_material.shader = SOIL_SHADER
	soil_material.set_shader_parameter("earth_texture",EARTH)
	soil_material.set_shader_parameter("seed",float(index+1))
	material = soil_material
	set_process(false)
func set_state(data: Dictionary) -> void:
	visible = bool(data.get("tilled",false)) and not bool(data.get("removed",false))
	if not visible or soil_material == null: return
	var columns := LAYOUT.columns(index)
	var offset := index - LAYOUT.first(index)
	var joined := Vector2.ZERO
	if offset % columns > 0 and cultivated(index-1): joined.x = 1.0
	if offset % columns < columns-1 and cultivated(index+1): joined.y = 1.0
	var state := {"moisture":clampf(float(data.get("moisture",45))/100.0,0,1),"fertility":clampf(float(data.get("fertility",100))/100.0,0,1),"soil_tint":TINTS.get(str(data.get("soil_type","loam")),Color.WHITE),"joined":joined,"wetland":1.0 if str(data.get("soil_type","loam")) == "wetland" else 0.0,"fallow":1.0 if bool(data.get("fallow",false)) else 0.0,"planted":0.0 if str(data.get("crop","")) == "" else 1.0,"animate_water":0.0 if str(GameState.visual_fx.get("motion","full")) == "reduced" else 1.0}
	state.snow_cover = float(GameState.ground_conditions().get("snow",0.0))
	if state == snapshot: return
	snapshot = state
	for key in state: soil_material.set_shader_parameter(key,state[key])
	queue_redraw()
func cultivated(other: int) -> bool:
	if other < 0 or other >= GameState.plots.size(): return false
	return bool(GameState.plots[other].get("tilled",false)) and not bool(GameState.plots[other].get("removed",false))
func _draw() -> void:
	# Meets the adjacent cell exactly; the eight-pixel inter-row aisle stays walkable.
	var width := LAYOUT.step(index).x
	draw_rect(Rect2(-width*0.5,-11,width,28),Color.WHITE)
