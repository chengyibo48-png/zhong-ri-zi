extends SceneTree
const SELECTOR := preload("res://scripts/interaction_selection.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _arrive(world: Node) -> void:
	var settled := 0
	for frame in range(900):
		var state = root.get_node("GameState")
		settled = settled + 1 if state.walking_target.is_empty() and state.farm_queue.is_empty() and state.farm_active_task.is_empty() and not state.action_busy() else 0
		if settled >= 3: break
		await physics_frame
	await process_frame
	await process_frame
func _motion(world: Node,at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_canvas_transform() * at
	world._unhandled_input(event)
func _click(world: Node,at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_canvas_transform() * at
	world._unhandled_input(event)
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(55).timeout.connect(func(): quit(1))
	var selector := SELECTOR.new()
	var points := [{"kind":"npc","id":"npc","x":100,"y":100},{"kind":"plot","index":0,"x":100,"y":100}]
	_check(selector.hit(Vector2(100,100),points).kind == "plot","田块命中优先于重叠精灵")
	_check(selector.hit(Vector2(119,100),points).kind == "npc","田块严格边界回退精灵")
	_check(selector.hit(Vector2(129,100),points).is_empty(),"精灵严格横向边界")
	_check(selector.hit(Vector2(100,56),[points[0]]).is_empty(),"精灵严格上边界")
	_check(selector.hit(Vector2(100,120),[points[0]]).is_empty(),"精灵严格下边界")
	var state = root.get_node("GameState")
	state.current_interior = ""
	state.selected_tool = "hoe"
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var point: Vector2 = world.plot_nodes[0].global_position
	world.player.global_position = point + Vector2(0,10)
	world._refresh_world_target()
	world._cycle_world_target()
	_check(world.interaction_selection.manual != "","循环形成手动目标")
	_motion(world,point)
	_check(world.interaction_selection.manual == "" and world.selected_world_target.index == 0,"鼠标移动清空手动选择并优先悬停田")
	state.plots[0].crop = ""
	state.plots[0].tilled = false
	var before: int = state.stamina
	_click(world,point)
	await _arrive(world)
	_check(state.plots[0].tilled and state.stamina < before and state.walking_target.is_empty(),"近距点击按原版农事队列走近并操作命中田")
	# Click beyond interaction range and let the real physics controller arrive.
	state.plots[0].tilled = false
	world.player.global_position = point + Vector2(0,90)
	state.player_position = world.player.global_position
	_click(world,point)
	_check(not state.walking_target.is_empty() and state.walking_target.get("auto_interact",false),"远距点击建立抵达操作")
	await _arrive(world)
	_check(state.walking_target.is_empty() and state.plots[0].tilled,"真实移动抵达后开垦命中田")
	_check(world.player.global_position.distance_to(point) < 53,"操作前进入原版互动范围")
	var ground: Vector2 = world.player.global_position + Vector2(0,160)
	_check(world.interaction_selection.hit(ground,world._world_target_candidates()).is_empty(),"空地验证使用无交互目标的落点")
	var ground_plan: Dictionary = world.player.preview_walk({"kind":"walk","world_click":true,"click_room":"","auto_interact":false,"x":ground.x,"y":ground.y})
	_check(ground_plan.get("reachable",false),"地面落点有碰撞检查路线")
	_click(world,ground)
	_check(not state.walking_target.is_empty() and not state.walking_target.get("auto_interact",true),"点击空地只行走")
	await _arrive(world)
	_check(world.player.global_position.distance_to(ground) < 1,"真实控制器抵达空地落点")
	# Canceling a clicked route must discard its pending farm action.
	state.plots[0].tilled = false
	_click(world,point)
	_check(not state.walking_target.is_empty(),"点击田块再次建立待操作路线")
	var cancel := InputEventKey.new()
	cancel.pressed = true
	cancel.keycode = KEY_ESCAPE
	world._unhandled_key_input(cancel)
	await physics_frame
	await physics_frame
	_check(state.walking_target.is_empty() and not state.plots[0].tilled,"Esc 取消点击路线及抵达操作")
	var house: Dictionary = world.world_data.village.houses[0]
	var blocked := Vector2(float(house.x) + float(house.w) / 2,float(house.y) + float(house.h) * 0.7)
	_check(world.interaction_selection.hit(blocked,world._world_target_candidates()).is_empty(),"建筑墙内不是门口目标")
	_click(world,blocked)
	_check(state.walking_target.is_empty(),"点击障碍内部不伪装成可达空地")
	world.hud.call("show_map")
	var selected: String = world.interaction_selection.key
	_click(world,point)
	_motion(world,point)
	_check(state.walking_target.is_empty() and world.interaction_selection.key == selected,"模态页面阻止世界鼠标交互")
	world.hud.call("close_map")
	var room_id := ""
	for id in state.system_catalog.interiors.layouts:
		if str(id) != "building-river-10":
			room_id = str(id)
			break
	state.current_interior = room_id
	state.interior_position = Vector2(480,550)
	change_scene_to_file("res://scenes/interior.tscn")
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	var room_point: Dictionary = {}
	for item in world._room_points():
		if str(item.get("kind","")) != "egg": continue
		var candidate: Dictionary = item.duplicate(true)
		candidate.world_click = true
		candidate.click_room = room_id
		candidate.auto_interact = true
		var plan: Dictionary = world.player.preview_walk(candidate)
		if plan.get("reachable",false):
			room_point = candidate
			break
	_check(not room_point.is_empty(),"室内陈设存在可行走的近距落点")
	if not room_point.is_empty():
		_click(world,Vector2(float(room_point.x),float(room_point.y)))
		_check(not state.walking_target.is_empty() and not world.player.walk_is_exit,"点击室内陈设使用屋内路线")
		await _arrive(world)
		_check(state.current_interior == room_id and state.walking_target.is_empty(),"室内走到陈设而不出屋")
		_check(world.interaction_selection.key == world.interaction_selection.target_key(room_point),"抵达交互仍是点击陈设")
		var target_before: String = world.interaction_selection.key
		world._cycle_room_target(1)
		_motion(world,Vector2(float(room_point.x),float(room_point.y)))
		_check(world.interaction_selection.manual == "" and world.interaction_selection.key == target_before,"室内悬停覆盖手动目标")
		var exit_point: Dictionary = {}
		for item in world._room_points():
			if str(item.get("kind","")) == "exit": exit_point = item
		_check(not exit_point.is_empty(),"房间有真实出口目标")
		if not exit_point.is_empty():
			_click(world,Vector2(float(exit_point.x),float(exit_point.y)))
			await _arrive(world)
			_check(state.current_interior == "" and current_scene.name == "FarmWorld","点击出口经物理行走后实际出屋")
	print("Mouse interaction smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
