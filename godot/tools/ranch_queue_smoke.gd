extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _json(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func _settle() -> void:
	await process_frame
	await process_frame
func _arrive(state: Node) -> void:
	for frame in range(1600):
		if state.walking_target.is_empty() and state.ranch_queue.is_empty() and state.ranch_active_task.is_empty(): break
		await physics_frame
	await _settle()
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1); return
	create_timer(100).timeout.connect(func(): quit(1))
	var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RANCH_QUEUE_FIXTURE")))
	if not input is Dictionary: quit(1); return
	var fixture: Dictionary = input
	var state = root.get_node("GameState")
	_check(state.load_game_data(state.convert_external_save(fixture.source)),"原版牧场场景导入")
	for row in fixture.filters:
		_check(_json(state.ranch_filtered_ids(str(row.filter))) == _json(row.ids),"原版动物筛选 "+str(row.filter))
	for row in fixture.plans:
		_check(_json(state.ranch_batch_plan(row.ids,str(row.action))) == _json(row.tasks),"原版照料计划 "+str(row.action)+"/"+str(row.ids))
	for row in fixture.transactions:
		var copy = load("res://scripts/game_state.gd").new()
		copy._load_content(); copy._load_initial_state()
		_check(copy.load_game_data(copy.convert_external_save(row.before)),"原版牧场事务输入")
		_check(copy.perform_ranch_task(row.task) == bool(row.result.ok),"原版照料结果 "+str(row.task.action))
		var expected: Dictionary = row.expected
		_check(copy.stamina == int(expected.stamina) and copy.minutes == int(expected.minutes) and copy.money == int(expected.money),"原版照料消耗 "+str(row.task.action))
		for key in expected.animal:
			_check(_json(copy.animals[0].get(str(key))) == _json(expected.animal[key]),"原版动物属性 "+str(row.task.action)+"/"+str(key))
		for id in expected.bag: _check(int(copy.inventory.get(str(id),0)) == int(expected.bag[id]),"原版照料材料 "+str(row.task.action)+"/"+str(id))
		_check(_json(copy.quality.get("egg",[0,0,0])) == _json(expected.quality),"原版产物品质 "+str(row.task.action))
		_check(_json(copy.ranch.get("collection",{})) == _json(expected.collection),"原版牧场收集记录 "+str(row.task.action))
		copy.free()
	state.current_interior = ""
	state.ui_open = false
	state.player_position = state._farm_position(0)+Vector2(0,90)
	state.inventory.feed = 30
	state.stamina = 100
	state.minutes = 600
	state.ranch.policy = "day"
	for index in range(state.animals.size()):
		state.animals[index].position = {"x":state.player_position.x+float(index)*40,"y":state.player_position.y+80,"room":null,"inside":{"x":480,"y":490}}
		state.animals[index].hunger = 20
		state.animals[index].care.feed = -1
	change_scene_to_file("res://scenes/main.tscn")
	await _settle()
	var ids: Array = state.animals.map(func(a): return str(a.id))
	_check(state.queue_ranch_tasks(state.ranch_batch_plan(ids,"feed")),"建立三只伙伴顺序添料")
	_check(state.animals[0].hunger == 20 and state.inventory.feed == 30,"出发未提前扣料")
	_check(state.ranch_actor_held(str(ids[0])),"暂时稳住当前照料伙伴")
	await _arrive(state)
	_check(state.ranch_completed == 3 and state.animals.all(func(a): return int(a.hunger) >= 60),"真实行走逐只添料")
	_check(str(state.ranch_actor_action.get("id",""))==str(ids[2]) and str(state.ranch_actor_action.get("kind",""))=="feed","成功照料挂接最后伙伴的喂料特效")
	_check(float(state.ranch_holds.get(str(ids[2]),0))-float(state.ranch_actor_clock)<=2.2 and float(state.ranch_holds.get(str(ids[2]),0))>float(state.ranch_actor_clock),"成功照料停留缩短为2.2秒")

	_check(state.ranch_queue.is_empty() and state.ranch_active_task.is_empty(),"完成清空牧场队列")
	current_scene.hud.show_ranch()
	var panel = current_scene.hud.ranch_panel
	panel.batch_action.select(1)
	panel._refresh_batch()
	_check(panel.batch_label.text.contains("可安排") and not panel.batch_button.disabled,"名册批量收取预览")
	await _settle()
	panel.batch_button.grab_focus()
	await _settle()
	_check(panel.control_scroll.get_global_rect().encloses(panel.batch_button.get_global_rect()),"批量执行焦点完整可见")
	panel.animal_filter.select(3)
	panel.refresh()
	_check(panel.animal_list.item_count == 1 and str(panel.animal_list.get_item_metadata(0)) == str(ids[0]),"名册按鸡筛选且稳定 ID 选择")
	current_scene.hud.close_top_panel()
	state.animals[0].care.feed = -1; state.animals[0].hunger = 20
	state.inventory.feed = 5
	var captured: Array = state.ranch_batch_plan([ids[0]],"feed")
	_check(state.queue_ranch_tasks(captured),"捕获当前饲料开始任务")
	state.ranch.feed = "hay"
	await _arrive(state)
	_check(state.ranch_completed == 1 and int(state.inventory.feed) == 4,"途中偏好变化使用原计划饲料")
	state.ranch.feed = "feed"
	state.inventory.feed = 1
	for index in [0,1]:
		state.animals[index].hunger = 20; state.animals[index].care.feed = -1
	_check(state.queue_ranch_tasks(state.ranch_batch_plan([ids[0],ids[1]],"feed")),"逐只检查饲料供应")
	await _arrive(state)
	_check(state.ranch_completed == 1 and int(state.animals[1].hunger) == 20 and state.message.contains("已完成 1"),"材料不足停止并保留已完成照料")
	state.inventory.feed = 30
	state.animals[0].care.pet = -1
	var bond := int(state.animals[0].bond)
	_check(state.queue_ranch_tasks([{"animalId":ids[0],"action":"pet"}]),"建立取消照料")
	state.stop_walking()
	await create_timer(1.2).timeout
	_check(int(state.animals[0].bond) == bond and state.ranch_active_task.is_empty(),"取消保留未执行资源")
	# Enter the animal's actual barn before executing, including a transition from another room.
	var barn_id := str(state.system_catalog.ranch.species[str(state.animals[0].type)].home)
	var house_id := str(state.system_catalog.ranch.barns[barn_id].house)
	var building: Dictionary = state.house_data(house_id)
	state.animals[0].position.room = house_id
	if state.atlas_source_navigation==null:state.atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
	state.atlas_source_navigation.refresh(state)
	state.animals[0].position.inside = state.atlas_source_navigation.safe(state,house_id,{"x":480,"y":490,"direction":"down"})
	_check(not state.atlas_source_navigation.blocked(state,house_id,state.animals[0].position.inside.x,state.animals[0].position.inside.y),"畜舍测试伙伴采用原版可站立位置")
	state.current_interior = "building-farm-13"
	state.interior_position = Vector2(480,550)
	state.interior_return_position = Vector2(float(building.door.x),float(building.door.y)+35)
	change_scene_to_file("res://scenes/interior.tscn")
	await _settle()
	_check(state.queue_ranch_tasks([{"animalId":ids[0],"action":"pet"}]),"从其他房间开始照料")
	_check(current_scene.player.walk_is_exit,"首先走到当前房间出口")
	await _arrive(state)
	print("Ranch transition diagnostics room=",state.current_interior," expected=",house_id," position=",current_scene.player.global_position," message=",state.message," task=",state.ranch_active_task," walking=",state.walking_target," points=",current_scene.player.walk_path)
	_check(state.current_interior == house_id and state.ranch_completed == 1,"到实际畜舍进屋后完成照料")
	_check(int(state.animals[0].bond) > bond and current_scene.player.global_position.distance_to(Vector2(480,490)) < 70,"走近动物后才增加亲近")
	var animal_points: Array = (current_scene._room_target_candidates() if current_scene.has_method("_room_target_candidates") else []).filter(func(p): return str(p.get("kind","")) == "animal")
	_check(animal_points.size() == 1 and str(animal_points[0].id) == str(ids[0]),"畜舍内动物加入键盘和鼠标共享目标")
	_check(state.ranch_default_action(0) == "collect","有产物时默认先收取")
	state.animals[0].ready = 0; state.animals[0].feathers = 0; state.animals[0].care.feed = state.day
	_check(state.ranch_default_action(0) == "pet","当日已添料且无产物时默认陪伴")
	# Recheck missing animal at arrival, rather than applying a stale list index.
	state.animals[0].care.clean = -1; state.animals[0].clean = 20
	_check(state.queue_ranch_tasks([{"animalId":ids[0],"action":"clean"}]),"建立伙伴消失测试")
	state.animals.remove_at(0)
	await _arrive(state)
	_check(state.ranch_completed == 0 and state.ranch_queue.is_empty() and state.message.contains("不在牧场"),"伙伴移走后停止且不误处理下一只")
	state.leave_interior(true)
	await _settle()
	state.ranch.pet.position = {"x":state.player_position.x,"y":state.player_position.y+70}
	state.ranch.pet.mode = "follow"
	state.ranch.pet.hunger = 20; state.ranch.pet.fed = -1; state.ranch.pet.energy = 70; state.ranch.pet.trained = -1
	var food_before := int(state.inventory.feed)
	_check(state.queue_ranch_tasks([{"pet":true,"action":"feed"}]),"走近跟随宠物喂食")
	_check(state.ranch_actor_held("pet"),"跟随宠物在照料期间暂时停住")
	state.ui_open = true
	var hold_clock := float(state.ranch_actor_clock)
	await _settle()
	_check(float(state.ranch_actor_clock) == hold_clock,"打开页面暂停伙伴定位计时")
	state.ui_open = false
	await _settle()
	_check(float(state.ranch_actor_clock) > hold_clock,"关闭页面继续伙伴定位计时")
	await _arrive(state)
	_check(state.ranch_queue.is_empty() and state.ranch_active_task.is_empty() and int(state.ranch.pet.hunger)==20 and int(state.inventory.feed)==food_before,"打开界面取消旧照料，关闭不会继续扣料")
	_check(state.queue_ranch_tasks([{"pet":true,"action":"feed"}]),"关闭界面后重新安排宠物喂食")
	await _arrive(state)
	_check(int(state.ranch.pet.hunger) == 70 and int(state.inventory.feed) == food_before-1 and state.ranch_completed == 1,"宠物喂食抵达后结算")
	var training_before := int(state.ranch.pet.training)
	var energy_before := int(state.ranch.pet.energy)
	_check(state.queue_ranch_tasks([{"pet":true,"action":"train"}]),"走近宠物训练")
	await _arrive(state)
	_check(int(state.ranch.pet.training) == training_before+10 and int(state.ranch.pet.energy) == energy_before-15,"宠物训练抵达后结算")
	var save: Dictionary = state._make_save_data()
	_check(not save.has("ranch_queue") and not save.has("ranch_active_task") and not save.has("ranch_holds"),"牧场行走队列与短暂定位不写入存档")
	_check(not save.has("ranch_actor_action") and not save.has("ranch_actor_poses"),"操作特效和姿态不写入存档")
	var animals_before: Array = state.animals.duplicate(true)
	var plots_before: Array = state.plots.duplicate(true)
	state.load_game_data(save)
	_check(_json(state.animals) == _json(animals_before) and _json(state.plots) == _json(plots_before), "直接读取当前内存存档不清空动物或农田")
	_check(state.ranch_actor_action.is_empty() and state.ranch_actor_poses.is_empty(),"读档清理旧操作特效")
	state.animals.clear()
	var empty_targets: Array = current_scene._world_target_candidates()
	_check(empty_targets.filter(func(point): return str(point.get("kind", "")) == "animal").is_empty(), "动物已清空而旧画面节点尚在时不产生过期目标")
	var empty_save: Dictionary = state._make_save_data()
	_check(state.load_game_data(empty_save) and state.animals.is_empty(), "直接读取空牧场存档不补发初始动物")
	if current_scene != null: current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Ranch queue smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
