extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
	if ok:passed+=1
	else:
		failed+=1
		push_error(label)
func same(a:Variant,b:Variant)->bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in b:
			if not a.has(k) or not same(a[k],b[k]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not same(a[i],b[i]):return false
		return true
	return a==b

func settle():
	await process_frame
	await process_frame
	await physics_frame
func arrive(state):
	for frame in range(900):
		if state.kitchen_task.is_empty() and state.walking_target.is_empty():break
		await physics_frame
	await settle()
func choose(box:OptionButton,id:String)->bool:
	for i in range(box.item_count):
		if str(box.get_item_metadata(i))==id:
			box.select(i)
			return true
	return false
func _run():
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	create_timer(90).timeout.connect(func():push_error("Research UI timeout");quit(1))
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("KITCHEN_MANAGEMENT_FIXTURE")+".ui.json"))
	if not fixture is Dictionary:quit(1);return
	check(fixture.rows.size()==2,"发现配方及普通试配两类原版样本")
	var state=root.get_node("GameState")
	for row in fixture.rows:
		check(state.load_game_data(state.convert_external_save(row.before)),"试配输入读取")
		state.current_interior=str(fixture.house.id)
		state.interior_position=Vector2(480,550)
		change_scene_to_file("res://scenes/interior.tscn")
		await settle()
		var panel=current_scene.hud.kitchen_panel
		current_scene.hud.show_kitchen(false,"research")
		check(choose(panel.first_box,str(row.id)) and choose(panel.second_box,str(row.second)),"面板原料选项可用")
		panel._refresh_detail()
		check(not panel.action_button.disabled,"实际试配按钮允许出发")
		panel._act()
		check(not panel.visible and not state.kitchen_task.is_empty(),"按试配按钮进入走近灶台流程")
		check(int(state.inventory[row.id])==int(row.before.bag[row.id]) and int(state.inventory[row.second])==int(row.before.bag[row.second]),"出发不提前消耗原料")
		await arrive(state)
		check(state.kitchen_task.is_empty() and state.walking_target.is_empty(),"抵达灶台后完成试配")
		check(state.message==str(row.result.msg),"实际试配完整原文")
		check(same(state.known_recipes,row.expected.knownRecipes),"实际发现配方顺序")
		check(JSON.stringify(state.kitchen.experiments)==JSON.stringify(row.expected.kitchen.experiments),"实际组合手札")
		check(same(state.journal_entries(),row.expected.journal),"实际学会菜谱日记")
		check(same(state.legacy_systems.eventLog,row.expected.eventLog),"实际学会菜谱事件记录")
		check(int(state.inventory[row.id])==int(row.expected.bag.get(row.id,0)) and int(state.inventory[row.second])==int(row.expected.bag.get(row.second,0)),"实际原料消耗或保留")
		check(int(state.inventory.get("gardenSoup",0))==int(row.expected.bag.get("gardenSoup",0)),"实际普通汤产出")
		check(same(state.legacy_systems.discovered,row.expected.discovered),"实际图鉴发现记录")
		# A protected ingredient must fail in the same preview used by the button.
		current_scene.hud.show_kitchen(false,"research")
		choose(panel.first_box,str(row.id))
		choose(panel.second_box,str(row.second))
		state.economy.locked=[str(row.id)]
		var before:Dictionary=state._make_save_data().duplicate(true)
		panel._act()
		check(panel.visible and state.kitchen_task.is_empty(),"锁定原料拒绝出发且保留面板")
		check(state.message=="所选材料不足；相同材料需要两份。","锁定试配原版提示")
		check(JSON.stringify(state.inventory)==JSON.stringify(before.inventory) and JSON.stringify(state.kitchen)==JSON.stringify(before.kitchen),"锁定试配无额外结算")
		current_scene.hud.close_top_panel()
	print("KITCHEN_RESEARCH_UI_SMOKE: %d passed, %d failed"%[passed,failed])
	current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(0 if failed==0 else 1)
