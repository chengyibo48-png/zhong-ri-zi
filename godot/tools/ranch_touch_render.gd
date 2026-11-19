extends SceneTree
var passed:=0
var failed:=0
var out:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle()->void:
	for i:int in 8:await process_frame
func shot(name:String)->void:
	await settle();RenderingServer.force_draw();check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"touch screenshot "+name)
func run()->void:
	check(OS.get_environment("ZRZ_FORCE_TOUCH")=="1","actual touch sizing policy")
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.source_input_mode="touch";s.flags.introDone=true;s.animals.clear();s.ranch.births=[];s.current_interior="";s.player_settings.textScale=1.25
	s.player_position=Vector2(2660,2800);root.size=Vector2i(1280,720)
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/ranch-touch";DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var panel:Control=current_scene.hud.ranch_panel;panel.open_panel()
	for i:int in panel.pages.get_tab_count():
		panel.pages.current_tab=i;await settle()
		check(root.get_visible_rect().encloses(panel.pages.get_global_rect()),"touch empty page fits "+str(i));await shot("empty-"+str(i))
	var animal:Dictionary=s._ranch_new_animal("cow","female","local",0);animal.name="小牛名字很长也能看清楚";panel.selected_animal_id=str(animal.id);panel.refresh();panel.pages.current_tab=1;await shot("long-name")
	panel._request_welcome({"action":"adopt:dog","pet":true});await shot("pet-adoption")
	check(panel.welcome_dialog.size.y<=root.get_visible_rect().size.y and panel.welcome_dialog.get_ok_button().size.y>=48,"touch adoption fits and primary button is large")
	panel.welcome_dialog.canceled.emit();panel.welcome_dialog.hide();panel.close()
	print("RANCH_TOUCH: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
