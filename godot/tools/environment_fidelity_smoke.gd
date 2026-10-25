extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BUILDING_TASK_FIXTURE")))
	if not input is Dictionary: quit(1); return
	var state = root.get_node("GameState")
	for row in input.weatherProfiles:
		state.minutes = int(row.minutes)
		var actual: Dictionary = state.weather_profile(int(row.day))
		var e: Dictionary = row.expected
		var differences: Array[String] = []
		for key in e:
			var native_key: String = "mean_temperature" if str(key)=="meanTemperature" else str(key)
			var expected: Variant = "" if str(key)=="event" and e[key]==null else e[key]
			var value: Variant = actual.get(native_key)
			var equal: bool
			if expected is float or expected is int: equal = (value is float or value is int) and absf(float(expected)-float(value))<0.000001
			else: equal = value==expected
			if not equal: differences.append(str(key)+": "+str(value)+" / "+str(expected))
		if differences.is_empty(): passed += 1
		else: failed += 1; push_error("原版天气 "+str(row.day)+"/"+str(row.minutes)+" "+"; ".join(differences))
	print("Environment fidelity: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
