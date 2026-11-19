extends SceneTree
var state:Node
func _initialize()->void:call_deferred("run")
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.minutes=720;state.day=0;state.ui_hud_visible=false
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(8):await process_frame
	var world:Node=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	var player:Node2D=world.player;player.set_physics_process(false)
	var actors:Array=[];var ids:Array=load("res://scripts/character_art.gd").data().actors.keys();ids.erase("player");ids.sort()
	for id:String in ids:
		var actor:Node2D=load("res://scripts/character_visual.gd").new();actor.configure(id);world.add_child(actor);actor.set_pose(Vector2.RIGHT,true);actor.set_process(false);actors.append(actor)
	var result:Array=[]
	for at:Vector2 in [Vector2(3150,2185),Vector2(2860,650),Vector2(1500,2725)]:
		player.global_position=at;state.player_position=at
		for i in actors.size():actors[i].global_position=at+Vector2((i%6-2.5)*34,-50+floori(i/6.0)*32)
		player.camera.zoom=Vector2(1.35,1.35);player.camera.reset_smoothing();player.camera.force_update_scroll()
		for i in range(90):
			for actor in actors:actor._process(1.0/60);actor.set_process(false)
			await process_frame
		var times:Array[float]=[];var cpu:Array[float]=[];var traveled:=0.0
		for frame in range(240):
			var started:=Time.get_ticks_usec()
			state.source_keyboard.keys={str(["arrowright","arrowdown","arrowleft","arrowup"][(frame/30)%4]):true}
			var before:Vector2=player.global_position;player.advance_player_frame(1.0/60);player.character_visual._process(1.0/60);player.character_visual.set_process(false)
			traveled+=player.global_position.distance_to(before)
			for actor in actors:actor._process(1.0/60);actor.set_process(false)
			cpu.append((Time.get_ticks_usec()-started)/1000.0)
			await process_frame;await RenderingServer.frame_post_draw
			times.append((Time.get_ticks_usec()-started)/1000.0)
		times.sort();cpu.sort();state.source_keyboard.clear()
		result.append({"origin":[at.x,at.y],"frames":240,"extra_residents":actors.size(),"distance":traveled,"frame_median_ms":times[120],"frame_p95_ms":times[228],"simulation_median_ms":cpu[120],"simulation_p95_ms":cpu[228]})
	print("FIXED_ROUTE_BENCHMARK ",JSON.stringify(result)," device=",RenderingServer.get_video_adapter_name())
	await root.get_node("AudioService").prepare_exit();quit()
