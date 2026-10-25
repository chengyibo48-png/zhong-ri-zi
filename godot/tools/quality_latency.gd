extends SceneTree
var start_usec := 0
var report: Dictionary = {}
func _initialize() -> void:
	start_usec=Time.get_ticks_usec();call_deferred("run")
func run() -> void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"): quit(1);return
	create_timer(120).timeout.connect(func():quit(1))
	var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
	root.size=Vector2i(1280,800)
	state.current_interior="";state.player_position=Vector2(2831,1652)
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	report.runner_to_first_scene_ms=float(Time.get_ticks_usec()-start_usec)/1000.0
	var captures: Array[float]=[];var saves: Array[float]=[]
	for i in range(8):
		var before:=Time.get_ticks_usec()
		var data: Dictionary=state._make_save_data()
		var encoded:=preload("res://scripts/save_json.gd").encode(data)
		captures.append(float(Time.get_ticks_usec()-before)/1000.0)
		report.save_bytes=encoded.to_utf8_buffer().size()
		state.money+=1;before=Time.get_ticks_usec()
		if not state.save_game("user://latency-save.json",true): quit(1);return
		saves.append(float(Time.get_ticks_usec()-before)/1000.0)
	report.capture_and_encode_ms=captures;report.atomic_save_ms=saves
	var transitions: Array[Dictionary]=[]
	for room: String in ["home-an","","building-farm-12",""]:
		state.current_interior=room;state.interior_position=Vector2(480,540)
		var before:=Time.get_ticks_usec()
		change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		transitions.append({"room":room,"to_first_render_ms":float(Time.get_ticks_usec()-before)/1000.0})
	report.scene_transitions=transitions
	state.ui_open=false;state.set_process(true)
	var initial_harvests:=int(state.player_stats.get("harvested",0))
	var before:=Time.get_ticks_usec()
	if not state.queue_farm_tasks([{"index":0,"action":"harvest"},{"index":1,"action":"harvest"}]):quit(1);return
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline and (not state.farm_queue.is_empty() or not state.farm_active_task.is_empty() or state.action_busy()): await process_frame
	report.two_plot_batch_seconds=float(Time.get_ticks_usec()-before)/1000000.0
	report.batch_completed=state.farm_completed
	report.harvested_delta=int(state.player_stats.get("harvested",0))-initial_harvests
	var ok: bool=state.farm_completed==2 and int(report.harvested_delta)>0
	report.passed=ok;report.adapter=RenderingServer.get_video_adapter_name()
	report.scope="Runner/scene startup, eight non-identical atomic saves and a real two-plot walking harvest. Local test hardware only; not a cold executable benchmark."
	var file:=FileAccess.open("res://artifacts/quality-redesign-20261015/latency-final.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	state.set_process(false);state.cancel_player_action();current_scene.queue_free();await process_frame
	print("Quality latency: %d passed, %d failed" % [1 if ok else 0,0 if ok else 1])
	await root.get_node("AudioService").prepare_exit();quit(0 if ok else 1)
