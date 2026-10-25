extends SceneTree
## Sustained native input/rendering plus accelerated annual state transitions.
var passed := 0
var failed := 0
var held_key := 0
var telemetry: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed+=1
	else: failed+=1;push_error(text)
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	event.unicode=String.chr(code).to_lower().unicode_at(0)
	Input.parse_input_event(event)
func replace_scene(state: Node, step: int) -> void:
	if held_key != 0:key(held_key,false);held_key=0
	state.current_interior = "home-an" if step%3==1 else "building-farm-12" if step%3==2 else ""
	state.player_position=Vector2(2831,1652);state.interior_position=Vector2(480,550)
	state.ui_open=false
	change_scene_to_file("res://scenes/main.tscn" if state.current_interior=="" else "res://scenes/interior.tscn")
func run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	var duration := 600.0 if OS.get_environment("SOAK_SECONDS").is_empty() else float(OS.get_environment("SOAK_SECONDS"))
	create_timer(duration+120).timeout.connect(func():push_error("Soak deadline");quit(1))
	Engine.max_fps=60
	var state := root.get_node("GameState")
	state.flags.introDone=true
	var starting_day: int=state.day
	root.size=Vector2i(1280,800)
	replace_scene(state,0)
	for i in range(10):await process_frame
	var started := Time.get_ticks_msec()
	var next_day := duration/112.0
	var next_sample := 15.0
	var next_key := 1.0
	var days := 0
	var frames := 0
	var roundtrips := 0
	while float(Time.get_ticks_msec()-started)/1000.0 < duration:
		await process_frame;frames+=1
		var seconds := float(Time.get_ticks_msec()-started)/1000.0
		if seconds>=next_key:
			if held_key!=0:key(held_key,false)
			held_key=[KEY_W,KEY_D,KEY_S,KEY_A][int(next_key)%4]
			key(held_key,true);next_key+=1.0
		if seconds>=next_day and days<112:
			state.advance_day();days+=1;next_day=duration*float(days+1)/112.0
			if days%7==0:
				if held_key!=0:key(held_key,false);held_key=0
				var wanted_money: int=state.money
				check(state.save_game("user://annual-soak.json",true),"Annual safe-boundary write")
				check(state.load_game("user://annual-soak.json") and state.day==starting_day+days and state.money==wanted_money,"Annual roundtrip keeps progress")
				roundtrips+=1
				replace_scene(state,int(days/7))
				root.size=Vector2i(1920,1080) if days%14==0 else Vector2i(960,600) if days%21==0 else Vector2i(1280,800)
		if seconds>=next_sample:
			telemetry.append({"seconds":seconds,"day":state.day,"nodes":get_node_count(),"memory_bytes":OS.get_static_memory_usage(),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"frames":frames})
			print("SOAK_PROGRESS: %.0f seconds, %d days, %d frames"%[seconds,days,frames])
			next_sample+=15.0
	if held_key!=0:key(held_key,false)
	while days<112:
		state.advance_day();days+=1
	check(days==112 and state.day==starting_day+112,"All four seasons and annual boundary reached")
	check(state.plots.size() in [24,72] and state.animals.size()<=32,"Long-run catalog invariants")
	check(state.save_game("user://annual-final.json",true) and state.load_game("user://annual-final.json"),"Final annual save reload")
	var report := {"seconds":duration,"frames":frames,"days_advanced":days,"roundtrips":roundtrips,"passed":passed,"failed":failed,"telemetry":telemetry,"adapter":RenderingServer.get_video_adapter_name(),"joypads":Input.get_connected_joypads(),"scope":"Automated native keyboard, scene, resolution and yearly-state soak. Not a human playthrough, physical-controller test, or low-end-device certification."}
	var output := OS.get_environment("SOAK_OUTPUT")
	if output.is_empty(): output = "res://artifacts/quality-20261014/soak-report.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	state.set_process(false)
	await process_frame
	if is_instance_valid(current_scene):current_scene.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("RUNTIME_SOAK: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
