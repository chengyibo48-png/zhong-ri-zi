extends Control
class_name FestivalPanel

var season_option: OptionButton
var dish_option: OptionButton
var details_label: Label
var status_label: Label
var choice_buttons: Array[Button] = []
var dish_ids: Array[String] = []

const SEASONS := ["春", "夏", "秋", "冬"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.075, 0.065, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -220
	panel.offset_bottom = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3c3d32")
	style.border_color = Color("d4b774")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "四季饭桌 · 把这一季端上来"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("f2e4bc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("d3d9b3"))
	column.add_child(status_label)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	season_option = OptionButton.new()
	season_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for season in SEASONS: season_option.add_item(season + "季")
	season_option.item_selected.connect(_selection_changed)
	controls.add_child(season_option)
	dish_option = OptionButton.new()
	dish_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dish_option.item_selected.connect(_selection_changed)
	controls.add_child(dish_option)
	details_label = Label.new()
	details_label.custom_minimum_size.y = 190
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	details_label.add_theme_color_override("font_color", Color("eee8d6"))
	column.add_child(details_label)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	column.add_child(choices)
	for index in range(2):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		button.pressed.connect(_participate.bind(index))
		choices.add_child(button)
		choice_buttons.append(button)
	var note := Label.new()
	note.text = "从本季第 14 天起可以开席；错过当天仍可在本季稍后补办。带一道做好的料理，选择交换手艺或听听邻里故事。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("c8cfb0"))
	column.add_child(note)
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	season_option.select(GameState.season_index())
	refresh()
	season_option.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _selection_changed(_index: int) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(details_label): return
	var season := season_option.selected if season_option.selected >= 0 else GameState.season_index()
	var status := GameState.festival_status(season)
	var day_number := GameState.day % 112 % 28 + 1
	status_label.text = "%s · 第 %d 年 · 本日第 %d 天" % [str(status.get("name", "四季饭桌")), int(status.get("year", 1)), day_number]
	details_label.text = "%s\n\n%s\n\n%s\n\n%s" % [str(status.get("prepare", "")), str(status.get("activity", "")), str(status.get("after", "")), "已留下本季故事。" if bool(status.get("done", false)) else "本次完成后：全村关系 +10 · 稻米 ×3 · 解锁节令菜谱"]
	var prior_dish:=dish_ids[dish_option.selected] if dish_option.selected>=0 and dish_option.selected<dish_ids.size() else ""
	dish_ids.clear()
	dish_option.clear()
	var available_items: Array[String] = []
	for item_id in GameState.item_catalog:
		if str(GameState.item_catalog[item_id].get("kind", "")) == "料理" and int(GameState.inventory.get(item_id, 0)) > 0:
			available_items.append(str(item_id))
	available_items.sort_custom(func(a, b): return str(GameState.item_catalog[a].get("name", a)) < str(GameState.item_catalog[b].get("name", b)))
	for item_id in available_items:
		dish_ids.append(item_id)
		dish_option.add_item("%s ×%d" % [str(GameState.item_catalog[item_id].get("name", item_id)), int(GameState.inventory.get(item_id, 0))])
	if not dish_ids.is_empty(): dish_option.select(maxi(0,dish_ids.find(prior_dish)))
	var choices: Array = status.get("choices", [])
	for index in range(choice_buttons.size()):
		choice_buttons[index].text = str(choices[index]) if index < choices.size() else "暂不可参与"
		choice_buttons[index].disabled = not bool(status.get("open", false)) or bool(status.get("done", false)) or dish_ids.is_empty() or index >= choices.size()
	if not bool(status.get("open", false)):
		status_label.text += " · 第 14 天起开放"
	elif bool(status.get("done", false)):
		status_label.text += " · 已完成"
	elif dish_ids.is_empty():
		status_label.text += " · 请先准备一道料理"

func _participate(choice: int) -> void:
	if dish_option.selected < 0 or dish_option.selected >= dish_ids.size():
		GameState.message = "先准备一道料理，再来赴约。"
		GameState.changed.emit()
		return
	if GameState.action_busy():return
	var dish_id:=dish_ids[dish_option.selected]
	var season:=season_option.selected
	var starting_day:=GameState.day
	var starting_room:=GameState.current_interior
	var position:=GameState.player_position if starting_room=="" else GameState.interior_position
	var target:Dictionary={"kind":"ui","id":dish_id,"x":position.x,"y":position.y}
	var restore:=func():
		if is_instance_valid(self) and GameState.day==starting_day and GameState.current_interior==starting_room:
			visible=true
			GameState.ui_open=true
			season_option.select(season)
			refresh()
			var index:=dish_ids.find(dish_id)
			if index>=0:dish_option.select(index)
			choice_buttons[choice].grab_focus()
	var commit:=func():
		if GameState.day!=starting_day or GameState.current_interior!=starting_room:return
		GameState.confirm_operation(GameState.attend_festival(dish_id,choice,season))
		restore.call()
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	var spec:=GameState.ACTION_RULES.ui("e-festival",choice_buttons[choice].text)
	spec.item=dish_id
	if not GameState.begin_action(spec,target,commit,restore):restore.call()
