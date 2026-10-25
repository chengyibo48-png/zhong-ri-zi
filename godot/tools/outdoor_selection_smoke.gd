extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
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
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(55).timeout.connect(func(): quit(1))
	var state = root.get_node("GameState")
	state.set_process(false)
	state.current_interior = ""
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	state.selected_tool = "hoe"
	state.player_direction = "down"
	world.player.global_position = world.plot_nodes[0].global_position + Vector2(0,-10)
	world._refresh_world_target()
	_check(world.selected_world_target.kind == "plot","朝向与工具选择田块")
	var options: Array = world.interaction_selection.options
	_check(options.size() >= 2,"邻接田块形成多个实际候选")
	var initial: String = world.interaction_selection.key
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_BRACKETRIGHT
	world._unhandled_key_input(key)
	_check(world.interaction_selection.key != initial,"户外右括号切换")
	key.keycode = KEY_BRACKETLEFT
	world._unhandled_key_input(key)
	_check(world.interaction_selection.key == initial,"户外左括号切回")
	var joy := InputEventJoypadButton.new()
	joy.pressed = true
	joy.button_index = JOY_BUTTON_LEFT_STICK
	var was_riding: bool = state.riding
	var buttons:Array=[]
	buttons.resize(11);buttons.fill(false)
	state.poll_source_gamepad(1000.0,world.player,{"connected":true,"buttons":buttons.duplicate(),"axes":[0.0,0.0]})
	buttons[10]=true
	state.poll_source_gamepad(1001.0,world.player,{"connected":true,"buttons":buttons,"axes":[0.0,0.0]})
	_check(world.interaction_selection.key != initial and state.riding == was_riding,"L3 切目标而不骑车")
	var selected: Dictionary = world.selected_world_target.duplicate(true)
	_check(world.hovered_plot == int(selected.index),"高亮只对应选中田")
	for plot in state.plots: plot.tilled = false
	world.interaction_selection.manual = world.interaction_selection.target_key(selected)
	var before_other := bool(state.plots[0].tilled)
	world._interact()
	world.player.set_physics_process(true)
	state.set_process(true)
	for frame in range(900):
		if state.walking_target.is_empty() and state.farm_queue.is_empty() and state.farm_active_task.is_empty() and not state.action_busy(): break
		await physics_frame
	state.set_process(false)
	world.player.set_physics_process(false)
	await _finish_action(state)
	_check(bool(state.plots[int(selected.index)].tilled),"执行手动选中田的开垦")
	_check(int(selected.index) == 0 or bool(state.plots[0].tilled) == before_other,"不误操作旧最近田")
	state.selected_tool = "hand"
	world._refresh_world_target()
	_check(world.interaction_selection.manual == "","工具切换清空手动目标")
	world.hud.call("show_map")
	initial = world.interaction_selection.key
	world._unhandled_key_input(key)
	world._unhandled_input(joy)
	_check(world.interaction_selection.key == initial,"模态地图阻止切换")
	world.hud.call("close_map")
	# A real NPC node and actual plot are placed together to exercise dispatch.
	var npc = world.npc_nodes[0]
	npc.visible = true
	npc.global_position = world.plot_nodes[0].global_position + Vector2(16,0)
	world.player.global_position = world.plot_nodes[0].global_position + Vector2(0,8)
	world.interaction_selection.clear()
	world._refresh_world_target()
	world.interaction_selection.manual = "npc/" + str(npc.npc_id)
	world._interact()
	await _finish_action(state)
	_check(world.hud.npc_dialogue.visible and state.ui_open,"选中居民实际打开对话")
	world.hud.npc_dialogue.close()
	# A door candidate executes entry even with another near target.
	var house: Dictionary = world.world_data.village.houses[0]
	world.player.global_position = Vector2(float(house.door.x),float(house.door.y)) + Vector2(0,8)
	world.interaction_selection.manual = "enter/" + str(house.id)
	world._refresh_world_target()
	_check(world.selected_world_target.kind == "enter","房门属于统一候选")
	world._interact()
	await _finish_action(state)
	_check(state.current_interior == str(house.id),"选中的房門实际进入")
	await process_frame
	await process_frame
	state.leave_interior()
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	var chore: Dictionary = world.world_data.village.outdoorActions[0]
	world.player.global_position = Vector2(float(chore.x),float(chore.y)) + Vector2(0,8)
	world.interaction_selection.manual = str(chore.kind) + "/" + str(chore.id)
	world._refresh_world_target()
	_check(world.selected_world_target.id == chore.id,"牧场杂务形成候选")
	world._interact()
	await _finish_action(state)
	_check(int(state.interior_state.chores.get(str(chore.id),-1)) == state.day,"牧场杂务实际执行")
	world.player.global_position = Vector2(1900,1900)
	world._refresh_world_target()
	_check(world.selected_world_target.is_empty() and world.hovered_plot == -1 and world.hovered_npc == "","离开范围清空目标及高亮")
	print("Outdoor selection smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed > 0 else 0)
