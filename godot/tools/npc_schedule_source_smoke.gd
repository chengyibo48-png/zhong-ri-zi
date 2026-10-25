extends SceneTree

const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
var rows := 0
var keys: Dictionary = {}
var scenarios: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	var rules = load("res://scripts/npc_schedule.gd")
	state.set_process(false)
	var fixture := OS.get_environment("NPC_SCHEDULE_FIXTURE")
	var file := FileAccess.open(fixture, FileAccess.READ)
	if file == null:
		push_error("Missing NPC_SCHEDULE_FIXTURE")
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = SAVE_JSON.decode(JSON.parse_string(line))
		var input: Dictionary = row.input
		var expected: Dictionary = row.expected
		var actual: Dictionary = rules.activity(input.person, int(input.index), int(input.day), float(input.minutes), bool(input.shelter), input.home, input.work, input.school, input.market, input.friend_home, str(input.friend_name), bool(input.bridge), str(input.festival), bool(input.housework), int(input.museum_level), input.museum_door)
		for field in ["key", "label", "gesture", "room", "reason"]:
			_check(actual[field] == expected[field], "%d:%s:%s" % [rows, str(input.person.id), field])
		_check(actual.target_point.x == expected.target.x, "%d target.x" % rows)
		_check(actual.target_point.y == expected.target.y, "%d target.y" % rows)
		_check(bool(actual.indoors) == (expected.room != null and str(expected.room) != ""), "%d indoors" % rows)
		_check(actual.target == Vector2(expected.target.x, expected.target.y), "%d visual target" % rows)
		keys[str(expected.key)] = int(keys.get(str(expected.key), 0)) + 1
		scenarios[str(row.scenario)] = int(scenarios.get(str(row.scenario), 0)) + 1
		# Also verify the shared real-state adapter at representative daily thresholds.
		if float(input.minutes) in [600.0, 930.0, 1000.0]:
			state.day = int(input.day)
			state.minutes = float(input.minutes)
			state.neighbors.day = state.day
			state.neighbors.people[str(input.person.id)].event = {"status": "accepted"} if bool(input.housework) else {}
			state.community_projects.bridge = bool(input.bridge)
			state.collection.level = int(input.museum_level)
			var adapted: Dictionary = rules.from_state(state, input.person)
			for field in ["key", "label", "gesture", "room", "reason", "indoors"]:
				_check(adapted[field] == actual[field], "%d adapter.%s" % [rows, field])
			for axis in ["x", "y"]:
				_check(absf(float(adapted.target_point[axis]) - float(expected.target[axis])) < 0.000000001, "%d exported world coordinate.%s" % [rows, axis])
			_check(state.npc_dialogue_activity(input.person) == adapted, "%d dialogue adapter" % rows)
			var house: Dictionary = state._atlas_npc_house(input.person)
			_check(str(house.get("id", "")) == str(state.npc_residents[str(input.person.id)].get("room", "")), "%d atlas room" % rows)
		rows += 1
	var counts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture + ".counts.json"))
	_check(rows == int(counts.rows), "independent row count")
	_check(keys.size() == counts.keys.size(), "independent key count size")
	for key in counts.keys: _check(int(keys.get(key, -1)) == int(counts.keys[key]), "independent key count " + str(key))
	_check(scenarios.size() == counts.scenarios.size(), "independent scenario count size")
	for scenario in counts.scenarios: _check(int(scenarios.get(scenario, -1)) == int(counts.scenarios[scenario]), "independent scenario count " + str(scenario))
	_check(keys.size() == 12, "all twelve source schedule branches")
	print("NPC original schedule: %d rows, %d passed, %d failed; %s" % [rows, passed, failed, JSON.stringify(keys)])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 30: push_error("FAIL " + label)
