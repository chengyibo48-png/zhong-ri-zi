extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _finish_action(state: Node) -> void:
	for step in range(80):
		if not state.action_busy(): break
		state._process_action(0.1)
	await process_frame
	await process_frame
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(55).timeout.connect(func(): quit(1))
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOME_TARGETS_FIXTURE")))
	if not fixtures is Dictionary:
		quit(1)
		return
	var state = root.get_node("GameState")
	state.set_process(false)
	var home_id := ""
	for house in state.world_village.houses:
		if str(house.name) == "爷爷的老屋": home_id = str(house.id)
	state.current_interior = home_id
	state.interior_position = Vector2(480,550)
	change_scene_to_file("res://scenes/interior.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	_check(world._room_layout().is_empty(),"自宅走动态扩建布局")
	for row in fixtures.rows:
		state.building.house = int(row.house)
		state.building.roomUse = str(row.roomUse)
		var actual: Array = world._room_points()
		_check(JSON.parse_string(JSON.stringify(actual)) == row.points,"原版自宅阶段及功能间候选一致")
	for row in fixtures.furniture:
		state.building.house = 3
		state.building.layout = [row.piece.duplicate(true)]
		state.building.revision = int(state.building.revision) + 1
		world._sync_furniture_collisions()
		await process_frame
		var points: Array = world._home_furniture_points()
		_check(points.size() == 1,"家具生成可走近使用点")
		if points.is_empty(): continue
		var point: Dictionary = points[0]
		_check(str(point.id) == str(row.point.id) and str(point.kind) == str(row.point.kind) and str(point.name) == str(row.point.name) and str(point.service) == str(row.point.get("service","")) and Vector2(float(point.x),float(point.y)).distance_to(Vector2(float(row.point.x),float(row.point.y))) < 0.01,"原版家具坐标、旋转和服务一致")
		world.player.global_position = Vector2(float(point.x),float(point.y)) + Vector2(0,8)
		world.interaction_selection.manual = "build-piece-ignored"
		world._refresh_room_target()
		world.interaction_selection.manual = "build-piece/" + str(point.id)
		world._interact()
		await _finish_action(state)
		_check(str(world.selected_room_target.id) == str(point.id),"家具选择后交互同一对象")
	state.building.layout = []
	state.building.revision = int(state.building.revision) + 1
	world._sync_furniture_collisions()
	await process_frame
	state.building.house = 3
	for entry in [
		{"id":"home-bed","point":Vector2(238,335),"panel":"sleep_open"},
		{"id":"home-plan","point":Vector2(480,548),"panel":"building_open"},
		{"id":"home-kitchen","point":Vector2(650,384),"panel":"kitchen_open"},
		{"id":"home-storage","point":Vector2(300,384),"panel":"kitchen_open"},
		{"id":"home-function","point":Vector2(650,558),"panel":"museum_open"}]:
		state.building.roomUse = "display"
		world.player.global_position = entry.point
		world._refresh_room_target()
		var point: Dictionary = {}
		for candidate in world._room_points():
			if str(candidate.id) == str(entry.id): point = candidate
		world.interaction_selection.manual = world.interaction_selection.target_key(point)
		world._interact()
		await _finish_action(state)
		_check(world.hud.call(str(entry.panel)) and str(world.selected_room_target.id) == str(entry.id),"自宅实际入口打开对应页面")
		world.hud.close_top_panel()
	# The room marker now includes the home and allows pointer selection.
	world.player.global_position = Vector2(238,335)
	world._hover_at(Vector2(238,315))
	_check(str(world.selected_room_target.id) == "home-bed","自宅鼠标悬停睡床")
	world._click_at(Vector2(238,315))
	await _finish_action(state)
	_check(world.hud.sleep_open(),"自宅近距点击打开睡觉确认")
	world.hud.close_sleep()
	world.player.set_physics_process(true)
	world.player.global_position = Vector2(480,550)
	state.interior_position = world.player.global_position
	world._click_at(Vector2(238,315))
	_check(not state.walking_target.is_empty() and not world.player.walk_is_exit,"自宅远距点击使用屋内路线")
	for frame in range(600):
		if state.walking_target.is_empty(): break
		await physics_frame
	await _finish_action(state)
	_check(state.current_interior == home_id and world.hud.sleep_open(),"自宅真实移动到床铺后打开确认")
	print("Home targets smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
