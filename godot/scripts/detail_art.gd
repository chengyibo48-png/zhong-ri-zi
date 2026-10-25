extends RefCounted
static func texture(key: String) -> Texture2D:
	var row: Dictionary = preload("res://scripts/world_art.gd").entries().get(key, {})
	return preload("res://scripts/character_art.gd").texture(str(row.get("path", ""))) if bool(row.get("baseReady", false)) else null

static func draw(target: CanvasItem, key: String, rectangle: Rect2, tint: Color = Color.WHITE) -> bool:
	var art := texture(key)
	if art == null: return false
	target.draw_texture_rect(art, rectangle, false, tint)
	return true

static func panel(key: String, margin: float = 6.0) -> StyleBoxTexture:
	var art := texture(key)
	if art == null: return null
	var style := StyleBoxTexture.new()
	style.texture = art
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_texture_margin(side, margin)
	style.set_content_margin_all(7)
	return style
