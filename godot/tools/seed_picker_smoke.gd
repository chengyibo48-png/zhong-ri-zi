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

func _finish_action(state: Node) -> void:
	for step in range(80):
		if not state.action_busy(): break
		state._process_action(0.1)
	await process_frame
	await process_frame

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		push_error("选种验证需隔离临时 APPDATA。")
		quit(1)
		return
	create_timer(50).timeout.connect(func(): quit(1))
	var fixture_path := OS.get_environment("SEED_FIXTURE")
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixtures is Array:
		push_error("Missing source SEED_FIXTURE")
		quit(1)
		return
	root.size = Vector2i(960, 600)
	var state = root.get_node("GameState")
	state.set_process(false)
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	# Standalone HUD has no world actor; world context is covered by its real-scene probe.
	hud.context_actions.set_process(false)
	await process_frame
	var picker = hud.seed_picker
	for fixture in fixtures:
		state.day = int(fixture.day)
		state.inventory = fixture.bag.duplicate(true)
		picker.open_panel()
		_check(picker.crop_buttons.size() == fixture.rows.size(), "完整原版作物列表")
		var rows_match := true
		var disabled_match := true
		for row in fixture.rows:
			var crop: Dictionary = state.crop_data(row.id)
			rows_match = rows_match and state.crop_name(row.id) == row.name and int(crop.days) == int(row.days) and str(crop.group) == row.group and state.seed_item_id(row.id) == row.seed
			rows_match = rows_match and picker.crop_labels[row.id].text.contains("背包种子 %d 份" % int(row.quantity))
			disabled_match = disabled_match and picker.crop_buttons[row.id].disabled == not bool(row.enabled)
		_check(rows_match, "源作物名称天数类别和库存")
		_check(disabled_match, "当季禁用规则")
		var before_inventory: Dictionary = state.inventory.duplicate(true)
		for row in fixture.rows:
			if bool(row.enabled) and int(row.quantity) == 0:
				state.farm.seedKind = "heirloom"
				picker.crop_buttons[row.id].pressed.emit()
				_check(state.selected_seed == row.id and state.selected_tool == "seed" and state.farm.seedKind == "normal" and not picker.visible, "允许选择零库存当季种子并恢复普通品种")
				_check(state.inventory == before_inventory, "选择不消耗种子")
				break
		var old_seed: String = state.selected_seed
		for row in fixture.rows:
			if not bool(row.enabled):
				_check(not state.choose_normal_seed(row.id) and state.selected_seed == old_seed, "反季选择拒绝且保留种子")
				break
		picker.close()
	_check(not state.choose_normal_seed("missing"), "未知作物拒绝")
	var save: Dictionary = state._make_save_data().duplicate(true)
	var selected: String = state.selected_seed
	_check(state.load_game_data(save) and state.selected_seed == selected and state.selected_tool == "seed" and state.farm.seedKind == "normal", "选种状态存档往返")
	for script_path in ["res://scripts/farm_world.gd", "res://scripts/interior_world.gd"]:
		var world := Node2D.new()
		root.add_child(world)
		world.set_script(load(script_path))
		world.hud = hud
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_Q
		world._unhandled_key_input(key)
		_check(picker.visible and state.ui_open, "室内外 Q 打开选种")
		var before: float = state.minutes
		state.pass_time(10)
		_check(float(state.minutes) == before, "选种页暂停时间")
		key.keycode = KEY_ESCAPE
		world._unhandled_key_input(key)
		_check(not picker.visible and not state.ui_open and state.selected_seed == selected, "Esc 取消不修改选择")
		world._unhandled_key_input(InputEventKey.new())
		hud.show_seed_picker()
		var pad := InputEventJoypadButton.new()
		pad.pressed = true
		pad.button_index = JOY_BUTTON_B
		var probe_actor := Node2D.new()
		world.add_child(probe_actor)
		var buttons:Array=[]
		buttons.resize(11);buttons.fill(false)
		state.poll_source_gamepad(1000.0,probe_actor,{"connected":true,"buttons":buttons.duplicate(),"axes":[0.0,0.0]})
		buttons[1]=true
		state.poll_source_gamepad(1001.0,probe_actor,{"connected":true,"buttons":buttons,"axes":[0.0,0.0]})
		_check(not picker.visible and not state.ui_open, "手柄合上选种页")
		world.free()
	state.day = 0
	var bag = hud.market_panel
	var winter_crop := ""
	for crop_id in state.crop_catalog:
		if not state.crop_in_season(str(crop_id)):
			winter_crop = str(crop_id)
			break
	var seed_id: String = state.seed_item_id(winter_crop)
	state.inventory[seed_id] = 1
	state.farm.seedKind = "heirloom"
	hud.show_market("inventory", false)
	bag.selected_id = seed_id
	bag._refresh_details()
	_check(bag.action_button.text == "选为播种" and not bag.action_button.disabled, "背包种子选择按钮")
	bag.action_button.pressed.emit()
	_check(not bag.visible and state.selected_seed == winter_crop and state.farm.seedKind == "normal" and state.selected_tool == "seed" and int(state.inventory[seed_id]) == 1, "背包允许选反季普通种子但不消耗")
	var food_id := ""
	for item_id in state.item_catalog:
		if int(state.item_catalog[item_id].get("energy", 0)) > 0:
			food_id = str(item_id)
			break
	state.inventory[food_id] = 2
	state.stamina = 20
	hud.show_market("inventory", false)
	bag.selected_id = food_id
	bag._refresh_details()
	_check(bag.action_button.text.begins_with("吃一份"), "背包可食物操作入口")
	bag.action_button.pressed.emit()
	await _finish_action(state)
	_check(int(state.inventory.get(food_id, 0)) == 1 and state.stamina > 20, "背包吃一份调用食物系统")
	state.stamina = 100
	bag.selected_id = food_id
	bag.action_button.pressed.emit()
	await _finish_action(state)
	_check(int(state.inventory.get(food_id, 0)) == 1 and state.stamina == 100, "满体力不消耗食物")
	bag.close()
	state.day = 0
	state.selected_seed = "cabbage"
	hud.show_seed_picker()
	for i in range(5): await process_frame
	_check(picker.scroll.get_global_rect().encloses(picker.crop_buttons.cabbage.get_parent().get_global_rect()) and root.gui_get_focus_owner() == picker.crop_buttons.cabbage, "首行完整可见并获得焦点")
	picker.close()
	var shot := OS.get_environment("SEED_SHOT")
	if shot != "" and DisplayServer.get_name() != "headless":
		state.day = 0
		hud.show_seed_picker()
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shot)
	hud.queue_free()
	await process_frame
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Seed picker smoke: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
