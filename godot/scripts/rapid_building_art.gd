extends RefCounted
const WORLD_ART := preload("res://scripts/world_art.gd")
const TEXTURES := preload("res://scripts/character_art.gd")
const SHADER := preload("res://art/shaders/rapid_building_season.gdshader")

static func configure(target: Node2D, data: Dictionary, season: int, minutes: float) -> void:
	var key: String = WORLD_ART.key_for(data)
	var row: Dictionary = WORLD_ART.entries().get(key, {})
	if not bool(row.get("rapidSeasonMaterial", false)): return
	var texture: Texture2D = TEXTURES.texture(str(row.get("path", "")))
	if texture == null: return
	var rectangle: Array = preload("res://scripts/world_layout.gd").house_rect(key, row.get("worldRect", []))
	if data.has("_layout_rect"): rectangle = data._layout_rect
	if data.has("_visual_rect"): rectangle = data._visual_rect
	if rectangle.size() != 4: return
	var sprite: Sprite2D = target.get_node_or_null("RapidSeasonArt") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "RapidSeasonArt"
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHADER
		sprite.material = shader_material
		target.add_child(sprite)
	sprite.texture = texture
	sprite.position = Vector2(float(rectangle[0]), float(rectangle[1]))
	sprite.scale = Vector2(float(rectangle[2]), float(rectangle[3])) / Vector2(texture.get_size())
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	material.set_shader_parameter("season", clampi(season, 0, 3))
	material.set_shader_parameter("evening", smoothstep(1020.0, 1200.0, minutes))
	material.set_shader_parameter("roof_bottom", float(row.get("roofBottom", 0.57)))
