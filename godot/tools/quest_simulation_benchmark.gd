extends SceneTree
var reports:Array=[]
func _initialize()->void:call_deferred("run")
func pct(values:Array[float],p:float)->float:
	var copy:=values.duplicate();copy.sort();return copy[mini(copy.size()-1,ceili(copy.size()*p)-1)] if not copy.is_empty() else 0.0
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var state:Node=root.get_node("GameState");state.flags.introDone=true
	# Same full resident/task visibility in both versions, with native simulation active.
	for id:String in state.relations:state.relations[id].talked=0
	for metric:String in ["visit:ranch","visit:fishing","visit:kitchen","visit:calendar"]:state.quest_event(metric)
	state.changed.emit()
	var scenarios:Array=[{"name":"farm","at":Vector2(3150,2185),"room":"","day":0},{"name":"town","at":Vector2(2860,650),"room":"","day":0},{"name":"winter","at":Vector2(2800,1800),"room":"","day":84},{"name":"interior","at":Vector2(400,530),"room":"home-an","day":0}]
	var probe:=OS.get_environment("ZRZ_BENCH_PROBE")=="1"
	for repeat_index in range(1 if probe else 3):
		for scenario:Dictionary in scenarios:
			if probe and str(scenario.name)!="winter":continue
			state.source_keyboard.clear();state.current_interior=scenario.room;state.day=scenario.day;state.minutes=720 if scenario.room=="" else 1260
			state.player_position=scenario.at;state.interior_position=scenario.at;state.ui_open=false
			root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
			var load_started:=Time.get_ticks_usec()
			change_scene_to_file("res://scenes/main.tscn" if scenario.room=="" else "res://scenes/interior.tscn")
			await process_frame;await process_frame
			var load_ms:float=(Time.get_ticks_usec()-load_started)/1000.0
			Engine.max_fps=0;state.ui_open=false
			var player:Node2D=current_scene.player;player.camera.zoom=Vector2(1.35,1.35);player.camera.reset_smoothing()
			var minute_start:float=state.minutes
			var start:=Time.get_ticks_usec();var last:=start;var wall:Array[float]=[];var cpu:Array[float]=[];var longest:=0.0;var distance:=0.0;var previous:Vector2=player.global_position
			var slow_frames:Array=[]
			var cache_script:Script=load("res://scripts/texture_cache.gd") if probe else null
			var previous_loads:int=int(cache_script.metrics.loads) if probe else 0
			var writes:Array=[];var old_mtime:=FileAccess.get_modified_time(state.SAVE_PATH);var next_poll:=0.0
			while true:
				var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
				if elapsed>=25.0:break
				root.mode=Window.MODE_WINDOWED;state.ui_open=false;state.mobile_orientation_blocked=false
				state.source_keyboard.keys={str(["arrowright","arrowleft"][floori(elapsed/.45)%2]):true}
				await process_frame
				var now:=Time.get_ticks_usec();var frame_ms:float=(now-last)/1000.0;last=now
				if elapsed>=5.0:
					wall.append(frame_ms);cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
					longest=maxf(longest,frame_ms);distance+=player.global_position.distance_to(previous)
				if probe and frame_ms>50:
					slow_frames.append({"elapsed":elapsed,"ms":frame_ms,"phase":"warmup" if elapsed<5 else "sample","new_textures":int(cache_script.metrics.loads)-previous_loads,"snapshot_max_ms":state.autosave_coordinator.metrics.snapshot_max_ms,"worker_alive":state.autosave_coordinator.thread!=null,"audio":root.get_node("AudioService").generation_metrics.duplicate(),"navigation":load("res://scripts/npc_navigation.gd").metrics.duplicate()})
				if probe:previous_loads=int(cache_script.metrics.loads)
				previous=player.global_position
				if elapsed>=next_poll:
					next_poll=elapsed+.25;var modified:=FileAccess.get_modified_time(state.SAVE_PATH)
					if modified!=old_mtime:writes.append(elapsed);old_mtime=modified
			state.source_keyboard.clear()
			var result:Dictionary={"scenario":scenario.name,"repeat":repeat_index+1,"warmup_seconds":5,"sample_seconds":20,"frames":wall.size(),"p50_ms":pct(wall,.50),"p95_ms":pct(wall,.95),"p99_ms":pct(wall,.99),"max_ms":longest,"process_p50_ms":pct(cpu,.5),"process_p95_ms":pct(cpu,.95),"load_ms":load_ms,"distance":distance,"save_events":writes,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"nodes":get_node_count(),"slow_frames":slow_frames,"simulation_minutes":float(state.minutes)-minute_start}
			var coordinator:Variant=state.get("autosave_coordinator")
			if coordinator!=null:result.autosave_metrics=coordinator.metrics.duplicate(true)
			if float(state.minutes)-minute_start<15:push_error("Benchmark simulation did not remain active");quit(1);return
			if FileAccess.file_exists("res://scripts/texture_cache.gd"):
				var cache:Script=load("res://scripts/texture_cache.gd");result.texture_cache=cache.metrics.duplicate();result.texture_bytes_estimated=cache.bytes
			result.audio_generation=root.get_node("AudioService").get("generation_metrics")
			result.navigation=load("res://scripts/npc_navigation.gd").metrics.duplicate()
			if state.get("quest_runtime")!=null:result.quest_metrics=state.quest_runtime.metrics.duplicate()
			reports.append(result);print("FULL_SIM_SAMPLE ",JSON.stringify(result))
			var output:=OS.get_environment("ZRZ_ART_OUTPUT")+"/full-simulation-"+OS.get_environment("ZRZ_REVIEW_STAGE")+".json"
			var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"measurements":reports},"\t"));file.close()
	await root.get_node("AudioService").prepare_exit();quit()
