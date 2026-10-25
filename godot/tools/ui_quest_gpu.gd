extends SceneTree
var s: Node
var w: Node
var passed:=0
var failed:=0
var screens: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,text: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(text)
func settle() -> void:
	for i: int in range(12):await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();check(image!=null,"GPU frame "+name)
	check(image.save_png("res://artifacts/ui-quests-20261017/"+name+".png")==OK,"save "+name);screens.append(name)
func open(name: String) -> void:
	w.hud.ui_stack.leave();await settle()
	match name:
		"tasks":w.hud.life_plan_panel.open_panel()
		"menu":w.hud.show_life_menu()
		"bag":w.hud.show_market("inventory",false)
		"map":w.hud.show_map()
		"calendar":w.hud.show_weather()
		"farm":w.hud.show_farm_planner(false,0)
		"ranch":w.hud.show_ranch()
		"fishing":w.hud.show_fishing("river","fishing")
		"kitchen":w.hud.show_kitchen(false)
		"processing":w.hud.show_kitchen(false,"process")
		"building":w.hud.show_building({},false)
		"tools":w.hud.show_tools(false)
		"skills":w.hud.show_skills()
		"neighbors":w.hud.show_neighbors()
		"person":w.hud.neighbor_journal.open_panel("granny")
		"dialogue":w.hud.show_npc_dialogue("granny")
		"story":w.hud.show_npc_story("granny")
		"gift":w.hud.show_gifts("granny")
		"knowledge":w.hud.show_museum("catalog","item:carp")
		"portable":w.hud.show_item_catalog()
		"community":w.hud.community_panel.open_panel("orders")
		"projects":w.hud.community_panel.open_panel("projects")
		"home":w.hud.show_home()
		"mail":w.hud.show_mail()
		"settings":w.hud.show_settings()
		"saves":w.hud.show_saves()
		"sleep":w.hud.show_sleep()
		"help":w.hud.show_help()
		"feedback":w.hud.show_feedback()
		"seeds":w.hud.show_seed_picker()
		"festival":w.hud.show_festival()
	await settle()
func validate(name: String) -> void:
	var panel: Control=w.hud.ui_stack.active()
	check(panel!=null,"active modal "+name)
	if panel==null:return
	var papers: Array=panel.get_children().filter(func(n: Node):return n is PanelContainer)
	for paper: PanelContainer in papers:
		var rect:=paper.get_global_rect()
		check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=root.get_visible_rect().end.x+2 and rect.end.y<=root.get_visible_rect().end.y+2,"safe modal envelope "+name+str(rect))
	check(s.ui_open,"modal blocks world input "+name)
	if panel==w.hud.life_plan_panel and not panel.current_rows.is_empty():check(root.get_visible_rect().encloses(panel.action_dock.get_global_rect()),"task primary actions stay in view "+name)
func run() -> void:
	create_timer(210,true,false,true).timeout.connect(func():push_error("UI GPU timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.current_interior=""
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.player.set_physics_process(false);Input.warp_mouse(Vector2(2,2));w.hud.hover_card.hide()
	root.size=Vector2i(960,600);s.changed.emit();await capture("hud-960x600")
	var all: Array[String]=["tasks","menu","bag","map","calendar","farm","ranch","fishing","kitchen","processing","building","tools","skills","neighbors","person","dialogue","story","gift","knowledge","portable","community","projects","home","mail","settings","saves","sleep","help","feedback","seeds","festival"]
	for name: String in all:
		await open(name);validate(name);await capture(name+"-960x600")
	for screen: Vector2i in [Vector2i(1280,800),Vector2i(1280,720)]:
		root.size=screen
		for name: String in ["tasks","menu","bag","ranch","fishing","knowledge","dialogue"]:
			await open(name);validate(name);await capture(name+"-%dx%d" % [screen.x,screen.y])
	root.size=Vector2i(960,600);s.player_settings.textScale=1.25;s.player_settings.contrast=true;s.changed.emit()
	for name: String in ["tasks","menu","bag","ranch","fishing","knowledge","dialogue","settings"]:
		await open(name);validate("large-"+name);await capture("large-"+name+"-960x600")
	# All retained material themes keep notebook text and panels readable.
	s.player_settings.textScale=1;s.player_settings.contrast=false
	for theme: String in ["porcelain","timber"]:
		s.ui_art.theme=theme;s.changed.emit()
		for name: String in ["tasks","bag","ranch"]:
			await open(name);validate(theme+"-"+name);await capture(theme+"-"+name)
	s.ui_art.theme="paper";s.feedback.prefs.motion="reduced";s.changed.emit();w.hud.ui_stack.leave();await capture("hud-reduced-motion")
	# Context layout and deferred settings pause are checked during a real live session.
	s.player_position=Vector2(749,2790);w.player.global_position=s.player_position;s.minutes=480;s.stamina=100
	check(s.begin_fishing("fishing"),"live context session begins")
	for i: int in range(200):
		if not s.fishing_active():break
		s._process_action(.04)
		if str(s.fishing_session.game.stage)=="fight":break
	await settle();check(root.get_visible_rect().encloses(w.hud.fishing_panel.live_panel.get_global_rect()),"desktop tracking dock fits")
	check(not w.hud.fishing_panel.live_panel.get_global_rect().intersects(w.hud.date_card.get_global_rect()),"tracking avoids resource card")
	await capture("fishing-tracking-ui")
	s.player_settings.textScale=1.25;s.changed.emit();await settle();check(root.get_visible_rect().encloses(w.hud.fishing_panel.live_panel.get_global_rect()),"large-text tracking fits")
	await capture("large-fishing-tracking-ui")
	w.hud.show_settings();await settle();var before: float=s.fishing_session.game.time;s._process_action(.1);check(float(s.fishing_session.game.time)==before and s.ui_open,"deferred modal state preserves fishing pause")
	w.hud.close_top_panel();await settle();s.cancel_player_action();w.hud.ui_stack.leave()
	# Subpages return to a preserved source with world input still blocked.
	s.player_settings.textScale=1;s.player_settings.contrast=false;s.changed.emit();await open("tasks")
	var chosen: String=w.hud.life_plan_panel.selected_id
	w.hud.show_museum("catalog","item:cabbage");await settle();w.hud.close_top_panel();await settle()
	check(w.hud.life_plan_panel.visible and w.hud.life_plan_panel.selected_id==chosen and s.ui_open,"detail back restores task context")
	w.hud.close_top_panel();await settle();check(not s.ui_open,"closing final modal resumes world")
	var f:=FileAccess.open("res://artifacts/ui-quests-20261017/gpu-report.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"failed":failed,"screenshots":screens,"renderer":RenderingServer.get_video_adapter_name()},"  "))
	print("UI quest GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
