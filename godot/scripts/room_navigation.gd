extends RefCounted

const CLEARANCE := preload("res://scripts/navigation_clearance.gd")
const CELL_SIZE := 8.0
const REGION := Rect2i(0, 0, 120, 75)

static func exit_route(room: Node2D, from: Vector2, exit_point: Vector2) -> Dictionary:
	var rectangles: Array[Rect2] = []
	for shape_node in room.find_children("*", "CollisionShape2D", true, false):
		if not shape_node.get_parent() is StaticBody2D or shape_node.get_parent().is_queued_for_deletion() or shape_node.disabled: continue
		if shape_node.shape is RectangleShape2D:
			rectangles.append(Rect2(shape_node.global_position - shape_node.shape.size * 0.5, shape_node.shape.size).grow(9.0))
	var cache: Dictionary = room.get_meta("exit_navigation", {})
	var result := route_rectangles(from,exit_point,rectangles,cache)
	room.set_meta("exit_navigation",cache)
	return result

static func route_rectangles(from: Vector2, exit_point: Vector2, rectangles: Array[Rect2], cache: Dictionary) -> Dictionary:
	var failure := {"reachable": false, "points": [], "distance": 0.0}
	if not CLEARANCE.point_clear(from, rectangles) or not CLEARANCE.point_clear(exit_point, rectangles): return failure
	var points: Array[Vector2] = [from]
	if CLEARANCE.segment_clear(from, exit_point, rectangles):
		points.append(exit_point)
	else:
		var grid: AStarGrid2D
		if cache.get("rectangles", []) == rectangles and cache.has("grid"):
			grid = cache.grid
		else:
			grid = AStarGrid2D.new()
			grid.region = REGION
			grid.cell_size = Vector2.ONE * CELL_SIZE
			grid.offset = Vector2.ONE * CELL_SIZE * 0.5
			grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
			grid.update()
			for y in range(REGION.size.y):
				for x in range(REGION.size.x):
					var cell := Vector2i(x, y)
					if not CLEARANCE.point_clear(grid.get_point_position(cell), rectangles):
						grid.set_point_solid(cell, true)
			cache.grid = grid
			cache.rectangles = rectangles
		var start := CLEARANCE.attachment(grid, from, rectangles)
		var finish := CLEARANCE.attachment(grid, exit_point, rectangles)
		if start.x < 0 or finish.x < 0:
			failure["reason"] = "attachment"
			return failure
		var cells := grid.get_id_path(start, finish)
		if cells.is_empty():
			failure["reason"] = "disconnected"
			return failure
		for cell in cells: points.append(grid.get_point_position(cell))
		points.append(exit_point)
		if not CLEARANCE.path_clear(points, rectangles):
			failure["reason"] = "segment"
			return failure
	var distance := 0.0
	for index in range(1, points.size()): distance += points[index - 1].distance_to(points[index])
	return {"reachable": true, "points": points, "distance": distance}
