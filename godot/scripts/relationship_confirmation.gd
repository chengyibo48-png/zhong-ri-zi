extends Control

signal confirmed
signal cancelled
signal extra_requested
var title_label: Label
var detail_label: Label
var confirm_button: Button
var cancel_button: Button
var extra_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.07, 0.04, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -170
	panel.offset_bottom = 170
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303a30")
	style.border_color = Color("c5b184")
	style.set_border_width_all(3)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail_label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	confirm_button = Button.new()
	confirm_button.custom_minimum_size.y = 40
	confirm_button.pressed.connect(func(): confirmed.emit())
	actions.add_child(confirm_button)
	cancel_button = Button.new()
	cancel_button.custom_minimum_size.y = 40
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	extra_button = Button.new()
	extra_button.custom_minimum_size.y = 40
	extra_button.pressed.connect(func(): extra_requested.emit())
	extra_button.visible = false
	actions.add_child(extra_button)
	for button in [confirm_button, cancel_button]:
		var other: Button = cancel_button if button == confirm_button else confirm_button
		for direction in ["top", "bottom", "left", "right"]:
			button.set("focus_neighbor_" + direction, other.get_path())
		button.focus_next = other.get_path()
		button.focus_previous = other.get_path()
	visible = false

func open(title: String, detail: String, confirm_text: String, cancel_text: String) -> void:
	if GameState.action_busy():return
	extra_button.visible = false
	title_label.text = title
	detail_label.text = detail
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	visible = true
	# Opening the page is not consent; the choice requires a separate press.
	cancel_button.grab_focus()

func close() -> void:
	visible = false

func _cancel() -> void:
	close()
	cancelled.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()



func show_extra(text: String) -> void:
	extra_button.text = text
	extra_button.visible = true
	for index in range(3):
		var buttons := [confirm_button, cancel_button, extra_button]
		var button: Button = buttons[index]
		var following: Button = buttons[(index + 1) % 3]
		var preceding: Button = buttons[(index + 2) % 3]
		button.focus_next = following.get_path()
		button.focus_previous = preceding.get_path()
		button.focus_neighbor_bottom = following.get_path()
		button.focus_neighbor_top = preceding.get_path()
