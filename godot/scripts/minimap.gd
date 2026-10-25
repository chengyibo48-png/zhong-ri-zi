extends Control

const MAP_ART = preload("res://scripts/atlas_map_art.gd")

const MAP_SIZE := 168.0
const PADDING := 6.0


func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	GameState.player_moved.connect(_on_player_moved)
	GameState.changed.connect(_on_state_changed)
	queue_redraw()

func _on_player_moved(_position: Vector2) -> void:
	queue_redraw()

func _on_state_changed() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 180, 180), Color("ede5c9"), true)
	for fill in MAP_ART.rectangles(GameState):
		var area:=Rect2(Vector2(float(fill.x),float(fill.y))/3840.0*MAP_SIZE+Vector2(PADDING,PADDING),Vector2(float(fill.w),float(fill.h))/3840.0*MAP_SIZE)
		var ink:=Color.from_string(str(fill.color),Color.WHITE)
		ink.a=float(fill.alpha)
		draw_rect(area,ink,true)
	var world_player := GameState.interior_return_position if GameState.current_interior != "" else GameState.player_position
	var player := world_player / 3840.0 * MAP_SIZE + Vector2(PADDING, PADDING)
	var tracking: Dictionary = GameState.atlas_resolve(GameState.atlas.get("tracking"))
	if not tracking.is_empty():
		var world_target := Vector2(float(tracking.get("x", 0)), float(tracking.get("y", 0)))
		var route: Dictionary = GameState.atlas_preview(tracking)
		var route_points: Array = [world_player] + route.get("points", [])
		if bool(route.get("reachable", false)) and route_points.size() > 1:
			for index in range(1, route_points.size()):
				var from_map: Vector2 = route_points[index - 1] / 3840.0 * MAP_SIZE + Vector2(PADDING, PADDING)
				var to_map: Vector2 = route_points[index] / 3840.0 * MAP_SIZE + Vector2(PADDING, PADDING)
				draw_line(from_map, to_map, Color("fff0bf", 0.88), 1.5, true)
		var target := world_target / 3840.0 * MAP_SIZE + Vector2(PADDING, PADDING)
		if not bool(route.get("reachable", false)):
			draw_line(player, target, Color("efb951", 0.45), 0.8)
		preload("res://scripts/detail_art.gd").draw(self, "ui/minimap_pin", Rect2(target - Vector2(4, 10), Vector2(8, 10)))
		draw_circle(target, 3.2, Color("efb951"))
		draw_arc(target, 5.2, 0.0, TAU, 18, Color("493e31"), 1.0)
	draw_circle(player, 4.0, Color("fff0a8"))
	draw_arc(player, 6.0, 0.0, TAU, 20, Color("5a4c35"), 1.0)
	draw_rect(Rect2(0, 0, 180, 180), Color("d3c092"), false, 2.0)
