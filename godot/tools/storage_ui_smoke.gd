extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	game_state.set_process(false)
	world.set_process(false)
	world.player.set_physics_process(false)
	if world.hud.onboarding_open(): world.hud.toggle_onboarding()
	var building: Dictionary = game_state.get("building")
	var upgrades: Dictionary = game_state.get("upgrades")
	var inventory: Dictionary = game_state.get("inventory")
	var storage: Dictionary = game_state.get("storage")
	building.levels.granary = 1
	upgrades.storage = true
	building.modes.granary = "fresh"
	inventory["rice"] = 8
	storage["rice"] = 0
	world.hud.call("show_building", {}, false)
	var panel: Control = world.hud.get("building_panel")
	panel.call("_set_tab", "storage")
	var storage_tab: Control = panel.get("storage_tab")
	_check(storage_tab != null and storage_tab.visible, "建设簿提供独立粮仓周转页")
	_check(not bool(panel.get("storage_store_button").disabled), "一阶粮仓显示可存入的分类余量")
	panel.get("storage_store_button").pressed.emit()
	_check(game_state.action_busy() and not panel.visible and not game_state.ui_open, "存入按钮先关闭面板分拣")
	_check(int(inventory.get("rice", 0)) == 8 and int(storage.get("rice", 0)) == 0, "分拣开始不提前搬动")
	_check(str(game_state.action_snapshot().kind) == "pack" and is_equal_approx(float(game_state.action_snapshot().duration), 1.2), "原版分拣动作与时长")
	var cancel_key := InputEventKey.new()
	cancel_key.keycode = KEY_ESCAPE
	cancel_key.pressed = true
	Input.parse_input_event(cancel_key)
	await process_frame
	_check(panel.visible and game_state.ui_open and panel.tab == "storage" and panel.storage_category == "food", "取消恢复粮仓分类页")
	_check(int(inventory.get("rice", 0)) == 8 and int(storage.get("rice", 0)) == 0, "取消不搬动物品")
	panel.get("storage_store_button").pressed.emit()
	_finish_action(game_state)
	_check(panel.visible and panel.tab == "storage", "完成恢复分类页")
	_check(root.gui_get_focus_owner() == panel.storage_category_buttons.food, "无可搬余量时恢复分类按钮焦点")
	_check(int(inventory.get("rice", 0)) == 5 and int(storage.get("rice", 0)) == 3, "建设簿按钮触发一键分类存入")
	building.levels.granary = 2
	building.modes.granary = "supply"
	inventory["rice"] = 3
	panel.call("refresh")
	_check(not bool(panel.get("storage_withdraw_button").disabled), "二阶周转模式启用一键取回")
	panel.get("storage_withdraw_button").pressed.emit()
	_check(int(inventory.get("rice", 0)) == 3 and int(storage.get("rice", 0)) == 3, "取回动作开始不提前搬动")
	_finish_action(game_state)
	_check(int(inventory.get("rice", 0)) == 5 and int(storage.get("rice", 0)) == 1, "建设簿按钮按五份随身余量取回")
	panel.storage_category = "food"
	inventory["rice"] = 9
	panel.refresh()
	panel.get("storage_store_button").pressed.emit()
	panel.storage_category = "material"
	_finish_action(game_state)
	_check(int(inventory.get("rice", 0)) == 5 and panel.storage_category == "food", "分拣捕获开始分类并恢复")
	inventory["rice"] = 8
	panel.refresh()
	panel.get("storage_store_button").pressed.emit()
	upgrades.storage = false
	_finish_action(game_state)
	_check(int(inventory.get("rice", 0)) == 8 and game_state.message == "先改良丰收粮仓。", "完成时重新检查储物柜解锁")
	upgrades.storage = true
	panel.refresh()
	panel.get("storage_store_button").pressed.emit()
	var original_room: String = game_state.current_interior
	game_state.current_interior = "invalid-room"
	game_state._process_action(0.1)
	_check(not game_state.action_busy() and not panel.visible and int(inventory.get("rice", 0)) == 8, "换房间清除旧分拣事务")
	game_state.current_interior = original_room
	world.hud.call("show_building", {}, false)
	panel.call("_set_tab", "storage")
	var saved: Dictionary = game_state._make_save_data()
	game_state.feedback.prefs.pace = "brisk"
	panel.get("storage_store_button").pressed.emit()
	_check(is_equal_approx(float(game_state.action_snapshot().duration), 0.78), "利落节奏按原版缩短分拣时长")
	_check(not game_state._make_save_data().has("storage_action"), "未完成分拣回调不入存档")
	game_state.load_game_data(saved)
	_finish_action(game_state)
	_check(not game_state.action_busy() and int(game_state.inventory.get("rice", 0)) == 8, "读档清除待提交分拣且保留库存")
	world.hud.call("close_building")
	world.queue_free()
	await process_frame
	print("Building storage UI migration: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func _finish_action(state: Node) -> void:
	for step in range(30):
		if not state.action_busy(): break
		state._process_action(0.1)
