extends SceneTree
var checks:int=0
func _initialize()->void:call_deferred("run")
func settle()->void:
	for frame:int in 8:await process_frame
func capture(name:String)->void:
	await settle();RenderingServer.force_draw()
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/activity-ui";DirAccess.make_dir_recursive_absolute(out)
	assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.minutes=660;s.current_interior="building-town-8"
	var point:Dictionary=load("res://scripts/house_geometry.gd").points(s.current_interior)[0];s.interior_position=Vector2(point.x,point.y)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);change_scene_to_file("res://scenes/interior.tscn");await settle()
	current_scene.player.set_physics_process(false)
	var hud:Node=current_scene.hud;var panel:Control=hud.house_activity_panel
	current_scene._interact_target(point);await settle()
	assert(panel.visible and hud.ui_stack.active()==panel and hud._gamepad_panel()==panel);checks+=3
	await capture("desktop-choice")
	hud.apply_source_gamepad({"kind":"activate"});await settle();assert(panel.slider.visible and panel.slider.has_focus());checks+=2
	var value:float=panel.slider.value
	hud.apply_source_gamepad({"kind":"horizontal","value":1});await process_frame
	# The native source command calls this branch 'horizontal'; keyboard slider input
	# is also exercised directly through Godot's GUI event system.
	var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(panel.slider.value>value);checks+=1
	await capture("desktop-alignment")
	panel.slider.value=float(s.house_activity.active.view.steps[1].target);panel.confirm.pressed.emit();await settle()
	assert(s.house_activity.active.step==2);checks+=1
	panel.choices.get_child(1).pressed.emit();await settle();assert(s.action_busy() and not panel.visible);checks+=2
	var time:float=s.minutes
	assert(hud._gamepad_panel()==hud.action_progress);checks+=1
	hud.action_progress.skip_button.grab_focus();hud.apply_source_gamepad({"kind":"activate"})
	assert(not s.action_busy());checks+=1
	for i:int in 30:s._process_action(.1)
	assert(s.minutes==time+5);checks+=1
	await capture("desktop-keepsake")
	s.minutes=660;current_scene._interact_target(point);await settle();hud.ui_stack.back();await settle()
	assert(not panel.visible and s.house_activity.active.is_empty() and s.minutes==660);checks+=3
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600);s.player_settings.textScale=1.3;root.get_node("UIArtService").apply_all(true)
	current_scene._interact_target(point);await capture("small-large-text");assert(root.get_visible_rect().grow(1).encloses(panel.paper.get_global_rect()));checks+=1
	panel.close();s.player_settings.contrast=true;root.get_node("UIArtService").apply_all(true);current_scene._interact_target(point);await capture("high-contrast");panel.close()
	print("HOUSE_ACTIVITY_UI: ",checks," checks passed; native controls and gamepad command path; no hardware certification")
	await root.get_node("AudioService").prepare_exit();quit()
