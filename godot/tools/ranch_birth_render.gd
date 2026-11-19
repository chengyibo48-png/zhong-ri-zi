extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.animals.clear();s.ranch.births=[];s.ranch.birthHistory=[];s.ranch.settledDay=-1;s.day=30;s.minutes=600;s.money=10000;s.stamina=100;s.inventory.grainFeed=100;s.ranch.policy="inside";s.ui_open=false
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;s.ranch.barns[id].clean=100;s.ranch.barns[id].comfort=2
	var mother:Dictionary=s._ranch_new_animal("cow","female","local",40);var father:Dictionary=s._ranch_new_animal("cow","male","local",40)
	check(s.perform_ranch_task({"action":"breed","arg":[mother.id,father.id],"receipt":"birth-film-pair"}),"actual pair transaction prepares birth")
	s.ranch.births[0].remaining=1
	mother.position.inside={"x":395,"y":490,"direction":"right"};father.position.inside={"x":650,"y":490,"direction":"left"}
	s.current_interior="building-pasture-17";s.interior_position=Vector2(480,530);root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/interior.tscn")
	for i:int in 16:await process_frame
	current_scene.player.set_physics_process(false);current_scene.hud.hide()
	var cash:int=s.money;check(s.perform_ranch_task({"action":"purchase","arg":["cow","female","local",true],"name":"新来的小牛","receipt":"birth-film-adopt"}),"actual purchase charges once before arrival")
	var paid:int=s.money;check(paid<cash and s.animals.size()==3,"arrival does not defer successful purchase")
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/birth";DirAccess.make_dir_recursive_absolute(out)
	var movies:bool=OS.get_environment("ZRZ_RANCH_MOVIES")=="1";var folder:String=out+"/arrival-birth-motion"
	if movies:DirAccess.make_dir_recursive_absolute(folder)
	for frame:int in 288:
		if frame==144:
			s.day+=1;s._advance_ranch(0,"晴",s.minutes);s.changed.emit()
			check(s.animals.size()==4 and s.ranch.births.is_empty() and s.ranch.birthHistory.size()==1,"visible daily settlement creates exactly one newborn")
			check(bool(mother.rest) and int(mother.postpartumUntil)==s.day+2,"mother enters recovery without blocking play")
		root.mode=Window.MODE_WINDOWED;s.ui_open=false;s.mobile_orientation_blocked=false;s.advance_ranch_movement(1.0/24);await process_frame
		if movies:RenderingServer.force_draw();root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg"%frame,.94)
		if frame in [0,143,145,287]:RenderingServer.force_draw();check(root.get_texture().get_image().save_png(out+"/frame-%03d.png"%frame)==OK,"arrival birth GPU capture")
	check(s.money==paid,"arrival and newborn presentation add no transaction charge")
	print("RANCH_BIRTH_GPU: %d passed, %d failed; movies="%[passed,failed],movies);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
