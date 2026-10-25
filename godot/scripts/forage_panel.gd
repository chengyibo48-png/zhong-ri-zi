extends Control
class_name ForagePanel

var point_ids: Array[String] = []
var selected_id := ""
var summary_label: Label
var point_list: ItemList
var detail_label: Label
var recent_label: Label
var mode_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.10, 0.08, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -255
	panel.offset_bottom = 255
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e3b30")
	style.border_color = Color("b0b886")
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
	title.text = "山野采集手记"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("e8e6c9"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	summary_label = Label.new()
	summary_label.add_theme_color_override("font_color", Color("d6dbb0"))
	column.add_child(summary_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 15)
	column.add_child(body)
	point_list = ItemList.new()
	point_list.custom_minimum_size = Vector2(310, 300)
	point_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	point_list.item_selected.connect(_choose_point)
	body.add_child(point_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 185
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", Color("e4e7d2"))
	right.add_child(detail_label)
	mode_button = Button.new()
	mode_button.custom_minimum_size.y = 40
	mode_button.pressed.connect(_toggle_mode)
	right.add_child(mode_button)
	recent_label = Label.new()
	recent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recent_label.add_theme_color_override("font_color", Color("c6d1b2"))
	right.add_child(recent_label)
	var hint := Label.new()
	hint.text = "走近资源自动发现 · G 切换采法 · 靠近恢复中的资源按 Delete 覆土护根"
	hint.add_theme_color_override("font_color", Color("c4cdaa"))
	column.add_child(hint)
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	refresh()
	point_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _choose_point(index: int) -> void:
	if index >= 0 and index < point_ids.size():
		selected_id = point_ids[index]
		_refresh_detail()

func _toggle_mode() -> void:
	GameState.toggle_forage_mode()
	refresh()
	mode_button.grab_focus()

func refresh() -> void:
	if not visible or not is_instance_valid(point_list):
		return
	var discovered: Array = GameState.forage.get("discovered", [])
	summary_label.text = "已观察 %d / %d 处 · 采集 %d 次%s" % [discovered.size(), GameState.forage_points.size(), int(GameState.forage.get("xp", 0)), " · 熟手采集节省体力" if int(GameState.forage.get("xp", 0)) >= 20 else " · 采集 20 次后节省体力"]
	point_ids.clear()
	point_list.clear()
	for point in GameState.forage_points:
		var point_id := str(point.get("id", ""))
		if not discovered.has(point_id):
			continue
		var item_id := str(point.get("item", ""))
		var description := GameState.forage_description(point_id, item_id, str(point.get("event", "")))
		point_ids.append(point_id)
		point_list.add_item("%s · %s" % [str(point.get("name", item_id)), description])
	if point_ids.is_empty():
		selected_id = ""
		point_list.add_item("尚未发现资源 · 去茶山、竹林或溪南走走")
		point_list.set_item_disabled(0, true)
	elif not point_ids.has(selected_id):
		selected_id = point_ids[0]
	if selected_id != "":
		point_list.select(point_ids.find(selected_id))
	_refresh_detail()
	mode_button.text = "当前：%s · 点击切换" % ("多采一份，恢复更久" if str(GameState.forage.get("mode", "gentle")) == "full" else "留根轻采，恢复更快")
	var finds: Array = GameState.forage.get("finds", [])
	var recent_lines: Array[String] = ["最近采集"]
	for offset in range(mini(4, finds.size())):
		var record: Dictionary = finds[finds.size() - 1 - offset]
		var item_id := str(record.get("item", ""))
		recent_lines.append("第 %d 天 · %s ×%d · %s%s" % [int(record.get("day", 0)) + 1, str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), int(record.get("qty", 0)), str(record.get("weather", "")), " · 优质" if int(record.get("grade", 0)) > 0 else ""])
	if finds.is_empty():
		recent_lines.append("还没有采集记录。")
	recent_label.text = "\n".join(recent_lines)

func _refresh_detail() -> void:
	if selected_id == "":
		detail_label.text = "观察附近的山林与溪边，逐处记下可采资源。"
		return
	for point in GameState.forage_points:
		if str(point.get("id", "")) != selected_id:
			continue
		var item_id := str(point.get("item", ""))
		var definition: Dictionary = GameState.system_catalog.get("forage", {}).get("defs", {}).get(item_id, {})
		var state := GameState.forage_status(selected_id, item_id, str(point.get("event", "")))
		var distance := roundi(GameState.player_position.distance_to(Vector2(float(point.get("x", 0)), float(point.get("y", 0)))) / 32.0)
		detail_label.text = "%s · 约 %d 步\n%s\n\n%s\n用途：%s\n%s" % [str(point.get("name", item_id)), distance, GameState.forage_description(selected_id, item_id, str(point.get("event", ""))), str(definition.get("method", "留根留种")), str(definition.get("use", "")), "可在此处按 Delete 用熟堆肥覆土，提前一天恢复。" if int(state.wait) > 1 else "轻采后资源会自行恢复；多采会增加这处的压力。"]
		return
