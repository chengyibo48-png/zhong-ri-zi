extends CharacterBody2D

const MOTION := preload("res://scripts/player_motion.gd")
var walk_source_path: Array=[]
const CHARACTER_SCENE := preload("res://scenes/character_visual.tscn")
var facing := Vector2.DOWN
var camera: Camera2D
var character_visual: Node2D
var walk_path: Array[Vector2] = []
var walk_index := 0
var walk_source := false
var walk_is_exit := false
var walk_chase_at := 0.0

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	facing = GameState.player_direction_vector()
	character_visual = CHARACTER_SCENE.instantiate()
	character_visual.call("configure", "player", {"color": "#648974"})
	character_visual.call("configure_player")
	character_visual.call("set_riding", GameState.riding)
	add_child(character_visual)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	collision.shape = shape
	add_child(collision)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	var indoors := GameState.current_interior != ""
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 960 if indoors else 3840
	camera.limit_bottom = 600 if indoors else 3840
	add_child(camera)
	camera.make_current()
	GameState.changed.connect(_apply_camera_settings)
	GameState.changed.connect(_sync_riding_visual)
	_apply_camera_settings()
	if not GameState.building_task.is_empty() or not GameState.ranch_active_task.is_empty() or not GameState.farm_active_task.is_empty() or not GameState.kitchen_task.is_empty():
		# The old scene's exit target is replaced by the next admitted frame.
		GameState.walking_target.clear()
	elif not GameState.walking_target.is_empty():
		call_deferred("walk_to", GameState.walking_target.duplicate(true))

# The GameState render frame owns production simulation. The physics entry
# remains available when simulation is disabled for isolated movement probes.
func _physics_process(frame_delta: float) -> void:
	if GameState.is_processing():return
	GameState.poll_source_gamepad(float(Time.get_ticks_usec())/1000.0,self)
	GameState.source_frame_time = float(Time.get_ticks_usec())/1000000.0
	var admitted := not GameState.ui_open and not GameState.action_busy() and not GameState.simulation_hidden()
	advance_player_frame(frame_delta)
	if admitted:GameState._advance_frame_time(clampf(frame_delta, 0.0, 0.05))

func pause_player_frame() -> void:
	velocity = Vector2.ZERO
	if is_instance_valid(character_visual):character_visual.call("set_pose", facing, false)

func advance_player_frame(frame_delta: float) -> void:
	var _delta := clampf(frame_delta, 0.0, 0.05)
	if GameState.ui_open or GameState.action_busy() or GameState.simulation_hidden():
		pause_player_frame()
		return
	var previous_position := global_position
	var keyboard:Vector2=GameState.source_keyboard.direction(GameState.player_settings.get("bindings",{}))
	keyboard += GameState.touch_direction
	var direction:Dictionary={"x":float(keyboard.x)+float(GameState.source_gamepad.motion.x),"y":float(keyboard.y)+float(GameState.source_gamepad.motion.y)}
	var automatic:=false
	GameState.advance_navigation_queues(self)
	_recheck_source_target(GameState.source_frame_time)
	if direction.x==0.0 and direction.y==0.0 and not GameState.walking_target.is_empty():
		automatic = true
		_walking_direction(_delta)
		direction={"x":0.0,"y":0.0}
		if not is_inside_tree(): return
	var walking:=_move_source(_delta,float(direction.x),float(direction.y),GameState.source_keyboard.fast(),automatic)
	if automatic and walk_source_path.is_empty() and not GameState.walking_target.is_empty():
		_walking_direction(0.0)
	if not is_inside_tree():return

	if is_instance_valid(character_visual):
		character_visual.call("set_pose", facing, walking)
	if global_position != previous_position:
		if GameState.current_interior != "":
			GameState.interior_moved.emit(global_position)
		else:
			GameState.player_moved.emit(global_position)


func preview_walk(target: Dictionary) -> Dictionary:
	if bool(target.get("source_destination",false)): return _preview_action_walk(target)
	if bool(target.get("world_click",false)): return _preview_click_walk(target)
	if not bool(target.get("fishing_task",false)) and not target.has("npc") and not target.has("farm_task") and not target.has("ranch_task") and not target.has("building_task") and not target.has("kitchen_stage") and not bool(target.get("museum_task",false)) and not bool(target.get("leave_before_find",false)):
		return GameState.atlas_preview(target,GameState.player_navigation_position())

	return _preview_action_walk(target)

func _preview_action_walk(target: Dictionary) -> Dictionary:
	var point:=target.duplicate()
	if str(point.get("ranch_stage",""))=="enter":point.kind="enter"
	var position:Dictionary=GameState.player_navigation_position()
	var indoors:=GameState.current_interior!=""
	var origin:Dictionary=GameState.house_data(GameState.current_interior).door.duplicate() if indoors else position
	var result:Dictionary=GameState.interaction_route(point,origin,"")
	result.local_walk=false
	if indoors:
		var exit:={"x":480.0,"y":590.0,"kind":"exit"}
		for row in get_parent().call("_room_points"):
			if str(row.get("kind",""))=="exit":exit=row;break
		var inside:Dictionary=GameState.interaction_route(exit,position,GameState.current_interior)
		result.room_points=inside.points
		result.roomPath=inside.path
		result.distance=float(result.distance)+float(inside.distance)
		result.reachable=bool(result.reachable) and bool(inside.reachable)
	result.seconds=maxi(1,ceili(float(result.distance)/GameState.player_movement_speed())) if result.reachable else 0
	return result

func _preview_click_walk(target: Dictionary) -> Dictionary:
	if str(target.get("click_room","")) != GameState.current_interior:return {"reachable":false,"points":[],"distance":0.0}
	var point:=target.duplicate()
	if str(point.get("ranch_stage",""))=="enter":point.kind="enter"
	return GameState.interaction_route(point,GameState.player_navigation_position(),GameState.current_interior,bool(target.get("auto_interact",false)))

func _current_navigation_targets() -> Array:
	# Map walk targets are snapshots; the source only chases explicit npc/animal actions.
	if walk_source and str(GameState.walking_target.get("kind","")) not in ["npc","animal"]:return []
	if str(GameState.walking_target.get("kind","")) == "npc" and GameState.walking_target.has("npc"):
		var destination := GameState.npc_destination(str(GameState.walking_target.get("id","")))
		return [] if destination.is_empty() else [destination]
	if bool(GameState.walking_target.get("fishing_task",false)):return [GameState.walking_target]
	if bool(GameState.walking_target.get("museum_task",false)):return [GameState.walking_target]
	if GameState.walking_target.has("ranch_task"):
		var target := GameState.ranch_task_destination(GameState.ranch_active_task)
		return [] if target.is_empty() else [target]
	if GameState.walking_target.has("building_task"): return [GameState.walking_target]
	if GameState.walking_target.has("farm_task"): return [GameState.walking_target]
	if GameState.walking_target.has("kitchen_stage"): return [GameState.walking_target]
	if bool(GameState.walking_target.get("world_click",false)) and get_parent().has_method("resolve_interaction_target"):
		var current: Dictionary = get_parent().call("resolve_interaction_target",GameState.walking_target)
		if current.is_empty(): return []
		current.world_click = true
		current.click_room = GameState.current_interior
		current.auto_interact = true
		return [current]
	return GameState.atlas_targets()


func _matches_navigation_target(current: Dictionary) -> bool:
	if str(GameState.walking_target.get("kind","")) == "npc" and GameState.walking_target.has("npc"): return true
	return str(current.get("id","")) == str(GameState.walking_target.get("id",""))

func walk_to(target: Dictionary) -> bool:
	GameState.npc_task.clear()
	if not bool(target.get("museum_task",false)):GameState.museum_task.clear()
	if not target.has("farm_task"): GameState.cancel_farm_queue()
	if not target.has("ranch_task"): GameState.cancel_ranch_queue()
	if not target.has("kitchen_stage"): GameState.kitchen_task.clear()
	if not target.has("building_task"): GameState.building_task.clear()
	var plan := preview_walk(target)
	if not bool(plan.get("reachable", false)) or bool(plan.get("here", false)):
		GameState.walking_target.clear()
		GameState.message = "已经在这间屋里。" if bool(plan.get("here", false)) else "当前布局无法通行，换一个落点或调整障碍再出发。"
		GameState.changed.emit()
		return false
	GameState.walking_target = target.duplicate(true)
	walk_source=plan.has("path")
	walk_source_path=plan.get("roomPath" if GameState.current_interior!="" and not bool(plan.get("local_walk",false)) else "path",[]).duplicate(true)
	walk_is_exit = GameState.current_interior != "" and not bool(plan.get("local_walk",false))
	walk_path.clear()
	for point in plan.get("room_points" if walk_is_exit else "points", []): walk_path.append(point)
	walk_index = 0
	GameState.message = "先走出小屋，再前往%s。" % str(target.get("name", "目标")) if walk_is_exit else "沿路前往%s，方向键或 Esc 可停下。" % str(target.get("name", "目标"))
	GameState.changed.emit()
	return true

func _walking_direction(_delta: float) -> Vector2:
	if walk_path.is_empty():
		GameState.stop_walking()
		return Vector2.ZERO
	# _move_source consumes at most one original waypoint per frame.
	if walk_index >= walk_path.size():
		var target: Dictionary = GameState.walking_target.duplicate(true)
		walk_path.clear()
		walk_source_path.clear()
		if walk_is_exit:
			var exit_point:Dictionary={"kind":"exit","x":global_position.x,"y":global_position.y}
			GameState.begin_point_action(exit_point,GameState.leave_interior.bind(true))
		else:
			GameState.walking_target.clear()
			if bool(target.get("fishing_task",false)):
				GameState.finish_fishing_task(target)
				return Vector2.ZERO
			if bool(target.get("building_task",false)):
				GameState.finish_building_task(target)
				return Vector2.ZERO
			if bool(target.get("ranch_task",false)):
				GameState.finish_ranch_task(target)
				return Vector2.ZERO
			if bool(target.get("farm_task",false)):
				GameState.finish_farm_task(target)
				return Vector2.ZERO
			if str(target.get("kitchen_stage","")) == "station":
				GameState.finish_kitchen_task(target)
				return Vector2.ZERO
			if bool(target.get("museum_task",false)):
				GameState.finish_museum_task(target)
				return Vector2.ZERO
			if bool(target.get("auto_interact",false)) and get_parent().has_method("_activate_walk_target"):
				get_parent().call("_activate_walk_target",target)
				return Vector2.ZERO
			if str(target.get("kind","")) == "npc" and target.has("npc") and get_parent().has_method("_activate_walk_target"):
				get_parent().call("_activate_walk_target",target)
				return Vector2.ZERO
			var house_id := str(target.get("house", target.get("id", "")))
			if str(target.get("kind", "")) == "enter":
				GameState.begin_point_action(target,GameState.enter_interior.bind(house_id))
				return Vector2.ZERO
			GameState.message = "已到达%s。" % str(target.get("name", "目标"))
			GameState.changed.emit()
		return Vector2.ZERO
	return Vector2.ZERO

func _recheck_source_target(now: float) -> void:
	var pending: Dictionary=GameState.walking_target
	if walk_is_exit or str(pending.get("kind","")) not in ["npc","animal"] or now<=walk_chase_at:return
	walk_chase_at=now+0.7
	var target: Dictionary=GameState.npc_destination(str(pending.get("id",""))) if str(pending.kind)=="npc" else GameState.ranch_actor_destination(str(pending.get("id","")))
	if target.is_empty():return
	if GameState.atlas_source_navigation==null:GameState.atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
	var navigation=GameState.atlas_source_navigation
	navigation.refresh(GameState)
	if navigation.distance(target,pending)<=30.0:return
	walk_source_path=navigation.route(GameState,GameState.current_interior,GameState.player_navigation_position(),{"x":float(target.x),"y":float(target.y)+5.0})
	walk_path.clear()
	for point in walk_source_path:walk_path.append(Vector2(float(point.x),float(point.y)))
	walk_index=0
	GameState.walking_target=target.duplicate(true)

func _move_source(delta: float, input_x: float, input_y: float, fast: bool, automatic: bool) -> bool:
	if GameState.atlas_source_navigation==null:GameState.atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
	var navigation=GameState.atlas_source_navigation
	navigation.refresh(GameState)
	var p: Dictionary=GameState.player_navigation_position()
	if global_position!=Vector2(float(p.x),float(p.y)):
		p.x=float(global_position.x)
		p.y=float(global_position.y)
	var path: Array=walk_source_path if automatic else []
	var count:=path.size()
	var result: Dictionary=MOTION.step(navigation,GameState,GameState.current_interior,p,path,input_x,input_y,GameState.player_movement_rate(fast),delta)
	walk_index+=count-path.size()
	GameState.set_player_navigation_position(p)
	global_position=Vector2(float(p.x),float(p.y))
	facing=GameState.player_direction_vector()
	velocity=Vector2.ZERO
	return bool(result.walking)

func _sync_riding_visual() -> void:
	if is_instance_valid(character_visual): character_visual.call("set_riding", GameState.riding and GameState.current_interior == "")

func _apply_camera_settings() -> void:
	if not is_instance_valid(camera): return
	var zoom := float(GameState.player_settings.get("zoom", 1.0))
	# Keep the saved distance preference; the authored scene now has a closer baseline.
	var baseline := 1.12 if GameState.current_interior != "" else 1.35
	camera.zoom = Vector2.ONE * zoom * baseline

