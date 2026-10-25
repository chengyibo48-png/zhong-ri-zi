extends SceneTree
var HEAT: GDScript
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
func _arrive(state: Node) -> void:
	for frame in range(600):
		if state.kitchen_task.is_empty() and state.walking_target.is_empty(): break
		await physics_frame
	await _settle()
func _run() -> void:
	root.size = Vector2i(960,600)
	HEAT = load("res://scripts/kitchen_heat_panel.gd")
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(55).timeout.connect(func(): quit(1))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("KITCHEN_HEAT_FIXTURE")))
	for sample in fixture.samples:
		_check(absf(HEAT.heat_at(float(sample.ms)/1000.0)-float(sample.value)) < 0.00001,"原版指针波形 " + str(sample.ms))
	for row in fixture.cases:
		var copy = load("res://scripts/game_state.gd").new()
		copy._load_content()
		copy._load_initial_state()
		copy.inventory.cabbage = 4
		var heat := -1.0 if row.heat == null else float(row.heat)
		_check(copy.cook_recipe("greens",1,heat,false) == bool(row.result.ok),"原版火候事务 " + str(row.heat))
		_check(int(copy.inventory.cabbage) == int(row.cabbage) and int(copy.inventory.greens) == int(row.greens),"火候材料与产出 " + str(row.heat))
		_check(copy.quality.get("greens",[0,0,0]).map(func(value): return int(value)) == row.quality.map(func(value): return int(value)),"品质区间边界 " + str(row.heat))
		copy.free()
	_check(HEAT.heat_text(34.999).begins_with("小火") and HEAT.heat_text(35).begins_with("火候正好") and HEAT.heat_text(75).begins_with("火候正好") and HEAT.heat_text(75.001).begins_with("大火"),"火候提示严格边界")
	for row in fixture.seasonal:
		var copy = load("res://scripts/game_state.gd").new()
		copy._load_content()
		copy._load_initial_state()
		copy.inventory.wildHerb = 1
		copy.inventory.shoot = 1
		copy.quality.wildHerb = [1,0,0]
		copy.quality.shoot = [1,0,0]
		_check(copy._kitchen_grade("springBowl",copy.recipe_data("springBowl").ingredients,1,"stove",int(row.manual)) == int(row.grade),"原版节令品质加成 " + str(row.manual))
		copy.free()
	var state = root.get_node("GameState")
	state.current_interior = "building-farm-13"
	state.interior_position = Vector2(480,550)
	state.inventory.cabbage = 4
	change_scene_to_file("res://scenes/interior.tscn")
	await _settle()
	var hud = current_scene.hud
	hud.show_kitchen(false,"cook")
	var recipes = hud.kitchen_panel
	recipes.selected_id = "greens"
	recipes._refresh_detail()
	_check(recipes.manual_button.visible and not recipes.manual_button.disabled,"菜谱提供亲手掌火入口")
	recipes._manual()
	_check(not hud.kitchen_heat_panel.visible and not recipes.visible and int(state.inventory.cabbage) == 4,"手动制作先关闭菜谱行走，未开火不耗食材")
	await _arrive(state)
	var panel = hud.kitchen_heat_panel
	_check(panel.visible and state.ui_open and state.kitchen_task.is_empty(),"抵达灶台后打开火候页并暂停世界")
	_check(hud.notification_stack.z_index<panel.z_index and panel.good_zone.color == Color("6d9a67"),"火候页保留绿色区域且位于世界通知之上")
	_check(root.gui_get_focus_owner() == panel.finish_button,"火候页默认起锅焦点")
	_check(int(state.inventory.cabbage) == 4 and int(state.inventory.get("greens",0)) == 0,"打开火候页不提前结算")
	var minutes_before := int(state.minutes)
	await create_timer(0.2).timeout
	_check(int(state.minutes) == minutes_before,"火候计时不推进游戏时间")
	var cancel := InputEventKey.new()
	cancel.pressed = true
	cancel.keycode = KEY_ESCAPE
	hud.handle_life_menu_key(cancel)
	_check(not panel.visible and not state.ui_open and panel.task.is_empty() and int(state.inventory.cabbage) == 4,"Esc 关闭保留材料")
	panel.open_panel({"id":"greens","n":1})
	panel.started_usec = Time.get_ticks_usec() - 1727876
	var manual_xp_before := int(state.skills.cooking.xp)
	_check(panel.finish(false) and not panel.visible and int(state.inventory.cabbage) == 2,"绿色区间起锅成功后关闭")
	_check(int(state.quality.get("greens",[0,0,0])[1]) == 1,"亲手掌火产生原版上品")
	_check(int(state.skills.cooking.xp) == mini(99999,manual_xp_before+3),"实际掌火每份三点烹饪经验")
	_check(state.message.ends_with(" · 火候恰好。"),"实际掌火原版出锅反馈")
	_check(not panel.finish(false) and int(state.inventory.cabbage) == 2,"重复起锅不能重复扣料")
	state.inventory.cabbage = 4
	panel.open_panel({"id":"greens","n":1})
	panel.started_usec = Time.get_ticks_usec() - 1727876
	var quick_xp_before := int(state.skills.cooking.xp)
	_check(panel.finish(true) and int(state.inventory.cabbage) == 2,"省心火候完成料理")
	_check(int(state.skills.cooking.xp) == mini(99999,quick_xp_before+3),"实际快做每份三点烹饪经验")
	_check(state.message.ends_with(" · 家常快做。"),"实际快做原版出锅反馈")
	_check(int(state.quality.get("greens",[0,0,0])[0]) == 1,"省心制作不取得手动火候奖励")
	state.inventory.cabbage = 0
	panel.open_panel({"id":"greens","n":1})
	_check(not panel.finish(true) and panel.visible and panel.result_label.text != "","食材变化失败保留页面并说明原因")
	panel.close()
	state.player_settings.textScale = 1.4
	hud.refresh()
	panel.open_panel({"id":"greens","n":1})
	await _settle()
	var card = panel.get_child(1).get_child(0)
	if card.get_global_rect().position.y < 0 or card.get_global_rect().end.y > root.size.y: print("Heat card: ",card.get_global_rect()," root: ",root.size)
	_check(card.get_global_rect().position.y >= 0 and card.get_global_rect().end.y <= root.size.y,"放大字体时火候页面上下界在屏幕内")
	panel.close()
	hud.show_kitchen(false,"cook")
	recipes.selected_id = "pickles"
	recipes._refresh_detail()
	_check(recipes.manual_button.disabled,"隔日腌制不提供亲手掌火")
	hud.close_top_panel()
	print("Kitchen heat smoke: %d passed, %d failed" % [passed,failed])
	current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
