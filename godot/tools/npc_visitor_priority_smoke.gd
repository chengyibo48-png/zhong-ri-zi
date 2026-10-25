extends SceneTree

const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
var rows := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	state.set_process(false)
	state.current_interior = "building-river-10"
	state.collection.level = 0
	var world = load("res://scenes/interior.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	var home_probe = Node2D.new()
	home_probe.set_script(load("res://scripts/interior_world.gd"))
	# Skip scene ready; only its owner synchronization is under test.
	home_probe.set_process(false)
	home_probe.set_block_signals(true)
	var path := OS.get_environment("NPC_VISITOR_FIXTURE")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing NPC_VISITOR_FIXTURE")
		world.queue_free()
		await process_frame
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = SAVE_JSON.decode(JSON.parse_string(line))
		var input: Dictionary = row.input
		var npc_id := str(input.person.id)
		state.day = int(input.day)
		state.minutes = float(input.minutes)
		state.neighbors.day = state.day
		for resident in state.neighbors.people.values(): resident.event = {}
		state.neighbors.people[npc_id].event = {"status": "accepted"} if bool(input.housework) else {}
		state.collection.level = int(input.museum_level)
		state.community_projects.bridge = bool(input.bridge)
		# Source fixtures now advance the real actor before deciding room visibility.
		for person in state.npc_catalog:
			for house in state.world_village.houses:
				if str(house.get("owner", "")) == str(person.id):
					state.npc_residents[str(person.id)] = {"x":float(house.door.x),"y":float(house.door.y),"direction":"down","room":str(house.id)}
					break
		state.npc_residents[npc_id] = row.startingPosition.duplicate(true)
		state.npc_movement = load("res://scripts/npc_movement.gd").new()
		state.npc_movement.clock = 0.25
		state.player_position = Vector2(24,38)
		state.interior_position = state.player_position
		state.current_interior = ""
		state.npc_movement.update_actor(state,input.person,int(input.index),0.25)
		state.current_interior = "building-river-10"
		state.npc_movement.publish(state)
		_check(state.npc_residents[npc_id].get("room") == row.actualPosition.get("room"), "%d actual source room after movement" % rows)
		world._sync_museum_visitor()
		world._publish_npc_positions()
		var wanted := npc_id if row.actualPosition.get("room") == "building-river-10" else ""
		_check(str(world.visitor_id) == wanted, "%d visitor id" % rows)
		_check((world.visitor_npc != null and is_instance_valid(world.visitor_npc)) == (wanted != ""), "%d visitor node" % rows)
		if wanted != "":
			_check(str(world.visitor_npc.npc_id) == wanted, "%d rendered actor" % rows)
			_check(str(world.visitor_npc.schedule_label) == str(row.expected.label), "%d activity text" % rows)
			state.interior_position = world.visitor_npc.global_position
			_check(state.npc_is_near(wanted), "%d face to face interaction" % rows)
			_check(state.interior_npc_positions.has(wanted), "%d room position published" % rows)
		else:
			_check(not state.interior_npc_positions.has(npc_id), "%d absent room position" % rows)
			_check(not state.npc_is_near(npc_id), "%d cannot interact with absent visitor" % rows)
		state.current_interior = "home-" + npc_id
		home_probe._sync_room_owner(0.0)
		var home_expected: bool = str(row.actualPosition.get("room", "")) == state.current_interior
		_check((home_probe.owner_npc != null and is_instance_valid(home_probe.owner_npc)) == home_expected, "%d resident only in own planned room" % rows)
		for child in home_probe.get_children(): child.free()
		home_probe.resident_nodes.clear()
		home_probe.owner_npc = null
		home_probe.visitor_npc = null
		home_probe.owner_activity_stamp = ""
		state.current_interior = "building-river-10"
		rows += 1
		if rows % 32 == 0: await process_frame
	var counts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".counts.json"))
	_check(rows == int(counts.rows), "independent row count")
	home_probe.free()
	world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("NPC native museum visitor priorities: %d rows, %d passed, %d failed" % [rows, passed, failed])
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 20: push_error("FAIL " + label)
