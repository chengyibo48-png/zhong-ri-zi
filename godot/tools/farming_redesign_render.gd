extends SceneTree
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failed += 1; push_error(label)
func settle() -> void:
	for frame in range(8): await process_frame
func capture(name: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	var prefix := OS.get_environment("FARM_RENDER_PREFIX")
	if prefix.is_empty(): prefix = "after"
	check(root.get_texture().get_image().save_png("res://artifacts/farming-redesign-20261016/"+prefix+"-"+name+".png") == OK,"save "+name)
func run() -> void:
	create_timer(110).timeout.connect(func(): quit(1))
	var s := root.get_node("GameState")
	s.set_process(false); s.flags.introDone = true; s.minutes = 620; s.day = 35
	root.size = Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn"); await settle()
	var world := current_scene
	world.set_process(false); world.player.set_physics_process(false); world.hud.hide()
	var crops := ["cabbage","carrot","tomato","eggplant","rice","leek"]
	for i in s.plots.size():
		s.plots[i] = s._new_plot()
		var p: Dictionary = s.plots[i]
		p.tilled = true
		p.crop = crops[i%6]
		p.growth = [0.0,0.35,0.75,1.0][int(i/6)%4]*s.crop_days(str(p.crop))
		p.moisture = [10,40,70,95][int(i/6)%4]
		p.soil_type = ["loam","sand","humus","clay","wetland","loam"][i%6]
		if i == 14: p.crop = ""; p.tilled = false
		if i == 18: p.fallow = true; p.crop = ""
		if i == 8: p.companion = {"crop":"bean","growth":2.8,"kind":"normal"}
	for node in world.plot_nodes: node.queue_redraw()
	world.player.global_position = s.farm_plot_position(0)+Vector2(-52,42)
	world.player.camera.position = Vector2(154,8)
	world.player.camera.zoom = Vector2(2.1,2.1)
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.queue_redraw()
	await capture("farm")
	for mode in ["dry","wet"]:
		for p in s.plots:
			p.crop = ""; p.companion = {}; p.moisture = 0 if mode == "dry" else 90
		for node in world.plot_nodes: node.queue_redraw()
		await capture(mode)
	var summer_day: int = s.day
	for winter_day in range(84,112):
		s.day = winter_day
		if float(s.ground_conditions().get("snow",0)) > 0: break
	for node in world.plot_nodes: node.queue_redraw()
	world._refresh_ground_season(s.season_index())
	preload("res://scripts/ground_style.gd").update_weather(world.ground_layer,float(s.ground_conditions().get("snow",0)))
	await capture("winter")
	s.day = summer_day
	for node in world.plot_nodes: node.queue_redraw()
	world._refresh_ground_season(s.season_index())
	preload("res://scripts/ground_style.gd").update_weather(world.ground_layer,0)
	# Extension shows the same renderer and row connectivity at its own spacing.
	world.player.global_position = s.farm_plot_position(24)+Vector2(-45,42)
	world.player.camera.position = Vector2(276,15)
	world.player.camera.zoom = Vector2(1.5,1.5)
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	await capture("extension")
	world.hud.show()
	s.selected_seed = "tomato"
	world.hud.call("show_farm_planner",false,1)
	await settle()
	var panel: Control = world.hud.farm_planner_panel
	check(panel.visible,"planner opens")
	check(panel.summary_label.text.contains("今日田况"),"real summary displayed")
	check(panel.details_label.text.contains("播种参考"),"real sowing forecast available")
	await capture("planner-1280")
	panel.crop_filter.select(1); panel._refresh_crop_list()
	for id in panel.crop_ids: check(s.crop_in_season(id),"season filter")
	panel.crop_search.text = "番茄"; panel._refresh_crop_list()
	check(panel.crop_ids.size() == 1 and panel.crop_ids[0] == "tomato","crop search keeps intended item")
	root.size = Vector2i(960,600); await settle()
	await capture("planner-960")
	var bounds: Rect2 = panel.get_child(1).get_global_rect()
	check(root.get_visible_rect().encloses(bounds),"planner stays within native viewport")
	panel.close()
	print("FARMING_REDESIGN_RENDER: ",failed," failed")
	await root.get_node("AudioService").prepare_exit(); quit(1 if failed else 0)
