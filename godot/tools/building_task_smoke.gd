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
	for frame in range(1800):
		if state.walking_target.is_empty() and state.building_task.is_empty(): break
		await physics_frame
	await _settle()
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1); return
	create_timer(110).timeout.connect(func(): quit(1))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BUILDING_TASK_FIXTURE")))
	if not raw is Dictionary: quit(1); return
	var fixture: Dictionary = raw
	var script = load("res://scripts/game_state.gd")
	for row in fixture.rows:
		var state = script.new()
		state._load_content();state._load_initial_state()
		var label := str(row.task)+"/"+str(row.variant)
		_check(state.load_game_data(state.convert_external_save(row.before)),"营造原版输入 "+label)
		var preview: Dictionary = state.preview_building_task(row.task)
		_check(bool(preview.ok)==bool(row.preview.ok) and bool(row.unchanged),"营造预检结果 "+label)
		_check(state.money==int(row.before.money) and state.minutes==int(row.before.minutes),"预检不结算 "+label)
		var destination: Dictionary = state.building_task_destination(row.task)
		_check(float(destination.x)==float(row.destination.x) and float(destination.y)==float(row.destination.y),"原版营造地点 "+label)
		_check(state.perform_building_task(row.task)==bool(row.result.ok),"原版事务成功 "+label)
		var e: Dictionary = row.expected
		_check(state.money==int(e.money) and state.stamina==int(e.stamina) and state.minutes==int(e.minutes),"原版营造消耗 "+label)
		for id in state.inventory: _check(int(state.inventory.get(str(id),0))==int(e.bag.get(id,0)),"营造物品 "+str(id)+"/"+label)
		for id in row.before.bag:
			if not e.bag.has(id): _check(int(state.inventory.get(str(id),0))==0,"营造耗尽材料 "+str(id)+"/"+label)
		for field in ["building","furniture","upgrades","skills","toolkit"]:
			_check(_json(state.get(field))==_json(e[field]),"原版营造字段 "+field+"/"+label)
		_check(_json(state.legacy_systems.toolUpgrades)==_json(e.toolUpgrades),"工具旧版状态 "+label)
		_check(int(state.legacy_systems.waterReserve)==int(e.waterReserve) and int(state.farm.water)==int(e.water),"修缮蓄水 "+label)
		_check(_json(state.ranch.barns)==_json(e.barns),"棚舍基础修缮 "+label)
		var quality_ok := true
		var ids: Array = state.quality.keys()
		for id in e.quality:
			if not ids.has(id): ids.append(id)
		for id in ids: quality_ok = quality_ok and _json(state.quality.get(id,[0,0,0]))==_json(e.quality.get(id,[0,0,0]))
		_check(quality_ok,"消耗保留品质结算 "+label)
		_check(_json(state.farm.facilities)==_json(e.facilities),"基础喷灌设施 "+label)
		if str(row.task.op) == "legacy":
			_check(_json(state.journal_entries())==_json(e.journal),"原版完整基础修缮日志 "+label)
			_check(_json(state.legacy_systems.eventLog)==_json(row.before.eventLog),"基础修缮不新增事件记录 "+label)
		elif str(row.task.op) == "tool":
			_check(_json(state.journal_entries())==_json(e.journal),"完整原版工具日志 "+label)
			_check(_json(state.legacy_systems.eventLog)==_json(row.before.eventLog),"工具改良不新增事件记录 "+label)
		state.free()
	for row in fixture.daily:
		var state = script.new()
		state._load_content();state._load_initial_state()
		_check(state.load_game_data(state.convert_external_save(row.before)),"营造日结输入 "+str(row.label))
		state.day = int(row.expected.day)
		state._advance_building(int(row.before.day))
		var e: Dictionary = row.expected
		_check(_json(state.building)==_json(e.building) and _json(state.upgrades)==_json(e.upgrades),"原版竣工状态 "+str(row.label))
		_check(int(state.farm.water)==int(e.water) and _json(state.farm.facilities)==_json(e.facilities),"原版水源与养护效果 "+str(row.label))
		_check(absf(float(state.plots[0].fertility)-float(e.fertility))<0.0001,"原版空田养土保持小数 "+str(row.label))
		var inventory_ok := true
		for id in e.bag: inventory_ok = inventory_ok and int(state.inventory.get(str(id),0))==int(e.bag[id])
		_check(inventory_ok,"原版互助种子发放 "+str(row.label))
		_check(float(state.kitchen.lots.bag.rice[0].age)==float(e.bagAge) and float(state.kitchen.lots.storage.rice[0].age)==float(e.storageAge),"粮仓只减缓储藏食材陈放 "+str(row.label))
		for id in e.discovered:
			_check(state.museum_entries.has("item:"+str(id)),"日结物品记入认识记录 "+str(id))
		if str(row.label)=="four-completions":
			var expected_completions:Array=e.journal.filter(func(record):return str(record.text).ends_with("阶竣工。"))
			var actual_completions:Array=state.journal_entries().filter(func(record):return str(record.text).ends_with("阶竣工。"))
			_check(expected_completions.size()==4 and _json(actual_completions)==_json(expected_completions),"原版四项竣工日志内容、日期与顺序")
		state.free()
	var state = root.get_node("GameState")
	_check(state.load_game_data(state.convert_external_save(fixture.source)),"营造场景输入")
	state.ui_open = false
	state.current_interior = ""
	var house: Dictionary = state.building_task_destination({"op":"project","id":"house"})
	state.player_position = Vector2(float(house.x)+80,float(house.y)+80)
	change_scene_to_file("res://scenes/main.tscn")
	await _settle()
	current_scene.hud.toggle_onboarding()
	var money_before := int(state.money)
	_check(state.queue_building_task({"op":"project","id":"house"}),"创建扩建行走")
	_check(state.money==money_before and state.building.jobs.is_empty(),"未到工地不扣款开工")
	await _arrive(state)
	_check(state.building.jobs.size()==1 and str(state.building.jobs[0].id)=="house" and state.money<money_before,"真实行走抵达后开工")
	_check(current_scene.player.global_position.distance_to(Vector2(float(house.x),float(house.y)))<53,"实际工地距离")
	var workshop: Dictionary = state.building_task_destination({"op":"craft","id":"bench"})
	state.player_position = Vector2(float(workshop.x)+70,float(workshop.y)+70)
	current_scene.player.global_position = state.player_position
	var furniture_before := int(state.furniture.get("bench",0))
	_check(state.queue_building_task({"op":"craft","id":"bench","n":3}),"创建家具制作路线")
	state.stop_walking()
	await _settle()
	_check(int(state.furniture.get("bench",0))==furniture_before and state.building_task.is_empty(),"取消不结算家具")
	_check(state.queue_building_task({"op":"craft","id":"bench","n":3}),"重新走去制作家具")
	await _arrive(state)
	_check(int(state.furniture.get("bench",0))==furniture_before+3,"抵达后制作三件")
	state.player_position = Vector2(float(workshop.x)+70,float(workshop.y)+70)
	current_scene.player.global_position = state.player_position
	_check(state.queue_building_task({"op":"craft","id":"bench","n":1}),"创建材料变化路线")
	state.inventory.wood = 0
	await _arrive(state)
	_check(int(state.furniture.get("bench",0))==furniture_before+3,"抵达时材料不足拒绝事务")
	_check(not state._make_save_data().has("building_task"),"运行时营造任务不入存档")

	state.inventory.wood = 100
	state.inventory.bamboo = 100
	var home_id := ""
	for h in state.world_village.houses:
		if str(h.name)=="爷爷的老屋": home_id = str(h.id)
	state.player_position = Vector2(float(house.x),float(house.y))
	current_scene.player.global_position = state.player_position
	_check(state.enter_interior(home_id),"进入老屋准备室内营造")
	await _settle()
	state.interior_return_position = Vector2(float(workshop.x)+70,float(workshop.y)+70)
	furniture_before = int(state.furniture.get("bench",0))
	_check(state.queue_building_task({"op":"craft","id":"bench","n":1}),"室内发起家具制作")
	_check(state.current_interior==home_id and int(state.furniture.get("bench",0))==furniture_before,"室内发起不会提前结算或瞬移出屋")
	await _arrive(state)
	_check(state.current_interior=="" and int(state.furniture.get("bench",0))==furniture_before+1,"实际走出室内并接续工坊")
	state.player_position = Vector2(float(workshop.x)+70,float(workshop.y)+70)
	current_scene.player.global_position = state.player_position
	_check(state.queue_building_task({"op":"craft","id":"bench","n":1}),"创建新路线取消测试")
	current_scene.player.walk_to({"id":"manual","kind":"walk","x":state.player_position.x+15,"y":state.player_position.y,"world_click":true,"click_room":""})
	_check(state.building_task.is_empty(),"新的手动路线取消待结算营造")
	state.stop_walking()
	var panel: Control = current_scene.hud.building_panel
	current_scene.hud.show_building({},false)
	panel.project_id = "well"
	panel.refresh()
	await _settle()
	_check(panel.find_child("ProjectsTab",true,false).visible and not panel.find_child("CraftTab",true,false).visible,"营造簿仅显示当前分页")
	_check(panel.project_list.item_count==6 and not panel.project_start.disabled,"远离工地仍可选择非施工中的工程")
	panel._set_tab("craft")
	await _settle()
	_check(panel.furniture_list.item_count==state.content.furniture.size() and not panel.craft_one.disabled,"远离工坊仍可走去制作")
	panel._set_tab("legacy")
	await _settle()
	_check(panel.legacy_buttons.size()==state.content.upgrades.size() and panel.legacy_tab.visible,"全部基础修缮可从营造簿访问")
	state.player_settings.textScale = 1.4
	state.changed.emit()
	panel.legacy_buttons.roof.grab_focus()
	for frame in range(4): await process_frame
	var button: Control = panel.legacy_buttons.roof
	_check(Rect2(Vector2.ZERO,Vector2(960,600)).encloses(panel.get_global_rect()) and panel.legacy_tab.get_global_rect().encloses(button.get_global_rect()),"大字体基础修缮焦点滚动可见")
	panel.close()
	state.building_task = {"op":"craft","id":"bench","n":1}
	state.load_game_data(state._make_save_data())
	_check(state.building_task.is_empty(),"读档取消旧营造任务")
	print("Building task smoke: %d passed, %d failed"%[passed,failed])
	current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
