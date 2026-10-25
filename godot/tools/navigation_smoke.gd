extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var temporary_root := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	var userdata := OS.get_user_data_dir().replace("\\", "/")
	if temporary_root == "" or not userdata.begins_with(temporary_root + "/"):
		push_error("导航集成检查需要临时 APPDATA，以免覆盖玩家存档。")
		quit(1)
		return
	var state = root.get_node("GameState")
	state.set_process(false)
	state.current_interior = ""
	state.walking_target.clear()
	state.riding = false
	state.player_position = Vector2(200, 200)
	var previous_geometry: Dictionary = state.world_village
	state.world_village = previous_geometry.duplicate(true)
	state.world_village.solids = [[260,140,60,120]]
	state.world_village.houses = []
	state.world_village.corridors = []
	var obstacle := Rect2(260, 140, 60, 120)
	state.atlas_navigation = load("res://scripts/village_navigation.gd").new({"solids": [[260, 140, 60, 120]]})
	var world := Node2D.new()
	root.add_child(world)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = obstacle.size
	shape.shape = rectangle
	body.position = obstacle.get_center()
	body.add_child(shape)
	world.add_child(body)
	var actor := CharacterBody2D.new()
	actor.set_script(load("res://scripts/player.gd"))
	actor.position = state.player_position
	world.add_child(actor)
	await physics_frame
	var destination := {"kind": "walk", "name": "试验落点", "x": 420, "y": 200}
	var preview: Dictionary = actor.preview_walk(destination)
	_check(bool(preview.get("reachable", false)) and float(preview.get("distance", 0)) > 220, "路线预览绕开实体障碍并计算路径长度")
	var blocked := {"kind": "walk", "name": "障碍内落点", "x": 280, "y": 200}
	_check(not bool(actor.preview_walk(blocked).get("reachable", true)), "点击障碍内部不会伪装成可达落点")
	var edge_route: Dictionary = state.atlas_route(Vector2(247, 200), Vector2(420, 200))
	_check(bool(edge_route.get("reachable", false)) and edge_route.points[0] == Vector2(247, 200), "实际可站立的障碍边缘可以连接到路线网格")
	var tight_navigation = load("res://scripts/village_navigation.gd").new({"solids": [[2974, 428, 225, 108], [2990, 587, 165, 63]]})
	var doorway := Vector2(3081.68, 554)
	var tight_route: Dictionary = tight_navigation.route(Vector2(2831, 1652), doorway)
	_check(bool(tight_route.get("reachable", false)) and not bool(tight_route.get("snapped", true)) and tight_route.points.back() == doorway, "窄门廊保留实际入口而不吸附到远处")
	tight_navigation.set_dynamic_obstacles([Rect2(100, 100, 20, 20)])
	tight_navigation.path_cache["probe"] = []
	tight_navigation.set_dynamic_obstacles([Rect2(100.5, 100, 20, 20)])
	_check(tight_navigation.path_cache.is_empty() and tight_navigation.dynamic_rectangles[0].position.x == 91.5, "家具在同一网格内移动也会更新几何并清除旧路线")
	var previous_pins: Array = state.atlas.get("pins", []).duplicate(true)
	state.atlas.pins = []
	_check(state.atlas_pin_point(Vector2(420, 200), "选中地点") and int(state.atlas.pins.back().x) == 420, "地图图钉记录所选地点而非玩家当前位置")
	_check(not state.atlas_pin_point(Vector2(280, 200), "无效地点"), "障碍内部不能留下可通行图钉")
	state.atlas.pins = previous_pins
	var panel := Control.new()
	panel.set_script(load("res://scripts/map_panel.gd"))
	root.add_child(panel)
	panel.open_panel()
	panel.custom_target = destination.duplicate()
	panel.custom_target.erase("id")
	panel._refresh_detail()
	panel._go_target()
	_check(not panel.visible and not state.walking_target.is_empty(), "地图出发按钮关闭面板并启动原生自动步行")
	state.ui_open = true
	var paused_at := actor.global_position
	for frame in range(8): await physics_frame
	_check(actor.global_position.distance_to(paused_at) < 0.1 and state.walking_target.is_empty() and actor.walk_path.is_empty(), "打开生活簿取消自动路线并保持位置")
	state.ui_open = false
	actor.walk_to(destination)
	var key := InputEventKey.new()
	key.keycode = state.bound_key("right", KEY_D)
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	await physics_frame
	await physics_frame
	var release := InputEventKey.new()
	release.keycode = key.keycode
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	_check(state.walking_target.is_empty(), "手动方向键接管角色并中断自动路线")
	actor.walk_to(destination)
	var collided := false
	for frame in range(300):
		await physics_frame
		if obstacle.has_point(actor.global_position) or state.atlas_source_navigation.blocked(state,"",actor.global_position.x,actor.global_position.y): collided = true
		if state.walking_target.is_empty(): break
	_check(not collided and actor.global_position.distance_to(Vector2(420, 205)) < 0.5 and state.walking_target.is_empty(), "角色按原版阻挡规则绕过障碍并抵达目标")
	state.minutes = 600
	state.npc_residents.qiao = {"x":500.0,"y":200.0,"room":null,"direction":"down"}
	state.npc_movement.publish(state)
	var neighbor_target: Dictionary = {}
	for target in state.atlas_targets():
		if str(target.get("id", "")) == "neighbor-qiao": neighbor_target = target
	actor.walk_to(neighbor_target)
	for frame in range(5): await physics_frame
	state.npc_residents.qiao.x = 600.0
	state.npc_movement.publish(state)
	for frame in range(160):
		await physics_frame
		if state.walking_target.is_empty(): break
	_check(actor.global_position.distance_to(Vector2(500, 205)) < 0.5, "地图人物落点保持出发时的位置，不混入面对面追踪规则")
	panel.queue_free()
	world.queue_free()
	await process_frame
	state.world_village = previous_geometry
	state.set_process(true)
	state.atlas_navigation = load("res://scripts/village_navigation.gd").new(state.world_village)
	state.current_interior = "home-granny"
	state.minutes = 450
	state.interior_position = Vector2(480, 550)
	var house: Dictionary = state.interior_house()
	var door: Dictionary = house.get("door", {})
	state.interior_return_position = Vector2(float(door.get("x", 0)), float(door.get("y", 0))) + Vector2(0, 20)
	var room = load("res://scenes/interior.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await physics_frame
	var outdoor_target := {"kind": "walk", "name": "屋外落点", "x": state.interior_return_position.x, "y": state.interior_return_position.y + 64}
	var granny_targets: Array = state.atlas_targets().filter(func(target: Dictionary) -> bool: return str(target.get("id", "")) == "neighbor-granny")
	_check(not granny_targets.is_empty() and str(granny_targets[0].get("kind", "")) == "enter" and str(granny_targets[0].get("house", "")) == "home-granny", "屋内居民的地图目标指向其住宅入口")
	var room_preview: Dictionary = room.player.preview_walk(outdoor_target)
	_check(bool(room_preview.get("reachable", false)) and not room_preview.get("room_points", []).is_empty(), "从住宅预览路线包含室内出口路径")
	room.player.walk_to(outdoor_target)
	for frame in range(240):
		await physics_frame
		if state.current_interior == "" and state.walking_target.is_empty(): break
	var target_position := Vector2(float(outdoor_target.x), float(outdoor_target.y)+5.0)
	_check(state.current_interior == "" and state.player_position.distance_to(target_position) < 5, "自动走出原门并在场景切换后继续到达户外目标")
	var house_target: Dictionary = {}
	for target in state.atlas_targets():
		if str(target.get("id", "")) == "home-granny": house_target = target
	if current_scene != null and current_scene.get("player") != null:
		current_scene.get("player").walk_to(house_target)
		for frame in range(180):
			await physics_frame
			if state.current_interior == "home-granny": break
	_check(state.current_interior == "home-granny" and state.walking_target.is_empty(), "选择建筑后沿路抵达入口并自动进屋")
	if current_scene != null: current_scene.queue_free();current_scene=null
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Navigation migration: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
