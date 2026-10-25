extends Control
class_name SleepPanel

var sleep_button: Button
var detail_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.05, 0.08, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -160
	panel.offset_bottom = 160
	var style := StyleBoxFlat.new()
	style.bg_color = Color("30363a")
	style.border_color = Color("bba978")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "今天，就到这里吧。"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail_label)
	var note := Label.new()
	note.text = "收好工具，睡醒后体力恢复，田地、动物和加工会继续一天。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	sleep_button = Button.new()
	sleep_button.text = "熄灯，迎接明天"
	sleep_button.pressed.connect(_sleep)
	actions.add_child(sleep_button)
	var continue_button := Button.new()
	continue_button.text = "再走走"
	continue_button.pressed.connect(close)
	actions.add_child(continue_button)
	visible = false
	GameState.changed.connect(refresh)
	GameState.bedtime_reached.connect(open_panel)

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	refresh()
	sleep_button.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or not is_instance_valid(detail_label):
		return
	var date := GameState.date_text()
	var tomorrow := GameState.weather_profile(GameState.day + 1)
	detail_label.text = "%s · 明天：%s %d°C" % [date, str(tomorrow.get("label", "晴")), int(tomorrow.get("temperature", 20))]

func _sleep() -> void:
	if GameState.action_busy():return
	var starting_day:=GameState.day
	var starting_room:=GameState.current_interior
	var position: Dictionary=GameState.player_navigation_position()
	var target:Dictionary={"kind":"ui","id":"next-day","x":position.x,"y":position.y}
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	var spec:=GameState.ACTION_RULES.ui("next-day",sleep_button.text)
	var commit:=func():
		if GameState.day==starting_day and GameState.current_interior==starting_room:
			GameState.advance_day()
			GameState.confirm_operation(true)
	var restore:=func():
		if is_instance_valid(self) and GameState.day==starting_day and GameState.current_interior==starting_room:
			open_panel()
	if not GameState.begin_action(spec,target,commit,restore):restore.call()
