extends Node2D

const CHARACTER_SCENE := preload("res://scenes/character_visual.tscn")

var npc_id := ""
var _last_presentation: Array = []
var npc_data: Dictionary = {}
var npc_index := 0
var home_target := Vector2.ZERO
var work_target := Vector2.ZERO
var schedule_key := ""
var schedule_label := ""
var schedule_reason := ""
var indoor_activity := false
var scheduled_working := false
var walk_speed := 92.0
var facing := Vector2.DOWN
var path: Array[Vector2] = []
var character_visual: Node2D

func _ready() -> void:
	add_to_group("resident_visual_actor")
	character_visual = CHARACTER_SCENE.instantiate()
	character_visual.call("configure", npc_id, npc_data)
	add_child(character_visual)

func set_schedule(plan: Dictionary, route: Array[Vector2]) -> void:
	schedule_key = str(plan.get("key", ""))
	schedule_label = str(plan.get("label", ""))
	schedule_reason = str(plan.get("reason", ""))
	indoor_activity = bool(plan.get("indoors", false))
	scheduled_working = bool(plan.get("working", schedule_key == "work"))
	path = route.duplicate()
	var tier := str(npc_data.get("tier", ""))
	var age := int(npc_data.get("age", 30))
	walk_speed = 103.0 if tier == "child" else 64.0 if age > 60 else 92.0
	if is_instance_valid(character_visual): character_visual.call("set_working", false)
	queue_redraw()

func advance(delta: float, player_position: Vector2, paused: bool) -> void:
	if paused:
		if is_instance_valid(character_visual):
			character_visual.call("set_pose", facing, false)
			character_visual.call("set_working", false)
		return
	if global_position.distance_squared_to(player_position) < 58.0 * 58.0:
		if is_instance_valid(character_visual):
			character_visual.call("set_pose", facing, false)
			character_visual.call("set_working", false)
		return
	var budget := walk_speed * delta
	var moved := false
	while not path.is_empty() and budget > 0.0:
		var offset := path[0] - global_position
		var distance := offset.length()
		if distance <= 0.75:
			global_position = path.pop_front()
			continue
		facing = Vector2.RIGHT if absf(offset.x) > absf(offset.y) and offset.x > 0.0 else Vector2.LEFT if absf(offset.x) > absf(offset.y) else Vector2.DOWN if offset.y > 0.0 else Vector2.UP
		var step := minf(distance, budget)
		global_position += offset / distance * step
		budget -= step
		moved = true
	if is_instance_valid(character_visual):
		character_visual.call("set_pose", facing, moved)
		character_visual.call("set_working", scheduled_working and path.is_empty() and not moved)
	if moved: queue_redraw()

func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-36, 31), str(npc_data.get("name", npc_id)), HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color("fff2d4"))
	if schedule_label != "":
		draw_string(ThemeDB.fallback_font, Vector2(-54, -46), schedule_label.substr(0, 9), HORIZONTAL_ALIGNMENT_CENTER, 108, 9, Color("f5dfa8"))

func present_resident(state: Node, room: String = "") -> void:
	var p: Dictionary = state.npc_residents.get(npc_id, {})
	var actual_room := str(p.room) if p.get("room") != null else ""
	visible = not p.is_empty() and actual_room == room
	if not visible: return
	var runtime: Dictionary = state.npc_movement.actors.get(npc_id, {}) if state.npc_movement != null else {}
	var at: Dictionary = p if room == "" else runtime.get("inside", {})
	if at.is_empty(): at = {"x":565.0,"y":430.0,"direction":"left"}
	global_position = Vector2(float(at.x), float(at.y))
	var on_screen := preload("res://scripts/life_presentation.gd").visible_rect(self,96.0).has_point(global_position)
	if is_instance_valid(character_visual): character_visual.visible = on_screen
	if not on_screen: return
	var signature := [global_position,at.get("direction"),runtime.get("walking",false),runtime.get("activity"),runtime.get("plan",{}),state.ui_open]
	if signature == _last_presentation: return
	_last_presentation = signature.duplicate(true)
	var plan: Dictionary = runtime.get("plan", {})
	if plan.is_empty(): plan = state.npc_dialogue_activity(npc_data)
	schedule_key = str(plan.get("key", ""))
	schedule_label = str(runtime.get("activity", plan.get("label", "")))
	schedule_reason = str(plan.get("reason", ""))
	indoor_activity = actual_room != ""
	facing = {"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN}.get(str(at.get("direction","down")),Vector2.DOWN)
	if is_instance_valid(character_visual):
		character_visual.call("set_pose", facing, bool(runtime.get("walking", false)) and not state.ui_open)
		character_visual.call("set_working", not bool(runtime.get("walking", false)) and str(plan.get("key", "")) == "work" and not state.ui_open)
	queue_redraw()

func sync_action_visual(snapshot: Dictionary) -> void:
	if not is_instance_valid(character_visual): return
	var matched: Dictionary = {}
	if visible and str(snapshot.get("npcId", "")) == npc_id:
		var clip := str(snapshot.get("kind", ""))
		if preload("res://scripts/character_art.gd").has_clip(npc_id, clip):
			matched = snapshot
	character_visual.call("set_sequence_snapshot", matched)
