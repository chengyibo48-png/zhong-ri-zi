extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	return event

func _pad(code: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = code
	return event

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		push_error("工具栏验证需隔离临时 APPDATA。")
		quit(1)
		return
	create_timer(50).timeout.connect(func(): quit(1))
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOOLBAR_FIXTURE")))
	if not fixture is Dictionary:
		push_error("Missing original TOOLBAR_FIXTURE")
		quit(1)
		return
	var state = root.get_node_or_null("GameState")
	if state == null:
		quit(1)
		return
	for index in range(fixture.toolbar.size()):
		var entry: Dictionary = fixture.toolbar[index]
		_check(state.TOOLBAR_IDS[index] == entry.id and state.TOOLBAR_NAMES[entry.id] == entry.name and int(entry.key) == index + 1, "原版工具名称与顺序")
	for expected in fixture.harvest:
		state._reset_plots()
		for plot in state.plots:
			plot.crop = ""
			plot.growth = 0
			plot.tilled = true
		for i in [1,6,7,8,13]:
			state.plots[i].crop = "cabbage"
			state.plots[i].growth = state.crop_days("cabbage")
		state.toolkit.tools.sickle = {"level":2,"branch":expected.branch,"shape":expected.shape,"xp":0}
		state.farm.autoSeed = bool(expected.auto)
		var seed_id: String = state.seed_item_id("cabbage")
		var seed_before: int = int(state.inventory.get(seed_id,0))
		state.stamina = 100
		state.selected_tool = expected.id
		var targets: Array = [7] if expected.id == "hand" else state._farm_targets(7,"sickle")
		_check(targets == expected.targets.map(func(value): return int(value)), "手/镰目标顺序与原版一致")
		state.farm_plot_action(7)
		var cleared: Array = []
		for i in [1,6,7,8,13]:
			if str(state.plots[i].crop) == "": cleared.append(i)
		_check(cleared == expected.cleared.map(func(value): return int(value)), "手/镰实际收获范围")
		_check(int(state.tool_data("sickle").xp) == int(expected.xp), "手/镰成功作业熟练度")
		_check(int(state.inventory.get(seed_id,0)) - seed_before == int(expected.seedGain), "细作与自动留种不重复")
	for id in state.TOOLBAR_IDS:
		state.select_toolbar_tool(id)
		var snapshot: Dictionary = state._make_save_data().duplicate(true)
		_check(state.load_game_data(snapshot) and state.selected_tool == id, "八种工具保存读回")
	var current: String = state.selected_tool
	_check(not state.select_toolbar_tool("missing") and state.selected_tool == current, "未知工具不改变选择")
	root.size = Vector2i(960,600)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	var hud = world.hud
	for index in range(7):
		world._unhandled_key_input(_key(KEY_1 + index))
		var id: String = state.TOOLBAR_IDS[index]
		_check(state.selected_tool == id and hud.toolbar_buttons[id].button_pressed, "数字键与工具栏同步")
		hud.toolbar_buttons.hoe.pressed.emit()
		_check(state.selected_tool == "hoe", "鼠标选择工具")
	world._unhandled_key_input(_key(KEY_8))
	_check(state.selected_tool == "build" and hud.building_open() and hud.building_panel.tab == "layout", "8 直接打开布置草图")
	hud.close_building()
	state.select_toolbar_tool("hoe")
	_send_pad(world,_pad(JOY_BUTTON_LEFT_SHOULDER))
	_check(state.selected_tool == "build" and hud.building_open(), "左肩键循环至布置")
	hud.close_building()
	_send_pad(world,_pad(JOY_BUTTON_RIGHT_SHOULDER))
	_check(state.selected_tool == "hoe", "右肩键循环回锄头")
	hud.show_map()
	world._unhandled_key_input(_key(KEY_6))
	_send_pad(world,_pad(JOY_BUTTON_RIGHT_SHOULDER))
	_check(state.selected_tool == "hoe", "面板中不切换工具")
	hud.close_map()
	var plots_before: Array = state.plots.duplicate(true)
	var stamina_before: int = state.stamina
	state.select_toolbar_tool("rod")
	state.farm_plot_action(7)
	_check(state.plots == plots_before and state.stamina == stamina_before, "鱼竿不能误操作农田")
	var house_id := ""
	for house in state.world_village.houses:
		if str(house.get("name","")) == "爷爷的老屋":
			house_id = str(house.id)
			state.player_position = Vector2(float(house.door.x),float(house.door.y))
			break
	_check(state.enter_interior(house_id), "进入实际室内")
	await process_frame
	await process_frame
	world = current_scene
	hud = world.hud
	for index in range(7):
		world._unhandled_key_input(_key(KEY_1 + index))
		_check(state.selected_tool == state.TOOLBAR_IDS[index], "实际室内数字键")
	world._unhandled_key_input(_key(KEY_8))
	_check(state.selected_tool == "build" and hud.building_open() and hud.building_panel.tab == "layout", "室内布置入口")
	hud.close_building()
	state.select_toolbar_tool("hand")
	_send_pad(world,_pad(JOY_BUTTON_RIGHT_SHOULDER))
	_check(state.selected_tool == "rod", "室内肩键轮换")
	print("Toolbar smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _send_pad(world:Node,event:InputEventJoypadButton)->void:
	var source_indices:={JOY_BUTTON_A:0,JOY_BUTTON_B:1,JOY_BUTTON_X:2,JOY_BUTTON_Y:3,JOY_BUTTON_LEFT_SHOULDER:4,JOY_BUTTON_RIGHT_SHOULDER:5,JOY_BUTTON_BACK:8,JOY_BUTTON_START:9,JOY_BUTTON_LEFT_STICK:10,JOY_BUTTON_RIGHT_STICK:11,JOY_BUTTON_DPAD_UP:12,JOY_BUTTON_DPAD_DOWN:13,JOY_BUTTON_DPAD_LEFT:14,JOY_BUTTON_DPAD_RIGHT:15}
	var buttons:Array=[]
	buttons.resize(17)
	buttons.fill(false)
	var state=root.get_node("GameState")
	var actor:=Node.new()
	world.add_child(actor)
	state.poll_source_gamepad(1000.0,actor,{"connected":true,"buttons":buttons,"axes":[0.0,0.0]})
	buttons[source_indices[event.button_index]]=event.pressed
	state.poll_source_gamepad(1001.0,actor,{"connected":true,"buttons":buttons,"axes":[0.0,0.0]})
	actor.free()
