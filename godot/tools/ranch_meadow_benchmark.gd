extends SceneTree
var reports:Array=[]
func _initialize()->void:call_deferred("run")
func pct(values:Array[float],p:float)->float:
	var sorted:=values.duplicate();sorted.sort();return sorted[mini(sorted.size()-1,ceili(sorted.size()*p)-1)] if not sorted.is_empty() else 0.0
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(OS.get_environment("TEMP").replace("\\","/")+"/"):quit(1);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var s:Node=root.get_node("GameState");s.flags.introDone=true;s.ui_open=false;s.current_interior="";s.minutes=600;s.day=0
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	for repeat:int in 3:
		for scenario:String in ["meadow"]:
			s.cancel_player_action();s.ui_open=false;s.animals.clear();s.ranch.births=[];s.ranch.policy="inside" if scenario=="barn" else "day";s.ranch_actor_poses.clear();s.ranch_holds.clear()
			s.ranch.nextId=1;s.ranch.meadowEnabled=true;s.ranch.meadowAssignments={};s.ranch_movement=null;s.day=0;s.minutes=600;s.stamina=100;s.ranch.settledDay=-1
			for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;s.ranch.barns[id].clean=100;s.ranch.barns[id].comfort=2
			var counts:Dictionary={"hen":4,"duck":4,"cow":7 if scenario=="birth" else 8,"sheep":4,"goat":4,"pig":4,"rabbit":4};var index:int=0;var cows:Array=[]
			for species:String in counts:
				for i:int in int(counts[species]):
					var animal:Dictionary=s._ranch_new_animal(species,"female" if i%2==0 else "male","local",40)
					if species=="cow":cows.append(animal)
					var point:=Vector2(2600+(index%8)*20,2760+(index/8)*20)
					animal.position.x=point.x;animal.position.y=point.y;animal.position.direction="down"
					var meadow:Script=load("res://scripts/ranch_meadow.gd");var assigned:Dictionary=meadow.assignment(s,animal);var at:Vector2=meadow.stand(assigned)
					animal.position.room=meadow.ID;animal.position.inside={"x":at.x,"y":at.y,"direction":"down"}
					if scenario=="idle":s.ranch_holds[str(animal.id)]=s.ranch_actor_clock+100
					index+=1
			if scenario=="birth":s.ranch.births=[{"id":"bench-birth-"+str(repeat),"type":"cow","mother":cows[0].id,"father":cows[1].id,"breed":"local","remaining":1,"total":8}]
			s.current_interior="ranch-meadow";s.player_position=Vector2(2670,2556);s.interior_position=Vector2(420,400)
			var load_at:=Time.get_ticks_usec();change_scene_to_file("res://scenes/meadow.tscn");await process_frame;await process_frame
			var load_ms:float=(Time.get_ticks_usec()-load_at)/1000.0;s.changed.emit();s.ui_open=false
			var start:=Time.get_ticks_usec();var last:=start;var wall:Array[float]=[];var calls:Array[float]=[];var saves:Array=[];var events:Array=[];var previous_save:=FileAccess.get_modified_time(s.SAVE_PATH);var next_save:=8.0;var born:=false;var minute_start:float=s.minutes
			while true:
				var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
				if elapsed>=25.0:break
				root.mode=Window.MODE_WINDOWED;s.ui_open=false;s.mobile_orientation_blocked=false
				if elapsed>=next_save:s.request_autosave();next_save+=8.0
				if scenario=="birth" and elapsed>=12 and not born:
					var begin:=Time.get_ticks_usec();s.day=1;s._advance_ranch(0,"晴",s.minutes);events.append({"at":elapsed,"birth_ms":(Time.get_ticks_usec()-begin)/1000.0,"animals":s.animals.size()});born=true;s.changed.emit()
				await process_frame
				var now:=Time.get_ticks_usec();var frame_ms:float=(now-last)/1000.0;last=now
				if elapsed>=5:wall.append(frame_ms);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				var modified:=FileAccess.get_modified_time(s.SAVE_PATH)
				if modified!=previous_save:saves.append(elapsed);previous_save=modified
			var result:Dictionary={"scenario":scenario,"repeat":repeat+1,"warmup_seconds":5,"sample_seconds":20,"p50_ms":pct(wall,.5),"p95_ms":pct(wall,.95),"p99_ms":pct(wall,.99),"max_ms":pct(wall,1),"frames":wall.size(),"draw_calls_p50":pct(calls,.5),"load_ms":load_ms,"save_events":saves,"events":events,"simulation_minutes":float(s.minutes)-minute_start,"animals":s.animals.size(),"nodes":get_node_count(),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"autosave":s.autosave_coordinator.metrics.duplicate(true),"navigation":load("res://scripts/npc_navigation.gd").metrics.duplicate()}
			reports.append(result);print("RANCH_PERF ",JSON.stringify(result))
			var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/ranch-meadow-performance-"+OS.get_environment("ZRZ_REVIEW_STAGE")+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"measurements":reports},"\t"));file.close()
			if float(result.simulation_minutes)<15 or saves.is_empty():printerr("Benchmark simulation or autosave was paused");quit(1);return
	await root.get_node("AudioService").prepare_exit();quit()
