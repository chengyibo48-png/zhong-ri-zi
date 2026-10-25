extends SceneTree
var s: Node
var world: Node
var passed: int=0
var failed: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(8):await process_frame
func capture(name: String) -> void:
	var progress:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/gpu-progress.txt",FileAccess.WRITE);progress.store_string(name);progress.close()
	await settle();await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image!=null and image.get_width()>0,"GPU frame "+name)
	check(image.save_png("res://artifacts/fishing-overhaul-20261017/"+name+".png")==OK,"save "+name)
func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func():push_error("Fishing GPU timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.day=0;s.minutes=800;s.current_interior=""
	var scene_error:=change_scene_to_file("res://scenes/main.tscn");check(scene_error==OK,"load main scene");await settle()
	if current_scene==null:quit(1);return
	world=current_scene
	Input.warp_mouse(Vector2(8,8))
	world.hud.seed_button.tooltip_text=""
	world.player.set_physics_process(false)
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	world.player.global_position=Vector2(749,2790);s.player_position=world.player.global_position
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	s.clock_changed.emit();world._refresh();await capture("waterfront-before-fishing")
	var panel: Control=world.hud.fishing_panel
	for screen: Vector2i in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1280,720)]:
		root.size=screen;s.source_input_mode="touch" if screen.y==720 else "keyboard"
		panel.open_panel("river","fishing");await settle()
		for page: int in range(3):
			panel.tabs.current_tab=page;await settle()
			check(root.get_visible_rect().encloses(panel.tabs.get_global_rect()),"fishing page fits "+str(screen)+str(page))
			await capture("fishing-page-%d-%dx%d" % [page,screen.x,screen.y])
		panel.close()
		world.hud.show_museum("catalog","item:carp");await settle()
		var book: Control=world.hud.museum_panel
		for category: int in [0,2,3,5,6]:
			book.category_option.select(category);book._category_changed(category);await settle()
			check(root.get_visible_rect().encloses(book.item_list.get_global_rect()),"knowledge list fits "+str(screen)+str(category))
			await capture("knowledge-%d-%dx%d" % [category,screen.x,screen.y])
		book.close()
		world.hud.item_catalog_panel.open_panel();world.hud.item_catalog_panel._select_item("carp");await settle()
		check(world.hud.item_catalog_panel.detail_name.text=="尚待发现","portable guide uses discovery state")
		await capture("portable-guide-%dx%d" % [screen.x,screen.y]);world.hud.item_catalog_panel.close()
	root.size=Vector2i(1280,800)
	panel.open_panel("river","fishing");panel.start_cast();await settle()
	check(s.fishing_active(),"live fishing starts on map")
	if s.fishing_active():
		for frame: int in range(250):
			var g: Dictionary=s.fishing_session.game
			if g.stage=="fight":g.holding=clampf((float(g.fishPos)-float(g.barPos))*5,-.6,.6)>float(g.velocity)
			s._process_action(.04)
			if s.fishing_active() and str(s.fishing_session.game.stage)=="fight" and float(s.fishing_session.game.phaseTime)>2.0:break
		await capture("tracking-gameplay")
		for frame: int in range(1000):
			if not s.fishing_active():break
			var g: Dictionary=s.fishing_session.game
			if g.stage=="fight":g.holding=clampf((float(g.fishPos)-float(g.barPos))*5,-.6,.6)>float(g.velocity)
			s._process_action(.04)
		check(not s.fishing.pending.is_empty(),"actual GPU catch produces decision panel")
		await capture("catch-decision")
		panel._resolve(false)
		s.cancel_player_action()
	for i: int in range(4):
		var at: Dictionary=s.system_catalog.fishing.trapSlots[i]
		s.fishing.traps[str(at.id)]={"bait":"grain","baitedDay":-1,"lastDay":0,"product":{"fish":"shrimp","grade":1,"length":7,"producedDay":0,"water":str(at.water),"method":"trap"} if i%2==0 else {}}
	s.changed.emit();await capture("physical-traps")
	for d: int in [0,3,95]:
		s.day=d;s.minutes=1210 if d==0 else 800;s.clock_changed.emit();world._refresh();await capture("waterfront-"+s.weather_for(d)+("-night" if d==0 else ""))
	s.visual_fx.motion="reduced";world.queue_redraw();await capture("waterfront-reduced-motion")
	s.visual_fx.motion="full";s.day=0;s.minutes=800;s.fishing.pending={};s.ui_open=false
	for spot: Dictionary in s.system_catalog.fishing.spots:
		world.player.global_position=Vector2(float(spot.x),float(spot.y));s.player_position=world.player.global_position
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();s.clock_changed.emit();world._refresh()
		await capture("bank-"+str(spot.id))
	world.player.global_position=Vector2(749,2790);s.player_position=world.player.global_position;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	for direction: String in ["down","left","right","up"]:
		world.player.character_visual.facing={"down":Vector2.DOWN,"up":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}[direction]
		for pose: String in ["cast","waiting","bite","fight","caught"]:
			world.player.character_visual.set_fishing_pose(pose,0.6);await settle()
			check(bool(world.player.character_visual.painted_active),"painted fishing "+direction+pose)
		await capture("painted-fishing-"+direction)
	world.player.character_visual.set_fishing_pose("idle")

	var report:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/gpu-report.json",FileAccess.WRITE);report.store_string(JSON.stringify({"passed":passed,"failed":failed,"renderer":RenderingServer.get_video_adapter_name()},"  "));report.close()
	print("Fishing GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
