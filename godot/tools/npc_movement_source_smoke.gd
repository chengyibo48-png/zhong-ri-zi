extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
var cases := 0
var frames := 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 25: push_error("FAIL " + label)

func compare(actual: Variant, expected: Variant, label: String) -> void:
	if actual is Dictionary and expected is Dictionary:
		for field in expected:
			if field in ["plan", "npc", "scheduleKey"]: continue
			check(actual.has(field), label+"."+str(field)+" exists")
			if actual.has(field): compare(actual[field],expected[field],label+"."+str(field))
	elif actual is Array and expected is Array:
		check(actual.size()==expected.size(),label+" length")
		for i in range(mini(actual.size(),expected.size())): compare(actual[i],expected[i],label+"/"+str(i))
	elif (actual is float or actual is int) and (expected is float or expected is int):
		check(absf(float(actual)-float(expected))<0.00000001,label+" coordinate/clock")
	else: check(actual==expected,label+" value")

func _run() -> void:
	var state = root.get_node("GameState")
	state.set_process(false)
	var path := OS.get_environment("NPC_MOVEMENT_FIXTURE")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = SAVE_JSON.decode(JSON.parse_string(line))
		check(state.load_game_data(state.convert_external_save(row.before)), "source state loaded")
		# Directly preserve the valid in-memory source state; browser load separately resets non-home room.
		state.npc_residents = row.before.village.npc.duplicate(true)
		state.current_interior = str(row.before.village.interior) if row.before.village.interior!=null else ""
		state.player_position = Vector2(row.before.player.x,row.before.player.y)
		state.interior_position = state.player_position
		var person: Dictionary = {}
		for n in state.npc_catalog:
			if str(n.id)==str(row.id): person=n; break
		if str(row.scenario)=="focused":
			state.npc_movement.actors[str(row.id)] = {"wait":2.0+int(row.index)*0.31,"path":[],"phase":"","walking":false,"inside":{"x":480.0,"y":560.0,"direction":"up"}}
			state.action_sequence.active["npcId"] = str(row.id)
		for sample in row.samples:
			state.npc_movement.clock += float(sample.dt)
			state.npc_movement.navigation.refresh(state)
			state.npc_movement.update_actor(state,person,int(row.index),float(sample.dt))
			state.npc_movement.publish(state)
			var label := str(row.id)+"/"+str(row.scenario)+"/"+str(frames)
			compare(state.npc_residents[str(row.id)],sample.p,label+"/resident")
			compare(state.npc_movement.actors[str(row.id)],sample.a,label+"/runtime")
			check(absf(float(state.npc_movement.clock)-float(sample.clock))<0.00000001,label+"/clock")
			var point: Variant = sample.point
			if point==null:
				check(not state.npc_positions.has(str(row.id)) if state.current_interior=="" else not state.interior_npc_positions.has(str(row.id)),label+"/absent")
			else:
				var native_point: Vector2 = state.npc_positions.get(str(row.id),Vector2.ZERO) if state.current_interior=="" else state.interior_npc_positions.get(str(row.id),Vector2.ZERO)
				check(native_point==Vector2(point.x,point.y),label+"/scene point")
			frames += 1
		state.action_sequence.active.clear()
		cases += 1
		if cases % 24 == 0: print("Movement progress: ", cases, "/", int(168))
	var counts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
	check(cases==int(counts.cases),"independent cases")
	check(frames==int(counts.frames),"independent frames")
	await root.get_node("AudioService").prepare_exit()
	print("NPC source movement: %d cases, %d frames, %d passed, %d failed" % [cases,frames,passed,failed])
	quit(1 if failed else 0)
