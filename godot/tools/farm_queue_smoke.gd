extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _json(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func _settle() -> void:
	await process_frame
	await process_frame
func _arrive(state: Node) -> void:
	for frame in range(1200):
		if state.walking_target.is_empty() and state.farm_queue.is_empty() and state.farm_active_task.is_empty(): break
		await physics_frame
	await _settle()
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(80).timeout.connect(func(): quit(1))
	var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FARM_QUEUE_FIXTURE")))
	if not input is Dictionary:
		quit(1)
		return
	var fixture: Dictionary = input
	var state = root.get_node("GameState")
	var converted: Dictionary = state.convert_external_save(fixture.source)
	_check(not converted.is_empty() and state.load_game_data(converted),"原版田块场景基准导入")
	for row in fixture.ranges:
		state.toolkit.tools[str(row.tool)] = row.config.duplicate(true)
		_check(_json(state.farm_tool_plan(int(row.index),str(row.tool))) == _json(row.tasks),"原版范围计划 " + str(row.tool)+"/"+str(row.index)+"/"+str(row.config))
	for row in fixture.filters:
		var indices: Array = state.farm_filtered_indices(str(row.filter),str(row.region),str(row.crop))
		_check(_json(indices) == _json(row.indices),"原版田块筛选 " + str(row.filter)+"/"+str(row.region)+"/"+str(row.crop))
		for action in row.plans:
			_check(_json(state.farm_batch_plan(indices,str(action))) == _json(row.plans[action]),"原版批量计划 " + str(action))
	for row in fixture.transactions:
		var copy = load("res://scripts/game_state.gd").new()
		copy._load_content()
		copy._load_initial_state()
		_check(copy.load_game_data(copy.convert_external_save(row.before)),"原版事务输入 " + str(row.task.action))
		_check(copy.perform_farm_task(row.task) == bool(row.result.ok),"原版事务成功 " + str(row.task.action))
		_check(copy.stamina == int(row.stamina) and copy.minutes == int(row.minutes),"原版劳动消耗 " + str(row.task.action))
		var p: Dictionary = copy.plots[0]
		_check(bool(p.tilled) == bool(row.tilled) and str(p.crop) == ("" if row.crop == null else str(row.crop)) and float(p.growth) == float(row.growth),"原版作物状态 " + str(row.task.action))
		_check(float(p.fertility) == float(row.bed.fertility) and float(p.moisture) == float(row.bed.moisture) and float(p.compacted) == float(row.bed.compacted),"原版土壤状态 " + str(row.task.action))
		for id in row.bag: _check(int(copy.inventory.get(str(id),0)) == int(row.bag[id]),"原版物品结算 " + str(row.task.action) + "/" + str(id))
		_check(_json(copy.quality.get("cabbage",[0,0,0])) == _json(row.quality),"原版收成品质 " + str(row.task.action))
		copy.free()
	for row in fixture.specialTransactions:
		var copy = load("res://scripts/game_state.gd").new()
		copy._load_content()
		copy._load_initial_state()
		_check(copy.load_game_data(copy.convert_external_save(row.before)),"田间专项输入 "+str(row.task.action))
		_check(copy.perform_farm_task(row.task) == bool(row.result.ok),"田间专项结果 "+str(row.task.action)+"/"+str(row.before.stamina)+"/"+str(row.before.plots[0].tilled))
		var expected: Dictionary = row.expected
		_check(copy.stamina == int(expected.stamina) and copy.minutes == int(expected.minutes) and copy.money == int(expected.money),"田间专项消耗 "+str(row.task.action))
		for key in expected.plot:
			var value: Variant = copy.plots[0].get(str(key))
			if key == "companion" and value is Dictionary: value = value.duplicate(true); value.erase("density")
			_check(_json(value) == _json(expected.plot[key]),"田间专项状态 "+str(row.task.action)+"/"+str(key))
		for id in expected.bag: _check(int(copy.inventory.get(str(id),0)) == int(expected.bag[id]),"田间专项材料 "+str(row.task.action)+"/"+str(id))
		for id in expected.quality: _check(_json(copy.quality.get(str(id),[0,0,0])) == _json(expected.quality[id]),"田间专项品质 "+str(row.task.action)+"/"+str(id))
		_check(int(copy.player_stats.get("harvested",0)) == int(expected.harvested),"田间专项采收统计 "+str(row.task.action))
		copy.free()
	state.cancel_farm_queue()
	state.current_interior = ""
	state.ui_open = false
	state.stamina = 100
	for plot in state.plots:
		plot.crop = ""
		plot.tilled = false
		plot.removed = false
		plot.fallow = false
		plot.companion = {}
	state.player_position = state._farm_position(0)+Vector2(0,90)
	change_scene_to_file("res://scenes/main.tscn")
	await _settle()
	_check(state.queue_farm_tasks([{"index":0,"action":"restore"},{"index":1,"action":"restore"},{"index":2,"action":"restore"}]),"建立三块开垦行走任务")
	_check(not state.plots[0].tilled and not state.plots[1].tilled,"出发未提前开垦")
	await _arrive(state)
	_check(state.farm_completed == 3 and state.plots[0].tilled and state.plots[1].tilled and state.plots[2].tilled,"真实行走按序开垦三块")
	_check(current_scene.player.global_position.distance_to(state._farm_position(2)) < 53,"末块结算前角色实际走近")
	_check(state.message.contains("农事完成") and state.farm_queue.is_empty(),"结束汇总并清空队列")
	state.stamina = 3
	state.plots[3].tilled = false
	state.plots[4].tilled = false
	_check(state.queue_farm_tasks([{"index":3,"action":"restore"},{"index":4,"action":"restore"}]),"允许出发并逐块检查体力")
	await _arrive(state)
	_check(state.farm_completed == 1 and state.plots[3].tilled and not state.plots[4].tilled,"体力不足停止并保留已完成田")
	_check(state.message.contains("已完成 1") and state.farm_queue.is_empty(),"失败报告进度")
	state.stamina = 100
	state.plots[5].tilled = false
	_check(state.queue_farm_tasks([{"index":5,"action":"restore"}]),"建立取消测试任务")
	state.stop_walking()
	await create_timer(1.0).timeout
	_check(not state.plots[5].tilled and state.farm_queue.is_empty() and state.farm_active_task.is_empty(),"取消不结算待执行田")
	# Sowing choices are captured when the batch is planned.
	state.plots[0].tilled = true
	state.plots[0].crop = ""
	state.selected_seed = "cabbage"
	state.farm.seedKind = "normal"
	state.farm.density = "balanced"
	state.inventory.cabbageSeed = 4
	var tasks: Array = state.farm_batch_plan([0,0],"sow")
	_check(tasks.size() == 1,"批量规划去重")
	_check(state.queue_farm_tasks(tasks),"播种队列出发")
	state.selected_seed = "radish"
	await _arrive(state)
	_check(str(state.plots[0].crop) == "cabbage" and int(state.inventory.cabbageSeed) == 3,"播种使用规划时捕获的种子")
	current_scene.hud.show_farm_planner(false)
	var panel = current_scene.hud.farm_planner_panel
	panel.batch_action.select(2)
	panel._refresh_batch()
	_check(not panel.batch_button.disabled and panel.batch_label.text.contains("块可安排"),"远程田间簿显示筛选批量预览")
	await _settle()
	panel.batch_button.grab_focus()
	await _settle()
	_check(panel.batch_button.has_focus(),"批量执行按钮可获得键盘焦点")
	var button_rect: Rect2 = panel.batch_button.get_global_rect()
	var scroll_rect: Rect2 = panel.control_scroll.get_global_rect()
	_check(scroll_rect.encloses(button_rect) and panel.control_scroll.scroll_vertical > 0,"焦点进入批量控件时滚动至完整可见")
	current_scene.hud.close_top_panel()
	# Modal pages pause continuation between tasks; cancellation invalidates old timers.
	state.stamina = 100
	state.plots[10].tilled = false
	state.plots[11].tilled = false
	_check(state.queue_farm_tasks([{"index":10,"action":"restore"},{"index":11,"action":"restore"}]),"建立间隔暂停任务")
	for frame in range(600):
		if state.farm_completed == 1: break
		await physics_frame
	current_scene.hud.show_life_menu()
	await create_timer(1.2).timeout
	_check(state.farm_completed == 1 and not state.plots[11].tilled and state.farm_active_task.is_empty() and state.farm_queue.is_empty(),"打开页面取消批次剩余操作")
	state.stop_walking()
	current_scene.hud.life_menu.close()
	await create_timer(1.0).timeout
	_check(not state.plots[11].tilled and state.farm_queue.is_empty(),"关闭页面不会复活已取消批次")
	state.current_interior = "building-farm-13"
	state.interior_position = Vector2(480,550)
	state.interior_return_position = state._farm_position(6)+Vector2(0,90)
	state.plots[6].tilled = false
	change_scene_to_file("res://scenes/interior.tscn")
	await _settle()
	state.farm_next_at=float(Time.get_ticks_usec())/1000000.0+1000.0
	_check(state.queue_farm_tasks([{"index":6,"action":"restore"}]),"室内可开始农事，首次启动忽略旧批次间隔")
	_check(current_scene.player.walk_is_exit,"农事第一段使用实际屋内出口")
	await _arrive(state)
	_check(state.current_interior == "" and state.plots[6].tilled and state.farm_completed == 1,"已启动农事出屋续行不再等待旧批次间隔")
	print("Farm queue smoke: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
