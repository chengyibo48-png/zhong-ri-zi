extends Node2D
class_name FarmWorld

const PLOT_SCRIPT := preload("res://scripts/farm_plot.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const RANCH_VISUAL := preload("res://scripts/ranch_visual.gd")
const ANIMAL_SCRIPT := preload("res://scripts/ranch_animal.gd")
const NPC_SCRIPT := preload("res://scripts/world_npc.gd")
const PROP_SCRIPT := preload("res://scripts/world_prop.gd")
const GATHER_SCRIPT := preload("res://scripts/gather_node.gd")
const FISH_SCRIPT := preload("res://scripts/fish_spot.gd")
const NPC_SCHEDULE := preload("res://scripts/npc_schedule.gd")
const WORLD_EFFECTS_SCRIPT := preload("res://scripts/world_effects.gd")
const GROUND_TILE_SET := preload("res://art/ground_tileset.tres")
const WORLD_DATA_PATH := "res://data/world.json"
const SELECTION_SCRIPT := preload("res://scripts/interaction_selection.gd")
var interaction_selection := SELECTION_SCRIPT.new()
var quest_site_points: Dictionary={}
var selected_world_target: Dictionary = {}
var selection_tool := ""
var legacy_outdoor_catalog: Dictionary = {}
var legacy_gather_catalog: Dictionary = {}
var legacy_gather_nodes: Dictionary = {}
var pointer_hover: Dictionary = {}
var pointer_screen:Variant=null
signal interaction_presentation_changed
const INTERACTION_DESCRIPTION=preload("res://scripts/interaction_description.gd")

static var hovered_plot := -1
static var hovered_animal := -1
static var hovered_npc := ""
static var hovered_resource := ""
static var hovered_fish := ""
static var hovered_wildlife := ""
static var hovered_pet := false
static var hovered_building_piece := 0
var player: CharacterBody2D
var hud: CanvasLayer
var world_effects: Node2D
var plot_nodes: Array[Node2D] = []
var animal_nodes: Array[Node2D] = []
var npc_nodes: Array[Node2D] = []
var gather_nodes: Array[Node2D] = []
var fish_nodes: Array[Node2D] = []
var trap_nodes: Array[Node2D] = []
var world_data: Dictionary = {}
var ground_layer: TileMapLayer
var ground_season := -1
var npc_navigation := AStarGrid2D.new()
var npc_schedule_stamp := ""
var static_blockers: Dictionary = {}
var building_collision_root: Node2D
var building_collision_revision := -1
var legacy_furniture_nodes:Dictionary={}
var last_visual_season := -1
var _gather_redraw_elapsed := 0.0
var map_draw_count := 0
var _ambient_redraw_elapsed := 0.0
var _candidate_frame := -1
var _candidate_cache: Array = []
var _discovery_elapsed := 0.0

func _init() -> void:
	y_sort_enabled = true

func _ready() -> void:
	get_viewport().mouse_exited.connect(_pointer_leave)
	var ranch_fixtures := Node2D.new()
	ranch_fixtures.name = "RanchFixtures"
	ranch_fixtures.set_script(preload("res://scripts/ranch_fixture_visual.gd"))
	add_child(ranch_fixtures)
	if GameState.current_interior != "":
		call_deferred("_resume_saved_interior")
		return
	world_data = _read_world_data()
	queue_redraw()
	_create_ground_layer()
	world_effects = Node2D.new()
	world_effects.name = "WorldEffects"
	world_effects.set_script(WORLD_EFFECTS_SCRIPT)
	add_child(world_effects)
	world_effects.call("configure", preload("res://scripts/world_layout.gd").ambience_world(world_data))
	building_collision_root = Node2D.new()
	building_collision_root.name = "BuildingLayoutCollisions"
	add_child(building_collision_root)
	var village: Dictionary = world_data.get("village", {})
	for solid in village.get("solids", []):
		_add_blocker(Rect2(float(solid[0]), float(solid[1]), float(solid[2]), float(solid[3])))
	var tiles: Dictionary = world_data.get("tiles", {})
	for collision in tiles.get("collisions", []):
		_add_blocker(Rect2(float(collision[0]), float(collision[1]), float(collision[2]), float(collision[3])))
	_create_npc_navigation(village)
	_add_blocker(Rect2(-48, -48, 3936, 32))
	_add_blocker(Rect2(-48, 3840, 3936, 32))
	_add_blocker(Rect2(-48, -48, 32, 3936))
	_add_blocker(Rect2(3840, -48, 32, 3936))
	_create_village_props(village.get("allProps", []), "village")
	_create_village_props(tiles.get("objects", []), "tiles")
	_create_npcs(village)
	_create_landmark_interactions(village)
	for i in range(GameState.plots.size()):
		var plot := Node2D.new()
		plot.set_script(PLOT_SCRIPT)
		plot.set("index", i)
		plot.position = _plot_position(i)
		add_child(plot)
		plot_nodes.append(plot)
	world_effects.call("configure_plots", plot_nodes)
	for i in range(GameState.animals.size()):
		var animal := Node2D.new()
		animal.set_script(ANIMAL_SCRIPT)
		animal.set("animal_index", i)
		var animal_data: Dictionary = GameState.animals[i]
		var saved_position: Dictionary = animal_data.get("position", {})
		animal.position = Vector2(float(saved_position.get("x", 3070 + i % 4 * 22)), float(saved_position.get("y", 3082 + i % 3 * 18)))
		add_child(animal)
		animal_nodes.append(animal)
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = GameState.player_position
	add_child(player)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	var fishing_panel: Node = hud.get("fishing_panel")
	if fishing_panel != null and fishing_panel.has_signal("world_fishing_changed"):
		fishing_panel.connect("world_fishing_changed", _on_fishing_visual_changed)
	_prepare_quest_sites()
	_create_ambient_actors()
	GameState.ranch_positions_changed.connect(_sync_ranch_visuals)
	GameState.world_changed.connect(_refresh)
	GameState.clock_changed.connect(_refresh_clock)
	GameState.input_mode_changed.connect(func(_mode:String):queue_redraw())
	GameState.action_sequence_changed.connect(func(_snapshot:Dictionary):queue_redraw())
	_refresh()

func _resume_saved_interior() -> void:
	if not GameState.interior_house().is_empty():
		get_tree().change_scene_to_file("res://scenes/interior.tscn")
	else:
		GameState.current_interior = ""
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	_refresh_npc_schedules()
	_sync_building_collisions()

func _read_world_data() -> Dictionary:
	var file := FileAccess.open(WORLD_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Godot 世界地图数据无法读取。")
		return {}
	var parsed: Variant = load("res://scripts/save_json.gd").decode(JSON.parse_string(file.get_as_text()))
	if not parsed is Dictionary: return {}
	return parsed.get("world", parsed)

func _plot_position(index: int) -> Vector2:
	return GameState.farm_plot_position(index)

func _create_village_props(props: Array, source_group: String) -> void:
	var assets: Dictionary = world_data.get("tiles", {}).get("assets", {})
	for prop_index in props.size():
		if bool(props[prop_index].get("_ranchRemoved",false)): continue
		var visual_data: Dictionary = preload("res://scripts/world_layout.gd").prop(props[prop_index], prop_index, source_group)
		var kind := str(visual_data.get("kind", ""))
		var asset: Dictionary = assets.get(kind, {})
		if not visual_data.has("w"):
			visual_data["w"] = int(asset.get("w", 48))
		if not visual_data.has("h"):
			visual_data["h"] = int(asset.get("h", 56))
		var prop := Node2D.new()
		prop.set_script(PROP_SCRIPT)
		prop.set("data", visual_data)
		prop.add_to_group("seasonal_world_props")
		if kind in ["house", "brick", "home", "kitchen", "shop", "clinic", "school", "hall", "store", "shed"]:
			prop.position = Vector2(float(visual_data.get("x", 0)) + float(visual_data.get("w", 48)) * 0.5, float(visual_data.get("y", 0)) + float(visual_data.get("h", 56)))
		else:
			prop.position = Vector2(float(visual_data.get("x", 0)), float(visual_data.get("y", 0)))
		add_child(prop)

func _create_npcs(village: Dictionary) -> void:
	var original: Dictionary = GameState.npc_residents
	var houses: Array = village.get("houses", [])
	var home_doors: Dictionary = {}
	for house in houses:
		var owner := str(house.get("owner")) if house.get("owner") != null else ""
		if owner != "":
			var door: Dictionary = house.get("door", {})
			home_doors[owner] = Vector2(float(door.get("x", 0)), float(door.get("y", 0)))
	var workpoints: Dictionary = GameState.system_catalog.get("npc", {}).get("workpoints", {})
	var npc_index := 0
	for person in GameState.npc_catalog:
		var npc_id := str(person.get("id", ""))
		var saved: Dictionary = original.get(npc_id, {})
		var spawn := Vector2(float(saved.get("x", 2831)), float(saved.get("y", 1652)))
		if saved.get("room") != null:
			for house in houses:
				if str(house.get("owner", "")) == npc_id:
					var door: Dictionary = house.get("door", {})
					spawn = Vector2(float(door.get("x", 0)), float(door.get("y", 0)))
					break
		var npc := Node2D.new()
		npc.set_script(NPC_SCRIPT)
		npc.set("npc_id", npc_id)
		npc.set("npc_data", person)
		npc.set("npc_index", npc_index)
		npc.set("home_target", home_doors.get(npc_id, spawn))
		var work_data: Dictionary = workpoints.get(npc_id, {})
		npc.set("work_target", Vector2(float(work_data.get("x", spawn.x)), float(work_data.get("y", spawn.y))))
		npc.position = spawn
		npc.add_to_group("village_npc")
		add_child(npc)
		npc.call("present_resident", GameState)
		npc_nodes.append(npc)
		npc_index += 1

func _create_npc_navigation(village: Dictionary) -> void:
	npc_navigation.region = Rect2i(0, 0, 120, 120)
	npc_navigation.cell_size = Vector2(32, 32)
	npc_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	npc_navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	npc_navigation.update()
	for solid in village.get("solids", []):
		_mark_npc_navigation_rect(float(solid[0]), float(solid[1]), float(solid[2]), float(solid[3]))
	for collision in world_data.get("tiles", {}).get("collisions", []):
		_mark_npc_navigation_rect(float(collision[0]), float(collision[1]), float(collision[2]), float(collision[3]))
	var maps: Dictionary = village.get("maps", {})
	var offsets: Dictionary = village.get("offsets", {})
	for region_id in maps:
		var offset: Dictionary = offsets.get(region_id, {})
		for water in maps[region_id].get("water", []):
			_mark_npc_navigation_rect(float(water.x) + float(offset.get("x", 0)), float(water.y) + float(offset.get("y", 0)), float(water.w), float(water.h))

func _mark_npc_navigation_rect(x: float, y: float, width: float, height: float) -> void:
	var left := clampi(floori(x / 32.0), 0, 119)
	var top := clampi(floori(y / 32.0), 0, 119)
	var right := clampi(floori((x + width - 0.01) / 32.0), 0, 119)
	var bottom := clampi(floori((y + height - 0.01) / 32.0), 0, 119)
	for row in range(top, bottom + 1):
		for column in range(left, right + 1):
			npc_navigation.set_point_solid(Vector2i(column, row), true)

func _nearest_npc_walkable(point: Vector2) -> Vector2i:
	var origin := Vector2i(clampi(floori(point.x / 32.0), 0, 119), clampi(floori(point.y / 32.0), 0, 119))
	if not npc_navigation.is_point_solid(origin):
		return origin
	for radius in range(1, 12):
		var candidate := origin
		var candidate_distance := 1e20
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var cell := origin + Vector2i(x, y)
				if cell.x < 0 or cell.y < 0 or cell.x >= 120 or cell.y >= 120 or npc_navigation.is_point_solid(cell):
					continue
				var distance := Vector2(cell - origin).length_squared()
				if distance < candidate_distance:
					candidate = cell
					candidate_distance = distance
		if candidate_distance < 1e20:
			return candidate
	return origin

func _npc_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var start := _nearest_npc_walkable(from)
	var finish := _nearest_npc_walkable(to)
	var cells: Array[Vector2i] = npc_navigation.get_id_path(start, finish)
	if cells.is_empty():
		return result
	for index in range(1, cells.size()):
		result.append(npc_navigation.get_point_position(cells[index]))
	if result.is_empty() or result.back().distance_to(to) > 8.0:
		result.append(to)
	return result

func _refresh_npc_schedules() -> void:
	GameState.ensure_neighbor_events()
	var event_stamp := ""
	for person in GameState.npc_catalog:
		var npc_id := str(person.get("id", ""))
		var resident: Dictionary = GameState.neighbors.people.get(npc_id, {})
		var event: Dictionary = resident.get("event", {})
		if not event.is_empty(): event_stamp += "%s:%s;" % [npc_id, str(event.get("status", ""))]
	var stamp := "%d:%d:%s:%s:%d:%s:%s" % [GameState.day, GameState.minutes, str(GameState.weather_profile().get("shelter", false)), event_stamp, int(GameState.collection.get("level", 0)), str(GameState.community_projects.get("bridge", false)), str(GameState.minutes > 1080.0)]
	if stamp == npc_schedule_stamp:
		return
	npc_schedule_stamp = stamp
	for npc in npc_nodes:
		var plan := NPC_SCHEDULE.from_state(GameState, npc.get("npc_data"))
		npc.call("set_schedule", plan, _npc_path(npc.global_position, plan.target))

func _create_landmark_interactions(village: Dictionary) -> void:
	GameState.forage_points.clear()
	legacy_gather_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_gather_points.json"))
	for point in legacy_gather_catalog.get(str(GameState.season_index()),[]):
		legacy_gather_nodes[str(point.id)]=_spawn_gather(str(point.id),str(point.item),str(point.name),Vector2(float(point.x),float(point.y)),str(point.get("event","")))
	var maps: Dictionary = village.get("maps", {})
	var offsets: Dictionary = village.get("offsets", {})
	for region_id in maps:
		var offset: Dictionary = offsets.get(region_id, {})
		var map_data: Dictionary = maps[region_id]
		for landmark in map_data.get("landmarks", []):
			if str(landmark.get("kind", "")) != "gather":
				continue
			_spawn_gather(str(landmark.get("id", "")), str(landmark.get("item", "")), str(landmark.get("name", "野生物产")), Vector2(float(landmark.x) + float(offset.get("x", 0)), float(landmark.y) + float(offset.get("y", 0))), str(landmark.get("event", "")))
	var southern_items := ["wood", "wildHerb", "berry", "mushroom", "bamboo", "tea"]
	for i in range(18):
		var item_id: String = southern_items[i % southern_items.size()]
		var definition: Dictionary = GameState.system_catalog.get("forage", {}).get("defs", {}).get(item_id, {})
		_spawn_gather("south-forage-%d" % i, item_id, str(definition.get("name", "野生物产")), Vector2(120 + i * 202, 3510 + (i % 2) * 235))
	_spawn_gather("drift-wood", "wood", "风后漂木", Vector2(1800, 3120), "storm")
	_spawn_gather("rain-mushroom", "mushroom", "雨后新菌", Vector2(850, 2120), "rain")
	_spawn_gather("mist-tea", "tea", "雾中嫩梢", Vector2(1440, 1095), "mist")
	var fish_spots: Array = GameState.system_catalog.get("fishing", {}).get("spots", [])
	for spot in fish_spots:
		var node := Node2D.new()
		node.set_script(FISH_SCRIPT)
		node.set("water_id", str(spot.get("water", "river")))
		node.set("spot_name", str(spot.get("name", "水边")))
		node.set("spot_id", str(spot.get("id", "")))
		node.position = Vector2(float(spot.get("x", 0)), float(spot.get("y", 0)))
		add_child(node)
		fish_nodes.append(node)
	for slot: Dictionary in GameState.system_catalog.fishing.trapSlots:
		var trap:=Node2D.new();trap.set_script(preload("res://scripts/fish_trap.gd"));trap.slot=slot;trap.position=Vector2(float(slot.x),float(slot.y));add_child(trap);trap_nodes.append(trap)

func _spawn_gather(node_id: String, item_id: String, title: String, at: Vector2, event: String = "") -> Node2D:
	var node := Node2D.new()
	node.set_script(GATHER_SCRIPT)
	node.set("node_id", node_id)
	node.set("item_id", item_id)
	node.set("node_name", title)
	node.set("event", event)
	node.position = at
	add_child(node)
	gather_nodes.append(node)
	GameState.register_forage_point({"id": node_id, "item": item_id, "name": title, "event": event, "x": at.x, "y": at.y})
	return node

func _create_ground_layer() -> void:
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -1
	var season := GameState.season_index()
	ground.tile_set = GROUND_TILE_SET
	for row in range(120):
		for col in range(120):
			ground.set_cell(Vector2i(col, row), 0, _ground_tile_coordinates(4, col, row, season))
	var village: Dictionary = world_data.get("village", {})
	var base_by_region := {"mountain": 0, "town": 1, "river": 2, "bamboo": 3, "farm": 4, "pasture": 5}
	for region in village.get("regions", []):
		var region_id := str(region.id)
		var left := int(region.x / 32)
		var top := int(region.y / 32)
		for row in range(top, top + 36):
			for col in range(left, left + 60):
				var variant := int(base_by_region.get(region_id, 4))
				ground.set_cell(Vector2i(col, row), 0, _ground_tile_coordinates(variant, col, row, season))
	for corridor in village.get("corridors", []):
		_paint_rect(ground, corridor, 6, season)
	var offsets: Dictionary = village.get("offsets", {})
	var maps: Dictionary = village.get("maps", {})
	for region_id in maps:
		var offset: Dictionary = offsets[region_id]
		var map_data: Dictionary = maps[region_id]
		for water in map_data.get("water", []):
			_paint_rect(ground, {"x": water.x + offset.x, "y": water.y + offset.y, "w": water.w, "h": water.h}, 8, season)
		for path in map_data.get("paths", []):
			var path_tile := 9 if path.kind == "wood" else 7 if path.kind == "stone" else 6
			_paint_rect(ground, {"x": path.x + offset.x, "y": path.y + offset.y, "w": path.w, "h": path.h}, path_tile, season)
	ground_layer = ground
	ground_season = season
	add_child(ground)
	preload("res://scripts/ground_style.gd").apply(ground)

func _ground_tile_coordinates(atlas_x: int, col: int, row: int, season: int) -> Vector2i:
	var variant := posmod(col * 17 + row * 31 + col * row, 4)
	return Vector2i(atlas_x, season * 4 + variant)

func _paint_rect(layer: TileMapLayer, rect: Dictionary, atlas_x: int, season: int) -> void:
	var left := maxi(0, floori(float(rect.x) / 32.0))
	var top := maxi(0, floori(float(rect.y) / 32.0))
	var right := mini(119, floori((float(rect.x) + float(rect.w)) / 32.0))
	var bottom := mini(119, floori((float(rect.y) + float(rect.h)) / 32.0))
	for row in range(top, bottom + 1):
		for col in range(left, right + 1):
			layer.set_cell(Vector2i(col, row), 0, _ground_tile_coordinates(atlas_x, col, row, season))

func _refresh_ground_season(season: int) -> void:
	if ground_layer == null or ground_season == season:
		return
	for cell in ground_layer.get_used_cells():
		var atlas_coordinates := ground_layer.get_cell_atlas_coords(cell)
		var variant := posmod(atlas_coordinates.y, 4)
		ground_layer.set_cell(cell, 0, Vector2i(atlas_coordinates.x, season * 4 + variant))
	ground_season = season
	preload("res://scripts/ground_style.gd").apply(ground_layer)

func _draw() -> void:
	map_draw_count += 1
	var village: Dictionary = world_data.get("village", {})
	for region in village.get("regions", []):
		draw_string(ThemeDB.fallback_font, Vector2(float(region.x) + 56.0, float(region.y) + 76.0), str(region.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.98, 0.94, 0.81, 0.62))
	if not preload("res://scripts/farm_surface_art.gd").counter(self):
		draw_rect(Rect2(2518, 1703, 48, 32), Color("8e7251"), true)
		draw_rect(Rect2(2512, 1694, 60, 10), Color("b77a56"), true)
		draw_string(ThemeDB.fallback_font, Vector2(2517, 1727), "杂货柜台", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff0ce"))
	if not preload("res://scripts/farm_surface_art.gd").stove(self):
		draw_rect(Rect2(2770, 1685, 46, 30), Color("7e6950"), true)
		draw_rect(Rect2(2765, 1679, 56, 8), Color("9d7856"), true)
		draw_circle(Vector2(2793, 1675), 7, Color("d98b54"))
		draw_string(ThemeDB.fallback_font, Vector2(2778, 1736), "小灶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff0ce"))
	_draw_quest_sites()
	_draw_economy_handover()
	_draw_building_layout()
	_draw_selected_target()

func _draw_economy_handover() -> void:
	var handovers: Array = GameState.system_catalog.get("economy", {}).get("handover", [])
	for point in handovers:
		var at := Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))
		var cooperative := str(point.get("name", "")).contains("合作社")
		var channel := "coop" if cooperative else "stall"
		var jobs: Array = []
		for job in GameState.economy.get("jobs", []):
			if str(job.get("channel", "")) == channel: jobs.append(job)
		var ready := jobs.any(func(job: Dictionary) -> bool: return int(job.get("ready", 0)) <= GameState._kitchen_now())
		if not preload("res://scripts/market_art.gd").draw(self,at,channel,jobs,GameState._kitchen_now()):
			var wood := Color("987048")
			draw_rect(Rect2(at.x - 35, at.y - 9, 70, 25), Color("23392f", 0.28), true)
			draw_rect(Rect2(at.x - 30, at.y - 25, 60, 20), wood, true)
			draw_rect(Rect2(at.x - 34, at.y - 29, 68, 6), Color("cfad76"), true)
			for slat in range(5): draw_rect(Rect2(at.x - 25 + slat * 12, at.y - 22, 2, 14), Color("b9955e"), true)
			draw_rect(Rect2(at.x - 25, at.y - 36, 34, 5), Color("d9bf84"), true)
			draw_rect(Rect2(at.x - 25, at.y - 43, 34, 7), Color("baa274"), true)
			draw_rect(Rect2(at.x + 12, at.y - 42, 4, 18), Color("836549"), true)
			draw_rect(Rect2(at.x + 6, at.y - 47, 31, 15), Color("a16b47") if ready else Color("5b816b"), true)
			draw_string(ThemeDB.fallback_font, at + Vector2(20, -36), "貨單" if cooperative else "竹匾", HORIZONTAL_ALIGNMENT_CENTER, 38, 8, Color("fff0c3"))
			if not jobs.is_empty():
				for item_index in range(mini(3, jobs.size())):
					draw_rect(Rect2(at.x - 19 + item_index * 14, at.y - 37, 10, 9), [Color("b87757"), Color("759166"), Color("d3b378")][item_index], true)
					draw_rect(Rect2(at.x - 16 + item_index * 14, at.y - 41, 3, 4), Color("546d4d"), true)
		if ready:
			draw_circle(at + Vector2(31, -8), 4, Color("f6d78c"))
		if player != null and player.global_position.distance_to(at) < 84.0:
			draw_arc(at + Vector2(0, -4), 44.0, 0.0, TAU, 24, Color("f2dfaa", 0.75), 2.0)
		draw_string(ThemeDB.fallback_font, at + Vector2(0, 28), GameState.interaction_input_label()+(" · 合作社货单" if cooperative else " · 摆摊与经营"), HORIZONTAL_ALIGNMENT_CENTER, 170, 11, Color("fff0ce"))

func _draw_building_layout() -> void:
	var building_rules: Dictionary = GameState.system_catalog.get("building", {})
	var zones: Dictionary = building_rules.get("zones", {})
	var definitions: Dictionary = building_rules.get("defs", {})
	var furniture: Dictionary = GameState.content.get("furniture", {})
	for zone_id in ["court", "orchard"]:
		var zone: Dictionary = zones.get(zone_id, {})
		var open := bool(GameState.upgrades.get("yard", false)) if zone_id == "court" else bool(GameState.building.get("land", {}).get("orchard", false))
		if zone.is_empty() or not open: continue
		var area := Rect2(float(zone.x), float(zone.y), int(zone.cols) * float(zone.size), int(zone.rows) * float(zone.size))
		draw_rect(area, Color("d7cfa2", 0.18), false, 2.0)
		for col in range(int(zone.cols) + 1):
			var x := float(zone.x) + col * float(zone.size)
			draw_line(Vector2(x, float(zone.y)), Vector2(x, area.end.y), Color("eee1b6", 0.2), 1.0)
		for row in range(int(zone.rows) + 1):
			var y := float(zone.y) + row * float(zone.size)
			draw_line(Vector2(float(zone.x), y), Vector2(area.end.x, y), Color("eee1b6", 0.2), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, area.position.y - 8), str(zone.get("name", zone_id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f7e9c7"))
	for piece in GameState.building.get("layout", []):
		var zone: Dictionary = zones.get(str(piece.get("zone", "")), {})
		var definition: Dictionary = definitions.get(str(piece.get("type", "")), {})
		if zone.is_empty() or definition.is_empty(): continue
		var cols := int(zone.cols)
		var rotation := posmod(int(piece.get("rotation", 0)), 4)
		var width := int(definition.get("w", 1)) if rotation % 2 == 0 else int(definition.get("h", 1))
		var height := int(definition.get("h", 1)) if rotation % 2 == 0 else int(definition.get("w", 1))
		var cell := int(piece.cell)
		var x := float(zone.x) + (cell % cols) * float(zone.size)
		var y := float(zone.y) + int(cell / cols) * float(zone.size)
		var box := Rect2(x + 3.0, y + 3.0, width * float(zone.size) - 6.0, height * float(zone.size) - 6.0)
		var data: Dictionary = furniture.get(str(piece.get("type", "")), {})
		var tint := Color(str(data.get("color", definition.get("color", "#a9895d"))))
		draw_rect(box, tint, true)
		draw_rect(box, tint.lightened(0.28), false, 2.0)
		if int(piece.get("key", 0)) == hovered_building_piece: draw_rect(box.grow(4.0), Color("f7e6a5"), false, 2.0)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(5, minf(box.size.y - 4.0, 19.0)), str(data.get("name", piece.get("type", "摆设"))), HORIZONTAL_ALIGNMENT_LEFT, maxf(20.0, box.size.x - 8.0), 12, Color("fff5df"))

func _sync_building_collisions() -> void:
	var revision := int(GameState.building.get("revision", 0))
	if revision == building_collision_revision or not is_instance_valid(building_collision_root): return
	building_collision_revision = revision
	for child in building_collision_root.get_children(): child.queue_free()
	var route_obstacles: Array[Rect2] = []
	var rules: Dictionary = GameState.system_catalog.get("building", {})
	var zones: Dictionary = rules.get("zones", {})
	var definitions: Dictionary = rules.get("defs", {})
	for piece in GameState.building.get("layout", []):
		if str(piece.get("zone", "")) == "home": continue
		var definition: Dictionary = definitions.get(str(piece.get("type", "")), {})
		if not bool(definition.get("solid", false)): continue
		var zone: Dictionary = zones.get(str(piece.get("zone", "")), {})
		if zone.is_empty(): continue
		var cols := int(zone.cols)
		var rotation := posmod(int(piece.get("rotation", 0)), 4)
		var width := int(definition.get("w", 1)) if rotation % 2 == 0 else int(definition.get("h", 1))
		var height := int(definition.get("h", 1)) if rotation % 2 == 0 else int(definition.get("w", 1))
		var cell := int(piece.cell)
		var size := Vector2(width * float(zone.size) - 8.0, height * float(zone.size) - 8.0)
		var center := Vector2(float(zone.x) + (cell % cols + width * 0.5) * float(zone.size), float(zone.y) + (int(cell / cols) + height * 0.5) * float(zone.size))
		route_obstacles.append(Rect2(center - size * 0.5, size))
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = size
		shape.shape = rectangle
		body.position = center
		body.add_child(shape)
		building_collision_root.add_child(body)
	GameState.atlas_set_dynamic_obstacles(route_obstacles)

func _add_blocker(rect: Rect2) -> void:
	rect = preload("res://scripts/world_layout.gd").collision(rect)
	if static_blockers.has(rect): return
	static_blockers[rect] = true
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.position + rect.size * 0.5
	body.add_child(collision)
	add_child(body)

func _process(delta: float) -> void:
	_candidate_frame = -1
	_ambient_redraw_elapsed += delta
	_gather_redraw_elapsed += delta
	var presentation := preload("res://scripts/life_presentation.gd")
	var view: Rect2 = presentation.visible_rect(self)
	if presentation.animate() and _ambient_redraw_elapsed >= 1.0 / 24.0:
		_ambient_redraw_elapsed = fmod(_ambient_redraw_elapsed, 1.0 / 24.0)
		for node in animal_nodes:
			if node.visible and view.has_point(node.global_position):
				node.queue_redraw()
	if presentation.animate() and _gather_redraw_elapsed >= 1.0 / 12.0:
		_gather_redraw_elapsed = fmod(_gather_redraw_elapsed, 1.0 / 12.0)
		for node in gather_nodes:
			if node.visible and view.has_point(node.global_position):
				node.queue_redraw()
	for npc in npc_nodes:
		npc.call("present_resident", GameState)
	_discovery_elapsed += delta
	if _discovery_elapsed >= 0.1:
		_discovery_elapsed = 0.0
		for node in gather_nodes:
			if player.global_position.distance_squared_to(node.global_position) < 240.0 * 240.0:
				GameState.discover_forage(str(node.node_id))
	if not GameState.ui_open:
		_refresh_pointer_hover()
		_refresh_world_target()


func _target_point(kind: String, identity: Variant, at: Vector2, label: String, ready: bool = true) -> Dictionary:
	return {"kind":kind,"id":identity,"x":at.x,"y":at.y,"name":label,"ready":ready}

func _legacy_outdoor_targets() -> Array:
	if legacy_outdoor_catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/outdoor_legacy_points.json"))
		if parsed is Dictionary: legacy_outdoor_catalog = parsed
	var mask := (1 if bool(GameState.upgrades.get("storage",false)) else 0) + (2 if bool(GameState.upgrades.get("mill",false)) else 0) + (4 if bool(GameState.upgrades.get("room",false)) else 0)
	var key := "%d/%d/%d" % [GameState.season_index(),1 if bool(GameState.flags.get("bridge",false)) else 0,mask]
	var points: Variant = legacy_outdoor_catalog.get("cases",{}).get(key,[])
	return points if points is Array else []

func _world_target_candidates() -> Array:
	var frame := Engine.get_process_frames()
	if frame == _candidate_frame: return _candidate_cache
	_candidate_frame = frame
	var points: Array = []
	for id: String in quest_site_points:
		var site: Dictionary=quest_site_points[id]
		points.append(_target_point("quest-project",id,Vector2(float(site.x),float(site.y)),str(GameState.content.projects[id].name)))
	points.append_array(preload("res://scripts/ranch_products.gd").points(GameState,""))
	for i in range(plot_nodes.size()):
		var point := _target_point("plot","plot-" + str(i),plot_nodes[i].global_position,str(i + 1) + " 号田")
		point.index = i
		points.append(point)
	for i in range(mini(animal_nodes.size(), GameState.animals.size())):
		if not animal_nodes[i].visible: continue
		var animal: Dictionary = GameState.animals[i]
		var point := _target_point("animal",str(animal.get("id",i)),animal_nodes[i].global_position,str(animal.get("name","家畜")))
		point.index = i
		points.append(point)
	for npc in npc_nodes:
		if npc.visible:
			points.append(_target_point("npc",str(npc.npc_id),npc.global_position,GameState.npc_name(str(npc.npc_id))))
	for node in gather_nodes:
		var point:=_target_point("gather",str(node.node_id),node.global_position,str(node.node_name))
		point.item=str(node.item_id)
		point.event=str(node.event)
		points.append(point)
	for trap: Node2D in trap_nodes:
		points.append(_target_point("fishtrap",str(trap.slot.id),trap.global_position,str(trap.slot.name)))
	for node in fish_nodes:
		points.append(_target_point("fish",str(node.spot_id),node.global_position,str(node.spot_name)))
	for wildlife in GameState.system_catalog.get("museum",{}).get("wildlife",[]):
		if not preload("res://scripts/life_presentation.gd").wildlife_available(str(wildlife.get("id", "")), GameState.season_index(), GameState.minutes, GameState.weather_profile()):
			continue
		points.append(_target_point("wildlife",str(wildlife.get("id","")),Vector2(float(wildlife.get("x",0)),float(wildlife.get("y",0))),str(wildlife.get("name","野生伙伴"))))
	var pet: Dictionary = GameState.ranch.get("pet",{}).get("position",{})
	points.append(_target_point("pet","pet",Vector2(float(pet.get("x",2822)),float(pet.get("y",1603))),str(GameState.pet_state.get("name","小团"))))
	for house in world_data.get("village",{}).get("houses",[]):
		var door: Dictionary = house.get("door",{})
		var point := _target_point("enter",str(house.get("id","")),Vector2(float(door.get("x",0)),float(door.get("y",0))),str(house.get("name","房屋")) + " · 推门进去")
		point.house = str(house.get("id",""))
		points.append(point)
	for source in GameState.system_catalog.get("economy",{}).get("handover",[]):
		points.append(source.duplicate(true))
	for source in world_data.get("village",{}).get("outdoorActions",[]):
		points.append(source.duplicate(true))
	for piece in GameState.building.get("layout",[]):
		if str(piece.get("zone","")) == "home": continue
		var definition: Dictionary = GameState.system_catalog.get("building",{}).get("defs",{}).get(str(piece.get("type","")),{})
		var point := _target_point("build-piece",int(piece.get("key",0)),_building_piece_position(piece),str(definition.get("name","陈设")))
		point.piece_key = int(piece.get("key",0))
		point.service = str(definition.get("service",""))
		points.append(point)
	points.append_array(_legacy_outdoor_targets())
	points.append(_target_point("tools","farm-tools",Vector2(2184,1536),"农具台"))
	points.append(_target_point("cook","farm-stove",Vector2(2793,1700),"小灶"))
	points.append(_target_point("shop","farm-counter",Vector2(2542,1717),"杂货柜台"))
	_candidate_cache = points
	return points

func _target_ready(point: Dictionary,tool: String) -> bool:
	return bool(INTERACTION_DESCRIPTION.describe(GameState,point,tool).get("ready",false))

func _refresh_world_target() -> Dictionary:
	# Explicit refresh also follows same-frame movement and interaction callbacks.
	_candidate_frame = -1
	if selection_tool != GameState.selected_tool:
		interaction_selection.clear()
		selection_tool = GameState.selected_tool
	var previous := interaction_selection.key
	var previous_point := Vector2(float(selected_world_target.get("x",0)),float(selected_world_target.get("y",0)))
	selected_world_target = interaction_selection.choose(player.global_position,GameState.player_direction_vector(),_world_target_candidates(),pointer_hover,GameState.selected_tool,"",_target_ready)
	var kind := str(selected_world_target.get("kind",""))
	hovered_plot = int(selected_world_target.get("index",-1)) if kind == "plot" else -1
	hovered_animal = int(selected_world_target.get("index",-1)) if kind == "animal" else -1
	hovered_npc = str(selected_world_target.get("id","")) if kind == "npc" else ""
	hovered_resource = str(selected_world_target.get("id","")) if kind == "gather" else ""
	hovered_fish = str(selected_world_target.get("id","")) if kind == "fish" else ""
	hovered_wildlife = str(selected_world_target.get("id","")) if kind == "wildlife" else ""
	hovered_pet = kind == "pet"
	hovered_building_piece = int(selected_world_target.get("piece_key",0)) if kind == "build-piece" else 0
	if previous != interaction_selection.key or previous_point != Vector2(float(selected_world_target.get("x",0)),float(selected_world_target.get("y",0))):
		interaction_presentation_changed.emit()
		queue_redraw()
		for node in plot_nodes + animal_nodes + npc_nodes + gather_nodes + fish_nodes: node.queue_redraw()
	return selected_world_target

func _cycle_world_target(direction: int = 1) -> void:
	pointer_screen=null
	pointer_hover.clear()
	_refresh_world_target()
	var target: Dictionary = interaction_selection.cycle(direction)
	_refresh_world_target()
	if not target.is_empty():
		GameState.message = "当前目标：" + str(target.get("name","手边物件"))
		GameState.changed.emit()
	queue_redraw()

func _draw_selected_target() -> void:
	if selected_world_target.is_empty() or GameState.ui_open or GameState.action_busy(): return
	var at := Vector2(float(selected_world_target.x),float(selected_world_target.y))
	draw_arc(at,19,0,TAU,24,Color("ffe39c"),2)


func _sync_ranch_visuals() -> void:
	for index in range(mini(animal_nodes.size(),GameState.animals.size())):
		var a: Dictionary = GameState.animals[index]
		var p: Dictionary = a.get("position",{})
		animal_nodes[index].position = Vector2(float(p.get("x",0)),float(p.get("y",0)))
		animal_nodes[index].visible = p.get("room") == null
		if animal_nodes[index].visible and preload("res://scripts/life_presentation.gd").visible_rect(self).has_point(animal_nodes[index].global_position):
			animal_nodes[index].queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		hud.call("handle_source_key",event)


func _pointer_leave() -> void:
	pointer_screen=null
	pointer_hover.clear()
	interaction_presentation_changed.emit()
	queue_redraw()

func _refresh_pointer_hover() -> void:
	if pointer_screen==null or GameState.ui_open:return
	if get_viewport().gui_get_hovered_control()!=null:
		_pointer_leave()
		return
	var at:Vector2=get_viewport().get_canvas_transform().affine_inverse()*Vector2(pointer_screen)
	var previous := pointer_hover
	pointer_hover=interaction_selection.hit(at,_world_target_candidates())
	if previous != pointer_hover: interaction_presentation_changed.emit()

func _hover_pointer(at:Vector2) -> void:
	pointer_screen=at
	_hover_at(get_viewport().get_canvas_transform().affine_inverse()*at)
	interaction_presentation_changed.emit()

func _hover_at(at: Vector2) -> void:
	interaction_selection.manual = ""
	pointer_hover = interaction_selection.hit(at,_world_target_candidates())
	_refresh_world_target()

func _click_at(at: Vector2,mode:String="keyboard") -> void:
	GameState.set_source_input_mode(mode)
	if GameState.ui_open or GameState.action_busy(): return
	# Source pointerdown replaces pending work before hit-testing, even a near hit.
	GameState._interrupt_navigation_for_ui()
	GameState.sound_requested.emit("soft")
	var target: Dictionary = interaction_selection.hit(at,_world_target_candidates()).duplicate(true)
	pointer_hover = target.duplicate(true)
	interaction_selection.manual = ""
	if not target.is_empty() and player.global_position.distance_to(Vector2(float(target.x),float(target.y))) < 53.0:
		_activate_walk_target(target)
		return
	if target.is_empty(): target = {"kind":"walk","id":"ground-click","name":"这处落点","x":at.x,"y":at.y}
	target.world_click = true
	target.click_room = GameState.current_interior
	target.auto_interact = str(target.get("kind","")) != "walk"
	player.call("walk_to",target)

func resolve_interaction_target(target: Dictionary) -> Dictionary:
	var identity := interaction_selection.target_key(target)
	for current in _world_target_candidates():
		if interaction_selection.target_key(current) == identity: return current
	return {}

func _activate_walk_target(target: Dictionary) -> void:
	if GameState.ui_open or str(target.get("click_room",GameState.current_interior)) != GameState.current_interior: return
	var current := resolve_interaction_target(target)
	if current.is_empty() or player.global_position.distance_to(Vector2(float(current.x),float(current.y))) >= 53.0:
		GameState.message = "目标已离开手边，请重新走近。"
		GameState.changed.emit()
		return
	_refresh_world_target()
	interaction_selection.manual = interaction_selection.target_key(current)
	pointer_hover = current
	_interact()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_click_at(get_viewport().get_canvas_transform().affine_inverse()*event.position,"touch")
		get_viewport().set_input_as_handled()
		return
	# Godot's emulated mouse event represents the same touch, not a second click.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1:return
	if not GameState.ui_open:
		if event is InputEventMouseMotion:
			_hover_pointer(event.position)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_click_at(get_viewport().get_canvas_transform().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
			return

func _close_top_panel() -> void:
	if hud.call("community_open"): hud.call("close_community")
	elif hud.call("skills_open"): hud.call("close_skills")
	elif hud.call("help_open"): hud.call("close_help")
	elif hud.call("feedback_open"): hud.call("close_feedback")
	elif hud.call("sleep_open"): hud.call("close_sleep")
	elif hud.call("mail_open"): hud.call("close_mail")
	elif hud.call("item_catalog_open"): hud.call("close_item_catalog")
	elif hud.call("settings_open"): hud.call("close_settings")
	elif hud.call("saves_open"): hud.call("close_saves")
	elif hud.call("market_open"): hud.call("close_market")
	elif hud.call("weather_open"): hud.call("close_weather")
	elif hud.call("forage_open"): hud.call("close_forage")
	elif hud.call("fishing_open"): hud.call("close_fishing")
	elif hud.call("kitchen_open"): hud.call("close_kitchen")
	elif hud.call("tools_open"): hud.call("close_tools")
	elif hud.call("farm_facilities_open"): hud.call("close_farm_facilities")
	elif hud.call("farm_planner_open"): hud.call("close_farm_planner")
	elif hud.call("home_open"): hud.call("close_home")
	elif hud.call("neighbors_open"): hud.call("close_neighbors")
	elif hud.call("museum_open"): hud.call("close_museum")
	elif hud.call("festival_open"): hud.call("close_festival")
	elif hud.call("building_open"): hud.call("close_building")
	elif hud.call("ranch_open"): hud.call("close_ranch")

func interact_from_gamepad() -> void:
	if GameState.ui_open or GameState.action_busy():return
	var target:Dictionary=_refresh_world_target()
	if not target.is_empty():_interact_target(target)

func _interact() -> void:
	if GameState.ui_open or GameState.action_busy():return
	if GameState.player_position!=player.global_position:GameState.player_position=player.global_position
	var target := _refresh_world_target()
	if target.is_empty():
		GameState.message = "走近田块、居民或物件，再按 " + OS.get_keycode_string(GameState.bound_key("interact",KEY_E)) + " 操作。"
		GameState.changed.emit()
		return
	_interact_target(target)

func _interact_target(target: Dictionary,performed: bool=false) -> void:
	if GameState.ui_open or GameState.action_busy() or target.is_empty():return
	if not performed and GameState.begin_point_action(target,_interact_target.bind(target.duplicate(true),true)):return
	if str(target.get("kind","")) in ["ranch-box","ranch-product","ranch-trough"]:
		GameState.confirm_operation(GameState.ranch_fixture_action(str(target.kind),str(target.id)))
		return
	var kind:=str(target.get("kind",""))
	var target_plot:=int(target.get("index",-1)) if kind=="plot" else -1
	var target_animal:=GameState.ranch_animal_index(str(target.get("id",""))) if kind=="animal" else -1
	var target_npc:=str(target.get("id","")) if kind=="npc" else ""
	var target_resource:=str(target.get("id","")) if kind=="gather" else ""
	if kind=="quest-project":
		var id: String="project:"+str(target.id)
		if not GameState.quests.entries.has(id):GameState.quest_accept(id)
		hud.life_plan_panel.open_panel(id,"active" if GameState.quests.entries.has(id) else "available");return
	if kind=="fishtrap":
		hud.fishing_panel.page=1;hud.show_fishing();return
	var target_fish:=str(target.get("id","")) if kind=="fish" else ""
	var target_wildlife:=str(target.get("id","")) if kind=="wildlife" else ""
	var target_pet:=kind=="pet"
	var target_building_piece:=int(target.get("piece_key",0)) if kind=="build-piece" else 0
	if kind=="npc" and performed:
		var actual:=resolve_interaction_target(target)
		if actual.is_empty():
			for location in GameState.atlas_targets():
				if str(location.id)=="neighbor-"+target_npc:
					player.walk_to(location)
					return
			return
		if player.global_position.distance_to(Vector2(float(actual.x),float(actual.y)))>70.0:
			actual.world_click=true
			actual.click_room=""
			actual.auto_interact=true
			player.walk_to(actual)
			return
	match str(target.get("kind","")):
		"enter":
			GameState.enter_interior(str(target.get("house",target.get("id",""))))
			return
		"economy":
			var coop := str(target.get("name","")).contains("合作社")
			hud.call("show_market","business" if coop else "sell",true,"coop" if coop else "stall")
			return
		"tools":
			hud.call("show_tools",true)
			return
		"cook":
			hud.call("show_kitchen",true)
			return
		"shop":
			hud.call("show_market","buy",true,"stall")
			return
		"rest":
			GameState.confirm_operation(GameState.rest_at_home())
			_emit_world_effect("care",Vector2(float(target.x),float(target.y)))
			return
		"orders","project","archive","gatherings":
			hud.call("show_community")
			hud.community_panel.call("_select_tab",{"orders":"orders","project":"projects","archive":"archives","gatherings":"gatherings"}[str(target.kind)])
			return
		"mail":
			hud.call("show_mail")
			return
		"festival":
			hud.call("show_festival")
			return
		"storage":
			hud.call("show_kitchen",false,"pantry")
			return
		"processing":
			hud.call("show_kitchen",false,"process")
			return
		"home":
			hud.call("show_home")
			return
		"forage-care":
			GameState.confirm_operation(GameState.care_forage(str(target.get("id","")),str(target.get("item","")),str(target.get("event",""))))
			return
		"forage":
			hud.call("show_forage")
			return
		"farmcare":
			hud.call("show_farm_planner",false,maxi(target_plot,0))
			return
		"weather":
			hud.call("show_weather")
			return
		"animals":
			hud.call("show_ranch")
			hud.ranch_panel.pages.current_tab=clampi(int(target.get("ranchPage",0)),0,3)
			if target.has("recipe"):hud.ranch_panel._select_meta(hud.ranch_panel.recipe_option,str(target.recipe))
			return
		"chore":
			if str(target.get("action","")) == "churn": GameState.queue_kitchen_task({"op":"process","id":"cream","n":1,"station":"dairy"})
			else: GameState.confirm_operation(GameState.perform_interior_chore(target),"good",false)
			return
		"ambient":
			GameState.sound_requested.emit("soft")
			GameState.message = "手边的小物件，也有自己的声响。"
			_emit_world_effect("greet",Vector2(float(target.x),float(target.y)))
			GameState.changed.emit()
			return
	if target_pet:
		var before_pet: Dictionary = GameState.pet_state.duplicate(true)
		GameState.confirm_operation(GameState.pat_companion())
		if GameState.pet_state != before_pet:
			_emit_world_effect("pet", player.global_position)
		queue_redraw()
		return
	if target_building_piece > 0:
		_use_building_piece(target_building_piece)
		return
	if target_resource != "":
		for node in gather_nodes:
			if str(node.node_id) == target_resource:
				var before_items: Dictionary = GameState.inventory.duplicate(true)
				var before_quality: Dictionary = GameState.quality.duplicate(true)
				GameState.confirm_operation(GameState.gather_node(str(node.node_id), str(node.item_id), str(node.event)))
				if int(GameState.inventory.get(str(node.item_id), 0)) > int(before_items.get(str(node.item_id), 0)):
					_emit_world_effect("gather", node.global_position, _quality_has_new_rare(before_quality, GameState.quality))
				node.queue_redraw()
				return
	if target_fish != "":
		for node in fish_nodes:
			if str(node.spot_id) == target_fish:
				var fishing_direction := player.global_position.direction_to(node.global_position)
				player.set("facing", fishing_direction)
				GameState.set_player_direction_from_vector(fishing_direction)
				var character: Node = player.get("character_visual")
				if character != null:
					character.call("set_pose", fishing_direction, false)
				GameState.begin_fishing(str(node.spot_id))
				return
	if target_wildlife != "":
		if GameState.confirm_operation(GameState.observe_wildlife(target_wildlife)):
			_emit_world_effect("greet", player.global_position)
		return
	if target_npc != "":
		var npc_at := player.global_position
		for npc in npc_nodes:
			if str(npc.get("npc_id")) == target_npc:
				npc_at = npc.global_position
				break
		GameState.confirm_operation(GameState.talk_to_npc(target_npc),"soft",false)
		_emit_world_effect("greet", npc_at)
		hud.call("show_npc_dialogue", target_npc)
		return
	if target_animal >= 0:
		var before_animal: Dictionary = GameState.animals[target_animal].duplicate(true)
		var action := str(GameState.selected_animal_action)
		if action == "auto":
			action = GameState.ranch_default_action(target_animal)
		GameState.queue_ranch_tasks([{"animalId":str(before_animal.get("id","")),"action":action,"arg":str(GameState.ranch.get("feed","feed"))}])
		if GameState.animals[target_animal] != before_animal:
			var effect_kind: String = {"collect": "harvest", "feed": "feed", "clean": "brush", "pet": "pet", "treat": "care", "rest": "care", "rescue": "care"}.get(action, "pet")
			var stock: Array = before_animal.get("qualityStock", [0, 0, 0, 0])
			_emit_world_effect(str(effect_kind), animal_nodes[target_animal].global_position, action == "collect" and stock.size() > 3 and int(stock[3]) > 0)
		for animal in animal_nodes:
			animal.queue_redraw()
		return
	if target_plot < 0:
		GameState.message = "走近田块，再按 E 操作。"
		GameState.changed.emit()
		return
	var before_plot: Dictionary = GameState.plots[target_plot].duplicate(true)
	var before_quality: Dictionary = GameState.quality.duplicate(true)
	if GameState.selected_tool in ["hoe","water","sickle"]:
		GameState.queue_farm_tasks(GameState.farm_tool_plan(target_plot,GameState.selected_tool))
	else: GameState.confirm_operation(GameState.farm_plot_action(target_plot))
	if GameState.plots[target_plot] != before_plot:
		var effect_kind: String = {"hoe": "hoe", "seed": "seed", "water": "water", "harvest": "harvest", "fertilizer": "feed", "care": "brush"}.get(str(GameState.selected_tool), "dig")
		_emit_world_effect(str(effect_kind), _plot_position(target_plot), _quality_has_new_rare(before_quality, GameState.quality))
	for plot_node in plot_nodes:
		plot_node.queue_redraw()
	GameState.changed.emit()

func _emit_world_effect(kind: String, at: Vector2, rare: bool = false) -> void:
	if GameState.action_commit_in_progress:return
	if is_instance_valid(world_effects):
		world_effects.call("burst", kind, at, rare)
	if is_instance_valid(player):
		var character: Node = player.get("character_visual")
		if character != null and character.has_method("play_action"):
			character.call("play_action", kind)

func _on_fishing_visual_changed(water_id: String, spot_id: String, state: String, value: float) -> void:
	for node in fish_nodes:
		if str(node.water_id) != water_id:
			continue
		if spot_id != "" and str(node.spot_id) != spot_id:
			continue
		node.call("set_fishing_state", state, value)
	if is_instance_valid(player):
		var character: Node = player.get("character_visual")
		if character != null and character.has_method("set_fishing_pose"):
			character.call("set_fishing_pose", state, value)

func _quality_has_new_rare(before: Dictionary, after: Dictionary) -> bool:
	for item_id in after:
		var old_grades: Array = before.get(item_id, [0, 0, 0])
		var new_grades: Array = after[item_id]
		if new_grades.size() > 2 and int(new_grades[2]) > (int(old_grades[2]) if old_grades.size() > 2 else 0):
			return true
	return false

func _refresh_legacy_gather() -> void:
	for point in legacy_gather_catalog.get(str(GameState.season_index()),[]):
		var id:=str(point.id)
		var node:Node2D=legacy_gather_nodes.get(id,null)
		if node==null:continue
		var definition:Dictionary=GameState.system_catalog.get("forage",{}).get("defs",{}).get(str(point.item),{})
		var title:=str(definition.get("name",point.baseName))+" · "+GameState.forage_description(id,str(point.item),str(point.get("event","")))
		node.set("item_id",str(point.item))
		node.set("node_name",title)
		for registered in GameState.forage_points:
			if str(registered.id)==id:
				registered.item=str(point.item)
				registered.name=title
				break
		node.queue_redraw()

func _refresh() -> void:
	_candidate_frame = -1
	preload("res://scripts/ground_style.gd").update_weather(ground_layer, float(GameState.ground_conditions().get("snow", 0.0)))
	_sync_legacy_furniture()
	_refresh_legacy_gather()
	_sync_building_collisions()
	queue_redraw()
	var visual_season := GameState.season_index()
	if visual_season != last_visual_season:
		last_visual_season = visual_season
		_refresh_ground_season(visual_season)
		get_tree().call_group("seasonal_world_props", "refresh_season")
	for plot_node in plot_nodes:
		plot_node.queue_redraw()
	while animal_nodes.size() > GameState.animals.size():
		var removed: Node2D = animal_nodes.pop_back()
		removed.queue_free()
	while animal_nodes.size() < GameState.animals.size():
		var created := Node2D.new()
		created.set_script(ANIMAL_SCRIPT)
		add_child(created)
		animal_nodes.append(created)
	for i in range(animal_nodes.size()):
		var animal_node := animal_nodes[i]
		var animal_data: Dictionary = GameState.animals[i]
		var saved_position: Dictionary = animal_data.get("position", {})
		animal_node.set("animal_index", i)
		animal_node.position = Vector2(float(saved_position.get("x", animal_node.position.x)), float(saved_position.get("y", animal_node.position.y)))
		animal_node.visible = saved_position.get("room", null) == null
		animal_node.queue_redraw()
	for npc in npc_nodes:
		npc.queue_redraw()
	for node in gather_nodes:
		node.queue_redraw()
	for node in fish_nodes:
		node.queue_redraw()

func _open_building_book() -> void:
	var sites: Dictionary = {}
	var projects: Dictionary = GameState.system_catalog.get("building", {}).get("projects", {})
	for project_id in projects:
		var project: Dictionary = projects[project_id]
		var house_name := str(project.get("house", ""))
		if house_name != "": sites[house_name] = GameState.is_near_building(house_name)
	sites["农具间"] = GameState.is_near_building("农具间")
	hud.call("show_building", sites, GameState.is_near_building("爷爷的老屋"))

func _house_id_by_name(house_name: String) -> String:
	for house in world_data.get("village", {}).get("houses", []):
		if str(house.get("name", "")) == house_name: return str(house.get("id", ""))
	return ""

func _near_economy_handover(house_name: String) -> bool:
	var label := "合作社" if house_name == "禾溪合作社" else "老街竹匾"
	for point in GameState.system_catalog.get("economy", {}).get("handover", []):
		if not str(point.get("name", "")).contains(label): continue
		var handover := Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))
		return player.global_position.distance_to(handover) <= 58.0
	return false

func _nearest_house_id(at: Vector2) -> String:
	var nearest_id := ""
	var nearest_distance := 62.0
	for house in world_data.get("village", {}).get("houses", []):
		var door: Dictionary = house.get("door", {})
		var point := Vector2(float(door.get("x", 0)), float(door.get("y", 0)))
		var distance := at.distance_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = str(house.get("id", ""))
	return nearest_id

func _building_piece_position(piece: Dictionary) -> Vector2:
	var zone: Dictionary = GameState.system_catalog.get("building", {}).get("zones", {}).get(str(piece.get("zone", "")), {})
	var definition: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {}).get(str(piece.get("type", "")), {})
	if zone.is_empty() or definition.is_empty(): return Vector2.ZERO
	var cols := int(zone.get("cols", 1))
	var rotation := posmod(int(piece.get("rotation", 0)), 4)
	var width := int(definition.get("w", 1)) if rotation % 2 == 0 else int(definition.get("h", 1))
	var height := int(definition.get("h", 1)) if rotation % 2 == 0 else int(definition.get("w", 1))
	var cell := int(piece.get("cell", 0))
	var size := float(zone.get("size", 48))
	return Vector2(float(zone.x) + (cell % cols + width * 0.5) * size, float(zone.y) + (int(cell / cols) + height * 0.5) * size)

func _use_building_piece(key: int) -> void:
	for piece in GameState.building.get("layout", []):
		if int(piece.get("key", 0)) != key: continue
		var service := str(GameState.system_catalog.get("building", {}).get("defs", {}).get(str(piece.get("type", "")), {}).get("service", ""))
		match service:
			"rest": GameState.confirm_operation(GameState.rest_at_home())
			"water": GameState.confirm_operation(GameState.fill_farm_water())
			"tools": hud.call("show_tools", true)
			"storage": hud.call("show_kitchen", false, "pantry")
			"farmcare": hud.call("show_farm_planner", false, maxi(hovered_plot, 0))
			"archive", "catalog": hud.call("show_museum", "catalog")
			_: GameState.message = "這處小景，是你親手安置的。"; GameState.sound_requested.emit("soft"); GameState.changed.emit()
		return


func _sync_legacy_furniture() -> void:
	var keep:Dictionary={}
	for piece in GameState.legacy_furniture_slots():
		var slot:int=int(piece.slot)
		keep[slot]=true
		var visual:Sprite2D=legacy_furniture_nodes.get(slot)
		if visual!=null and str(visual.type_id)!=str(piece.id):
			visual.queue_free();legacy_furniture_nodes.erase(slot);visual=null
		if visual==null:
			visual=Sprite2D.new()
			visual.set_script(load("res://scripts/legacy_furniture_visual.gd"))
			visual.type_id=str(piece.id);visual.slot=slot
			visual.name="LegacyFurniture%d"%slot
			visual.position=Vector2(float(piece.x),float(piece.y))
			add_child(visual)
			legacy_furniture_nodes[slot]=visual
		visual.refresh_season()
	for slot in legacy_furniture_nodes.keys():
		if keep.has(slot):continue
		legacy_furniture_nodes[slot].queue_free();legacy_furniture_nodes.erase(slot)

func _create_ambient_actors() -> void:
	var script := preload("res://scripts/ambient_actor.gd")
	for definition: Dictionary in GameState.system_catalog.get("museum", {}).get("wildlife", []):
		var actor := Node2D.new()
		actor.set_script(script)
		actor.set("definition", definition)
		actor.position = Vector2(float(definition.get("x", 0)), float(definition.get("y", 0)))
		add_child(actor)
	var pet := Node2D.new()
	pet.set_script(script)
	pet.set("companion", true)
	add_child(pet)

func _refresh_clock() -> void:
	if not is_inside_tree(): return
	preload("res://scripts/ground_style.gd").update_weather(ground_layer,float(GameState.ground_conditions().get("snow",0.0)))
	queue_redraw()

func _draw_quest_sites() -> void:
	var sites: Dictionary=quest_site_points
	for id: String in sites:
		var at:=Vector2(float(sites[id].x),float(sites[id].y))
		draw_line(at+Vector2(-18,-3),at+Vector2(-18,-32),Color("80684b"),4)
		draw_style_box(preload("res://scripts/detail_art.gd").panel("ui/tooltip"),Rect2(at+Vector2(-70,-68),Vector2(140,36)))
		var text: String=str(GameState.content.projects[id].name)+(" · 成" if bool(GameState.community_projects.get(id,false)) else "")
		draw_string(preload("res://art/fonts/NotoSansCJKsc-Regular.otf"),at+Vector2(-62,-45),text,HORIZONTAL_ALIGNMENT_LEFT,130,13,Color("354537"))

func _prepare_quest_sites() -> void:
	for id: String in preload("res://scripts/quest_service.gd").PROJECT_SITES:
		var target: Dictionary=preload("res://scripts/quest_service.gd").target(GameState,{"id":"project:"+id,"source":"project:"+id})
		if not target.is_empty():quest_site_points[id]=target
