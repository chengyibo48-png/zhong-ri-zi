extends "res://tools/ui_quest_gpu.gd"
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("task touch timeout");quit(1))
	check(OS.get_environment("ZRZ_FORCE_TOUCH")=="1","actual mobile sizing policy active")
	s=root.get_node("GameState");s.set_process(false);s.source_input_mode="touch";s.flags.introDone=true;s.current_interior="";s.ui_open=false;s.player_position=Vector2(749,2790);s.minutes=480
	root.size=Vector2i(1280,720);change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.player.set_physics_process(false);Input.warp_mouse(Vector2(1,1));w.hud.hover_card.hide()
	await capture("touch-hud")
	for name: String in ["tasks","menu","bag","ranch","fishing","knowledge","dialogue","settings"]:
		await open(name);validate("touch-"+name)
		var active: Control=w.hud.ui_stack.active()
		for node: Node in active.find_children("*","BaseButton",true,false):
			if node.is_visible_in_tree() and not node is TabBar:check(node.size.y>=48,"touch target minimum "+name+str(node.name))
		await capture("touch-"+name)
	w.hud.ui_stack.leave();s.player_position=Vector2(749,2790);s.stamina=100;s.minutes=480
	check(s.begin_fishing("fishing"),"live touch-context fishing begins")
	check(not w.hud.toolbar.visible,"fishing context changes immediately before cast payment")
	for i: int in range(200):
		if not s.fishing_active():break
		s._process_action(.04)
		if str(s.fishing_session.game.stage)=="fight":break
	await settle()
	check(root.get_visible_rect().encloses(w.hud.fishing_panel.live_panel.get_global_rect()),"context HUD avoids top resources and bottom touch area")
	check(not w.hud.toolbar.visible and not w.hud.get_node("MobileControls").action.visible,"ordinary controls yield to tracking")
	w.hud.fishing_panel.reel_button.button_down.emit();check(bool(s.fishing_session.game.holding),"touch press enters unified session");w.hud.fishing_panel.reel_button.button_up.emit();check(not bool(s.fishing_session.game.holding),"touch release enters unified session")
	await capture("touch-tracking")
	w.hud.show_settings();await settle();var time: float=s.fishing_session.game.time;s._process_action(.1);check(s.fishing_session.game.time==time,"settings freeze live session")
	w.hud.close_top_panel();await settle();s.cancel_player_action();check(w.hud.toolbar.visible,"cancel immediately restores the ordinary toolbar")
	s.player_settings.textScale=1.25;s.player_settings.contrast=true;s.changed.emit();await open("tasks");validate("touch-large-tasks");await capture("touch-large-tasks")
	var f:=FileAccess.open("res://artifacts/ui-quests-20261017/touch-report.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"failed":failed,"physicalScreen":[1280,720],"logicalViewport":str(root.get_visible_rect()),"policy":"Windows GPU ZRZ_FORCE_TOUCH=1; no Android device claim","screenshots":screens},"  "))
	print("UI quest touch GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
