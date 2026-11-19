extends SceneTree
var s:Node
var passed:=0
var failed:=0
var out:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle(count:int=8)->void:
	for i:int in count:await process_frame
func shot(name:String)->void:
	await settle();RenderingServer.force_draw();check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"GPU "+name)
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.day=30;s.minutes=600;s.money=10000;s.stamina=100;s.animals.clear();s.ranch.births=[]
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;s.ranch.barns[id].comfort=2;s.ranch.barns[id].clean=100
	var m:Dictionary=s._ranch_new_animal("cow","female","local",40);var f:Dictionary=s._ranch_new_animal("cow","male","local",40)
	var baby:Dictionary=s._ranch_new_animal("cow","female","local",0,[m.id,f.id]);baby.nurseryUntil=s.day+2
	s.ranch.births=[{"id":"visual-birth","type":"sheep","mother":null,"father":null,"breed":"local","remaining":4,"total":6,"pausedDays":1,"protected":false,"pauseReason":"畜舍需清扫"}]
	s.player_position=Vector2(2660,2800);root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/ranch";DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn");await settle(18)
	var panel:Control=current_scene.hud.ranch_panel;panel.open_panel();await settle()
	check(panel.pages.get_tab_count()==6,"separate nursery and pet pages retain production and daily pages")
	panel.pages.current_tab=4;await shot("nursery-journal")
	var before:int=s.money;panel._request_welcome({"barnId":"cattle","action":"purchase","arg":["cow","female","local",true]});await shot("adoption-preview")
	check(s.money==before and panel.welcome_dialog.visible,"adoption preview does not charge")
	current_scene.hud.apply_source_gamepad({"kind":"close"});check(panel.welcome_task.is_empty() and not panel.welcome_dialog.visible,"gamepad cancel clears stale confirmation without charge")
	panel.pages.current_tab=5;panel._request_welcome({"pet":true,"action":"adopt:dog"});await shot("pet-adoption")
	current_scene.hud.apply_source_gamepad({"kind":"horizontal","value":1});current_scene.hud.apply_source_gamepad({"kind":"activate"})
	check(panel.welcome_task.is_empty() and not panel.welcome_dialog.visible,"gamepad cancel button does not adopt")
	s.ranch.birthHistory=[{"id":"ui-birth","animalId":baby.id,"day":s.day,"kind":"gestation","parents":[m.id,f.id],"seen":false}]
	panel._view_newborn();check(panel.selected_animal_id==str(baby.id) and bool(s.ranch.birthHistory[0].seen),"birth record opens exact newborn for later naming")
	panel.pages.current_tab=1
	panel.selected_animal_id=str(m.id);panel.refresh();await settle();panel.animal_name.grab_focus();panel.animal_name.text="正在输入的名字";panel.refresh();await settle()
	check(panel.animal_name.text=="正在输入的名字" and panel.animal_name.has_focus(),"refresh retains edited name and focus")
	panel.close();s.ui_open=false
	# Actual interior with the original fixtures, mother and independently modeled calf.
	s.current_interior="building-pasture-17";s.interior_position=Vector2(480,530);s.ranch.policy="inside"
	change_scene_to_file("res://scenes/interior.tscn");await settle(16)
	current_scene.hud.hide();current_scene.player.set_physics_process(false)
	m.position.inside={"x":395,"y":490,"direction":"right"};f.position.inside={"x":650,"y":490,"direction":"left"};baby.position.inside={"x":360,"y":510,"direction":"right"}
	var movies:bool=OS.get_environment("ZRZ_RANCH_MOVIES")=="1";var folder:String=out+"/family-motion"
	if movies:DirAccess.make_dir_recursive_absolute(folder)
	var trace:Array=[]
	for frame:int in 360:
		root.mode=Window.MODE_WINDOWED;s.mobile_orientation_blocked=false;s.ui_open=false
		if frame==120:m.position.inside.direction="left"
		if frame==200:s.ranch_holds[str(m.id)]=s.ranch_actor_clock+4
		s.advance_ranch_movement(1.0/24);await process_frame
		var sample:Dictionary=s.animal_behavior.samples.get(str(baby.id),{})
		trace.append({"frame":frame,"phase":sample.get("phase",0),"action":sample.get("action",""),"position":baby.position.inside.duplicate(),"feet":str(sample.get("foot_offsets",[]))})
		if movies:RenderingServer.force_draw();root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg"%frame,.94)
		if frame in [0,100,230,359]:await shot("family-"+str(frame))
	check(not s.animal_behavior.samples.is_empty(),"actual world advances behavior samples")
	check(baby.position.room==m.position.room,"young calf remains in safe parent room")
	var file:=FileAccess.open(out+"/family-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace));file.close()
	current_scene.hud.show();var layout:Control=current_scene.hud.ranch_panel;layout.open_panel();s.player_settings.textScale=1.25;s.changed.emit();await shot("large-text-journal")
	check(layout.get_global_rect().size.x<=root.get_visible_rect().size.x+1,"journal stays within viewport")
	print("RANCH_DEEPENING_GPU: %d passed, %d failed; movies="%[passed,failed],movies)
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
