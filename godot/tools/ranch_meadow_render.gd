extends SceneTree
var s:Node
var out:String
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle(count:int=8)->void:
	for i:int in count:await process_frame
func shot(name:String)->void:
	await settle();RenderingServer.force_draw();check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"GPU "+name)
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.ui_open=false;s.animals.clear();s.ranch.births=[];s.day=0;s.minutes=600;s.ranch.policy="day"
	var meadow:Script=load("res://scripts/ranch_meadow.gd");meadow.ensure(s);s.ranch.meadowEnabled=true;s.ranch.meadowAssignments={}
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;s.ranch.barns[id].clean=100;s.ranch.barns[id].comfort=2
	for type_id:String in ["cow","cow","sheep","goat","hen","duck","pig","rabbit"]:
		for i:int in 4:
			var animal:Dictionary=s._ranch_new_animal(type_id,"female" if i%2==0 else "male","local",40);var row:Dictionary=meadow.assignment(s,animal);var at:Vector2=meadow.stand(row)
			animal.position.room=meadow.ID;animal.position.inside={"x":at.x,"y":at.y,"direction":"down"}
	s.current_interior=meadow.ID;s.interior_position=meadow.EXIT;root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/meadow";DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/meadow.tscn");await settle(15)
	var world:Node=current_scene;world.player.set_physics_process(false);world.player.camera.zoom=Vector2.ONE*.28;world.player.position=Vector2(1536,1024);s.interior_position=world.player.position;world.player.camera.reset_smoothing()
	await shot("eight-fields-overview");check(world.animal_nodes.size()==32,"all active animals render in expanded region")
	world.show_meadow_map();await shot("eight-fields-map");check(world.hud.ui_stack.active()==world.meadow_map,"meadow map joins shared keyboard pad back stack")
	world.hud.close_top_panel();await settle();check(not s.ui_open,"map back restores play")
	world.player.camera.zoom=Vector2.ONE*1.35;world.player.position=Vector2(420,400);s.interior_position=world.player.position;world.player.camera.reset_smoothing()
	await shot("cattle-field-natural-scale")
	var movies:bool=OS.get_environment("ZRZ_RANCH_MOVIES")=="1";var folder:String=out+"/grazing-motion";if movies:DirAccess.make_dir_recursive_absolute(folder)
	var trace:Array=[]
	for frame:int in 288:
		root.mode=Window.MODE_WINDOWED;s.ui_open=false;s.mobile_orientation_blocked=false;s.advance_ranch_movement(1.0/24);await process_frame
		var min_gap:float=100000
		for i:int in s.animals.size():
			for j:int in range(i+1,s.animals.size()):
				var a:Dictionary=s.animals[i].position.inside;var b:Dictionary=s.animals[j].position.inside
				min_gap=minf(min_gap,Vector2(float(a.x),float(a.y)).distance_to(Vector2(float(b.x),float(b.y))))
		check(min_gap>=9,"distributed grazing minimum gap frame "+str(frame))
		trace.append({"frame":frame,"minimum_gap":min_gap})
		if movies:RenderingServer.force_draw();root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg"%frame,.94)
		if frame==100:await shot("distributed-grazing")
	var f:=FileAccess.open(out+"/spacing-trace.json",FileAccess.WRITE);f.store_string(JSON.stringify(trace));f.close()
	world.player.position=Vector2(float(s.animals[0].position.inside.x),float(s.animals[0].position.inside.y))+Vector2(0,40)
	world._cycle_room_target(1);check(not world.selected_room_target.is_empty(),"gamepad cycles real nearby meadow target")
	var field:Rect2=meadow.pen(0);var picked:Dictionary=world.resolve_interaction_target({"id":str(s.animals[0].id),"kind":"animal"});check(not picked.is_empty(),"animal interaction follows actual meadow location")
	var saved:Dictionary=s._make_save_data().duplicate(true);check(s.load_game_data(saved),"live meadow state save round trip "+s.message)
	s.minutes=1260;s.clock_changed.emit();s.changed.emit();await shot("meadow-night")
	s.minutes=600;s.ranch.policy="inside"
	for frame:int in 360:s.advance_ranch_movement(.1)
	check(s.animals.any(func(a:Dictionary):return a.position.room!=meadow.ID),"recall uses exit and barn routes")
	print("RANCH_MEADOW_GPU: %d passed, %d failed; movies="%[passed,failed],movies);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
