extends Control
class_name SettingsPanel

signal fullscreen_requested

var fullscreen_button: Button
var reset_bindings_button: Button

const CHARACTER_SCENE := preload("res://scenes/character_visual.tscn")

var controls: VBoxContainer
var binding_buttons: Dictionary = {}
var speed_option: OptionButton
var zoom_option: OptionButton
var performance_option: OptionButton
var volume_slider: HSlider
var audio_sliders: Dictionary = {}
var text_scale_option: OptionButton
var text_speed_option: OptionButton
var ui_theme_option: OptionButton
var ui_seasonal_toggle: CheckButton
var appearance_options: Dictionary = {}
var appearance_toggles: Dictionary = {}
var player_name_edit: LineEdit
var gender_option: OptionButton
var toggles: Dictionary = {}
var visual_options: Dictionary = {}
var visual_toggles: Dictionary = {}
var capturing := ""
var appearance_apply_button: Button
var appearance_dirty := false
var appearance_syncing := false
var content_scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.07, 0.05, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -345
	panel.offset_right = 345
	panel.offset_top = -275
	panel.offset_bottom = 275
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303a30")
	style.border_color = Color("c5b184")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "生活设置"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	content_scroll = ScrollContainer.new()
	var scroll := content_scroll
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 7)
	scroll.add_child(controls)
	fullscreen_button = Button.new()
	fullscreen_button.text = "进入全屏"
	fullscreen_button.pressed.connect(func(): fullscreen_requested.emit(); refresh())
	controls.add_child(fullscreen_button)
	_add_option("时间速度", "speed", [["relaxed", "舒缓 · 约 15 分钟一天"], ["normal", "常规 · 约 10 分钟一天"]])
	_add_option("镜头距离", "zoom", [[1.0, "标准近景"], [1.2, "再近一些 · 120%"], [1.4, "细节近景 · 140%"]])
	_add_option("画面模式", "performance", [["auto", "自动"], ["light", "省电 · 30 帧"]])
	_add_option("字号", "textScale", [[1.0, "标准"], [1.15, "较大"], [1.3, "大字"]])
	_add_option("对话文字速度", "textSpeed", [["instant", "立即显示"], ["normal", "逐字 · 常规"], ["slow", "逐字 · 舒缓"]])
	_add_visual_option("交互特效", "density", [["standard", "标准"], ["quiet", "轻量"], ["off", "关闭粒子"]])
	_add_visual_option("雨雪表现", "weather", [["standard", "标准"], ["gentle", "轻柔"]])
	_add_visual_toggle("ambient", "乡间环境动效")
	_add_visual_toggle("motion", "减少动画与闪光")
	_add_toggle("hints", "显示操作提示")
	_add_toggle("sound", "开启声音")
	_add_toggle("gamepad", "接受手柄输入")
	_add_toggle("vibration", "手柄轻震动")
	_add_toggle("contrast", "提高文字对比度")
	_add_toggle("fishAssist", "钓鱼轻松辅助（下一竿生效）")
	var volume_row := HBoxContainer.new()
	controls.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = "总音量"
	volume_label.custom_minimum_size.x = 142
	volume_row.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_set_volume)
	volume_row.add_child(volume_slider)
	for row in [["music", "四季琴音"], ["ambient", "环境声"], ["effects", "交互音效"]]:
		_add_audio_slider(str(row[0]), str(row[1]))
	_add_ui_art_controls()
	_add_appearance_controls()
	var key_header := Label.new()
	key_header.text = "自定义按键 · 点选后按一个字母键；C、F、H、Q 保留为固定功能键"
	key_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(key_header)
	for pair in [["up", "上移"], ["left", "左移"], ["down", "下移"], ["right", "右移"], ["interact", "交互"], ["bag", "背包"], ["map", "地图"], ["journal", "生活日记"]]:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_begin_capture.bind(str(pair[0])))
		binding_buttons[str(pair[0])] = button
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(pair[1])
		label.custom_minimum_size.x = 142
		row.add_child(label)
		row.add_child(button)
		controls.add_child(row)
	reset_bindings_button = Button.new()
	reset_bindings_button.text = "恢复默认按键"
	reset_bindings_button.pressed.connect(_reset_bindings)
	controls.add_child(reset_bindings_button)
	var footer := Label.new()
	footer.text = "设置会随自动存档保存。移动仍可使用方向键；手柄可用左摇杆和十字键。"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer)
	GameState.changed.connect(refresh)
	_apply_audio()
	visible = false

func _add_option(title: String, key: String, choices: Array) -> void:
	var row := HBoxContainer.new()
	controls.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 142
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice in choices:
		option.add_item(str(choice[1]))
		option.set_item_metadata(option.item_count - 1, choice[0])
	option.item_selected.connect(_choose_option.bind(key, option))
	row.add_child(option)
	if key == "speed": speed_option = option
	if key == "zoom": zoom_option = option
	if key == "performance": performance_option = option
	if key == "textScale": text_scale_option = option
	if key == "textSpeed": text_speed_option = option

func _add_toggle(key: String, title: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.toggled.connect(_set_toggle.bind(key))
	controls.add_child(toggle)
	toggles[key] = toggle

func _add_visual_option(title: String, key: String, choices: Array) -> void:
	var row := HBoxContainer.new()
	controls.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 142
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice in choices:
		option.add_item(str(choice[1]))
		option.set_item_metadata(option.item_count - 1, choice[0])
	option.item_selected.connect(_choose_visual_option.bind(key, option))
	row.add_child(option)
	visual_options[key] = option

func _add_visual_toggle(key: String, title: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.toggled.connect(_set_visual_toggle.bind(key))
	controls.add_child(toggle)
	visual_toggles[key] = toggle

func open_panel() -> void:
	if GameState.action_busy() and not GameState.fishing_active():return
	if GameState.fishing_active():GameState.fishing_input("clear")
	preload("res://scripts/modal_status.gd").clear_message(self)
	appearance_dirty = false
	visible = true
	GameState.ui_open = true
	capturing = ""
	refresh()
	fullscreen_button.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false
	capturing = ""

func is_open() -> bool:
	return visible

func capture_active() -> bool:
	return visible and capturing != ""

func capture_event_key(event: InputEventKey) -> bool:
	if not capture_active():return false
	if event.keycode==KEY_ESCAPE:return capture_key(KEY_ESCAPE)
	var key:String=GameState.source_keyboard.key_name(event)
	# Match the source bindingKeyAllowed on the actual event key, not a layout's
	# physical Latin slot. Invalid input keeps the capture active.
	if key.length()!=1 or key.unicode_at(0)<97 or key.unicode_at(0)>122:return true
	return capture_key(key.to_upper().unicode_at(0))

func capture_key(keycode: int) -> bool:
	if not capture_active(): return false
	if keycode == KEY_ESCAPE:
		capturing = ""
		refresh()
		return true
	if keycode < KEY_A or keycode > KEY_Z or keycode in [KEY_C, KEY_F, KEY_H, KEY_Q]:
		return true
	var bindings: Dictionary = GameState.player_settings.get("bindings", {}).duplicate(true)
	var old := str(bindings.get(capturing, "e"))
	var value := char(keycode).to_lower()
	for action in bindings:
		if str(action) != capturing and str(bindings[action]) == value:
			bindings[action] = old
	bindings[capturing] = value
	GameState.player_settings.bindings = bindings
	GameState.message = "按键已更新：%s。" % value.to_upper()
	capturing = ""
	GameState.changed.emit()
	refresh()
	return true

func _reset_bindings() -> void:
	GameState.player_settings.bindings = GameState.initial_state.get("settings", {}).get("bindings", {}).duplicate(true)
	capturing = ""
	GameState.message = "常用快捷键已恢复为初始设置。"
	GameState.changed.emit()

func refresh() -> void:
	if not visible: return
	fullscreen_button.text = "退出全屏" if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else "进入全屏"
	var settings: Dictionary = GameState.player_settings
	speed_option.select(_option_index(speed_option, settings.get("speed", "relaxed")))
	zoom_option.select(_option_index(zoom_option, float(settings.get("zoom", 1.0))))
	performance_option.select(_option_index(performance_option, settings.get("performance", "auto")))
	text_scale_option.select(_option_index(text_scale_option, float(settings.get("textScale", 1.0))))
	text_speed_option.select(_option_index(text_speed_option, settings.get("textSpeed", "instant")))
	for key in visual_options:
		visual_options[key].select(_option_index(visual_options[key], GameState.visual_fx.get(key, "standard")))
	visual_toggles["ambient"].button_pressed = bool(GameState.visual_fx.get("ambient", true))
	visual_toggles["motion"].button_pressed = str(GameState.visual_fx.get("motion", "full")) == "reduced"
	volume_slider.set_value_no_signal(float(settings.get("volume", 0.2)))
	var audio_defaults := {"music": 0.35, "ambient": 0.3, "effects": 0.6}
	for key in audio_sliders:
		audio_sliders[key].set_value_no_signal(float(settings.get(key, audio_defaults[key])))
	ui_theme_option.select(_option_index(ui_theme_option, GameState.ui_art.get("theme", "paper")))
	ui_seasonal_toggle.set_pressed_no_signal(bool(GameState.ui_art.get("seasonal", true)))
	if not appearance_dirty:
		appearance_syncing = true
		player_name_edit.text = GameState.player_name
		gender_option.select(_option_index(gender_option, GameState.player_gender))
		for key in appearance_options:
			appearance_options[key].select(_option_index(appearance_options[key], GameState.appearance.get(key, 0 if key != "outfit" else "field")))
		for key in appearance_toggles:
			appearance_toggles[key].set_pressed_no_signal(bool(GameState.appearance.get(key, false)))
		appearance_syncing = false
	for key in toggles:
		toggles[key].button_pressed = bool(settings.get(key, true))
	for action in binding_buttons:
		var binding := str(settings.get("bindings", {}).get(action, "?" )).to_upper()
		binding_buttons[action].text = "按下新按键…" if capturing == action else binding

func _option_index(option: OptionButton, value: Variant) -> int:
	for index in range(option.item_count):
		if option.get_item_metadata(index) == value: return index
	return 0

func _choose_option(index: int, key: String, option: OptionButton) -> void:
	if index < 0: return
	GameState.player_settings[key] = option.get_item_metadata(index)
	if key == "performance": preload("res://scripts/performance_policy.gd").configure(get_tree().root)
	_apply_audio()
	GameState.changed.emit()

func _choose_visual_option(index: int, key: String, option: OptionButton) -> void:
	if index < 0: return
	GameState.visual_fx[key] = option.get_item_metadata(index)
	GameState.changed.emit()

func _set_visual_toggle(enabled: bool, key: String) -> void:
	if key == "motion":
		GameState.feedback_set_preference("motion", "reduced" if enabled else "full")
		return
	GameState.visual_fx[key] = enabled
	GameState.changed.emit()

func _set_toggle(enabled: bool, key: String) -> void:
	GameState.player_settings[key] = enabled
	if key=="fishAssist":GameState.fishing.mode="relaxed" if enabled else "standard"
	_apply_audio()
	GameState.changed.emit()
	if key == "sound" and enabled: GameState.sound_requested.emit("action")

func _set_volume(value: float) -> void:
	GameState.player_settings.volume = value
	_apply_audio()
	GameState.changed.emit()
	GameState.sound_requested.emit("action")

func _add_audio_slider(key: String, title: String) -> void:
	var row := HBoxContainer.new()
	controls.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 142
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_set_audio_channel.bind(key))
	row.add_child(slider)
	audio_sliders[key] = slider

func _add_ui_art_controls() -> void:
	var theme_row := HBoxContainer.new()
	controls.add_child(theme_row)
	var label := Label.new()
	label.text = "手账配色"
	label.custom_minimum_size.x = 142
	theme_row.add_child(label)
	ui_theme_option = OptionButton.new()
	ui_theme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice in [["paper", "竹纸手账"], ["porcelain", "青瓷小笺"], ["timber", "原木账簿"]]:
		ui_theme_option.add_item(str(choice[1]))
		ui_theme_option.set_item_metadata(ui_theme_option.item_count - 1, choice[0])
	ui_theme_option.item_selected.connect(_set_ui_theme.bind(ui_theme_option))
	theme_row.add_child(ui_theme_option)
	ui_seasonal_toggle = CheckButton.new()
	ui_seasonal_toggle.text = "显示四季边饰"
	ui_seasonal_toggle.toggled.connect(_set_ui_seasonal)
	controls.add_child(ui_seasonal_toggle)

func _set_ui_theme(index: int, option: OptionButton) -> void:
	if index >= 0: GameState.ui_art_set_preference("theme", option.get_item_metadata(index))

func _set_ui_seasonal(enabled: bool) -> void:
	GameState.ui_art_set_preference("seasonal", enabled)

func _add_appearance_controls() -> void:
	var heading := Label.new()
	heading.text = "还是你 · 外观随存档保存，可随时换回"
	heading.add_theme_color_override("font_color", Color("d9c99f"))
	controls.add_child(heading)
	var identity_row := HBoxContainer.new()
	controls.add_child(identity_row)
	var name_label := Label.new()
	name_label.text = "姓名"
	name_label.custom_minimum_size.x = 142
	identity_row.add_child(name_label)
	player_name_edit = LineEdit.new()
	player_name_edit.max_length = 12
	player_name_edit.text = GameState.player_name
	player_name_edit.placeholder_text = "给自己取个名字"
	player_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_edit.text_changed.connect(_set_player_name)
	identity_row.add_child(player_name_edit)
	_add_appearance_option("称呼", "gender", [["不设定", "不设定"], ["女", "女"], ["男", "男"]], GameState.player_gender)
	gender_option = appearance_options.get("gender")
	appearance_options.erase("gender")
	var preview_row := HBoxContainer.new()
	controls.add_child(preview_row)
	var preview_label := Label.new()
	preview_label.text = "衣着与发型预览"
	preview_label.custom_minimum_size.x = 142
	preview_row.add_child(preview_label)
	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(96, 82)
	preview_container.stretch = true
	preview_row.add_child(preview_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 82)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(viewport)
	var preview := CHARACTER_SCENE.instantiate()
	viewport.add_child(preview)
	preview.position = Vector2(48, 76)
	preview.scale = Vector2(1.35, 1.35)
	preview.call("configure", "player", {"color": "#648974"})
	preview.call("configure_player")
	_add_appearance_option("上衣颜色", "shirt", [[0, "青绿"], [1, "靛蓝"], [2, "陶红"], [3, "米黄"]], GameState.appearance.get("shirt", 0))
	_add_appearance_option("发型", "hair", [[0, "短发"], [1, "齐肩"], [2, "束发"], [3, "卷发"]], GameState.appearance.get("hair", 0))
	_add_appearance_option("肤色", "skin", [[0, "暖浅"], [1, "小麦"], [2, "暖棕"]], GameState.appearance.get("skin", 0))
	_add_appearance_option("发色", "hairColor", [[0, "墨黑"], [1, "栗棕"], [2, "茶褐"], [3, "银灰"]], GameState.appearance.get("hairColor", 0))
	_add_appearance_option("服装", "outfit", [["field", "盘扣便衣"], ["apron", "田间围裙"], ["traveler", "行路马甲"], ["festival", "节庆绣衣"]], GameState.appearance.get("outfit", "field"))
	for pair in [["hat", "戴草帽"], ["bag", "背帆布挎包"], ["weatherDress", "自动搭配雨披与冬围巾"]]:
		var toggle := CheckButton.new()
		toggle.text = str(pair[1])
		toggle.toggled.connect(_set_appearance_toggle.bind(str(pair[0])))
		controls.add_child(toggle)
		appearance_toggles[str(pair[0])] = toggle
	appearance_apply_button = Button.new()
	appearance_apply_button.text = "换好衣服"
	appearance_apply_button.pressed.connect(_apply_appearance)
	controls.add_child(appearance_apply_button)

func _add_appearance_option(title: String, key: String, choices: Array, selected: Variant) -> void:
	var row := HBoxContainer.new()
	controls.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 142
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice in choices:
		option.add_item(str(choice[1]))
		option.set_item_metadata(option.item_count - 1, choice[0])
	option.select(_option_index(option, selected))
	option.item_selected.connect(_set_appearance_option.bind(key, option))
	row.add_child(option)
	appearance_options[key] = option

func _set_appearance_option(index: int, _key: String, _option: OptionButton) -> void:
	if index >= 0 and not appearance_syncing: appearance_dirty = true

func _set_appearance_toggle(_enabled: bool, _key: String) -> void:
	if not appearance_syncing: appearance_dirty = true

func _set_player_name(_value: String) -> void:
	if not appearance_syncing: appearance_dirty = true

func _appearance_form() -> Dictionary:
	var form := {"name": player_name_edit.text, "gender": gender_option.get_item_metadata(gender_option.selected)}
	for key in appearance_options:
		var option: OptionButton = appearance_options[key]
		form[key] = option.get_item_metadata(option.selected)
	for key in appearance_toggles: form[key] = appearance_toggles[key].button_pressed
	return form

func _restore_appearance_form(form: Dictionary) -> void:
	appearance_syncing = true
	player_name_edit.text = str(form.name)
	gender_option.select(_option_index(gender_option, form.gender))
	for key in appearance_options: appearance_options[key].select(_option_index(appearance_options[key], form[key]))
	for key in appearance_toggles: appearance_toggles[key].set_pressed_no_signal(bool(form[key]))
	appearance_syncing = false
	appearance_dirty = true

func _apply_appearance() -> void:
	if GameState.action_busy(): return
	var form := _appearance_form()
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var scroll_value := content_scroll.scroll_vertical
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		_restore_appearance_form(form)
		refresh()
		_restore_appearance_focus.call_deferred(scroll_value, starting_day, starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		if GameState.apply_player_appearance(form): GameState.save_game(GameState.SAVE_PATH, true)
		restore.call()
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	var action := GameState.ACTION_RULES.ui("e-appearance", "换好衣服")
	if not GameState.begin_action(action, {"kind": "ui", "x": position.x, "y": position.y}, commit, restore): restore.call()

func _restore_appearance_focus(scroll_value: int, starting_day: int, starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	appearance_apply_button.grab_focus()
	content_scroll.scroll_vertical = scroll_value

func _begin_capture(action: String) -> void:
	capturing = action
	refresh()

func _set_audio_channel(value: float, key: String) -> void:
	GameState.player_settings[key] = value
	_apply_audio()
	GameState.changed.emit()

func _apply_audio() -> void:
	AudioService.apply_settings()
