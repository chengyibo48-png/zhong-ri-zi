extends SceneTree
var state:Node
var reports:Array=[]
var modern:=false
var point:Dictionary
var phase_counts:Dictionary={}
func _initialize()->void:call_deferred("run")
func pct(values:Array[float],p:float)->float:
	var copy:=values.duplicate();copy.sort();return copy[mini(copy.size()-1,ceili(copy.size()*p)-1)] if not copy.is_empty() else 0.0
func begin(scenario:String)->void:
	state.cancel_player_action();state.fishing.pending={};state.ui_open=false;state.fishing_focus_paused=false
	state.stamina=100;state.minutes=600;state.fishing.mode="standard";state.fishing.bait="plain";state.fishing.inputStyle="hold";state.fishing.tutorialDone=true
	state.player_position=Vector2(float(point.x),float(point.y));current_scene.player.global_position=state.player_position
	state.begin_fishing(str(point.id));state.fishing_session.launch()
	if scenario=="wait":state.fishing_session.game.plan.wait=1000.0
	elif scenario=="fight":
		state._process_action(.1);state._process_action(.1);state._process_action(.1);state._process_action(.1);state._process_action(.1);state._process_action(.1)
		state.fishing_session.game.hooked=true;state.fishing_session.transition("fight")
func input(scenario:String)->void:
	if not state.fishing_active():
		if state.fishing.pending is Dictionary and not state.fishing.pending.is_empty():state.fishing_resolve(true)
		begin(scenario);return
	var g:Dictionary=state.fishing_session.game
	var stage:String=str(g.stage);phase_counts[stage]=int(phase_counts.get(stage,0))+1
	if stage=="bite":state.fishing_input("press")
	if stage!="fight":return
	if modern:
		var surge:bool=str(g.fishPhase) in ["charge","surge"]
		if bool(g.holding) and (float(g.tension)>=68 or surge and float(g.tension)>=50):state.fishing_input("release")
		elif not bool(g.holding) and (float(g.tension)<=24 or float(g.tension)<=35 and not surge):state.fishing_input("press")
	else:
		var held:bool=clampf((float(g.fishPos)-float(g.barPos))*5,-.6,.6)>float(g.velocity)
		if held!=bool(g.holding):state.fishing_input("press" if held else "release")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(OS.get_environment("TEMP").replace("\\","/")+"/"):quit(1);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	state=root.get_node("GameState");state.flags.introDone=true;state.current_interior="";state.ui_open=false
	point=state.system_catalog.fishing.spots[0];state.player_position=Vector2(float(point.x),float(point.y));state.minutes=600
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var load_start:=Time.get_ticks_usec();change_scene_to_file("res://scenes/main.tscn");await process_frame;await process_frame
	var load_ms:float=(Time.get_ticks_usec()-load_start)/1000.0
	modern=state.fishing_session.game.has("stamina")
	# A new session identifies the model without relying on a save-format change.
	begin("wait");modern=state.fishing_session.game.has("stamina")
	for repeat_index:int in 3:
		for scenario:String in ["wait","fight","cycles"]:
			begin(scenario);phase_counts={}
			var start:=Time.get_ticks_usec();var last:=start;var wall:Array[float]=[];var cpu:Array[float]=[];var calls:Array[float]=[]
			var minute_total:=0.0;var old_minutes:float=state.minutes;var save_events:Array=[];var next_save:=8.0
			var navigation_start:int=int(load("res://scripts/npc_navigation.gd").metrics.route_calls)
			var previous_save:=FileAccess.get_modified_time(state.SAVE_PATH)
			while true:
				var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
				if elapsed>=25.0:break
				root.mode=Window.MODE_WINDOWED;state.ui_open=false;state.mobile_orientation_blocked=false;state.fishing_focus_paused=false
				input(scenario)
				if elapsed>=next_save:state.request_autosave();next_save+=8.0
				await process_frame
				var now:=Time.get_ticks_usec();var frame_ms:float=(now-last)/1000.0;last=now
				minute_total+=maxf(0,float(state.minutes)-old_minutes);old_minutes=float(state.minutes)
				if elapsed>=5.0:wall.append(frame_ms);cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				var modified:=FileAccess.get_modified_time(state.SAVE_PATH)
				if modified!=previous_save:save_events.append(elapsed);previous_save=modified
			var row:Dictionary={"scenario":scenario,"repeat":repeat_index+1,"warmup_seconds":5,"sample_seconds":20,"frames":wall.size(),"p50_ms":pct(wall,.5),"p95_ms":pct(wall,.95),"p99_ms":pct(wall,.99),"max_ms":pct(wall,1),"process_p50_ms":pct(cpu,.5),"process_p95_ms":pct(cpu,.95),"draw_calls_p50":pct(calls,.5),"load_ms":load_ms,"phase_frames":phase_counts.duplicate(),"simulation_minutes":minute_total,"save_events":save_events,"autosave":state.autosave_coordinator.metrics.duplicate(true),"nodes":get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"navigation":load("res://scripts/npc_navigation.gd").metrics.duplicate(),"texture_cache":load("res://scripts/texture_cache.gd").metrics.duplicate()}
			reports.append(row);print("FISHING_PERF ",JSON.stringify(row))
			var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/fishing-performance-"+OS.get_environment("ZRZ_REVIEW_STAGE")+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"modern":modern,"measurements":reports},"\t"));file.close()
			# Fishing intentionally freezes the life clock; NPC updates and autosave must remain live.
			if int(row.navigation.route_calls)<=navigation_start or save_events.is_empty():printerr("NPC navigation or autosave did not remain active");quit(1);return
	state.cancel_player_action();await root.get_node("AudioService").prepare_exit();quit()
