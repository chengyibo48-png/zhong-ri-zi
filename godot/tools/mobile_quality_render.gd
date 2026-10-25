extends SceneTree
var failures := 0
var qa_root := "res://artifacts/quality-20261014"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1;print("FAIL "+message)
func run() -> void:
	if not OS.get_environment("QUALITY_ARTIFACT_ROOT").is_empty(): qa_root = OS.get_environment("QUALITY_ARTIFACT_ROOT")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_root+"/screenshots"))
	root.size = Vector2i(844,390)
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(60): await process_frame
	var state := root.get_node("GameState")
	state.ui_open = false
	var hud = current_scene.hud
	var mobile = hud.get_node_or_null("MobileControls")
	check(mobile != null, "mobile controls created")
	if mobile == null: await root.get_node("AudioService").prepare_exit();quit(1);return
	check(Engine.max_fps == 30, "mobile frame cap")
	check(not state.mobile_orientation_blocked, "landscape continues simulation")
	check(mobile.action.get_global_rect().end.x <= root.get_visible_rect().size.x, "action inside viewport")
	var initial: Vector2=current_scene.player.global_position
	var press := InputEventScreenTouch.new();press.index=0;press.pressed=true;press.position=mobile.stick_center+Vector2(55,0)
	mobile._input(press)
	for i in range(20): await process_frame
	check(state.touch_direction.x > 0.5, "touch input admitted")
	check(current_scene.player.global_position != initial, "touch moves actual player")
	press = InputEventScreenTouch.new();press.index=0;press.pressed=false;press.position=mobile.stick_center
	mobile._input(press)
	await process_frame
	check(state.touch_direction == Vector2.ZERO, "release stops movement")
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(qa_root+"/screenshots/mobile-landscape.png")
	hud.show_market()
	for i in range(20):await process_frame
	check(state.ui_open, "touch inventory route opens")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(qa_root+"/screenshots/mobile-inventory.png")
	hud.market_panel.close()
	hud.show_saves()
	for i in range(20):await process_frame
	check(hud.save_panel.new_game_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "save actions remain inside viewport")
	check(hud.save_panel.list.get_parent() is ScrollContainer, "save slots scroll on small screens")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(qa_root+"/screenshots/mobile-saves.png")
	hud.save_panel.close()
	state.player_settings.textScale=1.4
	hud.refresh()
	hud.kitchen_heat_panel.open_panel({"id":"greens","n":1})
	for i in range(20):await process_frame
	var heat_card=hud.kitchen_heat_panel.get_child(1).get_child(0)
	check(heat_card.get_global_rect().position.y >= 0 and heat_card.get_global_rect().end.y <= root.get_visible_rect().size.y, "large text heat page fits mobile viewport")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(qa_root+"/screenshots/mobile-heat-large-text.png")
	hud.kitchen_heat_panel.close()
	root.size=Vector2i(390,844)
	for i in range(10):await process_frame
	check(state.mobile_orientation_blocked, "portrait pauses world")
	check(state.touch_direction == Vector2.ZERO, "portrait clears movement")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(qa_root+"/screenshots/mobile-portrait.png")
	print("MOBILE_QUALITY failures="+str(failures))
	await root.get_node("AudioService").prepare_exit();quit(0 if failures==0 else 1)
