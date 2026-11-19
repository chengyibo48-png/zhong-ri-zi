extends SceneTree
func _initialize()->void:call_deferred("run")
func quantile(values:Array,ratio:float)->float:return float(values[mini(values.size()-1,int(values.size()*ratio))])
func run()->void:
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var s:Node=root.get_node("GameState");s.flags.introDone=true;s.day=30;s.minutes=660
	var stress:bool=OS.get_environment("HOUSE_BARN_STRESS")=="1"
	if stress:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);seed(4242)
		s.money=100000;s.stamina=100;s.ranch.barns.cattle.built=true;s.ranch.barns.cattle.space=3
		while s.ranch_animal_count("cow")<s.ranch_barn_capacity("cattle"):
			assert(s.ranch_buy_animal("cow","female","local",false));await s.wait_for_saves()
		var i:int=0
		for animal:Dictionary in s.animals:
			if str(animal.type)!="cow":continue
			animal.rest=true;animal.position.room="building-pasture-17";animal.position.inside={"x":380+(i%4)*60,"y":350+(i/4)*75};i+=1
		s.minutes=660;s.stamina=100
	var rooms:Array=["building-pasture-17"] if stress else ["home-chen","building-town-8","building-town-4","building-pasture-17"]
	var rows:Array=[]
	for trial:int in 3:
		for room:String in rooms:
			s.current_interior=room;s.interior_position=Vector2(480,560);s.ui_open=false
			change_scene_to_file("res://scenes/interior.tscn")
			for frame:int in 8:await process_frame
			var warm:float=Time.get_ticks_usec()/1000000.0
			while Time.get_ticks_usec()/1000000.0-warm<5.0:await process_frame
			var start:float=Time.get_ticks_usec()/1000000.0;var previous:int=Time.get_ticks_usec();var samples:Array=[];var save_at:float=8;var saves:int=0
			while Time.get_ticks_usec()/1000000.0-start<20.0:
				await process_frame
				var now:int=Time.get_ticks_usec();samples.append(float(now-previous)/1000.0);previous=now
				if float(now)/1000000.0-start>=save_at:s.request_autosave();saves+=1;save_at+=8
			samples.sort()
			var row:Dictionary={"room":room,"trial":trial,"p50":quantile(samples,.5),"p95":quantile(samples,.95),"p99":quantile(samples,.99),"max":samples[-1],"frames":samples.size(),"autosaves":saves,"barn_cows":s.ranch_animal_count("cow"),"barn_capacity":s.ranch_barn_capacity("cattle"),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			rows.append(row);print("HOUSE_PERF ",JSON.stringify(row))
			var checkpoint:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+(("/house-barn-performance" if stress else "/house-performance")+"-"+OS.get_environment("HOUSE_PERF_LABEL")+".json"),FileAccess.WRITE);checkpoint.store_string(JSON.stringify(rows,"  "));checkpoint.close()
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+(("/house-barn-performance" if stress else "/house-performance")+"-"+OS.get_environment("HOUSE_PERF_LABEL")+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
	await root.get_node("AudioService").prepare_exit();quit()
