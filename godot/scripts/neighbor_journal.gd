extends Control
class_name NeighborJournal

const CHARACTER_PORTRAIT_SCRIPT := preload("res://scripts/character_portrait.gd")

var resident_list: ItemList
var portrait_view: Control
var relation_label: Label
var profile_label: Label
var dialogue_meta_label: Label
var dialogue_label: Label
var dialogue_skip_button: Button
var dialogue_timer: Timer
var dialogue_source_text := ""
var dialogue_visible_count := 0
var story_skip_button: Button
var story_timer: Timer
var story_source_text := ""
var story_visible_count := 0
var dialogue_topic_buttons: Dictionary = {}
var event_label: Label
var gift_label: Label
var gift_item_option: OptionButton
var gift_button: Button
var story_label: Label
var story_open_button: Button
var story_choice_buttons: Array[Button] = []
var home_room_button: Button
var date_button: Button
var marry_button: Button
var separate_button: Button
var shared_status_label: Label
var shared_row: HBoxContainer
var shared_meal_option: OptionButton
var host_row: HBoxContainer
var host_meal_option: OptionButton
var host_meal_button: Button
var shared_buttons: Dictionary = {}
var history_view: RichTextLabel
var close_button: Button
var find_button: Button
var event_buttons: Dictionary = {}
var selected_index := 0
var story_open_id := ""
var detail_scroll: ScrollContainer

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
	panel.offset_left = -430
	panel.offset_right = 430
	panel.offset_top = -255
	panel.offset_bottom = 255
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
	title.text = "禾溪邻里手记 · 见过的人与说过的话"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("eee8cb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var book_button:=Button.new();book_button.text="禾溪邻里簿"
	book_button.tooltip_text="行踪、约定与对话记录"
	book_button.pressed.connect(func():get_parent().show_neighbor_book())
	header.add_child(book_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	resident_list = ItemList.new()
	resident_list.custom_minimum_size.x = 190
	resident_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resident_list.item_selected.connect(_on_resident_selected)
	body.add_child(resident_list)
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.follow_focus = true
	body.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(detail)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 12)
	detail.add_child(identity_row)
	portrait_view = Control.new()
	portrait_view.set_script(CHARACTER_PORTRAIT_SCRIPT)
	portrait_view.custom_minimum_size = Vector2(96, 120)
	portrait_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	identity_row.add_child(portrait_view)
	var identity_text := VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	identity_row.add_child(identity_text)
	relation_label = Label.new()
	relation_label.add_theme_font_size_override("font_size", 18)
	relation_label.add_theme_color_override("font_color", Color("ffe2af"))
	identity_text.add_child(relation_label)
	profile_label = Label.new()
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_label.custom_minimum_size.y = 42
	profile_label.add_theme_color_override("font_color", Color("d8e4d6"))
	identity_text.add_child(profile_label)
	find_button = Button.new()
	find_button.text = "去找对方"
	find_button.pressed.connect(_on_find_resident)
	identity_text.add_child(find_button)
	dialogue_meta_label = Label.new()
	dialogue_meta_label.add_theme_color_override("font_color", Color("dfc58f"))
	identity_text.add_child(dialogue_meta_label)
	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size.y = 36
	dialogue_label.add_theme_color_override("font_color", Color("f2e7cc"))
	identity_text.add_child(dialogue_label)
	dialogue_skip_button = Button.new()
	dialogue_skip_button.text = "立即显示全文"
	dialogue_skip_button.visible = false
	dialogue_skip_button.pressed.connect(_finish_dialogue_reveal)
	identity_text.add_child(dialogue_skip_button)
	dialogue_timer = Timer.new()
	dialogue_timer.one_shot = false
	dialogue_timer.timeout.connect(_advance_dialogue_reveal)
	add_child(dialogue_timer)
	var dialogue_topic_row := HBoxContainer.new()
	dialogue_topic_row.add_theme_constant_override("separation", 4)
	identity_text.add_child(dialogue_topic_row)
	for entry in [{"id": "auto", "text": "聊聊此刻"}, {"id": "daily", "text": "说点家常"}, {"id": "advice", "text": "请教窍门"}, {"id": "memory", "text": "说起回忆"}]:
		var button := Button.new()
		button.text = str(entry.text)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_dialogue_topic.bind(str(entry.id)))
		dialogue_topic_row.add_child(button)
		dialogue_topic_buttons[str(entry.id)] = button
	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.custom_minimum_size.y = 42
	event_label.add_theme_color_override("font_color", Color("d9e5c2"))
	detail.add_child(event_label)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail.add_child(action_row)
	for entry in [{"id": "accept", "text": "答应帮忙"}, {"id": "later", "text": "改天再说"}, {"id": "supply", "text": "交材料 ×2"}, {"id": "join", "text": "一起劳动"}]:
		var button := Button.new()
		button.text = str(entry.text)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_event_action.bind(str(entry.id)))
		action_row.add_child(button)
		event_buttons[str(entry.id)] = button
	var gift_row := HBoxContainer.new()
	gift_row.add_theme_constant_override("separation", 8)
	detail.add_child(gift_row)
	gift_item_option = OptionButton.new()
	gift_item_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_row.add_child(gift_item_option)
	gift_button = Button.new()
	gift_button.text = "送上心意"
	gift_button.pressed.connect(_on_gift_pressed)
	gift_row.add_child(gift_button)
	gift_label = Label.new()
	gift_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gift_label.custom_minimum_size.y = 24
	gift_label.add_theme_color_override("font_color", Color("e4d8ad"))
	detail.add_child(gift_label)
	story_label = Label.new()
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size.y = 58
	story_label.add_theme_color_override("font_color", Color("f0dfbb"))
	detail.add_child(story_label)
	story_skip_button = Button.new()
	story_skip_button.text = "立即显示故事全文"
	story_skip_button.visible = false
	story_skip_button.pressed.connect(_finish_story_reveal)
	detail.add_child(story_skip_button)
	story_timer = Timer.new()
	story_timer.one_shot = false
	story_timer.timeout.connect(_advance_story_reveal)
	add_child(story_timer)
	var story_row := HBoxContainer.new()
	story_row.add_theme_constant_override("separation", 8)
	detail.add_child(story_row)
	story_open_button = Button.new()
	story_open_button.text = "打开当前故事"
	story_open_button.pressed.connect(_on_story_open)
	story_row.add_child(story_open_button)
	for choice_index in range(2):
		var choice_button := Button.new()
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(_on_story_choice.bind(choice_index))
		story_row.add_child(choice_button)
		story_choice_buttons.append(choice_button)
	var relationship_row := HBoxContainer.new()
	relationship_row.add_theme_constant_override("separation", 8)
	detail.add_child(relationship_row)
	home_room_button = Button.new()
	home_room_button.pressed.connect(_on_home_room)
	relationship_row.add_child(home_room_button)
	date_button = Button.new()
	date_button.text = "认真表达心意"
	date_button.pressed.connect(_on_date)
	relationship_row.add_child(date_button)
	marry_button = Button.new()
	marry_button.text = "結為伴侶"
	marry_button.pressed.connect(_on_marry)
	relationship_row.add_child(marry_button)
	separate_button = Button.new()
	separate_button.text = "友好分開"
	separate_button.pressed.connect(_on_separate)
	relationship_row.add_child(separate_button)
	shared_row = HBoxContainer.new()
	shared_row.add_theme_constant_override("separation", 6)
	detail.add_child(shared_row)
	shared_status_label = Label.new()
	shared_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(shared_status_label)
	shared_meal_option = OptionButton.new()
	shared_meal_option.custom_minimum_size.x = 120
	shared_row.add_child(shared_meal_option)
	for entry in [{"id": "meal", "text": "共餐"}, {"id": "visit", "text": "探親"}, {"id": "objects", "text": "整理舊物"}, {"id": "plan", "text": "商量來年"}]:
		var button := Button.new()
		button.text = str(entry.text)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_shared_life.bind(str(entry.id)))
		shared_row.add_child(button)
		shared_buttons[str(entry.id)] = button
	host_row = HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 6)
	detail.add_child(host_row)
	host_meal_option = OptionButton.new()
	host_meal_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_row.add_child(host_meal_option)
	host_meal_button = Button.new()
	host_meal_button.text = "請鄰居來家宴"
	host_meal_button.pressed.connect(_on_host_meal)
	host_row.add_child(host_meal_button)
	var history_title := Label.new()
	history_title.text = "交谈记录（最近 160 条）"
	history_title.add_theme_color_override("font_color", Color("eee8cb"))
	detail.add_child(history_title)
	history_view = RichTextLabel.new()
	history_view.bbcode_enabled = false
	history_view.scroll_active = true
	history_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_view.add_theme_color_override("default_color", Color("f4e7c7"))
	detail.add_child(history_view)
	GameState.changed.connect(refresh)
	visible = false
	refresh()

func open_panel(focus_npc_id: String = "") -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	dialogue_source_text = ""
	story_source_text = ""
	refresh(focus_npc_id)
	close_button.grab_focus()

func close() -> void:
	_finish_dialogue_reveal()
	_finish_story_reveal()
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh(focus_npc_id: String = "") -> void:
	if not is_instance_valid(resident_list):
		return
	var selected_id := focus_npc_id
	if selected_id == "" and selected_index >= 0 and selected_index < resident_list.item_count:
		selected_id = str(resident_list.get_item_metadata(selected_index))
	resident_list.clear()
	var target_index := 0
	for index in range(GameState.npc_catalog.size()):
		var person: Dictionary = GameState.npc_catalog[index]
		var npc_id := str(person.get("id", ""))
		var relation: Dictionary = GameState.relations.get(npc_id, {})
		resident_list.add_item("%s  ·  %d" % [str(person.get("name", npc_id)), int(relation.get("points", 0))])
		resident_list.set_item_metadata(index, npc_id)
		if npc_id == selected_id:
			target_index = index
	selected_index = clampi(target_index, 0, maxi(0, resident_list.item_count - 1))
	if resident_list.item_count > 0:
		resident_list.select(selected_index)
		_show_resident(selected_index)

func _on_resident_selected(index: int) -> void:
	selected_index = index
	story_open_id = ""
	_show_resident(index)

func _show_resident(index: int) -> void:
	if index < 0 or index >= GameState.npc_catalog.size():
		return
	var person: Dictionary = GameState.npc_catalog[index]
	var npc_id := str(person.get("id", ""))
	var relation: Dictionary = GameState.relations.get(npc_id, {})
	var points := int(relation.get("points", 0))
	relation_label.text = "%s  ·  关系 %d / 100%s" % [str(person.get("name", npc_id)), points, " · 今日已聊" if int(relation.get("talked", -1)) == GameState.day else ""]
	var records: Array = GameState.npc_history(npc_id)
	var latest: Dictionary = records.back() if not records.is_empty() else {}
	var emotion := str(latest.get("emotion", "calm"))
	portrait_view.call("configure", npc_id, person, emotion)
	var emotion_names := {"calm": "平静", "happy": "笑着说", "focus": "认真说", "thought": "想了想"}
	dialogue_meta_label.text = "%s · %s" % [str(emotion_names.get(emotion, "平静")), str(latest.get("category", "初识"))]
	_set_dialogue_text(str(latest.get("text", person.get("greeting", "你好。"))))
	for button in dialogue_topic_buttons.values():
		(button as Button).disabled = not GameState.npc_is_near(npc_id)
	var profile: Dictionary = GameState.system_catalog.get("npc", {}).get("profiles", {}).get(npc_id, {})
	var location := GameState.npc_location(npc_id)
	profile_label.text = "%s\n性格：%s　心愿：%s\n此刻：%s · %s\n%s" % [str(person.get("role", "村民")), str(profile.get("trait", "")), str(profile.get("goal", "")), str(location.get("place", "")), str(location.get("activity", "")), str(location.get("reason", ""))]
	_show_event(npc_id, profile)
	_show_gifts(npc_id, person)
	_show_story(npc_id)
	_show_relationship_actions(npc_id, person)
	if records.is_empty():
		history_view.text = "还没有交谈记录。走到村民身边按 E，记下今天的话。"
		return
	var lines: PackedStringArray = []
	for record in records:
		var year := int(int(record.get("day", 0)) / 112) + 1
		var date := int(record.get("day", 0)) % 112 + 1
		var season: String = ["春", "夏", "秋", "冬"][int((date - 1) / 28)]
		lines.append("第 %d 年 %s %d 日 %02d:%02d · %s\n%s" % [year, season, (date - 1) % 28 + 1, int(record.get("minute", 390)) / 60, int(record.get("minute", 390)) % 60, str(record.get("category", "日常")), str(record.get("text", ""))])
	history_view.text = "\n\n".join(lines)
	history_view.scroll_to_line(maxi(0, history_view.get_line_count() - 1))

func _set_dialogue_text(text: String) -> void:
	if text == dialogue_source_text:
		if str(GameState.player_settings.get("textSpeed", "instant")) == "instant":
			_finish_dialogue_reveal()
		elif not dialogue_timer.is_stopped():
			dialogue_timer.wait_time = _dialogue_interval()
		return
	dialogue_source_text = text
	dialogue_label.text = text
	dialogue_visible_count = 0
	if not visible or text.is_empty() or str(GameState.player_settings.get("textSpeed", "instant")) == "instant":
		_finish_dialogue_reveal()
		return
	dialogue_label.visible_characters = 0
	dialogue_skip_button.visible = true
	dialogue_timer.wait_time = _dialogue_interval()
	dialogue_timer.start()

func _dialogue_interval() -> float:
	return 0.06 if str(GameState.player_settings.get("textSpeed", "instant")) == "slow" else 0.025

func _advance_dialogue_reveal() -> void:
	dialogue_visible_count += 1
	dialogue_label.visible_characters = dialogue_visible_count
	if dialogue_visible_count >= dialogue_source_text.length():
		_finish_dialogue_reveal()

func _finish_dialogue_reveal() -> void:
	if is_instance_valid(dialogue_timer): dialogue_timer.stop()
	if is_instance_valid(dialogue_label): dialogue_label.visible_characters = -1
	if is_instance_valid(dialogue_skip_button): dialogue_skip_button.visible = false

func _set_story_text(text: String) -> void:
	if text == story_source_text:
		if str(GameState.player_settings.get("textSpeed", "instant")) == "instant":
			_finish_story_reveal()
		elif not story_timer.is_stopped():
			story_timer.wait_time = _dialogue_interval()
		return
	story_source_text = text
	story_label.text = text
	story_visible_count = 0
	if not visible or text.is_empty() or str(GameState.player_settings.get("textSpeed", "instant")) == "instant":
		_finish_story_reveal()
		return
	story_label.visible_characters = 0
	story_skip_button.visible = true
	story_timer.wait_time = _dialogue_interval()
	story_timer.start()

func _advance_story_reveal() -> void:
	story_visible_count += 1
	story_label.visible_characters = story_visible_count
	if story_visible_count >= story_source_text.length():
		_finish_story_reveal()

func _finish_story_reveal() -> void:
	if is_instance_valid(story_timer): story_timer.stop()
	if is_instance_valid(story_label): story_label.visible_characters = -1
	if is_instance_valid(story_skip_button): story_skip_button.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or (dialogue_timer == null or dialogue_timer.is_stopped()) and (story_timer == null or story_timer.is_stopped()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_finish_dialogue_reveal()
		_finish_story_reveal()
		get_viewport().set_input_as_handled()

func _on_find_resident() -> void:
	if selected_index < 0 or selected_index >= resident_list.item_count: return
	GameState.find_npc(str(resident_list.get_item_metadata(selected_index)))

func _on_dialogue_topic(topic: String) -> void:
	if selected_index < 0 or selected_index >= resident_list.item_count:
		return
	var npc_id := str(resident_list.get_item_metadata(selected_index))
	GameState.queue_npc_task(npc_id,"talk",{"topic":topic})

func _show_event(npc_id: String, profile: Dictionary) -> void:
	var resident: Dictionary = GameState.neighbors.get("people", {}).get(npc_id, {})
	var event: Dictionary = resident.get("event", {})
	var pending := not event.is_empty() and str(event.get("status", "")) != "done"
	event_label.visible = pending
	for button in event_buttons.values():
		(button as Button).visible = pending
	if not pending:
		return
	var status := str(event.get("status", "offered"))
	var item_id := str(profile.get("item", ""))
	var item_name := str(GameState.item_catalog.get(item_id, {}).get("name", item_id))
	var available := int(GameState.inventory.get(item_id, 0))
	var near := GameState.npc_is_near(npc_id)
	var state_name := "等你答复" if status == "offered" else "已约好，材料或劳动皆可" if status == "accepted" else "改天再说，随时可回来"
	event_label.text = "邻里小事：%s（%s）。交 %s ×2（持有 %d），或一起劳动 20 分钟 / 3 体力。没有截止日期。%s" % [str(profile.get("request", "")), state_name, item_name, available, "" if near else "走近这位村民后可处理。"]
	var can_offer := status in ["offered", "postponed"] and near
	var can_later := status in ["offered", "accepted"] and near
	var can_complete := status == "accepted" and near
	(event_buttons.accept as Button).disabled = not can_offer
	(event_buttons.later as Button).disabled = not can_later
	(event_buttons.supply as Button).disabled = not can_complete or available < 2
	(event_buttons.join as Button).disabled = not can_complete or GameState.stamina < 3
	(event_buttons.supply as Button).text = "交%s ×2" % item_name

func _on_event_action(operation: String) -> void:
	if selected_index < 0 or selected_index >= resident_list.item_count:
		return
	var npc_id := str(resident_list.get_item_metadata(selected_index))
	var resident: Dictionary = GameState.neighbors.get("people", {}).get(npc_id, {})
	var event: Dictionary = resident.get("event", {})
	if not event.is_empty():
		GameState.queue_npc_task(npc_id,operation,{"day":int(event.get("day",-1))})

func _show_gifts(npc_id: String, person: Dictionary) -> void:
	var previous_id := ""
	if gift_item_option.item_count > 0 and gift_item_option.selected >= 0:
		previous_id = str(gift_item_option.get_item_metadata(gift_item_option.selected))
	gift_item_option.clear()
	var likes: Array = person.get("likes", [])
	var preferred_names: PackedStringArray = []
	for item_id in likes:
		preferred_names.append(str(GameState.item_catalog.get(str(item_id), {}).get("name", str(item_id))))
	var matched_index := -1
	for item_id in GameState.item_catalog:
		var quantity := int(GameState.inventory.get(str(item_id), 0))
		if quantity <= 0:
			continue
		var name := str(GameState.item_catalog[item_id].get("name", item_id))
		var display := "%s ×%d%s" % [name, quantity, "　♥ 喜欢" if likes.has(str(item_id)) else ""]
		gift_item_option.add_item(display)
		var item_index := gift_item_option.item_count - 1
		gift_item_option.set_item_metadata(item_index, str(item_id))
		if str(item_id) == previous_id:
			matched_index = item_index
	if gift_item_option.item_count > 0:
		gift_item_option.select(matched_index if matched_index >= 0 else 0)
	var relation: Dictionary = GameState.relations.get(npc_id, {})
	var sent_today := int(relation.get("gifted", -1)) == GameState.day
	var likes_text := "、".join(preferred_names) if not preferred_names.is_empty() else "还没摸清特别偏好的口味"
	var note := "喜欢：%s。" % likes_text
	if sent_today:
		note += "今天已经收过心意。"
	elif not GameState.npc_is_near(npc_id):
		note += "走近后可送礼。"
	else:
		note += "普通材料 +5，料理 +10，喜欢的礼物 +15；连续送同一物品收益减半。"
	gift_label.text = note
	gift_item_option.disabled = gift_item_option.item_count == 0 or sent_today
	gift_button.disabled = gift_item_option.item_count == 0 or sent_today or not GameState.npc_is_near(npc_id)
	if gift_item_option.item_count == 0:
		gift_item_option.add_item("背包里没有可送出的物品")
		gift_item_option.disabled = true

func _on_gift_pressed() -> void:
	if selected_index < 0 or selected_index >= resident_list.item_count:
		return
	var npc_id := str(resident_list.get_item_metadata(selected_index))
	var item_id := str(gift_item_option.get_item_metadata(gift_item_option.selected)) if gift_item_option.selected >= 0 and gift_item_option.item_count > 0 else ""
	if item_id != "":
		if GameState.action_busy():return
		var starting_day:=GameState.day
		var starting_room:=GameState.current_interior
		var target_position:Vector2=GameState.interior_npc_positions.get(npc_id,GameState.interior_position) if starting_room!="" else GameState.npc_positions.get(npc_id,GameState.player_position)
		var target:Dictionary={"kind":"npc","id":npc_id,"npcId":npc_id,"x":target_position.x,"y":target_position.y}
		var restore:=func():
			if is_instance_valid(self) and GameState.day==starting_day and GameState.current_interior==starting_room:
				open_panel(npc_id)
				for i in range(gift_item_option.item_count):
					if str(gift_item_option.get_item_metadata(i))==item_id:gift_item_option.select(i);break
		var commit:=func():
			if GameState.day!=starting_day or GameState.current_interior!=starting_room:return
			GameState.confirm_operation(GameState.gift_npc(npc_id,item_id))
			restore.call()
		close()
		GameState.cancel_farm_queue()
		GameState.cancel_ranch_queue()
		GameState.kitchen_task.clear()
		GameState.building_task.clear()
		GameState.museum_task.clear()
		GameState.npc_task.clear()
		GameState.walking_target.clear()
		if not GameState.begin_action(GameState.ACTION_RULES.spec("trade",gift_button.text,item_id),target,commit,restore):restore.call()

func _show_story(npc_id: String) -> void:
	var arc: Array = GameState.content.get("arcs", {}).get(npc_id, [])
	var state: Dictionary = GameState.npc_stories.get(npc_id, {})
	var step := int(state.get("step", 0))
	var readiness := GameState.npc_story_readiness(npc_id)
	story_open_button.visible = true
	story_open_button.disabled = false
	for button in story_choice_buttons:button.hide()
	_set_story_text("个人故事 %d / %d\n%s" % [step,arc.size(),str(readiness.get("message",""))])

func _show_relationship_actions(npc_id: String, person: Dictionary) -> void:
	var is_romance := str(person.get("tier", "")) == "romance" and int(person.get("age", 0)) >= 18
	var spouse := str(GameState.marriage.get("spouse", ""))
	var relationship := str(GameState.partners.get(npc_id, ""))
	if relationship == "dating":
		relation_label.text += " · 心意相通"
	if spouse == npc_id:
		relation_label.text += " · 共同生活"
	home_room_button.visible = is_romance and not bool(GameState.upgrades.get("room", false))
	home_room_button.disabled = int(GameState.money) < 220 or not GameState._building_has({"wood":10,"bamboo":4})
	home_room_button.text = "整理厢房 · 220 金 / 木料10 / 竹材4"
	date_button.visible = is_romance and relationship != "dating" and spouse != npc_id and int(GameState.npc_stories.get(npc_id, {}).get("step", 0)) >= 4
	date_button.disabled = false
	marry_button.visible = is_romance and relationship == "dating" and spouse == "" and int(GameState.npc_stories.get(npc_id, {}).get("step", 0)) >= 4
	marry_button.disabled = false
	separate_button.visible = spouse == npc_id
	shared_row.visible = spouse == npc_id
	shared_status_label.visible = spouse == npc_id
	shared_status_label.text = "已留下 %d 次共同生活的记忆。每种安排每周一次，没有每日共餐义务。" % GameState.marriage.get("memories", []).size()
	shared_meal_option.clear()
	for item_id in GameState.item_catalog:
		var item: Dictionary = GameState.item_catalog[item_id]
		if str(item.get("kind", "")) != "料理" or int(GameState.inventory.get(str(item_id), 0)) < 1:
			continue
		shared_meal_option.add_item("%s ×%d" % [str(item.get("name", item_id)), int(GameState.inventory[item_id])])
		var item_index := shared_meal_option.item_count - 1
		shared_meal_option.set_item_metadata(item_index, str(item_id))
	var has_meal := shared_meal_option.item_count > 0
	if not has_meal:
		shared_meal_option.add_item("没有可共餐料理")
	shared_meal_option.disabled = not has_meal
	var weekly: Dictionary = GameState.marriage.get("weekly", {})
	for activity in shared_buttons:
		var key := "%d-%s" % [int(GameState.day / 7), str(activity)]
		(shared_buttons[activity] as Button).disabled = bool(weekly.get(key, false)) or activity == "meal" and not has_meal
	host_row.visible = bool(GameState.upgrades.get("room", false))
	host_meal_option.clear()
	for item_id in GameState.item_catalog:
		var item: Dictionary = GameState.item_catalog[item_id]
		if str(item.get("kind", "")) == "料理" and int(GameState.inventory.get(str(item_id), 0)) > 0:
			host_meal_option.add_item("%s ×%d" % [str(item.get("name", item_id)), int(GameState.inventory[item_id])])
			host_meal_option.set_item_metadata(host_meal_option.item_count - 1, str(item_id))
	if host_meal_option.item_count > 0: host_meal_option.select(0)
	var host_key := "meal-%d-%s" % [int(GameState.day / 7), npc_id]
	host_meal_button.disabled = host_meal_option.item_count == 0 or bool(GameState.season_events.get(host_key, false)) or not GameState.host_meal_location_allowed()
	if bool(GameState.season_events.get(host_key, false)): host_meal_button.text = "本周已邀过"
	elif not GameState.host_meal_location_allowed(): host_meal_button.text = "回农场备家宴"
	else: host_meal_button.text = "请邻居来家宴"

func _on_story_open() -> void:
	var npc_id := _selected_npc_id()
	if npc_id == "": return
	get_parent().show_npc_story(npc_id)

func _on_story_choice(choice: int) -> void:
	var npc_id := _selected_npc_id()
	if npc_id != "":GameState.queue_npc_task(npc_id,"story",{"choice":choice})

func _on_home_room() -> void:
	if GameState.action_busy(): return
	var npc_id := _selected_npc_id()
	if npc_id == "": return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var previous_story := story_open_id
	var scroll_value := detail_scroll.scroll_vertical
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		story_open_id = previous_story
		open_panel(npc_id)
		_restore_room_focus.call_deferred(scroll_value,starting_day,starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		GameState.confirm_operation(GameState.upgrade_home_room())
		restore.call()
	var action := GameState.ACTION_RULES.ui("upgrade",home_room_button.text)
	action.item = "room"
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action,{"kind":"ui","x":position.x,"y":position.y},commit,restore): restore.call()

func _restore_room_focus(scroll_value: int,starting_day: int,starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	if home_room_button.is_visible_in_tree() and not home_room_button.disabled: home_room_button.grab_focus()
	else: close_button.grab_focus()
	detail_scroll.scroll_vertical = scroll_value

func _on_date() -> void:
	var npc_id := _selected_npc_id()
	if npc_id != "":get_parent().begin_relationship_action("e-date",npc_id,self,date_button)

func _on_marry() -> void:
	var npc_id := _selected_npc_id()
	if npc_id == "":return
	get_parent().show_wedding(npc_id)

func _on_separate() -> void:
	if GameState.action_busy() or str(GameState.marriage.get("spouse",""))=="":return
	get_parent().show_separation()

func _on_shared_life(activity: String) -> void:
	var dish_id := ""
	if activity == "meal" and shared_meal_option.item_count > 0 and shared_meal_option.selected >= 0:
		dish_id = str(shared_meal_option.get_item_metadata(shared_meal_option.selected))
	_begin_neighbor_household_action("e-shared",activity,dish_id)

func _on_host_meal() -> void:
	var npc_id := _selected_npc_id()
	if npc_id == "" or host_meal_option.selected < 0: return
	_begin_neighbor_household_action("e-host",npc_id,str(host_meal_option.get_item_metadata(host_meal_option.selected)))

func _neighbor_dish_id(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""

func _select_neighbor_dish(option: OptionButton,item_id: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == item_id:
			option.select(index)
			return

func _begin_neighbor_household_action(action_id: String,item_id: String,dish_id: String) -> void:
	if GameState.action_busy(): return
	var npc_id := _selected_npc_id()
	if npc_id == "": return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var previous_story := story_open_id
	var scroll_value := detail_scroll.scroll_vertical
	var shared_id := _neighbor_dish_id(shared_meal_option)
	var host_id := _neighbor_dish_id(host_meal_option)
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var button: Button = host_meal_button if action_id == "e-host" else shared_buttons.get(item_id)
	if not is_instance_valid(button): return
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		story_open_id = previous_story
		open_panel(npc_id)
		_select_neighbor_dish(shared_meal_option,shared_id)
		_select_neighbor_dish(host_meal_option,host_id)
		_restore_neighbor_household_focus.call_deferred(button,scroll_value,starting_day,starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		if action_id == "e-host": GameState.confirm_operation(GameState.host_meal(item_id,dish_id))
		else: GameState.confirm_operation(GameState.share_life(item_id,dish_id))
		restore.call()
	var action := GameState.ACTION_RULES.ui(action_id,button.text)
	if action_id == "e-shared": action.item = item_id
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action,{"kind":"ui","x":position.x,"y":position.y},commit,restore): restore.call()

func _restore_neighbor_household_focus(button: Button,scroll_value: int,starting_day: int,starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	if button.is_visible_in_tree() and not button.disabled: button.grab_focus()
	else: close_button.grab_focus()
	detail_scroll.scroll_vertical = scroll_value

func _selected_npc_id() -> String:
	if selected_index < 0 or selected_index >= resident_list.item_count:
		return ""
	return str(resident_list.get_item_metadata(selected_index))
