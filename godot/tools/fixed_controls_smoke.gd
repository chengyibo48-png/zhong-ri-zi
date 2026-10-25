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
	event.keycode = code
	event.pressed = true
	return event

func _pad(code: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	return event

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		push_error("固定键验证需隔离临时 APPDATA。")
		quit(1)
		return
	create_timer(50).timeout.connect(func(): quit(1))
	var state = root.get_node("GameState")
	root.size = Vector2i(960, 600)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var hud = current_scene.hud
	var settings = hud.settings_panel
	_check(settings.binding_buttons.size() == 8, "八个改键入口")
	for action in ["bag", "map", "journal"]:
		settings.open_panel()
		settings.binding_buttons[action].pressed.emit()
		settings.capture_key(KEY_Z)
		_check(state.player_settings.bindings[action] == "z", "设置按钮捕获 " + action)
		settings.reset_bindings_button.pressed.emit()
		_check(state.player_settings.bindings == state.initial_state.settings.bindings and settings.capturing == "", "恢复默认键")
		settings.close()
	hud.onboarding_panel.guide_button.pressed.emit()
	_check(hud.help_open(), "新手手记指南按钮")
	hud.close_help()
	var atlas_before: Dictionary = state.atlas.duplicate(true)
	var onboarding_before: Dictionary = state.onboarding_state().duplicate(true)
	for script_path in ["res://scripts/farm_world.gd", "res://scripts/interior_world.gd"]:
		var world := Node2D.new()
		root.add_child(world)
		world.set_script(load(script_path))
		world.hud = hud
		world._unhandled_key_input(_key(KEY_C))
		_check(hud.weather_open() and hud.weather_panel.notebook.current_tab == 1 and not hud.building_open(), "C 打开节气日历")
		var before: float = state.minutes
		state.pass_time(5)
		_check(float(state.minutes) == before, "日历暂停时间")
		var modified := _key(KEY_H)
		modified.ctrl_pressed = true
		_check(not hud.handle_fixed_shortcut(modified), "组合键不触发全局功能")
		world._unhandled_key_input(_key(KEY_ESCAPE))
		_check(not state.ui_open, "Esc 合上日历")
		world._unhandled_key_input(_key(KEY_H))
		_check(not hud.ambient_hud.visible and hud.restore_hud_button.visible and not state.ui_open, "H 收起界面不暂停游戏")
		hud.refresh()
		_check(not hud.ambient_hud.visible and state.atlas == atlas_before and state.onboarding_state() == onboarding_before, "刷新不覆盖收起状态或改写偏好")
		world._unhandled_key_input(_key(KEY_B))
		_check(hud.market_open() and not hud.ambient_hud.visible, "收起界面仍可打开背包")
		world._unhandled_key_input(_key(KEY_ESCAPE))
		hud.restore_hud_button.pressed.emit()
		_check(hud.ambient_hud.visible and not hud.restore_hud_button.visible, "按钮恢复界面")
		state.onboarding_show()
		_send_pad(world,_pad(JOY_BUTTON_X))
		_check(hud.market_open(), "新手提示不拦截手柄背包")
		hud.close_market()
		if hud.onboarding_open(): hud.toggle_onboarding()
		onboarding_before = state.onboarding_state().duplicate(true)
		_send_pad(world,_pad(JOY_BUTTON_Y))
		_check(hud.map_open() and not hud.museum_open(), "手柄 Y 打开地图")
		_send_pad(world,_pad(JOY_BUTTON_START))
		_check(not hud.map_open() and not state.ui_open, "手柄 Start 关闭地图")
		_send_pad(world,_pad(JOY_BUTTON_B))
		_check(hud.life_menu.visible, "手柄 B 打开生活菜单")
		_send_pad(world,_pad(JOY_BUTTON_B))
		_check(not hud.life_menu.visible and not state.ui_open, "手柄 B 合上菜单")
		state.walking_target = {"id": "route", "x": 200, "y": 200}
		_send_pad(world,_pad(JOY_BUTTON_B))
		_check(state.walking_target.is_empty() and hud.life_menu.visible, "手柄 B 打开生活菜单并停止带路")
		_send_pad(world,_pad(JOY_BUTTON_B))
		_check(not state.ui_open,"再按手柄 B 合上路线中打开的菜单")
		hud.show_item_catalog()
		_send_pad(world,_pad(JOY_BUTTON_B))
		_check(not hud.item_catalog_open() and not state.ui_open, "室内外物品图录手柄关闭")
		world.free()
	hud.show_map()
	Input.parse_input_event(_key(KEY_TAB))
	await process_frame
	_check(hud.map_open(), "地图页 Tab 保持页面并切换焦点")
	var release := _key(KEY_TAB)
	release.pressed = false
	Input.parse_input_event(release)
	hud.close_map()
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		current_scene._unhandled_key_input(_key(KEY_F))
		await process_frame
		_check(root.mode == Window.MODE_FULLSCREEN and not hud.festival_open(), "原生 F 进入全屏")
		hud.show_settings()
		settings.fullscreen_button.pressed.emit()
		await process_frame
		_check(root.mode == Window.MODE_WINDOWED and settings.fullscreen_button.text == "进入全屏", "设置退出全屏恢复窗口")
		settings.fullscreen_button.pressed.emit()
		await process_frame
		_check(root.mode == Window.MODE_FULLSCREEN and settings.fullscreen_button.text == "退出全屏", "设置进入全屏并更新文字")
		settings.fullscreen_button.pressed.emit()
		settings.close()
	var shot := OS.get_environment("CONTROLS_SHOT")
	if shot != "" and DisplayServer.get_name() != "headless":
		hud.toggle_hud()
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shot)
	print("Fixed controls smoke: %d passed, %d failed; backend=%s" % [passed, failed, DisplayServer.get_name()])
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
