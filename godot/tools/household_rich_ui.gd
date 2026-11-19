extends SceneTree
var checks:int=0
func _initialize()->void:call_deferred("run")
func settle()->void:
	for frame:int in 8:await process_frame
func capture(name:String)->void:
	await settle();RenderingServer.force_draw();var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/home-ui";DirAccess.make_dir_recursive_absolute(out)
	assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.minutes=660;s.current_interior="building-farm-12";s.interior_position=Vector2(420,555)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);change_scene_to_file("res://scenes/interior.tscn");await settle()
	current_scene.player.set_physics_process(false);var hud:Node=current_scene.hud;var panel:Control=hud.house_activity_panel
	var inventory:Dictionary=s.inventory.duplicate(true);var owned:Array=s.building.layout.duplicate(true);var money:int=s.money
	panel.open_home_preview();await settle();assert(panel.visible and hud.ui_stack.active()==panel and hud._gamepad_panel()==panel);checks+=3;await capture("desktop-preview")
	hud.apply_source_gamepad({"kind":"activate"});await settle();assert(not panel.visible and s.interior_state.household.homePreset);checks+=2
	assert(s.money==money and s.inventory==inventory and s.building.layout==owned);checks+=3;await capture("desktop-installed")
	panel.open_home_preview();await settle();panel.choices.get_child(1).grab_focus();hud.apply_source_gamepad({"kind":"activate"});await settle()
	assert(not panel.visible and not s.interior_state.household.homePreset and s.building.layout==owned);checks+=3
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600);s.player_settings.textScale=1.3;root.get_node("UIArtService").apply_all(true);panel.open_home_preview();await capture("large-text-landscape")
	assert(root.get_visible_rect().grow(1).encloses(panel.paper.get_global_rect()));checks+=1
	for button:Button in panel.choices.get_children():assert(panel.paper.get_global_rect().grow(1).encloses(button.get_global_rect()));checks+=1
	hud.ui_stack.back();await settle();assert(not panel.visible and not s.ui_open and not s.interior_state.household.homePreset);checks+=3
	s.interior_position=Vector2(200,480);current_scene.player.position=s.interior_position
	hud.home_panel.open_panel();await settle();assert(not hud.home_panel.life_preview.disabled);checks+=1
	hud.home_panel.life_preview.pressed.emit();await settle();assert(panel.visible and panel.home_preview and not hud.home_panel.visible);checks+=3
	panel.choices.get_child(0).pressed.emit();await settle();assert(s.interior_state.household.homePreset);checks+=1
	panel.open_home_preview();panel.choices.get_child(1).pressed.emit();await settle();assert(not s.interior_state.household.homePreset);checks+=1
	# Returning to an existing activity restores its original layout and focus.
	s.current_interior="building-town-8";var point:Dictionary=load("res://scripts/house_geometry.gd").points(s.current_interior)[0];s.interior_position=Vector2(point.x,point.y)
	panel.open_panel(point);await settle();assert(not panel.home_preview and panel.preview.custom_minimum_size.y==90 and panel.choices.get_child(0).has_focus());checks+=3;panel.close()
	print("HOUSEHOLD_UI: ",checks," passed; keyboard/gamepad command and landscape touch simulation; no hardware certification")
	await root.get_node("AudioService").prepare_exit();quit()
