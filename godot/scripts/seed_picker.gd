extends Control

const ITEM_ICON := preload("res://scripts/item_icon.gd")
var crop_buttons: Dictionary = {}
var crop_labels: Dictionary = {}
var close_button: Button
var scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.07, 0.05, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-350, -275)
	panel.size = Vector2(700, 550)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "播下这一季的期待"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "合上 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var note := Label.new()
	note.text = "土壤轮作可以提高收成。豆类能养地，休耕也会慢慢恢复。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for crop_id in GameState.crop_catalog:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		rows.add_child(row)
		var icon := ITEM_ICON.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.configure(str(crop_id))
		row.add_child(icon)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		crop_labels[crop_id] = label
		var button := Button.new()
		button.custom_minimum_size.x = 130
		button.pressed.connect(_choose.bind(str(crop_id)))
		row.add_child(button)
		crop_buttons[crop_id] = button
	GameState.changed.connect(refresh)
	hide()

func refresh() -> void:
	if not visible: return
	for crop_id in crop_buttons:
		var crop: Dictionary = GameState.crop_data(str(crop_id))
		var seasons: Array[String] = []
		for season in crop.get("seasons", []):
			seasons.append(["春", "夏", "秋", "冬"][clampi(int(season), 0, 3)])
		crop_labels[crop_id].text = "%s · %d 天 · %s\n适种：%s · 背包种子 %d 份" % [GameState.crop_name(str(crop_id)), int(crop.get("days", 0)), str(crop.get("group", "")), "、".join(seasons), int(GameState.inventory.get(GameState.seed_item_id(str(crop_id)), 0))]
		crop_buttons[crop_id].text = "已选好" if crop_id == GameState.selected_seed else "选这颗种子"
		crop_buttons[crop_id].disabled = not GameState.crop_in_season(str(crop_id))

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	GameState._interrupt_navigation_for_ui()
	show()
	GameState.ui_open = true
	refresh()
	call_deferred("_focus_selection")

func _focus_selection() -> void:
	# Allow the newly visible containers to finish sizing before scrolling.
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible: return
	var selected: Button = crop_buttons.get(GameState.selected_seed, close_button)
	if not selected.disabled:
		selected.grab_focus()
		scroll.ensure_control_visible(selected.get_parent())
		if GameState.selected_seed == str(GameState.crop_catalog.keys()[0]):
			scroll.scroll_vertical = 0
	else:
		close_button.grab_focus()
		scroll.scroll_vertical = 0

func close() -> void:
	hide()
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _choose(crop_id: String) -> void:
	if GameState.choose_normal_seed(crop_id): close()
