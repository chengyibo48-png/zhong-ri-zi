extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	var room_rules = load("res://scripts/interior_world.gd")
	var room_navigation = load("res://scripts/room_navigation.gd")
	var village_navigation = load("res://scripts/village_navigation.gd").new(state.world_village)
	var failures := 0
	var segment_checked := 0
	var outdoor_checked := 0
	var room_checked := 0
	var layouts: Dictionary = state.system_catalog.get("interiors", {}).get("layouts", {})
	for house in state.world_village.get("houses", []):
		var door: Dictionary = house.get("door", {})
		var point := Vector2(float(door.get("x", 0)), float(door.get("y", 0)))
		var route: Dictionary = village_navigation.route(Vector2(2831, 1652), point)
		outdoor_checked += 1
		if not bool(route.get("reachable", false)) or route.get("points", []).is_empty() or route.points.back().distance_to(point) > 0.25:
			failures += 1
			print("BAD_DOOR ", house.get("id", ""), " ", point, " reachable=", route.get("reachable", false), " reason=", route.get("reason", ""))
		else:
			segment_checked += route.points.size() - 1
			if not _segments_clear(route.points, village_navigation.base_rectangles):
				failures += 1
				print("BAD_DOOR_SEGMENT ", house.get("id", ""))
	for id in layouts:
		var layout: Dictionary = layouts[id]
		var room = room_rules.new()
		room._add_wall_blockers()
		room._add_layout_blockers(layout)
		var rectangles: Array[Rect2] = []
		for shape_node in room.find_children("*", "CollisionShape2D", true, false):
			if shape_node.shape is RectangleShape2D:
				rectangles.append(Rect2(shape_node.global_position - shape_node.shape.size * 0.5, shape_node.shape.size).grow(9))
		var exit_point := Vector2(480, 590)
		for point in layout.get("points", []):
			if str(point.get("kind", "")) == "exit":
				exit_point = Vector2(float(point.get("x", 480)), float(point.get("y", 590)))
		var starts: Array[Vector2] = [Vector2(480, 550)]
		for row in layout.get("rows", []):
			var x := float(row.get("x", 480))
			var y := float(row.get("y", 300))
			var w := float(row.get("w", 80))
			var h := float(row.get("h", 32))
			starts.append(Vector2(x - w * 0.5 - 12, y))
			starts.append(Vector2(x + w * 0.5 + 12, y))
			starts.append(Vector2(x, y + 30))
		for start in starts:
			if not Rect2(114, 114, 732, 448).has_point(start) or rectangles.any(func(rect: Rect2) -> bool: return rect.has_point(start)): continue
			room_checked += 1
			var route: Dictionary = room_navigation.exit_route(room, start, exit_point)
			if not bool(route.get("reachable", false)):
				failures += 1
				if failures <= 20: print("BAD_ROOM ", id, " from=", start, " reason=", route.get("reason", ""))
			else:
				segment_checked += route.points.size() - 1
				if not _segments_clear(route.points, rectangles):
					failures += 1
					print("BAD_ROOM_SEGMENT ", id, " from=", start)
		room.free()
	print("Geometry audit: %d outdoor doors, %d physically clear room starts, %d collision-free segments, %d failures" % [outdoor_checked, room_checked, segment_checked, failures])
	quit(1 if failures > 0 else 0)


# Independent of the production slab calculation: intersect each path segment
# with the four edges using Godot Geometry2D, checking endpoints as well.
func _segments_clear(points: Array, rectangles: Array[Rect2]) -> bool:
	for index in range(1, points.size()):
		var start: Vector2 = points[index - 1]
		var finish: Vector2 = points[index]
		if start.is_equal_approx(finish): continue
		var bounds := Rect2(start, Vector2.ZERO).expand(finish).grow(0.01)
		for rect in rectangles:
			if not bounds.intersects(rect): continue
			if rect.has_point(start) or rect.has_point(finish): return false
			var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
			for edge in range(4):
				if Geometry2D.segment_intersects_segment(start, finish, corners[edge], corners[(edge + 1) % 4]) != null:
					return false
	return true
