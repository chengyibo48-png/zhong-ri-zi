extends Control
class_name MailPanel

var title_label: Label
var list: ItemList
var detail: Label
var claim_button: Button
var entry_ids: Array[String] = []
var selected_id := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.10, 0.09, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -260
	panel.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color("465044")
	style.border_color = Color("d1bf91")
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
	title_label = Label.new()
	title_label.text = "禾溪来信"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("f3e2bd"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "收起 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(280, 390)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_select)
	body.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	detail = Label.new()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", Color("f1e5cd"))
	right.add_child(detail)
	claim_button = Button.new()
	claim_button.custom_minimum_size.y = 42
	claim_button.text = "收下信件"
	claim_button.pressed.connect(_claim)
	right.add_child(claim_button)
	var hint := Label.new()
	hint.text = "每封信只可收取一次；随信物品会直接放进背包。信件最多保留最近 150 封。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("d1c6aa"))
	column.add_child(hint)
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	selected_id = ""
	visible = true
	GameState.ui_open = true
	GameState.open_mailbox()
	refresh()
	list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or not is_instance_valid(list): return
	entry_ids.clear()
	list.clear()
	var unread := 0
	for letter in GameState.letters:
		var letter_id := str(letter.get("id", ""))
		if letter_id == "": continue
		var is_unread := not GameState.mail_read.has(letter_id)
		if is_unread: unread += 1
		entry_ids.append(letter_id)
		list.add_item("%s%s · %s" % ["✉ " if is_unread else "　", str(letter.get("title", "无题")), str(letter.get("from", "寄信人"))])
	title_label.text = "禾溪来信 · 未读 %d" % unread
	if entry_ids.is_empty():
		selected_id = ""
		list.add_item("暂无来信，日子会慢慢带来消息。")
		list.set_item_disabled(0, true)
		detail.text = "信箱是空的。季节更替或熟悉的邻居有话想说时，信会送到这里。"
		claim_button.disabled = true
		return
	if not entry_ids.has(selected_id):
		selected_id = ""
		for letter_id in entry_ids:
			if not GameState.mail_read.has(letter_id):
				selected_id = letter_id
				break
		if selected_id == "": selected_id = entry_ids[0]
	list.select(entry_ids.find(selected_id))
	_update_detail()

func _select(index: int) -> void:
	if index < 0 or index >= entry_ids.size(): return
	selected_id = entry_ids[index]
	_update_detail()

func _update_detail() -> void:
	var letter: Dictionary = {}
	for candidate in GameState.letters:
		if str(candidate.get("id", "")) == selected_id:
			letter = candidate
			break
	if letter.is_empty():
		detail.text = "选择一封信。"
		claim_button.disabled = true
		return
	var gifts: Dictionary = letter.get("gift", {}) if letter.get("gift", {}) is Dictionary else {}
	var reward := ""
	for item_id in gifts:
		reward += "\n随信物品：%s ×%d" % [str(GameState.item_catalog.get(str(item_id), {}).get("name", item_id)), int(gifts[item_id])]
	var day_no := int(letter.get("day", 0)) + 1
	detail.text = "%s\n来自：%s\n第 %d 天\n\n%s%s" % [str(letter.get("title", "无题")), str(letter.get("from", "寄信人")), day_no, str(letter.get("text", "")), reward]
	var claimed := GameState.mail_read.has(selected_id)
	claim_button.text = "已收好" if claimed else "读完并收下信件"
	claim_button.disabled = claimed

func _claim() -> void:
	if selected_id == "" or GameState.action_busy(): return
	var letter_id := selected_id
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		selected_id = letter_id
		refresh()
		if claim_button.disabled: list.grab_focus()
		else: claim_button.grab_focus()
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		GameState.confirm_operation(GameState.claim_letter(letter_id))
		restore.call()
	var action := GameState.ACTION_RULES.ui("e-mail", claim_button.text)
	action.item = letter_id
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action, {"kind": "ui", "x": position.x, "y": position.y}, commit, restore): restore.call()
