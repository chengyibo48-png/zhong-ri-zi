extends Control
class_name FeedbackPanel

var body: VBoxContainer
var tab := "recent"
var type_filter := "全部"
var search_text := ""
var type_option: OptionButton
var search_box: LineEdit
var tab_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.055, 0.045, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -430
	panel.offset_right = 430
	panel.offset_top = -275
	panel.offset_bottom = 275
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303a30")
	style.border_color = Color("c5b184")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "禾溪 · 手边回响"
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭  Esc / B"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for row in [["recent", "消息与结果"], ["day", "七日回顾"], ["settings", "反馈偏好"]]:
		var button := Button.new()
		button.text = str(row[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(str(row[0])))
		tabs.add_child(button)
		tab_buttons[str(row[0])] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	_refresh_body()
	if tab_buttons.has(tab): tab_buttons[tab].grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if visible:
		_refresh_body()

func _select_tab(next_tab: String) -> void:
	tab = next_tab if next_tab in ["recent", "day", "settings"] else "recent"
	_refresh_body()

func _clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _refresh_body() -> void:
	if not is_instance_valid(body): return
	_clear_body()
	for key in tab_buttons:
		tab_buttons[key].disabled = key == tab
	match tab:
		"day": _build_days()
		"settings": _build_settings()
		_: _build_recent()

func _build_recent() -> void:
	var rows: Array = GameState.feedback.get("rows", [])
	var unread := rows.filter(func(row: Dictionary) -> bool: return not bool(row.get("read", false))).size()
	var filter_row := HBoxContainer.new()
	body.add_child(filter_row)
	type_option = OptionButton.new()
	type_option.custom_minimum_size.x = 150
	for label in ["全部", "未读", "收支", "照料", "社交", "提醒", "未完成"]:
		type_option.add_item(str(label))
		type_option.set_item_metadata(type_option.item_count - 1, str(label))
	filter_row.add_child(type_option)
	for index in range(type_option.item_count):
		if str(type_option.get_item_metadata(index)) == type_filter: type_option.select(index)
	search_box = LineEdit.new()
	search_box.placeholder_text = "查找物品、工作或提醒"
	search_box.max_length = 40
	search_box.text = search_text
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(search_box)
	var apply_button := Button.new()
	apply_button.text = "查找"
	apply_button.pressed.connect(_apply_filter)
	filter_row.add_child(apply_button)
	var read_button := Button.new()
	read_button.text = "全部已读"
	read_button.disabled = unread == 0
	read_button.pressed.connect(_mark_all_read)
	filter_row.add_child(read_button)
	var summary := Label.new()
	summary.text = "%d 条未读 · 最多保留 80 条；普通结果会自动收好。" % unread
	summary.add_theme_color_override("font_color", Color("d8cba6"))
	body.add_child(summary)
	var visible_rows: Array[Dictionary] = []
	for row in rows:
		var type := str(row.get("type", "提醒"))
		var matches_type := type_filter == "全部" or type_filter == "未读" and not bool(row.get("read", false)) or type_filter == type
		var query := search_text.strip_edges()
		var matches_text := query == "" or (str(row.get("title", "")) + str(row.get("text", ""))).containsn(query)
		if matches_type and matches_text: visible_rows.append(row)
	visible_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("read", false)) != bool(b.get("read", false)): return not bool(a.get("read", false))
		if int(a.get("priority", 0)) != int(b.get("priority", 0)): return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return int(a.get("id", 0)) > int(b.get("id", 0))
	)
	if visible_rows.is_empty():
		_add_note("这里还没有相应记录。", "动作完成、关系变化和需要留意的事情会慢慢记在这里。")
		return
	for row in visible_rows:
		_add_record(row)

func _add_record(row: Dictionary) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3b483b") if not bool(row.get("read", false)) else Color("374137")
	style.border_color = Color("d4bc82") if int(row.get("priority", 0)) > 0 else Color("758269")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	body.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = ("● " if not bool(row.get("read", false)) else "") + str(row.get("title", "手边的事")) + (" ×%d" % int(row.get("count", 1)) if int(row.get("count", 1)) > 1 else "")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("f0dfb7"))
	heading.add_child(title)
	var meta := Label.new()
	meta.text = "%s · %s" % [str(row.get("type", "提醒")), _date_time(row)]
	meta.add_theme_color_override("font_color", Color("c3c6a4"))
	heading.add_child(meta)
	var text := Label.new()
	text.text = str(row.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("font_color", Color("ede4cb"))
	column.add_child(text)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var link := str(row.get("link", "feedback"))
	if link != "feedback":
		var open_button := Button.new()
		open_button.text = "查看相关手记"
		open_button.pressed.connect(_open_link.bind(link))
		actions.add_child(open_button)
	if not bool(row.get("read", false)):
		var read_button := Button.new()
		read_button.text = "已看过"
		read_button.pressed.connect(_mark_read.bind(str(row.get("id", ""))))
		actions.add_child(read_button)

func _build_days() -> void:
	body.add_child(_add_section_label("统计实际有状态变化的操作；仓储和背包之间的存取不重复计作新获得。"))
	var days: Array = GameState.feedback.get("days", []).duplicate(true)
	days.reverse()
	if days.is_empty():
		_add_note("还没有每日记录。", "从下一次收获或照料开始，慢慢记下今天。")
		return
	for day_row in days:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3a4639")
		style.set_border_width_all(1)
		style.border_color = Color("827a5e")
		style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", style)
		body.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		var day_index := int(day_row.get("day", 0))
		var title := Label.new()
		title.text = "第 %d 天%s" % [day_index + 1, " · 今天" if day_index == GameState.day else ""]
		title.add_theme_font_size_override("font_size", 18)
		column.add_child(title)
		var summary := Label.new()
		summary.text = "%d 次有状态变化的操作 · 收入 %d 元 · 支出 %d 元" % [int(day_row.get("actions", 0)), int(day_row.get("income", 0)), int(day_row.get("spent", 0))]
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(summary)
		var item_lines: Array[String] = []
		var names: Array = day_row.get("items", {}).keys()
		names.sort()
		for key in names.slice(0, 24):
			var parts := str(key).split(":")
			if parts.size() != 2: continue
			var grade := clampi(int(parts[1]), 0, 3)
			item_lines.append("%s %s ×%d" % [["普通", "优质", "上品", "珍品"][grade], str(GameState.item_catalog.get(parts[0], {}).get("name", parts[0])), int(day_row.items[key])])
		var items := Label.new()
		items.text = "物品变化：" + ("、".join(item_lines) if not item_lines.is_empty() else "暂无物品收支")
		items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(items)
	_add_note("天气提醒", GameState.weather_warning())

func _build_settings() -> void:
	body.add_child(_add_section_label("动作结果会留在记录里。缩短节奏、减少飘动或关闭飘字，不会影响游戏结算。"))
	var prefs: Dictionary = GameState.feedback.get("prefs", {})
	_add_preference("动作节奏", "pace", [["normal", "舒缓 · 完整过程"], ["brisk", "利落 · 缩短效果"]], str(prefs.get("pace", "normal")))
	_add_preference("反馈动效", "motion", [["full", "轻柔飘动"], ["reduced", "减少飘动与过渡"]], str(prefs.get("motion", "full")))
	_add_preference("获得提示", "floating", [["normal", "最多三条，合并同类"], ["compact", "紧凑 · 只留最近一条"], ["off", "隐藏飘字，保留记录"]], str(prefs.get("floating", "normal")))
	_add_preference("文字提示停留", "seconds", [[5, "5 秒"], [8, "8 秒"], [12, "12 秒"]], int(prefs.get("seconds", 5)))
	_add_preference("普通通知", "quiet", [[false, "显示普通结果"], [true, "安静模式 · 只提示需关注消息"]], bool(prefs.get("quiet", false)))
	_add_note("提示去向", "提醒会写入手边回响；从记录卡片可以跳到物品、天气、农事、牧场、厨房、营造、钓鱼或邻里手记。")

func _add_preference(label_text: String, key: String, choices: Array, selected_value: Variant) -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 145
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice in choices:
		option.add_item(str(choice[1]))
		option.set_item_metadata(option.item_count - 1, choice[0])
		if choice[0] == selected_value: option.select(option.item_count - 1)
	option.item_selected.connect(func(index: int) -> void:
		if index >= 0: GameState.feedback_set_preference(key, option.get_item_metadata(index))
	)
	row.add_child(option)

func _add_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("d8cba6"))
	body.add_child(label)
	return label

func _add_note(title: String, text: String) -> void:
	var label := Label.new()
	label.text = title + "\n" + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 64
	label.add_theme_color_override("font_color", Color("e4d8bc"))
	body.add_child(label)

func _date_time(row: Dictionary) -> String:
	var seasons: Array = GameState.content.get("seasons", ["春", "夏", "秋", "冬"])
	var day_index := int(row.get("day", 0))
	var season := str(seasons[posmod(int(day_index / 28), seasons.size())])
	var minute := clampi(int(row.get("minute", 0)), 0, 1320)
	return "%s %d 日 · %02d:%02d" % [season, day_index % 28 + 1, int(minute / 60), minute % 60]

func _apply_filter() -> void:
	if type_option.selected >= 0: type_filter = str(type_option.get_item_metadata(type_option.selected))
	search_text = search_box.text.strip_edges().left(40)
	_refresh_body()

func _mark_all_read() -> void:
	GameState.feedback_mark_read("all")

func _mark_read(row_id: String) -> void:
	GameState.feedback_mark_read(row_id)

func _open_link(link: String) -> void:
	close()
	var hud := get_parent()
	if hud == null: return
	match link:
		"bag": hud.call("show_market", "inventory", false)
		"farmcare": hud.call("show_farm_planner", false, 0)
		"ranch": hud.call("show_ranch")
		"processing": hud.call("show_kitchen", false, "process")
		"build": hud.call("show_building", {}, false)
		"weather": hud.call("show_weather")
		"neighbors": hud.call("show_neighbor_book")
		"economy": hud.call("show_market", "business", true, "coop")
		"fishing": hud.call("show_fishing")
		"tools": hud.call("show_tools", false)
		_: hud.call("show_feedback")

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event is not InputEventKey: return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo: return
	if key_event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_TAB:
		if not body.get_children().is_empty():
			var first := body.get_child(0)
			if first is Control: first.grab_focus()

