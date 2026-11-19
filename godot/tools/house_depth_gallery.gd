extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true
	var fixture:String=OS.get_environment("HOUSE_COMPLETED_FIXTURE")
	if not fixture.is_empty():assert(s.load_game(fixture))
	var output:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/houses-"+OS.get_environment("HOUSE_GALLERY_PHASE");DirAccess.make_dir_recursive_absolute(output)
	var count:int=0
	for house:Dictionary in s.world_village.houses:
		if OS.get_environment("HOUSE_GALLERY_PHASE")=="memories" and not str(house.id).begins_with("home-"):continue
		if OS.get_environment("HOUSE_GALLERY_ROOM")!="" and str(house.id)!=OS.get_environment("HOUSE_GALLERY_ROOM"):continue
		for light:String in (["day"] if OS.get_environment("HOUSE_GALLERY_PHASE")=="memories" else ["day","night"]):
			s.current_interior=str(house.id);s.interior_position=Vector2(480,567);s.minutes=660 if light=="day" else 1220;s.ui_open=false
			change_scene_to_file("res://scenes/interior.tscn")
			for frame:int in 5:await process_frame
			current_scene.hud.ambient_hud.hide();current_scene.hud.context_actions.hide();current_scene.hud.interaction_prompt.hide()
			current_scene.player.camera.position_smoothing_enabled=false;current_scene.player.camera.reset_smoothing();current_scene.player.camera.force_update_scroll()
			RenderingServer.force_draw();assert(root.get_texture().get_image().save_png(output+"/"+str(house.id)+"-"+light+".png")==OK);count+=1
	print("HOUSE_GALLERY: ",count," native room frames")
	await root.get_node("AudioService").prepare_exit();quit()
