extends RefCounted

# Player feet collider is a circle with radius 9. Inflated rectangles keep
# both endpoint attachments and route segments outside physical obstacles.
static func point_clear(point: Vector2, rectangles: Array[Rect2]) -> bool:
	for rect in rectangles:
		if point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y: return false
	return true

static func segment_clear(start: Vector2, finish: Vector2, rectangles: Array[Rect2]) -> bool:
	var direction := finish - start
	for rect in rectangles:
		var lower := 0.0
		var upper := 1.0
		for axis in range(2):
			if absf(direction[axis]) < 0.00001:
				if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
					lower = 2.0
					break
			else:
				var a := (rect.position[axis] - start[axis]) / direction[axis]
				var b := (rect.end[axis] - start[axis]) / direction[axis]
				lower = maxf(lower, minf(a, b))
				upper = minf(upper, maxf(a, b))
		if lower <= upper: return false
	return true

static func attachment(grid: AStarGrid2D, point: Vector2, rectangles: Array[Rect2], radius_limit: int = 5) -> Vector2i:
	var origin := Vector2i((point - grid.offset) / grid.cell_size)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for radius in range(radius_limit + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius: continue
				var cell := origin + Vector2i(x, y)
				if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
				var center := grid.get_point_position(cell)
				var distance := point.distance_squared_to(center)
				if distance < best_distance and segment_clear(point, center, rectangles):
					best = cell
					best_distance = distance
		if best.x >= 0: return best
	return best

static func path_clear(points: Array[Vector2], rectangles: Array[Rect2]) -> bool:
	for index in range(1, points.size()):
		if not segment_clear(points[index - 1], points[index], rectangles): return false
	return true
