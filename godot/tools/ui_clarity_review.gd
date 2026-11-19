extends SceneTree
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void:call_deferred("run")
func check(ok:bool, text:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func settle() -> void:
	for frame:int in 10:await process_frame
func shot(name:String) -> void:
	await settle()
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"capture "+name)
func bounds(panel:Control,label:String) -> void:
	for child:Node in panel.get_children():
		if child is PanelContainer and child.visible:
			check(root.get_visible_rect().grow(1).encloses(child.get_global_rect()),label+" window inside viewport: "+str(child.get_global_rect()))
func run() -> void:
	create_timer(150).timeout.connect(func():quit(1))
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/ui"
	if OS.get_environment("ZRZ_FORCE_TOUCH")=="1":out+="/touch"
	DirAccess.make_dir_recursive_absolute(out)
	var s:Node=root.get_node("GameState")
	s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.ui_open=false;s.current_interior="";s.day=30;s.minutes=660
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var hud:Node=current_scene.hud
	current_scene.player.set_physics_process(false)
	await shot("desktop-hud")
	hud.life_menu.open_panel();await shot("desktop-menu");bounds(hud.life_menu,"desktop menu")
	check(hud.life_menu.grid.columns==2,"desktop uses two content columns")
	hud.life_menu._group("经营");await shot("desktop-menu-business")
	hud.ui_stack.leave()
	hud.life_plan_panel.open_panel();await shot("desktop-quests");hud.ui_stack.leave()
	s.npc_stories.chen={"step":1,"choices":[0],"lastDay":-1};s.relations.chen.points=10
	hud.npc_story_panel.open_panel("chen");await settle();hud.npc_story_panel.quote.visible_characters=-1
	await shot("desktop-story")
	check(hud.npc_story_panel.close_button.has_focus(),"story close focus preserved")
	hud.npc_story_panel.refresh();await settle()
	check(hud.npc_story_panel.quote.visible_characters==-1,"story refresh preserves text reveal")
	hud.ui_stack.leave()
	hud.npc_dialogue.open_panel("chen");await shot("desktop-dialogue");hud.ui_stack.leave()
	hud.show_market("inventory",false);await shot("desktop-inventory");hud.ui_stack.leave()
	hud.sleep_panel.open_panel();await shot("desktop-sleep");hud.ui_stack.leave()
	for entry:Array in [["show_ranch","ranch_panel","ranch"],["show_fishing","fishing_panel","fishing"],["show_settings","settings_panel","settings"],["show_map","map_panel","map"],["show_home","home_panel","home"],["show_kitchen","kitchen_panel","kitchen"]]:
		hud.call(str(entry[0]));await shot("desktop-"+str(entry[2]));bounds(hud.get(str(entry[1])),str(entry[2]));hud.ui_stack.leave()
	hud.show_settings()
	for id:String in ["画面","生活","声音","操作","形象"]:
		hud.settings_panel._settings_group(id,true);await settle()
		for child:Control in hud.settings_panel.controls.get_children():check(child.visible==(str(child.get_meta("settings_group","生活"))==id),"only controls of selected settings category visible")
		check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().is_visible_in_tree(),"settings category has visible focus")
	var form:Dictionary=hud.settings_panel._appearance_form()
	var before_look:Dictionary=s.appearance.duplicate(true)
	form.name="界面验收";form.shirt=(int(form.shirt)+1)%4
	hud.settings_panel._restore_appearance_form(form)
	check(s.appearance==before_look,"editing appearance does not commit early")
	hud.settings_panel.appearance_apply_button.pressed.emit()
	check(s.action_busy() and not hud.settings_panel.visible,"appearance starts original action")
	s.cancel_action();await settle()
	check(s.appearance==before_look and hud.settings_panel._appearance_form()==form,"cancel keeps appearance and draft")
	check(hud.settings_panel.appearance_apply_button.has_focus() and hud.settings_panel.appearance_apply_button.is_visible_in_tree(),"cancel restores visible appearance focus")
	hud.settings_panel.appearance_apply_button.pressed.emit()
	for step:int in 35:s._process_action(0.1)
	await settle()
	check(s.player_name=="界面验收" and int(s.appearance.shirt)==int(form.shirt),"appearance completes through original settlement")
	check(hud.settings_panel.appearance_apply_button.has_focus(),"complete restores submit focus")
	check(s.load_game(s.SAVE_PATH) and s.player_name=="界面验收","appearance save reload in isolated directory")
	hud.ui_stack.leave()
	root.size=Vector2i(720,1280);root.content_scale_size=Vector2i(720,1280);s.player_settings.textScale=1.35
	root.get_node("UIArtService").apply_all(true);hud.refresh();await settle()
	hud.life_menu.open_panel();await shot("portrait-menu");bounds(hud.life_menu,"portrait menu");check(hud.life_menu.grid.columns==1,"portrait uses one content column");hud.ui_stack.leave()
	hud.npc_story_panel.open_panel("chen");await settle();hud.npc_story_panel.quote.visible_characters=-1
	await shot("portrait-story");bounds(hud.npc_story_panel,"portrait story");hud.ui_stack.leave()
	hud.life_plan_panel.open_panel();await shot("portrait-quests");bounds(hud.life_plan_panel,"portrait journal");hud.ui_stack.leave()
	hud.show_market("inventory",false);await shot("portrait-inventory");bounds(hud.market_panel,"portrait bag");hud.ui_stack.leave()
	for entry:Array in [["show_ranch","ranch_panel","ranch"],["show_fishing","fishing_panel","fishing"],["show_settings","settings_panel","settings"]]:
		hud.call(str(entry[0]));await shot("portrait-"+str(entry[2]));bounds(hud.get(str(entry[1])),"portrait "+str(entry[2]));hud.ui_stack.leave()
	for skin:String in ["timber","porcelain","paper"]:
		s.ui_art.theme=skin;root.get_node("UIArtService").apply_all(true)
		hud.life_menu.open_panel();await settle();bounds(hud.life_menu,skin+" theme")
		check(hud.life_menu.group_buttons[hud.life_menu.active_group].get_theme_color("font_color").a>0.9,"category readable in "+skin);hud.ui_stack.leave()
	s.player_settings.textScale=1.0;root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
	root.get_node("UIArtService").apply_all(true);await settle()
	hud.life_menu.open_panel();await shot("small-menu");hud.ui_stack.leave()
	# Open a child screen from a focused menu card and return through the real
	# modal stack. Category, scroll and focus identity must survive.
	hud.life_menu.open_panel();hud.life_menu._group("随身");await settle()
	hud.life_menu.buttons.bag.grab_focus();hud.life_menu.buttons.bag.pressed.emit();await settle()
	check(hud.ui_stack.active()==hud.market_panel,"menu card enters bag through existing route")
	hud.ui_stack.back();await settle()
	check(hud.ui_stack.active()==hud.life_menu,"back returns to menu")
	check(hud.life_menu.buttons.bag.has_focus(),"back restores originating card focus")
	hud.ui_stack.leave()
	print("UI_CLARITY_REVIEW: ",checks," checks; ",failures," failures")
	await root.get_node("AudioService").prepare_exit();quit(1 if failures else 0)
