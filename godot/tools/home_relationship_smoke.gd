extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		push_error("家与饭桌验证需隔离临时 APPDATA。")
		quit(1)
		return
	create_timer(40.0).timeout.connect(func(): push_error("Home relationship smoke timed out"); quit(1))
	var state = root.get_node("GameState")
	state.set_process(false)
	var fixture_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOME_FIXTURE")))
	if not fixture_data is Dictionary: quit(1); return
	var rows: Array = fixture_data.hosts
	for fixture in rows:
		state.day = 10
		state.current_interior = ""
		state.upgrades.room = str(fixture.context) != "missing-room"
		state.inventory[str(fixture.dish)] = 2
		state.relations[str(fixture.npc)].points = 30
		state.skills.social.xp = 0
		state.skills.cooking.choice = "host" if str(fixture.context) == "farm-host" else null
		state.season_events = {}
		state.known_recipes.clear()
		for recipe in state.content.recipes:
			if str(recipe.get("source", "")) == "known": state.known_recipes.append(str(recipe.id))
		var before: Array = state.known_recipes.duplicate()
		var region := "town" if str(fixture.context) == "town" else "pasture" if str(fixture.context).begins_with("pasture") else "farm"
		var offset: Dictionary = state.world_village.offsets[region]
		state.player_position = Vector2(float(offset.x) + 500, float(offset.y) + 500)
		state.npc_positions[str(fixture.npc)] = Vector2(10, 10)
		if str(fixture.context).ends_with("interior"):
			for house in state.world_village.houses:
				if str(house.get("region", "")) == region:
					state.current_interior = str(house.id)
					break
		var result: bool = state.host_meal(str(fixture.npc), str(fixture.dish))
		var learned: Array[String] = []
		for recipe in state.known_recipes:
			if not before.has(recipe): learned.append(recipe)
		_check(result == fixture.ok and int(state.inventory.get(str(fixture.dish), 0)) == int(fixture.quantity) and int(state.relations[str(fixture.npc)].points) == int(fixture.points) and int(state.skills.social.xp) == int(fixture.xp) and learned == fixture.learned, "家宴原版规则一致：" + str(fixture.context))
		if result:
			var remaining := int(state.inventory.get(str(fixture.dish), 0))
			_check(not state.host_meal(str(fixture.npc), str(fixture.dish)) and int(state.inventory.get(str(fixture.dish), 0)) == remaining, "每周家宴重复操作不消耗料理：" + str(fixture.context))
	for fixture in fixture_data.shared:
		state.day = 10
		state.marriage = {"spouse": "qiao", "day": 5, "weekly": {}, "memories": []}
		for index in range(79): state.marriage.memories.append({"day": 5, "activity": "visit"})
		state.relations.qiao.points = 70
		state.inventory[str(fixture.dish)] = 2
		var result: bool = state.share_life(str(fixture.activity), str(fixture.dish))
		var recorded_message: String = state.message
		# JSON numbers are floats; compare the serialized memory payload on both sides.
		_check(result == fixture.ok and int(state.inventory[str(fixture.dish)]) == int(fixture.quantity) and int(state.relations.qiao.points) == int(fixture.points) and JSON.parse_string(JSON.stringify(state.marriage.memories)) == fixture.marriage.memories and state.marriage.weekly == fixture.marriage.weekly and recorded_message == fixture.message, "婚后每周安排与原版一致：" + str(fixture.activity))
		var remaining := int(state.inventory[str(fixture.dish)])
		var memories: int = state.marriage.memories.size()
		_check(not state.share_life(str(fixture.activity), str(fixture.dish)) and int(state.inventory[str(fixture.dish)]) == remaining and state.marriage.memories.size() == memories, "本周重复安排不消费且不重复记录：" + str(fixture.activity))
	state.current_interior = ""
	state.player_position = Vector2(2831, 1652)
	state.upgrades.room = true
	state.day = 10
	state.partners.qiao = "dating"
	state.npc_stories.qiao = {"step": 4, "choices": [0, 0, 0, 0], "lastDay": 9}
	state.relations.qiao.points = 80
	state.npc_positions.qiao = Vector2(10, 10)
	state.marriage = {"spouse": "", "day": -1, "weekly": {}, "memories": []}
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world=current_scene
	world.set_process(false);world.player.set_physics_process(false)
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	var panel=world.hud.neighbor_journal
	var wedding=world.hud.wedding_panel
	var separation=world.hud.separation_panel
	panel.open_panel("qiao")
	_check(not panel.marry_button.disabled and not panel.host_meal_button.disabled and not state.npc_is_near("qiao"), "婚礼及农場家宴入口保留原版远程操作条件")
	panel._on_marry()
	_check(world.hud._gamepad_panel()==wedding and wedding.z_index==20,"婚礼页聚焦自身并遮挡世界 HUD")
	_check(wedding.visible and state.marriage.spouse=="" and state.ui_open,"打开婚礼页不结算")
	wedding.cancel_button.pressed.emit()
	_check(not wedding.visible and state.marriage.spouse=="" and not state.ui_open,"取消婚礼回到世界")
	panel.open_panel("qiao");panel._on_marry();wedding.confirm_button.pressed.emit()
	for frame in range(35):state._process_action(0.1)
	_check(state.marriage.spouse=="qiao" and not wedding.visible and world.hud.home_panel.spouse_section.visible,"婚礼完成进入共同生活页")
	var quantity := int(state.inventory.get("greens", 0))
	var points := int(state.relations.qiao.points)
	var story: Dictionary = state.npc_stories.qiao.duplicate(true)
	world.hud.home_panel._ask_separate()
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	_check(not separation.visible and str(state.marriage.spouse) == "qiao" and not state.ui_open, "Esc 关闭独立分开页回到世界")
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	world.hud.show_separation()
	separation.confirm_button.pressed.emit()
	for frame in range(35): state._process_action(0.1)
	_check(str(state.marriage.spouse) == "" and str(state.partners.qiao) == "friend" and int(state.relations.qiao.points) == points and state.npc_stories.qiao == story and int(state.inventory.get("greens", 0)) == quantity, "确认分开只结束伴侣关系，保留好感故事与库存")
	var text := JSON.stringify(state.player_journal)
	_check(text.contains("结为伴侣") and text.contains("平静地商量"), "婚礼与友好分开记入完整生活日志")
	world.hud.close_top_panel()
	_check(not separation.visible and not state.ui_open,"关闭家庭页恢复世界输入")
	world.queue_free()
	print("Home relationship migration: %d passed, %d failed" % [passed, failed])
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
