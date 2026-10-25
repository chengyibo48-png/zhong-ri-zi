extends Control
class_name SkillsPanel

var card_list: VBoxContainer
var close_button: Button
var content_scroll: ScrollContainer
var choice_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.12, 0.14, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -370
	panel.offset_right = 370
	panel.offset_top = -285
	panel.offset_bottom = 285
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
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "四时手艺簿 · 做事熟练度"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("eee8cb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "合上 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var intro := Label.new()
	intro.text = "在日常劳作、料理、手作和交往中积累熟练度。每门手艺达到 25 点后，可记下一种长期专长。"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color("d8e4d6"))
	column.add_child(intro)
	content_scroll = ScrollContainer.new()
	var scroll := content_scroll
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	card_list = VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 10)
	scroll.add_child(card_list)
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	refresh()
	close_button.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _select_skill(skill_id: String, choice_id: String) -> void:
	if GameState.action_busy(): return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var scroll_value := content_scroll.scroll_vertical
	var key := skill_id + ":" + choice_id
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		refresh()
		_restore_choice_focus.call_deferred(key, scroll_value, starting_day, starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		GameState.confirm_operation(GameState.choose_skill(skill_id, choice_id))
		restore.call()
	var action := GameState.ACTION_RULES.ui("e-skill", "选择此风格")
	action.item = skill_id
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action, {"kind": "ui", "x": position.x, "y": position.y}, commit, restore): restore.call()

func _restore_choice_focus(key: String, scroll_value: int, starting_day: int, starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	var button: Button = choice_buttons.get(key)
	if is_instance_valid(button) and not button.disabled: button.grab_focus()
	else: close_button.grab_focus()
	content_scroll.scroll_vertical = scroll_value

func refresh() -> void:
	if not visible or not is_instance_valid(card_list):
		return
	choice_buttons.clear()
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()
	var names: Dictionary = GameState.content.get("skillNames", {})
	var choices: Dictionary = GameState.content.get("skillChoices", {})
	for skill_id_value in names:
		var skill_id := str(skill_id_value)
		var skill: Dictionary = GameState.skills.get(skill_id, {"xp": 0, "choice": null})
		var xp := int(skill.get("xp", 0))
		var selected := "" if skill.get("choice") == null else str(skill.choice)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("3a5049")
		card_style.border_color = Color("778d72")
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(5)
		card_style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", card_style)
		card_list.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 6)
		card.add_child(body)
		var title := Label.new()
		title.text = "%s · 熟练度 %d" % [str(names[skill_id_value]), xp]
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("f1e6c8"))
		body.add_child(title)
		var progress := ProgressBar.new()
		progress.max_value = 25
		progress.value = mini(25, xp)
		progress.show_percentage = false
		progress.custom_minimum_size.y = 13
		body.add_child(progress)
		var state_label := Label.new()
		state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if selected != "":
			state_label.text = "已记下专长；之后仍会继续积累熟练度。"
		elif xp >= 25:
			state_label.text = "专长已开放：选定后会长期影响对应生活玩法。"
		else:
			state_label.text = "再积累 %d 点熟练度即可选择专长。" % (25 - xp)
		state_label.add_theme_color_override("font_color", Color("d8e4d6"))
		body.add_child(state_label)
		for option in choices.get(skill_id_value, []):
			if not option is Array or option.size() < 3:
				continue
			var choice_id := str(option[0])
			var button := Button.new()
			button.text = ("✓ " if choice_id == selected else "") + str(option[1]) + " · " + str(option[2])
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.disabled = selected != "" or xp < 25
			choice_buttons[skill_id + ":" + choice_id] = button
			button.pressed.connect(_select_skill.bind(skill_id, choice_id))
			body.add_child(button)
