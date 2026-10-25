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
	create_timer(80).timeout.connect(func(): quit(1))
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("OUTDOOR_POINTS_FIXTURE")))
	if not fixtures is Dictionary:
		quit(1)
		return
	var state = root.get_node("GameState")
	state.set_process(false)
	state.current_interior = ""
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	for key in fixtures.cases:
		var parts: PackedStringArray = str(key).split("/")
		state.day = int(parts[0]) * 28
		state.flags.bridge = parts[1] == "1"
		var mask := int(parts[2])
		state.upgrades.storage = (mask & 1) != 0
		state.upgrades.mill = (mask & 2) != 0
		state.upgrades.room = (mask & 4) != 0
		_check(world._legacy_outdoor_targets() == fixtures.cases[key],"原版四季/河埠/设施组合完整匹配")
	state.day = 0
	state.flags.bridge = true
	state.upgrades.storage = true
	state.upgrades.mill = true
	state.upgrades.room = true
	var points: Array = world._legacy_outdoor_targets()
	var kinds: Dictionary = {}
	for point in points:
		if not kinds.has(str(point.kind)): kinds[str(point.kind)] = point
	var panels := {"orders":"community_open","project":"community_open","archive":"community_open","gatherings":"community_open","mail":"mail_open","festival":"festival_open","storage":"kitchen_open","processing":"kitchen_open","home":"home_open","tools":"tools_open","forage":"forage_open","farmcare":"farm_planner_open","weather":"weather_open","economy":"market_open","animals":"ranch_open"}
	for kind in panels:
		_check(kinds.has(kind),"原版场景存在 " + str(kind) + " 入口")
		if not kinds.has(kind): continue
		var point: Dictionary = kinds[kind]
		world.player.global_position = Vector2(float(point.x),float(point.y)) + Vector2(0,8)
		world._refresh_world_target()
		world.interaction_selection.manual = world.interaction_selection.target_key(point)
		world._interact()
		await _finish_action(state)
		_check(world.hud.call(str(panels[kind])) and str(world.selected_world_target.id) == str(point.id),"实际场景选中对象打开 " + str(kind))
		if kind in ["orders","project","archive","gatherings"]:
			_check(world.hud.community_panel.active_tab == {"orders":"orders","project":"projects","archive":"archives","gatherings":"gatherings"}[kind],"对应共作簿页签")
		if kind in ["storage","processing"]:
			_check(world.hud.kitchen_panel.mode == ("pantry" if kind == "storage" else "process"),"对应食记页签")
		world.hud.close_top_panel()
	var rest: Dictionary = kinds["rest"]
	for fixture in fixtures.rests:
		state.stamina = int(fixture.before.stamina)
		state.minutes = int(fixture.before.minutes)
		world.player.global_position = Vector2(float(rest.x),float(rest.y)) + Vector2(0,8)
		world._refresh_world_target()
		world.interaction_selection.manual = world.interaction_selection.target_key(rest)
		world._interact()
		await _finish_action(state)
		_check(state.stamina == int(fixture.stamina) and state.minutes == int(fixture.minutes) and state.message == str(fixture.message),"原版休息体力、时间上限与文案")
	# Preview routes for every static point in the maximum-unlock spring variant.
	world.player.global_position = Vector2(2831,1652)
	state.player_position = world.player.global_position
	var reachable := 0
	for point in points:
		var target: Dictionary = point.duplicate(true)
		target.world_click = true
		target.click_room = ""
		target.auto_interact = true
		var plan: Dictionary = world.player.preview_walk(target)
		if bool(plan.get("reachable",false)): reachable += 1
		else: push_warning("Unreachable static point: " + str(point.id) + " " + str(point.name))
	_check(reachable == points.size(),"全部已解锁静态点有实际可达的近距路线")
	print("Outdoor points smoke: %d passed, %d failed; routes %d/%d" % [passed,failed,reachable,points.size()])
	quit(1 if failed else 0)
