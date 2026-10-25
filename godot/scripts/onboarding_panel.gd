extends Control

signal guide_requested

const STEPS: Array[Dictionary] = [
	{"id": "guide", "title": "翻开生活指南", "hint": "点击生活指南查看按键、种植和村庄生活；指南也可以随时搜索。"},
	{"id": "sow", "title": "播下第一颗种子", "hint": "选 1 开垦空地，再选 2 选种，走到田边按 E 播种。"},
	{"id": "harvest", "title": "收下一份田间收成", "hint": "走近成熟作物，选 4 双手并按 E；收成会进入背包。"},
	{"id": "neighbor", "title": "向一位邻居问好", "hint": "走近村民按 E 交谈。N 邻里手记会记录关系、喜好和故事。"}
]

var expanded := false
var title_label: Label
var progress_label: Label
var hint_label: Label
var guide_button: Button
var hide_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var panel := PanelContainer.new()
	panel.set_meta("compact_hud", true)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_right = 250
	panel.offset_top = -274
	panel.offset_bottom = -108
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.20, 0.17, 0.94)
	style.border_color = Color("c7ad7c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.minimum_size_changed.connect(_fit_hint_card.bind(panel))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("f2e7cc"))
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	hide_button = Button.new()
	hide_button.set_meta("compact_hud", true)
	hide_button.text = "收起"
	hide_button.pressed.connect(_hide)
	header.add_child(hide_button)

	progress_label = Label.new()
	progress_label.add_theme_color_override("font_color", Color("d9c99f"))
	column.add_child(progress_label)
	hint_label = Label.new()
	hint_label.custom_minimum_size.y = 42
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint_label)

	var footer := HBoxContainer.new()
	column.add_child(footer)
	guide_button = Button.new()
	guide_button.set_meta("compact_hud", true)
	guide_button.text = "生活指南"
	guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_button.pressed.connect(_open_guide)
	footer.add_child(guide_button)
	var resume_label := Label.new()
	resume_label.text = "可随时收起"
	resume_label.add_theme_color_override("font_color", Color("d9c99f"))
	resume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(resume_label)

	GameState.changed.connect(refresh)
	refresh()

func _fit_hint_card(panel: PanelContainer) -> void:
	panel.offset_right = panel.offset_left + 232.0 * float(GameState.player_settings.get("textScale",1.0))
	var bottom := -108.0
	var hud := get_parent().get_parent() if get_parent() != null else null
	var status:Variant = hud.get("player_card") if hud != null else null
	if is_instance_valid(status):bottom=minf(bottom,status.get_global_rect().position.y-get_viewport_rect().size.y-12.0)
	panel.offset_bottom = bottom
	panel.offset_top = bottom - maxf(148,panel.get_combined_minimum_size().y)

func open_panel() -> void:
	expanded = true
	GameState.onboarding_show()
	refresh()
	guide_button.grab_focus()

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not is_instance_valid(title_label):
		return
	var state := GameState.onboarding_state()
	var done: Dictionary = state.get("done", {})
	var count := 0
	var next_step: Dictionary = {}
	for step in STEPS:
		if bool(done.get(str(step.id), false)):
			count += 1
		elif next_step.is_empty():
			next_step = step
	title_label.text = "禾溪起步"
	progress_label.text = "新手手记 · %d / %d" % [count, STEPS.size()]
	if next_step.is_empty():
		hint_label.text = preload("res://scripts/life_guidance.gd").suggestion(GameState.day)
	else:
		title_label.text = str(next_step.title)
		hint_label.text = str(next_step.hint)
	visible = expanded and not bool(state.get("hidden", true))

func _open_guide() -> void:
	guide_requested.emit()

func _hide() -> void:
	expanded = false
	GameState.onboarding_hide()

