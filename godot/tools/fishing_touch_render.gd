extends SceneTree
var passed: int=0
var failed: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(7):await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/fishing-overhaul-20261017/touch-"+name+".png")==OK,"touch GPU capture "+name)
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func():push_error("touch layout timeout");quit(1))
	check(OS.get_environment("ZRZ_FORCE_TOUCH")=="1","actual mobile sizing policy enabled")
	var s: Node=root.get_node("GameState");s.set_process(false);s.source_input_mode="touch";s.flags.introDone=true;s.current_interior="";s.player_position=Vector2(749,2790);s.ui_open=false;s.minutes=480
	root.size=Vector2i(1280,720)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var world: Node=current_scene;world.player.set_physics_process(false);world.hud.seed_button.tooltip_text=""
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	var panel: Control=world.hud.fishing_panel
	panel.open_panel("river","fishing")
	for page: int in range(3):
		panel.tabs.current_tab=page;await settle()
		check(root.get_visible_rect().encloses(panel.tabs.get_global_rect()),"touch page within safe area "+str(page))
		await capture("page-"+str(page))
	panel.close();world.hud.show_museum("catalog","item:carp");world.hud.museum_panel.category_option.select(3);world.hud.museum_panel._category_changed(3);await settle()
	check(root.get_visible_rect().encloses(world.hud.museum_panel.item_list.get_global_rect()),"touch discovery cards fit")
	await capture("knowledge");world.hud.close_museum()
	panel.open_panel("river","fishing");panel.start_cast()
	for i: int in range(200):
		if not s.fishing_active():break
		var game: Dictionary=s.fishing_session.game
		if game.stage=="fight":game.holding=float(game.fishPos)>float(game.barPos)
		s._process_action(.03)
		if s.fishing_active() and str(s.fishing_session.game.stage)=="fight":break
	await settle()
	check(root.get_visible_rect().encloses(panel.live_panel.get_global_rect()),"touch live HUD fits screen")
	check(not world.hud.get_node("MobileControls").action.visible,"normal movement controls yield to fishing controls")
	check(panel.reel_button.size.y>=48 and panel.fishing_cancel_button.size.y>=48,"touch primary targets are at least 48 logical pixels")
	await capture("tracking")
	panel._pause_settings();check(world.hud.settings_open(),"touch pause opens settings")
	var before: float=s.fishing_session.game.time;s._process_action(.1);check(s.fishing_session.game.time==before,"touch settings pause freezes session")
	world.hud.close_settings();s.cancel_player_action()
	var file:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/touch-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"physicalScreen":[1280,720],"logicalViewport":str(root.get_visible_rect()),"policy":"ZRZ_FORCE_TOUCH=1"},"  "));file.close()
	print("Fishing touch GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
