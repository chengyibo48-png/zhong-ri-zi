extends SceneTree
var reports:Array=[]
func _initialize()->void:call_deferred("run")
func pct(values:Array[float],p:float)->float:
	values.sort();return values[mini(values.size()-1,ceili(values.size()*p)-1)] if not values.is_empty() else 0.0
func run()->void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var s:Node=root.get_node("GameState");s.flags.introDone=true;s.animals.clear();s.day=30;s.minutes=500;s.ui_open=false
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	for repeat:int in 3:
		for scenario:String in ["village","home"]:
			s.current_interior="home-chen" if scenario=="home" else "";s.interior_position=Vector2(480,530);s.player_position=Vector2(2800,550);s.minutes=500;s.ui_open=false
			change_scene_to_file("res://scenes/interior.tscn" if scenario=="home" else "res://scenes/main.tscn");await process_frame;await process_frame
			var start:int=Time.get_ticks_usec();var last:int=start;var values:Array[float]=[];var saves:int=0;var next_save:float=8
			while (Time.get_ticks_usec()-start)<25000000:
				var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0;s.ui_open=false;s.mobile_orientation_blocked=false
				if elapsed>=next_save:s.request_autosave();next_save+=8;saves+=1
				await process_frame
				var now:int=Time.get_ticks_usec()
				if elapsed>=5:values.append((now-last)/1000.0)
				last=now
			var row:Dictionary={"scenario":scenario,"repeat":repeat,"p50":pct(values,.5),"p95":pct(values,.95),"p99":pct(values,.99),"max":pct(values,1),"frames":values.size(),"warmup":5,"sample":20,"save_requests":saves,"residents":s.npc_catalog.size()};reports.append(row);print("RESIDENT_PERF ",JSON.stringify(row))
			var f:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-performance-"+OS.get_environment("ZRZ_REVIEW_STAGE")+".json",FileAccess.WRITE);f.store_string(JSON.stringify(reports,"\t"));f.close()
	await root.get_node("AudioService").prepare_exit();quit()
