extends Control
class_name KitchenHeatPanel

var task: Dictionary = {}
var started_usec := 0
var reading: Label
var dish_label: Label
var fire_bar: Control
var good_zone: ColorRect
var needle: ColorRect
var finish_button: Button
var assist_button: Button
var cancel_button: Button
var result_label: Label

static func heat_at(seconds: float) -> float:
	return (sin(seconds / 1.1 - PI / 2.0) + 1.0) * 50.0

static func heat_text(value: float) -> String:
	return "小火 · 再等等" if value < 35 else "火候正好 · 可以起锅" if value <= 75 else "大火 · 等它回落"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.08,0.12,0.09,0.88)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 620
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("354333")
	style.border_color = Color("c7ad7c")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	dish_label = _label("",18)
	column.add_child(dish_label)
	column.add_child(_label("听见锅里滋啦一声",26))
	column.add_child(_label("把指针留在绿色区域，按「起锅」。\n错过也会做成可口家常饭。",17))
	fire_bar = Control.new()
	fire_bar.custom_minimum_size = Vector2(570,42)
	column.add_child(fire_bar)
	var track := ColorRect.new()
	track.set_meta("preserve_ui_color",true)
	track.color = Color("9b7750")
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_bar.add_child(track)
	good_zone = ColorRect.new()
	good_zone.anchor_left = 0.35
	good_zone.anchor_right = 0.75
	good_zone.anchor_bottom = 1
	good_zone.set_meta("preserve_ui_color",true)
	good_zone.color = Color("6d9a67")
	good_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_bar.add_child(good_zone)
	needle = ColorRect.new()
	needle.set_meta("preserve_ui_color",true)
	needle.color = Color("fff1be")
	needle.size = Vector2(4,50)
	needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_bar.add_child(needle)
	reading = _label("",18)
	column.add_child(reading)
	result_label = _label("",16)
	result_label.modulate = Color("f0c186")
	column.add_child(result_label)
	var actions := VBoxContainer.new()
	column.add_child(actions)
	finish_button = _button("起锅",func(): finish(false))
	assist_button = _button("省心火候 · 稳定快做",func(): finish(true))
	cancel_button = _button("取消 · 保留食材",close)
	for button in [finish_button,assist_button,cancel_button]: actions.add_child(button)
	column.add_child(_label("随时关闭不扣食材。Enter 起锅，Esc 取消。",14))
	visible = false

func _label(text: String,font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _button(text: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	return button

func open_panel(pending: Dictionary) -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	task = pending.duplicate(true)
	started_usec = Time.get_ticks_usec()
	dish_label.text = "柴火噼啪 · " + str(GameState.item_catalog.get(str(task.get("id","")),{}).get("name",task.get("id","")))
	result_label.text = ""
	visible = true
	GameState.ui_open = true
	_refresh_heat(0.0)
	finish_button.grab_focus()

func _process(_delta: float) -> void:
	if visible: _refresh_heat(float(Time.get_ticks_usec()-started_usec)/1000000.0)

func _refresh_heat(seconds: float) -> void:
	var value := heat_at(seconds)
	needle.position = Vector2((fire_bar.size.x - 4.0) * value / 100.0,-4)
	reading.text = heat_text(value)

func finish(assist: bool = false) -> bool:
	if not visible or task.is_empty(): return false
	var value := -1.0 if assist else heat_at(float(Time.get_ticks_usec()-started_usec)/1000000.0)
	var ok: bool = GameState.confirm_operation(GameState.cook_recipe(str(task.id),int(task.get("n",1)),value,false))
	if ok: close()
	else: result_label.text = GameState.message
	return ok

func close() -> void:
	task.clear()
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible
