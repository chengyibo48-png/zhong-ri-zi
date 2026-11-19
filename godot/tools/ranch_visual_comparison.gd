extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.animals.clear();s.ranch.births=[];s.day=30;s.minutes=600;s.ui_open=false;s.ranch.policy="inside"
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3
	var mother:Dictionary=s._ranch_new_animal("cow","female","local",40)
	var calf:Dictionary=s._ranch_new_animal("cow","female","local",0,[mother.id])
	mother.position.room="building-pasture-17";mother.position.inside={"x":395,"y":490,"direction":"right"}
	calf.position.room="building-pasture-17";calf.position.inside={"x":360,"y":510,"direction":"right"}
	s.current_interior="building-pasture-17";s.interior_position=Vector2(480,530)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/interior.tscn")
	for i:int in 16:await process_frame
	current_scene.hud.hide();current_scene.player.set_physics_process(false);current_scene.player.camera.zoom=Vector2.ONE*1.35;current_scene.player.camera.reset_smoothing()
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/comparison-"+OS.get_environment("ZRZ_REVIEW_STAGE");DirAccess.make_dir_recursive_absolute(out)
	for frame:int in 96:
		if frame>0:s.advance_ranch_movement(1.0/24)
		await process_frame
		if frame in [0,48,95]:
			RenderingServer.force_draw();var code:int=root.get_texture().get_image().save_png(out+"/frame-%03d.png"%frame)
			if code!=OK:printerr("FAIL comparison screenshot");quit(1);return
	print("RANCH_COMPARISON: 3 actual scene screenshots saved");await root.get_node("AudioService").prepare_exit();quit()
