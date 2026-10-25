extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _settle() -> void:
	await process_frame
	await process_frame
	await physics_frame
func _arrive(state: Node) -> void:
	for frame in range(1200):
		if state.kitchen_task.is_empty() and state.walking_target.is_empty(): break
		await physics_frame
	await _settle()
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(85).timeout.connect(func(): quit(1))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("KITCHEN_TASK_FIXTURE")))
	var state = root.get_node("GameState")
	for row in fixture.availability:
		var mask := int(row.mask)
		state.upgrades.kitchen = bool(mask & 1)
		state.upgrades.mill = bool(mask & 2)
		state.upgrades.yard = bool(mask & 4)
		_check(state.kitchen_station_available(str(row.id)) == bool(row.available),"原版设备解锁 " + str(row.id) + "/" + str(mask))
	state.upgrades.kitchen = true
	state.upgrades.mill = true
	state.upgrades.yard = true
	state.inventory.milk = 4
	state.kitchen.jobs = []
	state.stamina = 100
	var task: Dictionary = fixture.task
	var before := JSON.stringify([state.inventory,state.kitchen,state.stamina,state.minutes])
	var result: Dictionary = state.preview_kitchen_task(task)
	_check(bool(result.ok) == bool(fixture.preview.ok),"真实事务副本预检与原版一致")
	_check(JSON.stringify([state.inventory,state.kitchen,state.stamina,state.minutes]) == before,"预检不修改材料、工序、体力与时间")
	_check(bool(state.preview_kitchen_task({"op":"experiment","id":"cabbage","second":"egg"}).ok) == false,"缺试配材料预检拒绝")
	var house: Dictionary = fixture.house
	var door := Vector2(float(house.door.x),float(house.door.y))
	state.current_interior = ""
	state.player_position = door + Vector2(0,35)
	change_scene_to_file("res://scenes/main.tscn")
	await _settle()
	_check(state.queue_kitchen_task(task),"户外加工通过预检并建立任务")
	_check(int(state.inventory.milk) == 4 and state.kitchen.jobs.is_empty(),"出发时不扣材料、不创建加工批次")
	_check(str(state.walking_target.get("kitchen_stage","")) == "door","先走到原版小灶入口")
	await _arrive(state)
	_check(state.current_interior == str(house.id),"实际物理移动进入小灶")
	_check(state.kitchen_task.is_empty() and state.walking_target.is_empty(),"工位抵达后任务清除")
	_check(state.kitchen.jobs.size() == 1 and int(state.inventory.milk) == int(fixture.milk),"抵达工位消费原版批次材料")
	if state.kitchen.jobs.size() == 1:
		var job: Dictionary = state.kitchen.jobs[0]
		_check(str(job.station) == str(fixture.job.station) and int(job.qty) == int(fixture.job.qty),"批次工位与数量对齐原版")
		_check(int(job.ready)-int(job.start) == int(fixture.job.ready)-int(fixture.job.start),"加工时长对齐原版")
		_check(current_scene.player.global_position.distance_to(Vector2(float(fixture.points.dairy.x),float(fixture.points.dairy.y))) < 53,"结算时角色实际靠近乳品工位")
	# Every authored kitchen station gets a collision-checked approach.
	for id in fixture.stations:
		var st: Dictionary = fixture.points[id]
		var target := {"id":"kitchen-"+str(id),"kind":"kitchen-station","x":st.x,"y":st.y,"world_click":true,"auto_interact":true,"click_room":state.current_interior}
		_check(bool(current_scene.player.preview_walk(target).get("reachable",false)),"工位可达 " + str(id))
	# Cancel before reaching a different station.
	state.inventory.wheat = 4
	_check(state.queue_kitchen_task({"op":"process","id":"flour","n":1}),"屋内可建立另一工位任务")
	state.stop_walking()
	await _settle()
	_check(state.kitchen_task.is_empty() and state.walking_target.is_empty() and int(state.inventory.wheat) == 4,"取消不扣材料也不保留待加工任务")
	# Revalidate current inventory on arrival.
	current_scene.player.global_position = Vector2(480,550)
	state.interior_position = current_scene.player.global_position
	state.kitchen.jobs = []
	state.inventory.milk = 4
	_check(state.queue_kitchen_task(task),"材料齐全时可再次出发")
	state.inventory.milk = 0
	await _arrive(state)
	_check(state.kitchen.jobs.is_empty() and int(state.inventory.milk) == 0 and state.kitchen_task.is_empty(),"路途中材料变化使抵达事务拒绝")
	# Remote panel buttons also queue a walk, not an immediate transaction.
	state.inventory.cabbage = 4
	current_scene.player.global_position = Vector2(480,550)
	state.interior_position = current_scene.player.global_position
	current_scene.hud.show_kitchen(false,"cook")
	var panel = current_scene.hud.kitchen_panel
	panel.selected_id = "greens"
	panel._refresh_detail()
	_check(not panel.action_button.disabled,"远程菜谱允许请求走到工位")
	panel._act()
	_check(not state.kitchen_task.is_empty() and not panel.visible and int(state.inventory.cabbage) == 4,"点击菜谱关闭页面并出发，原料保留")
	await _arrive(state)
	_check(int(state.inventory.cabbage) == 2 and int(state.inventory.get("greens",0)) >= 1,"实际走到灶台后制作料理")
	# Full equipment cleaning/upgrade transactions use the same preview and walk.
	state.kitchen.equipment.stove.clean = 40
	_check(state.queue_kitchen_task({"op":"clean","id":"stove"}),"清洁任务预检")
	await _arrive(state)
	_check(int(state.kitchen.equipment.stove.clean) == 100,"走近后清洁设备")
	state.money = 300
	state.inventory.wood = 12
	state.inventory.bamboo = 8
	_check(state.queue_kitchen_task({"op":"upgrade","id":"stove"}),"升级任务预检")
	await _arrive(state)
	_check(int(state.kitchen.equipment.stove.level) == 1 and state.money == 210,"走近后升级及扣款")
	# Leave another real interior before continuing to the kitchen.
	state.current_interior = str(fixture.home.id)
	state.interior_position = Vector2(480,550)
	state.interior_return_position = door + Vector2(0,35)
	state.inventory.milk = 4
	state.kitchen.jobs = []
	change_scene_to_file("res://scenes/interior.tscn")
	await _settle()
	_check(state.queue_kitchen_task(task),"其他室内可开始厨房任务")
	_check(current_scene.player.walk_is_exit,"第一段路线实际使用室内出口")
	await _arrive(state)
	_check(state.current_interior == str(house.id) and state.kitchen.jobs.size() == 1,"走出其他房间、进入小灶并投料")
	if state.kitchen.jobs.size() == 1:
		var job: Dictionary = state.kitchen.jobs[0]
		job.ready = state._kitchen_now()
		var cream_before := int(state.inventory.get("cream",0))
		_check(state.queue_kitchen_task({"op":"collect","id":str(job.key)}),"完成批次可请求收取")
		_check(str(state.kitchen_task.get("station","")) == str(job.station),"收取任务取批次所属设备")
		await _arrive(state)
		_check(state.kitchen.jobs.is_empty() and int(state.inventory.get("cream",0)) == cream_before + int(job.qty),"走到批次工位后收取，产量正确")
	current_scene.player.global_position = Vector2(480,550)
	state.interior_position = current_scene.player.global_position
	state.inventory.milk = 4
	_check(state.queue_kitchen_task(task),"建立用于手动接管的厨房任务")
	var empty_target := {"id":"manual-ground","name":"空地","world_click":true,"click_room":state.current_interior,"x":480,"y":555}
	_check(current_scene.player.walk_to(empty_target) and state.kitchen_task.is_empty(),"另一条手动路线取消厨房待办")
	state.stop_walking()
	print("Kitchen task smoke: %d passed, %d failed" % [passed,failed])
	current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
