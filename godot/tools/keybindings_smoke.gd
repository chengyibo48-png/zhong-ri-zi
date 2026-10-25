extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error(label)

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		push_error("改键验证需隔离临时 APPDATA。")
		quit(1)
		return
	create_timer(40).timeout.connect(func(): quit(1))
	var state = root.get_node("GameState")
	var defaults := {"up": "w", "left": "a", "down": "s", "right": "d", "interact": "e", "bag": "b", "map": "m", "journal": "j"}
	var custom := {"up": "b", "left": "a", "down": "s", "right": "d", "interact": "e", "bag": "w", "map": "p", "journal": "n"}
	state.player_settings.bindings = custom.duplicate()
	state._normalize_player_settings()
	_check(state.player_settings.bindings == custom, "有效字母键应保留")
	var saved: Dictionary = state._make_save_data().duplicate(true)
	_check(state.load_game_data(saved) and state.player_settings.bindings == custom, "读档保留改键")
	state.player_settings.bindings = {"up": "b", "left": "a", "down": "s", "right": "d", "interact": "e", "bag": "b", "map": "m", "journal": "j"}
	state._normalize_player_settings()
	_check(state.player_settings.bindings == defaults, "重复键应整体恢复默认")
	state.player_settings.bindings = custom.duplicate()
	state.player_settings.bindings.map = "c"
	state._normalize_player_settings()
	_check(state.player_settings.bindings == defaults, "固定保留键应拒绝")
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	# This isolated settings/menu harness has no world actor or selected target.
	hud.context_actions.set_process(false)
	await process_frame
	var settings = hud.settings_panel
	settings.open_panel()
	settings.capturing = "bag"
	settings.capture_key(KEY_W)
	_check(state.player_settings.bindings.bag == "w" and state.player_settings.bindings.up == "b", "设置改键交换冲突动作")
	settings.close()
	state.player_settings.bindings = custom.duplicate()
	for script_path in ["res://scripts/farm_world.gd", "res://scripts/interior_world.gd"]:
		var world := Node2D.new()
		root.add_child(world)
		world.set_script(load(script_path))
		world.hud = hud
		for entry in [["bag", KEY_W, "market_open", "close_market"], ["map", KEY_P, "map_open", "close_map"], ["journal", KEY_N, "community_open", "close_community"]]:
			var event := InputEventKey.new()
			event.pressed = true
			event.keycode = entry[1]
			world._unhandled_key_input(event)
			_check(hud.call(entry[2]), script_path + " 打开 " + entry[0])
			if entry[0] == "journal":
				_check(hud.community_panel.active_tab == "journal", "日记键选择生活日志页")
			world._unhandled_key_input(event)
			_check(hud.call(entry[2]) and state.ui_open, script_path + " 面板内同键不触发世界快捷键 " + entry[0])
			var escape := InputEventKey.new()
			escape.pressed = true
			escape.keycode = KEY_ESCAPE
			world._unhandled_key_input(escape)
			_check(not hud.call(entry[2]) and not state.ui_open, script_path + " Escape 关闭 " + entry[0])
		var move_event := InputEventKey.new()
		move_event.pressed = true
		move_event.keycode = KEY_B
		world._unhandled_key_input(move_event)
		_check(not state.ui_open and not hud.market_open(), "改为移动的 B 不打开背包")
		var old_bag := InputEventKey.new()
		old_bag.pressed = true
		old_bag.keycode = KEY_M
		world._unhandled_key_input(old_bag)
		_check(not hud.map_open() and not hud.museum_open(), "旧地图 M 不继续触发图鉴")
		var menu_key := InputEventKey.new()
		menu_key.pressed = true
		menu_key.keycode = KEY_TAB
		state.walking_target = {"id": "route", "x": 200, "y": 200}
		world._unhandled_key_input(menu_key)
		_check(hud.life_menu.visible and state.ui_open and state.walking_target.is_empty(), "Tab 生活菜单停止自动行走")
		_check(hud.life_menu.buttons.size() == hud.life_menu.ENTRIES.size()+1 and root.gui_get_focus_owner() == hud.life_menu.buttons.bag, "基础入口、邻里簿与默认焦点")
		var before := float(state.minutes)
		state.pass_time(60.0)
		_check(float(state.minutes) == before, "生活菜单暂停时钟")
		hud.life_menu.buttons.journal.pressed.emit()
		_check(not hud.life_menu.visible and hud.community_open() and hud.community_panel.active_tab == "journal", "菜单交接生活日记")
		hud.close_community()
		menu_key.keycode = KEY_ESCAPE
		world._unhandled_key_input(menu_key)
		_check(hud.life_menu.visible, "Esc 打开生活菜单")
		world._unhandled_key_input(menu_key)
		_check(not hud.life_menu.visible and not state.ui_open, "Esc 返回村庄")
		if hud.onboarding_open(): hud.toggle_onboarding()
		var pad := InputEventJoypadButton.new()
		pad.pressed = true
		pad.button_index = JOY_BUTTON_START
		_send_pad(world,pad)
		_check(hud.life_menu.visible, "手柄 Start 打开生活菜单")
		pad.button_index = JOY_BUTTON_B
		_send_pad(world,pad)
		_check(not hud.life_menu.visible and not state.ui_open, "手柄 B 返回村庄")
		world.free()
	hud.queue_free()
	await process_frame
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var live_hud = current_scene.hud
	for route in [["bag", "market"], ["map", "map"], ["calendar", "weather"], ["orders", "community"], ["recipes", "kitchen"], ["relations", "neighbors"], ["journal", "community"], ["build", "building"], ["save", "saves"], ["settings", "settings"], ["help", "help"]]:
		live_hud.show_life_menu()
		live_hud.life_menu.buttons[route[0]].pressed.emit()
		_check(not live_hud.life_menu.visible and live_hud.call(route[1] + "_open") and state.ui_open, "真实农场菜单入口 " + route[0])
		if route[0] == "calendar":
			_check(live_hud.weather_panel.notebook.current_tab == 1, "日历入口打开节气页")
		live_hud.call("close_" + route[1])
	live_hud.show_life_menu()
	live_hud.life_menu.buttons.close.pressed.emit()
	_check(not live_hud.life_menu.visible and not state.ui_open, "回村按钮恢复时间")
	print("Keybinding smoke: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
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
