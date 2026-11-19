extends Control
const ART := preload("res://scripts/built_furniture_art.gd")
var furniture_id := "bench"
var view_rotation := 0
func _init() -> void:
	custom_minimum_size = Vector2(180, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)
func present(id: String, direction: int) -> void:
	furniture_id = id
	view_rotation = posmod(direction, 4)
	queue_redraw()
func _draw() -> void:
	draw_style_box(_backdrop(), Rect2(Vector2.ZERO, size))
	var tex := ART.texture_for(furniture_id, view_rotation)
	if tex == null:
		draw_string(ThemeDB.fallback_font, Vector2(12, 62), "暂无实物预览", HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 14, Color("cabd9d"))
		return
	var available := Vector2(maxf(20, size.x - 32), size.y - 34)
	var scale_factor := minf(available.x / tex.get_width(), available.y / tex.get_height())
	var sprite_size := tex.get_size() * scale_factor
	draw_texture_rect(tex, Rect2(Vector2((size.x - sprite_size.x) * 0.5, 8), sprite_size), false)
	draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 7), "%d° · 实物预览" % (view_rotation * 90), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 12, Color("e7d7b4"))
func _backdrop() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("283b34")
	box.set_corner_radius_all(8)
	return box
