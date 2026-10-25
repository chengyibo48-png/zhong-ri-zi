extends Node
## One event queue owns the three world hints. Moving progress updates at 20 Hz.
var pending := true
var deferred_pending := false
var elapsed := 0.0
var last_modal: Array = []
var refresh_count := 0
func _ready() -> void:
	GameState.changed.connect(invalidate)
	GameState.input_mode_changed.connect(func(_mode: String): invalidate())
	GameState.action_sequence_changed.connect(func(_value: Dictionary): invalidate_motion())
	GameState.player_moved.connect(func(_at: Vector2): invalidate_motion())
	GameState.interior_moved.connect(func(_at: Vector2): invalidate_motion())
	get_viewport().size_changed.connect(invalidate)
	var world := get_parent().get_parent()
	if world.has_signal("interaction_presentation_changed"):
		world.connect("interaction_presentation_changed", invalidate)
	invalidate()
func invalidate() -> void:
	pending = true
	if deferred_pending: return
	deferred_pending = true
	call_deferred("flush")
func invalidate_motion() -> void:
	pending = true
func _process(delta: float) -> void:
	var modal: Array = [GameState.ui_open, GameState.action_busy()]
	if modal != last_modal:
		last_modal = modal
		invalidate()
	elapsed += delta
	if pending and elapsed >= 0.05: flush()
func flush() -> void:
	deferred_pending = false
	if not pending or not is_inside_tree(): return
	pending = false
	elapsed = 0.0
	var hud := get_parent()
	var world := hud.get_parent()
	if not world.has_method("_world_target_candidates") and not world.has_method("_room_points"): return
	for key: String in ["context_actions", "interaction_prompt", "hover_card"]:
		var panel: Variant = hud.get(key)
		if is_instance_valid(panel): panel.refresh_world()
	refresh_count += 1
