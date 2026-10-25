extends Control

const POLICY := preload("res://scripts/performance_policy.gd")
var finger := -1
var motion := Vector2.ZERO
var stick_center := Vector2.ZERO
var rotate_hint: Label
var rotate_shade: ColorRect
var action: Button
var last_blocked := false
var last_busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotate_shade = ColorRect.new()
	rotate_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_shade.color = Color(0.06,0.12,0.10,0.9)
	rotate_shade.set_meta("preserve_ui_color", true)
	rotate_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	rotate_shade.z_index = 999
	add_child(rotate_shade)
	rotate_hint = Label.new()
	rotate_hint.text = "请横屏游玩\n转动手机后继续"
	rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_hint.add_theme_font_size_override("font_size", 30)
	rotate_hint.add_theme_color_override("font_color", Color("#fff4db"))
	rotate_hint.set_meta("preserve_notification_style",true)
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotate_hint.z_index = 1000
	add_child(rotate_hint)
	action = _button("互动", Vector2(-134, -216), _interact)
	_button("背包", Vector2(-254, -134), func(): get_parent().show_market())
	_button("种子", Vector2(-134, -134), get_parent().show_seed_picker)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(title: String, offset: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = offset.x
	button.offset_right = offset.x + 110
	button.offset_top = offset.y
	button.offset_bottom = offset.y + 68
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _layout() -> void:
	var safe := preload("res://scripts/hud_dock.gd").safe_margins(self)
	stick_center = Vector2(maxf(110,78+safe.x), size.y - maxf(200,160+safe.y))
	GameState.mobile_orientation_blocked = get_tree().root.size.x < get_tree().root.size.y
	rotate_hint.visible = GameState.mobile_orientation_blocked
	rotate_shade.visible = GameState.mobile_orientation_blocked
	queue_redraw()

func _process(_delta: float) -> void:
	var blocked := GameState.ui_open or GameState.mobile_orientation_blocked or GameState.fishing_active()
	var busy := GameState.action_busy()
	if blocked: _release()
	if blocked != last_blocked:
		last_blocked = blocked
		for child in get_children():
			if child is Button: child.visible = not blocked
		queue_redraw()
	if busy != last_busy:
		last_busy = busy
		action.text = "停下" if busy else "互动"

func _input(event: InputEvent) -> void:
	if GameState.ui_open or GameState.mobile_orientation_blocked or GameState.fishing_active(): return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and event.position.distance_to(stick_center) < 86:
			finger = event.index
			GameState.cancel_player_action()
			GameState.set_source_input_mode("touch")
			_update_motion(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == finger:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_update_motion(event.position)
		get_viewport().set_input_as_handled()

func _update_motion(point: Vector2) -> void:
	motion = ((point - stick_center) / 64.0).limit_length(1.0)
	GameState.touch_direction = motion if motion.length() > 0.12 else Vector2.ZERO
	queue_redraw()

func _release() -> void:
	if finger == -1 and motion == Vector2.ZERO and GameState.touch_direction == Vector2.ZERO: return
	finger = -1
	queue_redraw()
	motion = Vector2.ZERO
	GameState.touch_direction = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _release()

func _exit_tree() -> void:
	_release()
	GameState.mobile_orientation_blocked = false

func _interact() -> void:
	if GameState.action_busy(): GameState.cancel_player_action()
	else: get_parent().get_parent().call("_interact")

func _draw() -> void:
	if GameState.ui_open or GameState.mobile_orientation_blocked or GameState.fishing_active(): return
	draw_circle(stick_center, 78, Color(0.12, 0.21, 0.17, 0.46))
	draw_arc(stick_center, 78, 0, TAU, 48, Color(0.93, 0.89, 0.72, 0.8), 3, true)
	draw_circle(stick_center + motion * 46, 28, Color(0.90, 0.88, 0.71, 0.8))
