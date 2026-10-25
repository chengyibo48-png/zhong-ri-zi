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
	var path := OS.get_environment("NPC_WORLD_FIXTURE")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Dictionary=SAVE_JSON.decode(JSON.parse_string(line))
		check(state.load_game_data(state.convert_external_save(row.before)),"whole source world imported")
		state.npc_residents=row.before.village.npc.duplicate(true)
		state.current_interior=""
		state.player_position=Vector2(row.before.player.x,row.before.player.y)
		for sample in row.samples:
			state.advance_npc_movement(float(sample.dt))
			compare(state.npc_residents,sample.npc,str(row.scenario)+"/"+str(frames)+"/population")
			compare(state.npc_movement.actors,sample.actors,str(row.scenario)+"/"+str(frames)+"/all actors")
			check(absf(state.npc_movement.clock-float(sample.clock))<0.00000001,"whole world clock")
			frames+=1
		cases+=1
	var counts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
	check(cases==int(counts.cases),"independent world case count")
	check(frames==int(counts.frames),"independent world frame count")
	await root.get_node("AudioService").prepare_exit()
	print("NPC full source village simulation: %d cases, %d frames, %d passed, %d failed" % [cases,frames,passed,failed])
	quit(1 if failed else 0)
