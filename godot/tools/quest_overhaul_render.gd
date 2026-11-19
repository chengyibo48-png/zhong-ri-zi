extends SceneTree
var s:Node
var w:Node
var passed:=0
var failed:=0
var output:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle()->void:
	for i:int in 12:await process_frame
func capture(name:String)->void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"GPU screenshot "+name)
func run()->void:
	output=OS.get_environment("ZRZ_ART_OUTPUT")+("/task-ui-touch" if OS.get_environment("ZRZ_FORCE_TOUCH")=="1" else "/task-ui-desktop");DirAccess.make_dir_recursive_absolute(output)
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.current_interior="";s.ui_open=false;s.player_position=Vector2(2500,1800);s.minutes=600
	for id:String in s.relations:s.relations[id].talked=0
	s.changed.emit();root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene
	var panel:Control=w.hud.life_plan_panel
	for tab:String in ["main","people","life","today","done"]:
		panel.open_panel("",tab);await capture("desktop-"+tab)
		check(panel.task_list.item_count>0 or tab=="done","task section populated "+tab)
		check(panel.task_list.get_global_rect().end.x<root.get_visible_rect().end.x,"task list fits viewport "+tab)
	panel.open_panel("story:granny:0","active");await settle()
	check(panel.active_tab=="people" and panel.selected_id=="story:granny:0","legacy focus call opens correct story section")
	await capture("desktop-story-detail")
	panel.open_panel("wish:firstDish");await settle()
	var remembered:String=panel.selected_id;var scroll:int=panel.detail_scroll.scroll_vertical
	s.money+=1;s.changed.emit();await settle()
	check(panel.selected_id==remembered and panel.detail_scroll.scroll_vertical==scroll,"domain refresh preserves selected task and scroll")
	s.player_settings.textScale=1.25;s.source_input_mode="touch";s.changed.emit()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	panel.open_panel("", "main");await capture("touch-large-main")
	for button:Node in panel.action_dock.get_children():
		if button is Button:check(button.size.y>=48 or OS.get_environment("ZRZ_FORCE_TOUCH")!="1","touch action height")
	s.npc_stories.lan={"step":1,"choices":[0],"lastDay":0};s.relations.lan.points=10
	w.hud.ui_stack.leave();w.hud.show_npc_story("lan");await capture("child-observation")
	check(str(w.hud.npc_story_panel.last_view.activity.kind)=="read","child cooperation uses a safe observation action")
	w.hud.ui_stack.leave()
	# Real visible controller approach and handoff; fixed samples are for visual review only.
	s.player_settings.textScale=1.0;s.current_interior="";s.inventory.greens=1;s.inventory.beanSeed=0;s.flags.firstDish=false
	s.economy.locked=[];s._reconcile_kitchen_lots();s.quest_accept("wish:firstDish");s.ui_open=false
	var npc:Vector2=s.npc_positions.get("granny",Vector2(750,2700))
	s.player_position=npc+Vector2(-110,0);w.player.global_position=s.player_position;w.player.camera.reset_smoothing()
	s.quest_runtime.set_process(false)
	var destination:Dictionary=s.npc_destination("granny");destination.auto_interact=false
	w.player.walk_to(destination)
	var started:=false;var frames:String=output+"/handoff";DirAccess.make_dir_recursive_absolute(frames)
	for i:int in 144:
		root.mode=Window.MODE_WINDOWED;s.ui_open=false;s.mobile_orientation_blocked=false
		npc=s.npc_positions.get("granny",npc)
		if not started:
			if s.npc_is_near("granny"):
				s.source_keyboard.clear();started=s.quest_submit("wish:firstDish")
			elif i%24==0:w.player.walk_to(s.npc_destination("granny"))
		s.advance_simulation_frame(1.0/24.0,w.player)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(frames+"/frame-%04d.png"%i)
	s.source_keyboard.clear()
	print("HANDOFF_DIAGNOSTIC started=",started," final=",s.flags.firstDish," distance=",s.player_position.distance_to(npc)," message=",s.message)
	check(started and bool(s.flags.firstDish),"visible real controller approach and handoff settles")
	print("QUEST_UI_GPU: %d passed, %d failed; handoff_frames=144"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
