extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.minutes=600
	var p:Dictionary=s.system_catalog.fishing.spots[0];s.player_position=Vector2(float(p.x),float(p.y));s.ui_open=false;s.fishing.mode="standard";s.fishing.bait="plain"
	root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn")
	for i:int in 15:await process_frame
	var w:Node=current_scene;s.begin_fishing(str(p.id));s.fishing_session.launch()
	for i:int in 8:s._process_action(.1);await process_frame
	s.fishing_session.transition("fight");s._process_action(.01)
	if w.player.get("fishing_camera")!=null:w.player.fishing_camera.set_process(false)
	w.player.camera.zoom=Vector2.ONE*1.35;w.player.camera.offset=Vector2.ZERO;w.player.camera.reset_smoothing();w.player.camera.force_update_scroll()
	for i:int in 12:await process_frame
	RenderingServer.force_draw()
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/comparison-"+OS.get_environment("ZRZ_REVIEW_STAGE")+".png"
	assert(root.get_texture().get_image().save_png(out)==OK)
	await root.get_node("AudioService").prepare_exit();quit()
