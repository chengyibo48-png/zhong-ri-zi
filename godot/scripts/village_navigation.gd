extends RefCounted
class_name VillageNavigation

const CLEARANCE := preload("res://scripts/navigation_clearance.gd")
const CELL_SIZE := 16.0
const GRID_SIZE := 240

var grid := AStarGrid2D.new()
var path_cache: Dictionary = {}
var base_solid_cells: Dictionary = {}
var dynamic_solid_cells: Dictionary = {}
var base_rectangles: Array[Rect2] = []
var dynamic_rectangles: Array[Rect2] = []

func _init(village: Dictionary = {}) -> void:
	grid.region = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
	grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	grid.offset = Vector2.ONE * CELL_SIZE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for solid in village.get("solids", []):
		if solid is Array and solid.size() >= 4:
			_mark_rect(float(solid[0]), float(solid[1]), float(solid[2]), float(solid[3]))
	for solid in village.get("navigation_collisions", []):
		if solid is Array and solid.size() >= 4:
			_mark_rect(float(solid[0]), float(solid[1]), float(solid[2]), float(solid[3]))
	var maps: Dictionary = village.get("maps", {})
	var offsets: Dictionary = village.get("offsets", {})
	for region_id in maps:
		var offset: Dictionary = offsets.get(region_id, {})
		for water in maps[region_id].get("water", []):
			_mark_rect(float(water.get("x", 0)) + float(offset.get("x", 0)), float(water.get("y", 0)) + float(offset.get("y", 0)), float(water.get("w", 0)), float(water.get("h", 0)))

func _cells_for_rect(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if rect.size.x <= 0.0 or rect.size.y <= 0.0: return cells
	var left := clampi(floori(rect.position.x / CELL_SIZE), 0, GRID_SIZE - 1)
	var top := clampi(floori(rect.position.y / CELL_SIZE), 0, GRID_SIZE - 1)
	var right := clampi(floori((rect.end.x - 0.01) / CELL_SIZE), 0, GRID_SIZE - 1)
	var bottom := clampi(floori((rect.end.y - 0.01) / CELL_SIZE), 0, GRID_SIZE - 1)
	for row in range(top, bottom + 1):
		for column in range(left, right + 1):
			var cell := Vector2i(column, row)
			if not CLEARANCE.point_clear(grid.get_point_position(cell), [rect]): cells.append(cell)
	return cells

func _mark_rect(x: float, y: float, width: float, height: float) -> void:
	var rect := Rect2(x, y, width, height).grow(9.0)
	base_rectangles.append(rect)
	for cell in _cells_for_rect(rect):
		base_solid_cells[cell] = true
		grid.set_point_solid(cell, true)

func set_dynamic_obstacles(rectangles: Array) -> void:
	var next_cells: Dictionary = {}
	var next_rectangles: Array[Rect2] = []
	for obstacle in rectangles:
		if not obstacle is Rect2: continue
		next_rectangles.append(obstacle.grow(9.0))
		for cell in _cells_for_rect(obstacle.grow(9.0)): next_cells[cell] = true
	if next_cells == dynamic_solid_cells and next_rectangles == dynamic_rectangles: return
	for cell in dynamic_solid_cells:
		grid.set_point_solid(cell, base_solid_cells.has(cell))
	for cell in next_cells:
		grid.set_point_solid(cell, true)
	dynamic_solid_cells = next_cells
	dynamic_rectangles = next_rectangles
	path_cache.clear()

func _nearest_walkable(point: Vector2) -> Vector2i:
	var origin := Vector2i(clampi(floori(point.x / CELL_SIZE), 0, GRID_SIZE - 1), clampi(floori(point.y / CELL_SIZE), 0, GRID_SIZE - 1))
	if not grid.is_point_solid(origin): return origin
	for radius in range(1, 13):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius: continue
				var cell := origin + Vector2i(x, y)
				if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE or grid.is_point_solid(cell): continue
				var distance := Vector2(cell - origin).length_squared()
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best.x >= 0: return best
	return origin

func route(from: Vector2, to: Vector2) -> Dictionary:
	var rectangles: Array[Rect2] = []
	rectangles.append_array(base_rectangles)
	rectangles.append_array(dynamic_rectangles)
	var failure := {"reachable": false, "points": [], "distance": 0.0, "next": to}
	if not CLEARANCE.point_clear(from, rectangles): return failure
	var snapped := not CLEARANCE.point_clear(to, rectangles)
	var finish := _nearest_walkable(to) if snapped else CLEARANCE.attachment(grid, to, rectangles)
	var start := CLEARANCE.attachment(grid, from, rectangles)
	if start.x < 0 or finish.x < 0 or grid.is_point_solid(finish): return failure
	var destination := grid.get_point_position(finish) if snapped else to
	var points: Array[Vector2] = [from]
	if not CLEARANCE.segment_clear(from, destination, rectangles):
		var key := "%d,%d>%d,%d" % [start.x, start.y, finish.x, finish.y]
		var cells: Array[Vector2i] = []
		if path_cache.has(key):
			cells = path_cache[key]
		else:
			cells = grid.get_id_path(start, finish)
			if path_cache.size() >= 192: path_cache.clear()
			path_cache[key] = cells
		if cells.is_empty(): return failure
		for cell in cells:
			var point := grid.get_point_position(cell)
			if points.back().distance_to(point) > 0.01: points.append(point)
	points.append(destination)
	if not CLEARANCE.path_clear(points, rectangles):
		failure["reason"] = "segment"
		return failure
	var distance := 0.0
	for index in range(1, points.size()): distance += points[index - 1].distance_to(points[index])
	var next_point := points[mini(2, points.size() - 1)] if points.size() > 1 else to
	return {"reachable": true, "points": points, "distance": distance, "next": next_point, "snapped": snapped}
