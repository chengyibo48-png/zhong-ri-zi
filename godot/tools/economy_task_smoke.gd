extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _json(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func _quantities_equal(actual: Dictionary,expected: Dictionary) -> bool:
	for id in actual:
		if int(actual[id])!=int(expected.get(id,0)): return false
	for id in expected:
		if int(expected[id])!=int(actual.get(id,0)): return false
	return true
func _quality_equal(actual: Dictionary,expected: Dictionary) -> bool:
	var ids: Array = actual.keys()
	for id in expected:
		if not ids.has(id): ids.append(id)
	for id in ids:
		if _json(actual.get(id,[0,0,0]))!=_json(expected.get(id,[0,0,0])): return false
	return true
func _settle() -> void:
	await process_frame
	await process_frame
func _arrive(state: Node) -> void:
	for frame in range(3600):
		if state.walking_target.is_empty() and state.building_task.is_empty(): break
		await physics_frame
	await _settle()
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1); return
	create_timer(90).timeout.connect(func(): quit(1))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ECONOMY_TASK_FIXTURE")))
	if not raw is Dictionary: quit(1); return
	var fixture: Dictionary = raw
	var script = load("res://scripts/game_state.gd")
	var order_state = script.new()
	order_state._load_content();order_state._load_initial_state()
	for row in fixture.orders:
		order_state.day = int(row.day)
		_check(_json(order_state.economy_weekly_orders())==_json(row.orders),"四年原版每周订单 "+str(row.day))
	order_state.free()
	for row in fixture.rows:
		var state = script.new()
		state._load_content();state._load_initial_state()
		var label := str(row.task)+"/"+str(row.variant)
		_check(state.load_game_data(state.convert_external_save(row.before)),"原版交易输入 "+label)
		var before: Dictionary = state._make_save_data()
		var preview: Dictionary = state.preview_building_task(row.task)
		_check(bool(preview.ok)==bool(row.preview.ok) and bool(row.unchanged),"交易预检 "+label)
		_check(_json(state._make_save_data())==_json(before),"交易预检无结算 "+label)
		var target: Dictionary = state.building_task_destination(row.task)
		_check(float(target.x)==float(row.destination.x) and float(target.y)==float(row.destination.y),"原版交易柜台 "+label)
		_check(state.perform_building_task(row.task)==bool(row.result.ok),"原版交易成功 "+label)
		var e: Dictionary = row.expected
		_check(state.money==int(e.money) and state.minutes==int(e.minutes) and state.stamina==int(e.stamina),"原版交易费用和劳动 "+label)
		_check(_quantities_equal(state.inventory,e.bag),"原版交易库存 "+label)
		_check(_quality_equal(state.quality,e.quality),"原版交易品质 "+label)
		_check(_json(state.economy)==_json(e.economy),"原版货单、货签与流水 "+label)
		_check(_json(state.kitchen.lots)==_json(e.lots),"原版新鲜度批次 "+label)
		_check(int(state.player_stats.get("earned",0))==int(e.earned) and bool(state.flags.get("firstSale",false))==bool(e.firstSale),"原版交易统计 "+label)
		state.free()
	if OS.get_environment("ECONOMY_MODEL_ONLY")=="1":
		print("Economy model smoke: %d passed, %d failed"%[passed,failed])
		quit(1 if failed else 0)
		return
	var state = root.get_node("GameState")
	state.load_game_data(state.convert_external_save(fixture.source))
	state.current_interior = "";state.ui_open = false
	var shop: Dictionary = state.building_task_destination({"op":"economy-buy","id":"cabbageSeed","n":1})
	state.player_position = Vector2(float(shop.x)+70,float(shop.y)+70)
	change_scene_to_file("res://scenes/main.tscn")
	await _settle()
	current_scene.hud.toggle_onboarding()
	var money_before := int(state.money)
	_check(state.queue_building_task({"op":"economy-buy","id":"cabbageSeed","n":1}),"创建购买行走")
	_check(state.money==money_before and int(state.inventory.cabbageSeed)==0,"未到柜台不购买")
	await _arrive(state)
	_check(state.money<money_before and int(state.inventory.cabbageSeed)==1,"真实走到柜台后购买")
	state.player_position = Vector2(float(shop.x)+70,float(shop.y)+70)
	current_scene.player.global_position = state.player_position
	var cabbage_before := int(state.inventory.cabbage)
	_check(state.queue_building_task({"op":"economy-sell","id":"cabbage","n":3,"grade":-1}),"创建出售行走")
	state.stop_walking()
	await _settle()
	_check(int(state.inventory.cabbage)==cabbage_before,"取消不出售")
	_check(state.queue_building_task({"op":"economy-sell","id":"cabbage","n":3,"grade":-1}),"创建途中锁定测试")
	state.economy.locked.append("cabbage")
	await _arrive(state)
	_check(int(state.inventory.cabbage)==cabbage_before and state.building_task.is_empty(),"抵达时物品锁定拒绝出售")
	state.economy.locked.clear()
	var coop: Dictionary = state.building_task_destination({"op":"economy-send","id":"rice","n":3,"grade":-1,"channel":"coop","theme":"pantry"})
	state.player_position = Vector2(float(shop.x)+70,float(shop.y)+70)
	current_scene.player.global_position = state.player_position
	_check(state.queue_building_task({"op":"economy-send","id":"rice","n":3,"grade":-1,"channel":"coop","theme":"pantry"}),"走去合作社代销 "+str(state.message)+" rice="+str(state.inventory.rice))
	await _arrive(state)
	_check(state.economy.jobs.size()==1 and str(state.economy.jobs[0].channel)=="coop" and current_scene.player.global_position.distance_to(Vector2(float(coop.x),float(coop.y)))<53,"合作社实际距离后建代销单")
	state.player_position = Vector2(float(shop.x)+70,float(shop.y)+70)
	current_scene.player.global_position = state.player_position
	current_scene.hud.show_market("sell",false)
	var panel = current_scene.hud.market_panel
	panel.selected_id = "cabbage";panel.refresh();panel.quantity_box.value = 3
	_check(panel.mode=="sell" and panel.mode_buttons.buy.visible,"远处打开完整交易簿")
	panel._add_cart()
	_check(panel.cart.size()==1 and int(panel.cart[0].n)==3 and int(panel.cart[0].grade)==-1,"售货篮记录数量品质")
	panel.quantity_box.value = 4
	_check(int(panel.cart[0].n)==3,"修改当前数量不改已放货签")
	panel._add_cart()
	_check(panel.cart.size()==2,"同物品允许多条货签")
	panel.cart_selection = 0;panel.cart_remove.pressed.emit()
	_check(panel.cart.size()==1 and int(panel.cart[0].n)==4,"移出指定货签")
	for index in range(15): panel._add_cart()
	_check(panel.cart.size()==12 and panel.cart_add.disabled,"整篮上限十二条")
	var before_batch: Dictionary = state._make_save_data()
	panel.cart_submit.pressed.emit()
	_check(state.building_task.is_empty() and _json(state._make_save_data())==_json(before_batch),"整篮超库存预检原子拒绝")
	panel.cart.clear();panel._refresh_cart();panel.quantity_box.value=2;panel._add_cart()
	var before_sale := int(state.inventory.cabbage)
	panel.cart_submit.pressed.emit()
	_check(not state.building_task.is_empty() and not panel.visible and int(state.inventory.cabbage)==before_sale,"售货篮关闭界面并行走未提前出售")
	await _arrive(state)
	_check(int(state.inventory.cabbage)==before_sale-2,"真实抵达后整篮结算")
	current_scene.hud.show_market("sell",false)
	panel.selected_id="rice";panel.refresh();panel.channel_box.select(2);panel.refresh()
	_check(not panel.action_button.disabled,"远处允许交合作社并自动行走")
	panel._choose_mode("business")
	panel.selected_id="job:1";panel.refresh()
	_check(panel.lock_button.visible and not panel.lock_button.disabled,"远处可撤回代销并自动行走")
	current_scene.hud.close_market()
	_check(not state._make_save_data().has("building_task"),"交易运行时行走不入存档")
	print("Economy task smoke: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
