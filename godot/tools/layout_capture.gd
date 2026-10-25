extends SceneTree
## Capture actual scenes for placement review, using isolated saves via run_isolated.py.
var folder := "res://artifacts/layout-polish-20261015/screenshots"
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	for i in range(18): await process_frame
	await RenderingServer.frame_post_draw
	if label == "phone-home-an-day":
		var prompt=current_scene.hud.interaction_prompt
		print("PROMPT ",prompt.size," minimum ",prompt.get_combined_minimum_size())
		print("HEADING ",prompt.heading.size," min ",prompt.heading.get_combined_minimum_size())
		print("DESCRIPTION ",prompt.description.size," min ",prompt.description.get_combined_minimum_size())
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
func run() -> void:
	var scratch := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"): quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var state := root.get_node("GameState")
	state.set_process(false);state.flags.introDone=true;state.ui_open=false
	root.size=Vector2i(1280,800)
	if OS.get_environment("ZRZ_FORCE_TOUCH") == "1": root.size=Vector2i(844,390)
	var prefix := "phone-" if OS.get_environment("ZRZ_FORCE_TOUCH") == "1" else "pc-"
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(18): await process_frame
	current_scene.player.set_physics_process(false)
	var points := {"farm":Vector2(2770,1740),"town":Vector2(2840,590),"bamboo":Vector2(1070,1650),"river":Vector2(1617,3390),"mountain":Vector2(1260,680),"pasture":Vector2(2570,2540)}
	for region: String in points:
		current_scene.player.position=points[region]
		current_scene.player.camera.reset_smoothing();current_scene.player.camera.force_update_scroll()
		await capture(prefix+region)
	var houses: Array = ["building-farm-12","home-an","home-qiao","building-town-1"]
	if OS.get_environment("ZRZ_CAPTURE_ALL_ROOMS") == "1":
		houses = ["building-farm-12"]
		houses.append_array(state.system_catalog.get("interiors",{}).get("layouts",{}).keys())
	for house: String in houses:
		state.current_interior=house;state.interior_position=Vector2(480,480);state.minutes=720
		change_scene_to_file("res://scenes/interior.tscn")
		await capture(prefix+house+"-day")
		state.minutes=1260;current_scene.queue_redraw()
		await capture(prefix+house+"-night")
	print("LAYOUT_CAPTURE complete "+prefix)
	await root.get_node("AudioService").prepare_exit();quit(0)
