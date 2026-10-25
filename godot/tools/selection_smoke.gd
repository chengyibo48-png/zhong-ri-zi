extends SceneTree
const SELECTOR := preload("res://scripts/interaction_selection.gd")
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
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SELECTION_FIXTURE")))
	if not fixtures is Array:
		push_error("Missing source SELECTION_FIXTURE")
		quit(1)
		return
	var selection := SELECTOR.new()
	for fixture in fixtures:
		if fixture.has("clear"):
			selection.clear()
			_check(selection.key == "" and selection.manual == "", "清空目标")
			continue
		if fixture.has("cycle"):
			_check(selection.target_key(selection.cycle(int(fixture.cycle))) == str(fixture.expected), "原版正反循环目标")
			continue
		var facing: Vector2 = {"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}[str(fixture.face)]
		var hover: Dictionary = fixture.hover if fixture.hover is Dictionary else {}
		var room := str(fixture.room) if fixture.room != null else ""
		var chosen := selection.choose(Vector2(100,100),facing,fixture.points,hover,str(fixture.tool),room)
		_check(selection.target_key(chosen) == str(fixture.expected), str(fixture.label))
		var order: Array = []
		for option in selection.options: order.append(selection.target_key(option))
		_check(order == fixture.order, "原版候选排序")
	var state = root.get_node("GameState")
	state.set_process(false)
	var room_id := ""
	for id in state.system_catalog.interiors.layouts:
		var points: Array = state.system_catalog.interiors.layouts[id].get("points",[])
		if points.size() >= 3 and str(id) != "building-river-10":
			room_id = str(id)
			break
	_check(room_id != "", "找到真实陈设房间")
	state.current_interior = room_id
	state.interior_position = Vector2(480,550)
	change_scene_to_file("res://scenes/interior.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var chosen_point: Dictionary = {}
	for point in world._room_points():
		if str(point.get("kind","")) in ["egg","tea","bed-visit"]:
			chosen_point = point
			break
	_check(not chosen_point.is_empty(), "找到真实生活物件")
	# Place a real NPC node beside an authored point to exercise overlapping targets.
	if world.owner_npc == null:
		var npc = load("res://scripts/world_npc.gd").new()
		npc.npc_id = "granny"
		world.add_child(npc)
		world.owner_npc = npc
	world.resident_nodes[str(world.owner_npc.npc_id)] = world.owner_npc
	world.owner_npc.global_position = Vector2(float(chosen_point.x) + 20,float(chosen_point.y))
	world._publish_npc_positions()

	world.player.global_position = Vector2(float(chosen_point.x),float(chosen_point.y)) + Vector2(0,8)
	state.player_direction = "up"
	world._refresh_room_target()
	_check(not state.ui_open and not state.action_busy(),"世界目标切换前输入可用")
	_check(not world.selected_room_target.is_empty(), "实际房间形成近距目标")
	var original: String = world.interaction_selection.key
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_BRACKETRIGHT
	world._unhandled_key_input(event)
	_check(world.interaction_selection.options.size() >= 2 and world.interaction_selection.key != original, "括号键切换实际房间目标")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.button_index = JOY_BUTTON_LEFT_STICK
	var buttons:Array=[]
	buttons.resize(11);buttons.fill(false)
	state.poll_source_gamepad(1000.0,world.player,{"connected":true,"buttons":buttons.duplicate(),"axes":[0.0,0.0]})
	buttons[10]=true
	state.poll_source_gamepad(1001.0,world.player,{"connected":true,"buttons":buttons,"axes":[0.0,0.0]})
	_check(world.interaction_selection.options.size() >= 2 and world.interaction_selection.manual != "", "屋内手柄 L3 切换")
	world.hud.show_map()
	var before: String = world.interaction_selection.key
	world._unhandled_key_input(event)
	_check(world.interaction_selection.key == before, "面板中不切换目标")
	world.hud.close_map()
	world.interaction_selection.manual = world.interaction_selection.target_key(chosen_point)
	world._refresh_room_target()
	_check(str(world.selected_room_target.get("kind","")) != "npc", "手动选择陈设不被邻居抢走")
	world._interact()
	await _finish_action(state)
	_check(not world.hud.npc_dialogue.visible, "E 执行选择的陈设而非优先交谈")
	world.interaction_selection.manual = "npc/" + str(world.owner_npc.npc_id)
	world._refresh_room_target()
	world._interact()
	await _finish_action(state)
	_check(world.hud.npc_dialogue.visible and state.ui_open, "选中居民打开对话并暂停")
	world.hud.npc_dialogue.close()
	world._use_room_point({"kind":"sleep"})
	_check(world.hud.sleep_open() and state.ui_open, "睡床进入睡觉确认而非短暂休息")
	var day_before: int = state.day
	var room_before: String = state.current_interior
	var position_before: Vector2 = state.interior_position
	world.hud.close_sleep()
	_check(state.day == day_before, "取消睡觉保留日期")
	world._use_room_point({"kind":"sleep"})
	world.hud.sleep_panel._sleep()
	await _finish_action(state)
	await process_frame
	await process_frame
	_check(state.day == day_before + 1 and state.current_interior == room_before and state.interior_position == position_before and state.stamina == 100 and current_scene.name == "InteriorWorld", "原版过夜保留房间和位置并恢复体力")
	state.leave_interior()
	await process_frame
	await process_frame
	var home_id := ""
	for house in state.world_village.houses:
		if str(house.get("name","")) == "爷爷的老屋":
			home_id = str(house.id)
			state.player_position = Vector2(float(house.door.x),float(house.door.y))
			break
	_check(state.enter_interior(home_id), "进入自宅核对睡床")
	await process_frame
	await process_frame
	world = current_scene
	world.player.global_position = Vector2(238,335)
	world._interact()
	await _finish_action(state)
	_check(world.hud.sleep_open() and root.gui_get_focus_owner() == world.hud.sleep_panel.sleep_button, "自宅床边打开确认并聚焦睡觉按钮")
	world.hud.close_sleep()
	_check(state.day == day_before + 1, "自宅取消保留日期")
	print("Selection smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
