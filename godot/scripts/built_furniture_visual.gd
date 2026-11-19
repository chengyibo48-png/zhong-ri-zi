extends Node2D
const ART := preload("res://scripts/built_furniture_art.gd")
var piece: Dictionary = {}
var footprint := Rect2()
var world: Node2D
func configure(owner_world: Node2D, source: Dictionary, area: Rect2) -> void:
	world = owner_world
	piece = source.duplicate(true)
	position = Vector2(area.get_center().x, area.end.y)
	footprint = Rect2(area.position - position, area.size)
	set_meta("floor_anchor", position)
	if ART.ground_surface(str(piece.get("type",""))):z_index=-1
func _process(delta:float)->void:
	if str(piece.get("type",""))!="greenhouse":return
	var actor:=get_tree().get_first_node_in_group("player") as Node2D
	var opacity:=1.0
	if is_instance_valid(actor):
		var rect:Rect2=ART.sprite_rect("greenhouse",int(piece.get("rotation",0)),footprint)
		var body:=Rect2(actor.global_position-global_position+Vector2(-10,-42),Vector2(20,42))
		if global_position.y>actor.global_position.y and rect.intersects(body):opacity=.42
	_canopy_alpha=move_toward(_canopy_alpha,opacity,delta*5)
	(material as ShaderMaterial).set_shader_parameter("occlusion_alpha",_canopy_alpha)
var _canopy_alpha:=1.0
func _ready() -> void:
	set_process(str(piece.get("type",""))=="greenhouse")
	if is_processing():
		var shader_material:=ShaderMaterial.new();shader_material.shader=preload("res://art/shaders/furniture_occlusion.gdshader");material=shader_material
	GameState.clock_changed.connect(queue_redraw)
	world.interaction_presentation_changed.connect(queue_redraw)
func _draw() -> void:
	ART.draw(self, piece, footprint, GameState.minutes, int(world.hovered_building_piece) == int(piece.get("key", -1)))
