extends Control

class_name VillageMapCanvas

const MAP_ART = preload("res://scripts/atlas_map_art.gd")

signal point_selected(point: Vector2)
var preview_target: Dictionary = {}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point_selected.emit(event.position / size * 3840.0)
		accept_event()

func _ready() -> void:
	GameState.changed.connect(queue_redraw)
	GameState.player_moved.connect(func(_position: Vector2): queue_redraw())
	GameState.interior_moved.connect(func(_position: Vector2): queue_redraw())

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect.grow(2), Color("d5c399"), true)
	draw_rect(rect, Color("ede5c9"), true)
	for fill in MAP_ART.rectangles(GameState):
		var area := Rect2(Vector2(float(fill.x),float(fill.y))/3840.0*rect.size,Vector2(float(fill.w),float(fill.h))/3840.0*rect.size)
		var ink := Color.from_string(str(fill.color),Color.WHITE)
		ink.a=float(fill.alpha)
		draw_rect(area,ink,true)
	var offsets: Dictionary = GameState.world_village.get("offsets", {})
	for region_id in offsets:
		var region:Dictionary=offsets[region_id]
		var bounds:=GameState.atlas_region_bounds(str(region_id))
		var area:=Rect2(bounds.position/3840.0*rect.size,bounds.size/3840.0*rect.size)
		var font_size:=label_font_size()
		var palette: Dictionary=UIArtService._effective_palette(str(GameState.ui_art.get("theme","paper")))
		draw_rect(Rect2(area.position+Vector2(3,3),Vector2(minf(area.size.x-6,str(region.name).length()*font_size+10),font_size+8)),Color(str(palette.panel),.95))
		draw_string(get_theme_font("font","Label"),area.position+Vector2(7,font_size+5),str(region.name),HORIZONTAL_ALIGNMENT_LEFT,area.size.x-14,font_size,Color(str(palette.ink)))
	var origin := GameState.interior_return_position if GameState.current_interior != "" else GameState.player_position
	var player_map := origin / 3840.0 * rect.size
	draw_circle(player_map, 4.2, Color("fff2a2"))
	draw_arc(player_map, 7.0, 0, TAU, 18, Color("443b2f"), 1.5)
	var layer := str(GameState.atlas.get("layer", "all"))
	for target in GameState.atlas_targets():
		var kind := str(target.get("type", ""))
		var target_layer := "harvest" if kind == "harvest" else kind
		if layer == "all" and kind not in ["homes","services","pins"]: continue
		if layer != "all" and target_layer != layer: continue
		var at := Vector2(float(target.get("x", 0)), float(target.get("y", 0))) / 3840.0 * rect.size
		var marker: Color = Color("d7c69b") if kind in ["homes", "services"] else Color("cf866c") if kind == "neighbors" else Color("98c783") if kind == "harvest" else Color("e8aa72") if kind == "resources" else Color("8bc6d2") if kind == "water" else Color("ddd4b8") if kind == "animals" else Color("f1d35f")
		var marker_size := 3.3 if kind == "pins" else 1.7 if kind == "harvest" else 2.2
		if kind == "harvest":
			draw_rect(Rect2(at - Vector2.ONE * marker_size, Vector2.ONE * marker_size * 2.0), marker, true)
		else:
			draw_circle(at, marker_size, marker)
		if kind == "pins": preload("res://scripts/detail_art.gd").draw(self, "ui/minimap_pin", Rect2(at - Vector2(4, 10), Vector2(8, 10)))
	var tracking: Dictionary = GameState.atlas_resolve(GameState.atlas.get("tracking"))
	if not preview_target.is_empty(): tracking = GameState.atlas_resolve(preview_target)
	if not tracking.is_empty():
		var destination := Vector2(float(tracking.get("x", 0)), float(tracking.get("y", 0)))
		var route: Dictionary = GameState.atlas_preview(tracking)
		var route_points: Array = [origin] + route.get("points", [])
		if bool(route.get("reachable", false)) and route_points.size() > 1:
			for index in range(1, route_points.size()):
				var from_map: Vector2 = route_points[index - 1] / 3840.0 * rect.size
				var to_map: Vector2 = route_points[index] / 3840.0 * rect.size
				draw_line(from_map, to_map, Color("fff0bf", 0.88), 2.2, true)
		var at := destination / 3840.0 * rect.size
		draw_circle(at, 5.0, Color("f2bb62"))
		draw_arc(at, 8.0, 0, TAU, 20, Color("fff0c2"), 1.5)
	draw_rect(rect, Color("d9c798"), false, 2.0)

func label_font_size() -> int:
	return maxi(14,roundi(14*float(GameState.player_settings.get("textScale",1))))
