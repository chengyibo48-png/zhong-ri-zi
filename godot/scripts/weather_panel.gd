extends Control
class_name WeatherPanel

signal festival_requested(season: int)
const CALENDAR := preload("res://scripts/calendar_rules.gd")

var warning_label: Label
var forecast_box: VBoxContainer
var impact_label: Label
var close_button: Button
var notebook: TabContainer
var season_option: OptionButton
var calendar_grid: GridContainer
var calendar_detail: Label
var calendar_note: Label
var birthday_box: VBoxContainer
var selected_date := 1
var calendar_entries: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.12, 0.14, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -245
	panel.offset_bottom = 245
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c3d3e")
	style.border_color = Color("b9b99a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "禾溪日历与观天簿"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("eee8cb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var book_button:=Button.new();book_button.text="禾溪邻里簿"
	book_button.tooltip_text="行踪、约定与对话记录"
	book_button.pressed.connect(func():close();get_parent().show_neighbor_book())
	header.add_child(book_button)
	notebook = TabContainer.new()
	notebook.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(notebook)
	var forecast_page := VBoxContainer.new()
	forecast_page.name = "四日预报"
	notebook.add_child(forecast_page)
	warning_label = Label.new()
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.custom_minimum_size.y = 58
	warning_label.add_theme_color_override("font_color", Color("f3d3a4"))
	forecast_page.add_child(warning_label)
	forecast_box = VBoxContainer.new()
	forecast_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forecast_box.add_theme_constant_override("separation", 7)
	forecast_page.add_child(forecast_box)
	impact_label = Label.new()
	impact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impact_label.custom_minimum_size.y = 63
	impact_label.add_theme_color_override("font_color", Color("d8e4d6"))
	forecast_page.add_child(impact_label)
	_build_calendar()
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	season_option.select(GameState.season_index())
	selected_date = GameState.day % 28 + 1
	refresh()
	close_button.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or not is_instance_valid(forecast_box):
		return
	_refresh_calendar()
	warning_label.text = GameState.weather_warning()
	for child in forecast_box.get_children():
		child.queue_free()
	var forecast: Array[Dictionary] = GameState.weather_forecast(4)
	for offset in range(forecast.size()):
		var entry: Dictionary = forecast[offset]
		var row := PanelContainer.new()
		row.custom_minimum_size.y = 57
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("44564e") if bool(entry.extreme) else Color("3b5153")
		row_style.set_corner_radius_all(4)
		row_style.set_content_margin_all(7)
		row.add_theme_stylebox_override("panel", row_style)
		forecast_box.add_child(row)
		var line := HBoxContainer.new()
		row.add_child(line)
		var day_label := Label.new()
		day_label.text = ("今天" if offset == 0 else "明天" if offset == 1 else "%d 日后" % offset) + " · " + str(entry.label)
		day_label.custom_minimum_size.x = 165
		day_label.add_theme_color_override("font_color", Color("ffe2af") if bool(entry.extreme) else Color("f4e7c7"))
		line.add_child(day_label)
		var values := Label.new()
		values.text = "%d～%d°C  降水 %d  风 %d" % [int(entry.low), int(entry.high), int(entry.rain), int(entry.wind)]
		values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(values)
	var dry_count := 0
	var wet_count := 0
	for plot in GameState.plots:
		if str(plot.get("crop", "")) == "":
			continue
		if int(plot.get("moisture", 45)) < 28:
			dry_count += 1
		elif int(plot.get("moisture", 45)) > 86:
			wet_count += 1
	var today: Dictionary = GameState.weather_profile()
	impact_label.text = "田间：%d 块偏干，%d 块偏湿。今日蒸发系数 ×%.2f；牧场按防护与放牧策略避开恶劣天气。\n%s" % [dry_count, wet_count, float(today.evaporation), str(today.tip)]


func _scroll_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notebook.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column

func _text(parent: Node, value: String = "") -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _build_calendar() -> void:
	var page := _scroll_page("季节日历")
	season_option = OptionButton.new()
	for season in ["春季", "夏季", "秋季", "冬季"]: season_option.add_item(season)
	season_option.item_selected.connect(func(_index: int): selected_date = 1; _refresh_calendar())
	page.add_child(season_option)
	calendar_grid = GridContainer.new()
	calendar_grid.columns = 7
	calendar_grid.add_theme_constant_override("h_separation", 4)
	calendar_grid.add_theme_constant_override("v_separation", 4)
	page.add_child(calendar_grid)
	for date in range(1, 29):
		var button := Button.new()
		button.custom_minimum_size = Vector2(84, 58)
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_date.bind(date))
		calendar_grid.add_child(button)
	calendar_detail = _text(page)
	calendar_note = _text(page)
	var festival_button := Button.new()
	festival_button.text = "查看节庆准备与补办"
	festival_button.pressed.connect(_open_festival)
	page.add_child(festival_button)
	_text(page, "每季 28 天，每七天一行。每周第 6 天赶集，第 7 天休闲小聚。生日只是相聚的理由，错过不会扣关系。")
	birthday_box = _scroll_page("全年生日册")
	for person in GameState.npc_catalog:
		var birthday := int(person.get("birthday", 1)) - 1
		var seasons := ["春", "夏", "秋", "冬"]
		_text(birthday_box, "%s季 %02d 日 · %s" % [seasons[clampi(birthday / 28, 0, 3)], birthday % 28 + 1, str(person.get("name", ""))])

func _refresh_calendar() -> void:
	if not is_instance_valid(calendar_grid): return
	var season := season_option.selected if season_option.selected >= 0 else GameState.season_index()
	calendar_entries = CALENDAR.season_days(GameState.content, GameState.day, season)
	for index in range(calendar_entries.size()):
		var entry := calendar_entries[index]
		var marks: Array[String] = []
		if bool(entry.today): marks.append("今天")
		if bool(entry.festival): marks.append("邻里开席")
		if bool(entry.market): marks.append("赶集")
		if bool(entry.gathering): marks.append("小聚")
		if not entry.birthdays.is_empty(): marks.append("生日")
		if bool(entry.term_start): marks.append(str(entry.term))
		var button := calendar_grid.get_child(index) as Button
		button.text = "%02d\n%s" % [int(entry.date), " · ".join(marks)] if not marks.is_empty() else "%02d\n%s" % [int(entry.date), str(GameState.weather_profile(int(entry.day)).label)]
		button.tooltip_text = " · ".join(marks)
		button.modulate = Color("f2d29a") if bool(entry.today) else Color.WHITE
	_show_date()
	var crops: Array[String] = []
	for crop in GameState.crop_catalog.values():
		if season in crop.get("seasons", []): crops.append(str(crop.get("name", "")))
	var hints: Array = GameState.content.get("weekHints", [])
	var week := floori(float(GameState.day % 112) / 7.0)
	var festival := GameState.festival_status(season)
	calendar_note.text = "本周：%s\n本季饭桌：%s · 第 14 天起可参加或补办%s\n适种：%s" % [str(hints[week]) if week < hints.size() else "", str(festival.get("name", "")), " · 已完成" if bool(festival.get("done", false)) else "", "、".join(crops)]

func _select_date(date: int) -> void:
	selected_date = date
	_show_date()

func _show_date() -> void:
	if calendar_entries.is_empty(): return
	var entry := calendar_entries[clampi(selected_date - 1, 0, 27)]
	var birthdays: Array[String] = []
	for person in entry.birthdays: birthdays.append(str(person.name))
	var profile := GameState.weather_profile(int(entry.day))
	calendar_detail.text = "第 %d 年 · %s季 %02d 日 · %s\n%s · %s%s" % [
		floori(float(GameState.day) / 112.0) + 1, ["春", "夏", "秋", "冬"][int(entry.season)], int(entry.date), str(entry.term),
		str(profile.label), str(profile.get("tip", "")), "\n生日：" + "、".join(birthdays) if not birthdays.is_empty() else ""]
	if bool(entry.festival): calendar_detail.text += "\n邻里开席：带一道料理，选择交换手艺或听故事。"

func _open_festival() -> void:
	var season := season_option.selected
	close()
	festival_requested.emit(season)
