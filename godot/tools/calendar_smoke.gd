extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	var calendar = load("res://scripts/calendar_rules.gd")
	var birthdays := 0
	var markets := 0
	var gatherings := 0
	var festivals := 0
	var terms: Array[String] = []
	var matched := true
	for season in range(4):
		var days: Array[Dictionary] = calendar.season_days(state.content, 0, season)
		matched = matched and days.size() == 28
		for index in range(days.size()):
			var entry := days[index]
			var annual := season * 28 + index
			matched = matched and int(entry.day) == annual and int(entry.date) == index + 1
			matched = matched and str(entry.term) == str(state.content.terms[floori(float(annual * 24) / 112)])
			birthdays += entry.birthdays.size()
			markets += int(entry.market)
			gatherings += int(entry.gathering)
			festivals += int(entry.festival)
			if not terms.has(str(entry.term)): terms.append(str(entry.term))
	_check(matched and terms.size() == 24, "四季 112 天和二十四节气与原版日历公式一致")
	_check(birthdays == 24 and markets == 16 and gatherings == 16 and festivals == 4, "24 位生日、16 次赶集小聚和四季开席日期均保留")
	var next_year: Array[Dictionary] = calendar.season_days(state.content, 112, 0)
	_check(int(next_year[0].day) == 112 and bool(next_year[0].today) and not bool(next_year[1].today), "跨年日期和今天标记正确")
	state.day = 91
	var panel = load("res://scripts/weather_panel.gd").new()
	root.add_child(panel)
	panel.open_panel()
	_check(panel.notebook.get_tab_count() == 3 and panel.calendar_grid.get_child_count() == 28 and panel.birthday_box.get_child_count() == 24, "原生日历页、预报页和全年生日册可实例化")
	_check(panel.season_option.selected == 3 and panel.selected_date == 8 and state.ui_open, "打开日历定位当前季节日期并暂停世界")
	panel._select_date(8)
	_check(panel.calendar_detail.text.contains("生日：") and panel.calendar_detail.text.contains("冬"), "选中生日显示居民姓名和季节日期")
	panel.season_option.select(0)
	panel._refresh_calendar()
	panel._select_date(14)
	_check(panel.calendar_detail.text.contains("邻里开席") and panel.calendar_note.text.contains("适种："), "季节切换展示饭桌信息和适种作物")
	panel.close()
	_check(not panel.visible and not state.ui_open, "关闭日历恢复世界")
	panel.queue_free()
	await process_frame
	state.current_interior = "home-granny"
	state.interior_position = Vector2(480, 550)
	var room = load("res://scenes/interior.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_C
	room._unhandled_key_input(key)
	_check(room.hud.weather_open() and state.ui_open, "室内 C 键打开同一日历和天气簿")
	room.hud.weather_panel.season_option.select(1)
	room.hud.weather_panel._open_festival()
	_check(not room.hud.weather_open() and room.hud.festival_open() and room.hud.festival_panel.season_option.selected == 1 and state.ui_open, "节庆入口保留所选季节并交接面板暂停状态")
	key.keycode = KEY_ESCAPE
	room._unhandled_key_input(key)
	_check(not room.hud.festival_open() and not state.ui_open, "室内 Esc 可关闭节庆面板")
	room.queue_free()
	print("Calendar migration: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
