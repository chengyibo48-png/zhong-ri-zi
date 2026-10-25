extends SceneTree
## Actual rendered frame measurements with isolated saves. No certification claim.
var samples: Array[Dictionary] = []
var output: String
func _initialize() -> void:
	call_deferred("run")
func percentile(values: Array[float], amount: float) -> float:
	if values.is_empty(): return 0.0
	values.sort()
	return values[mini(values.size()-1, int(ceil(values.size()*amount))-1)]
func run() -> void:
	output = OS.get_environment("RUNTIME_PROFILE_OUTPUT")
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp+"/"):
		quit(1); return
	create_timer(120).timeout.connect(func(): push_error("Runtime profile timeout"); quit(1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var state := root.get_node("GameState")
	state.flags.introDone = true
	for scenario: Dictionary in [
		{"name":"farm_960", "size":Vector2i(960,600), "at":Vector2(2831,1652), "room":""},
		{"name":"town_1280", "size":Vector2i(1280,800), "at":Vector2(2800,1000), "room":""},
		{"name":"winter_1920", "size":Vector2i(1920,1080), "at":Vector2(2831,1652), "room":""},
		{"name":"interior_night", "size":Vector2i(1280,800), "at":Vector2(480,550), "room":"home-an"}]:
		root.size = scenario.size
		state.current_interior = scenario.room
		state.day = 84 if scenario.name == "winter_1920" else 0
		state.minutes = 1260 if scenario.name == "interior_night" else 720
		state.player_position = scenario.at
		state.interior_position = scenario.at
		change_scene_to_file("res://scenes/main.tscn" if scenario.room == "" else "res://scenes/interior.tscn")
		# Performance monitors refresh once a second; let scene-loading samples expire.
		for i in range(180): await process_frame
		var wall: Array[float] = []
		var cpu: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in range(240):
			await process_frame
			var now := Time.get_ticks_usec()
			wall.append(float(now-last)/1000.0)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			last = now
		samples.append({"scenario":scenario.name,"frames":wall.size(),"frame_median_ms":percentile(wall,0.5),"frame_p95_ms":percentile(wall,0.95),"process_median_ms":percentile(cpu,0.5),"process_p95_ms":percentile(cpu,0.95),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"nodes":get_node_count()})
	var report := {"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"joypads":Input.get_connected_joypads(),"measurements":samples,"scope":"Four actual GPU scenes; local device only, no human playthrough or physical controller certification."}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("RUNTIME_PROFILE: 4 scenarios completed")
	quit(0)
