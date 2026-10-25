extends SceneTree
var failed := 0
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in range(10): await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	var s := root.get_node("GameState")
	s.set_process(false);s.flags.introDone = true;s.day = 0;s.minutes = 620
	s.player_position = Vector2(2650,1850)
	root.size = Vector2i(1280,900)
	change_scene_to_file("res://scenes/main.tscn"); await settle()
	var world := current_scene
	world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
	world.player.camera.position = Vector2(186,-11)
	world.player.camera.zoom = Vector2(1.75,1.75)
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	for mode in ["prepared","planted"]:
		if mode == "planted":
			var crops := ["cabbage","radish","carrot","tomato","rice","eggplant","leek"]
			for i in range(49):
				s.plots[i].crop = crops[i%7]
				s.plots[i].growth = [0.0,0.35,0.75,1.0,0.75,0.35,1.0][int(i/7)]*s.crop_days(str(s.plots[i].crop))
				s.plots[i].moisture = 55
		for node in world.plot_nodes: node.queue_redraw()
		await settle();await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://artifacts/farm-grid-7x7-20261016/"+mode+".png")
		if result != OK: failed += 1
		for i in range(49):
			var rect := Rect2(s.farm_plot_position(i)+Vector2(-22,-30),Vector2(44,48))
			if not root.get_visible_rect().encloses(world.get_global_transform_with_canvas()*rect): failed += 1
	print("Farm grid 7x7 render: %d passed, %d failed" % [100-failed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
