extends Node2D
## Fine-scale floor and a soft textile grouping keep the editable room spacious.
var world: Node2D
var floor_material: ShaderMaterial
func _ready() -> void:
	var surface:=Polygon2D.new()
	var rect:Rect2=preload("res://scripts/house_geometry.gd").floor_rect(GameState.current_interior)
	surface.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	surface.show_behind_parent=true
	var shader:=ShaderMaterial.new();shader.shader=preload("res://art/shaders/interior_floor.gdshader")
	floor_material=shader
	surface.material=shader;add_child(surface)
	GameState.world_changed.connect(refresh)
	GameState.clock_changed.connect(refresh)
	refresh()
func refresh() -> void:
	var floor_name:=str(world._room_layout().get("floor","木纹"))
	floor_material.set_shader_parameter("floor_kind",{"青砖":1,"竹席":2,"水磨石":3}.get(floor_name,0))
	var surface: String={"青砖":"blue-brick-v2","竹席":"bamboo-mat-v2","水磨石":"terrazzo-v2"}.get(floor_name,"oak-planks-v2")
	floor_material.set_shader_parameter("floor_texture",preload("res://scripts/character_art.gd").texture("res://art/world/terrain/"+surface+".png"))
	var is_home:=str(GameState.interior_house().get("id",""))=="building-farm-12"
	var style:=str(GameState.building.get("style","wood")) if is_home else "wood"
	var tint: Vector3={"wood":Vector3(1,1,1),"blue":Vector3(.88,.99,1.03),"plum":Vector3(1.04,.94,.91)}.get(style,Vector3.ONE)
	floor_material.set_shader_parameter("wood_tint",tint)
	floor_material.set_shader_parameter("night_amount",preload("res://scripts/world_art.gd").night_factor(GameState.minutes))
	queue_redraw()
func _draw() -> void:
	var room:=GameState.interior_house()
	var home:=str(room.get("id",""))=="building-farm-12"
	var barn:=str(room.get("id","")).begins_with("ranch-")
	if barn:return
	var texture: Texture2D=preload("res://scripts/character_art.gd").texture("res://art/world/interior_surfaces/bedside-rug-v2.png")
	if texture==null:return
	var at:=Vector2(246,350) if home else Vector2(242,530)
	var size:=Vector2(188,66) if home else Vector2(186,65)
	var owner_id:String=str(room.get("owner",""))
	if not preload("res://scripts/resident_life.gd").profile(owner_id).is_empty():
		for row:Dictionary in world._room_layout().get("rows",[]):
			if str(row.get("kind",""))=="bed":at=Vector2(float(row.x),float(row.y)+22);break
	var accent:Color=Color(str(preload("res://scripts/resident_life.gd").profile(owner_id).get("roomAccent","#ffffff")))
	var tint:=Color.WHITE.lerp(accent,.32).lerp(Color(.73,.69,.60),preload("res://scripts/world_art.gd").night_factor(GameState.minutes)*.35)
	draw_texture_rect(texture,Rect2(at-size*.5,size),false,tint)
