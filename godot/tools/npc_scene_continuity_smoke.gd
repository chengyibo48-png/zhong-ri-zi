extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL "+label)

func freeze(scene: Node) -> void:
	scene.set_process(false)
	if scene.get("player") != null: scene.player.set_physics_process(false)

func _run() -> void:
	var state = root.get_node("GameState")
	state.set_process(false)
	state.ui_open = true
	state.current_interior = ""
	state.day = 1; state.minutes = 600.0
	var room := "home-granny"
	var home: Dictionary = state.house_data(room)
	# One resident inside and one at a distinctive outdoor coordinate.
	state.npc_residents.granny = {"x":float(home.door.x),"y":float(home.door.y),"direction":"down","room":room}
	state.npc_residents.qiao = {"x":2831.25,"y":1652.5,"direction":"left","room":null}
	state.npc_movement.actors.granny = {"inside":{"x":490.0,"y":550.0,"direction":"right"},"walking":false}
	state.npc_movement.publish(state)
	var exact: Dictionary = state.npc_residents.duplicate(true)
	var runtime_inside: Dictionary = state.npc_movement.actors.granny.inside.duplicate(true)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	freeze(world)
	await process_frame
	var qiao_actor: Node2D
	var granny_actor: Node2D
	for npc in world.npc_nodes:
		npc.present_resident(state)
		if str(npc.npc_id)=="qiao": qiao_actor=npc
		if str(npc.npc_id)=="granny": granny_actor=npc
	check(qiao_actor.visible and qiao_actor.global_position==Vector2(2831.25,1652.5),"outdoor scene uses current saved position")
	check(not granny_actor.visible,"resident inside not duplicated outdoors")
	state.npc_movement.actors.qiao = {"walking":true}
	qiao_actor.present_resident(state)
	check(not qiao_actor.character_visual.walking,"UI pause holds walking animation without mutating runtime")
	check(bool(state.npc_movement.actors.qiao.walking),"paused presentation preserves movement runtime")
	state.player_position = Vector2(home.door.x,home.door.y)
	check(state.enter_interior(room),"real scene entry")
	await process_frame
	await process_frame
	var interior = current_scene
	check(interior != null and interior.get_script()==load("res://scripts/interior_world.gd"),"actual scene switched to interior")
	freeze(interior)
	interior._sync_room_residents()
	interior._publish_npc_positions()
	check(interior.owner_npc != null,"actual resident present in home")
	check(interior.owner_npc.global_position==Vector2(490,550),"indoor runtime position carried across scene switch")
	check(not interior.resident_nodes.has("qiao"),"outdoor resident excluded from indoor actors")
	check(state.npc_residents==exact,"scene entry preserves all authoritative resident states")
	check(state.npc_movement.actors.granny.inside==runtime_inside,"scene entry preserves inside runtime")
	var raw: Dictionary=state._make_save_data().duplicate(true)
	check(raw.npc_residents==exact,"resident states included in save during interior visit")
	state.leave_interior()
	await process_frame
	await process_frame
	world=current_scene
	check(world != null and world.get_script()==load("res://scripts/farm_world.gd"),"actual scene returned outdoors")
	freeze(world)
	check(state.npc_residents==exact,"scene exit preserves all resident states")
	for npc in world.npc_nodes:
		npc.present_resident(state)
		if str(npc.npc_id)=="qiao": qiao_actor=npc
		if str(npc.npc_id)=="granny": granny_actor=npc
	check(qiao_actor.visible and qiao_actor.global_position==Vector2(2831.25,1652.5),"recreated outdoor scene preserves moved NPC position")
	check(not granny_actor.visible,"indoor resident stays inside after player exits")
	# Room membership follows movement, including all non-owner residents.
	state.current_interior = room
	var room_scene=load("res://scenes/interior.tscn").instantiate()
	root.add_child(room_scene)
	freeze(room_scene)
	for id in ["he","yan"]:
		state.npc_residents[id].room=room
		state.npc_movement.actors[id]={"inside":{"x":520.0,"y":510.0,"direction":"left"}}
	room_scene._sync_room_residents();room_scene._publish_npc_positions()
	check(room_scene.resident_nodes.size()==3,"room renders owner and multiple actual guests")
	var candidates: Array=room_scene._room_target_candidates()
	for id in ["granny","he","yan"]:
		var found:=false
		for point in candidates:
			if str(point.get("kind",""))=="npc" and str(point.get("id",""))==id: found=true
		check(found,"room interaction candidate "+id)
	state.npc_residents.he.room=null
	room_scene._sync_room_residents();room_scene._publish_npc_positions()
	check(not room_scene.resident_nodes.has("he") and not state.interior_npc_positions.has("he"),"departed actor removed from rendering and interaction")
	room_scene.queue_free()
	world.queue_free()
	current_scene=null
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("NPC actual scene continuity: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
