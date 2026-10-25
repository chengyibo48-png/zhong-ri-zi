extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var temporary := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temporary == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temporary + "/"):
		push_error("生活簿检查需要临时 APPDATA，以免覆盖玩家存档。")
		quit(1)
		return
	var state = root.get_node("GameState")
	var fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RECORDS_FIXTURE")))
	if not fixtures is Array:
		push_error("需要原版年度回顾对照数据。")
		quit(1)
		return
	for fixture in fixtures:
		state.day = int(fixture.day)
		state.player_stats = fixture.stats.duplicate(true)
		state.upgrades = fixture.upgrades.duplicate(true)
		state.community_projects = fixture.projects.duplicate(true)
		state.marriage = fixture.marriage.duplicate(true)
		state.npc_stories = fixture.stories.duplicate(true)
		state.archives.clear()
		for id in fixture.archives: state.archives.append(str(id))
		_check(state.year_summary() == fixture.expected, "原版五段年度总结一致：第 %d 组" % passed)
	state.day = 113
	state.player_journal.clear()
	state.player_journal.append_array([{"day": 1, "text": "旧"}, {"day": 113, "text": "同日旧二"}, {"day": 113, "text": "同日旧一"}, {"day": 113, "text": "同日新"}])
	state.legacy_archive = {"journal": [{"day": 113, "text": "同日旧二"}, {"day": 113, "text": "同日旧一"}, {"day": 1, "text": "旧"}]}
	var journal: Array[Dictionary] = state.journal_entries()
	_check(journal[0].text == "同日新" and journal[1].text == "同日旧二" and journal[2].text == "同日旧一" and journal.back().day == 1, "日志按日期倒序且保留浏览器同日原始顺序")
	var hud := CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	root.add_child(hud)
	hud.community_panel.open_panel("archives")
	_check(hud.community_panel.tabs.size() == 8 and _contains(hud.community_panel.card_list, "老院的钥匙") and _contains(hud.community_panel.card_list, "线索：完成陈木生"), "旧物柜呈现已获得文案和未获得线索")
	hud.community_panel._select_tab("journal")
	_check(_contains(hud.community_panel.card_list, "同日新") and _contains(hud.community_panel.card_list, "春 2 日"), "完整生活日志使用原生日期卡片")
	state.year_plans = {}
	state.day = 0
	hud.community_panel._select_tab("year")
	_check(_buttons(hud.community_panel.card_list, "记下这个想法") == 0 and _contains(hud.community_panel.card_list, "走完四季后"), "首年未走完四季时不提前显示年度选择")
	state.day = 112
	hud.community_panel._select_tab("year")
	_check(_buttons(hud.community_panel.card_list, "记下这个想法") == 3, "年度回顾提供三项来年选择")
	_find_button(hud.community_panel.card_list, "记下这个想法").grab_focus()
	_check(state.record_year_plan(1) and state.year_plans.get("1", -1) == 1 and _buttons(hud.community_panel.card_list, "记下这个想法") == 0 and _contains(hud.community_panel.card_list, "来年的安排已经写好"), "写下计划后显示已选结果并收起本轮选择")
	_check(hud.community_panel.content_scroll.follow_focus and root.gui_get_focus_owner() == hud.community_panel.tab_buttons["year"], "选项更新后恢复到当前页焦点并支持自动滚动")
	var saved: Dictionary = state._make_save_data().duplicate(true)
	state.year_plans = {}
	state.archives.clear()
	state.player_journal.clear()
	_check(state.load_game_data(saved) and state.year_plans.get("1", -1) == 1 and state.archives.has("key") and not state.player_journal.is_empty(), "计划、旧物与生活日志原生存档往返保留")
	hud.community_panel.close()
	state.day = 111
	state.advance_day()
	_check(bool(state.flags.get("yearReview", false)) and hud.community_open() and hud.community_panel.active_tab == "year" and not state.year_review_pending and state.ui_open, "室外跨年自动打开年度总结并暂停")
	hud.community_panel.close()
	state.day = 112
	state.advance_day()
	_check(not hud.community_open() and not state.year_review_pending, "普通睡醒不重复打开年度总结")
	hud.queue_free()
	await process_frame
	state.day = 223
	state.current_interior = "home-granny"
	state.interior_position = Vector2(480, 550)
	var room = load("res://scenes/interior.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	state.advance_day()
	for frame in range(5): await process_frame
	_check(state.current_interior == "home-granny" and current_scene == room and current_scene.hud.community_open() and current_scene.hud.community_panel.active_tab == "year" and state.ui_open, "原版室内跨年保留房屋并由当前 HUD 打开年度总结")
	print("Life records migration: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _contains(node: Node, text: String) -> bool:
	if node is Label and node.text.contains(text): return true
	for child in node.get_children():
		if _contains(child, text): return true
	return false

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null: return found
	return null

func _buttons(node: Node, text: String) -> int:
	var count := int(node is Button and node.text == text)
	for child in node.get_children(): count += _buttons(child, text)
	return count

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
