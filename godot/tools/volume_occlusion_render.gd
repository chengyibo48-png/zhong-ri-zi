extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.minutes=720;state.current_interior=""
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(8):await process_frame
	var world:Node=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	var player:Node2D=world.player;player.set_physics_process(false);player.camera.position_smoothing_enabled=false;player.camera.zoom=Vector2(2,2)
	var subjects:Dictionary={}
	for child:Node in world.get_children():
		if child.get_script()!=load("res://scripts/world_prop.gd"):continue
		var kind:=str(child.data.get("kind",""))
		if kind=="tree" and not subjects.has("tree") and child.global_position.distance_to(Vector2(2800,1800))<600:subjects.tree=child
		if kind=="house" and not subjects.has("roof") and child.global_position.distance_to(Vector2(2800,1800))<600:subjects.roof=child
	var greenhouse:Node2D=load("res://scripts/built_furniture_visual.gd").new();greenhouse.configure(world,{"type":"greenhouse","rotation":0,"zone":"yard","key":99999},Rect2(3050,2250,100,100));world.add_child(greenhouse);subjects.greenhouse=greenhouse
	var folder:=OS.get_environment("ZRZ_ART_OUTPUT")+"/volume";DirAccess.make_dir_recursive_absolute(folder)
	check(subjects.size()==3,"tree, real authored house and greenhouse are represented")
	for key:String in subjects:
		var node:Node2D=subjects[key]
		for behind in [true,false]:
			var at:Vector2=node.global_position+Vector2(0,-45 if behind else 20)
			if key!="greenhouse":
				var rect:Rect2=node._occlusion_rect
				if behind:at=node.global_position+Vector2(rect.get_center().x,rect.position.y+rect.size.y*.5)
				node._on_screen=true;node._visibility_elapsed=0
			player.global_position=at;player.camera.force_update_scroll()
			for i in range(12):
				node._process(1.0/24)
				await process_frame
			await create_timer(.16).timeout;await RenderingServer.frame_post_draw
			check(is_equal_approx(node.modulate.a,1),"foundation and trunk retain original node opacity "+key)
			check(node._canopy_alpha<.9 if behind else node._canopy_alpha>.9,"upper occlusion follows player depth "+key+str(behind))
			assert(root.get_texture().get_image().save_png(folder+"/"+key+("-behind" if behind else "-front")+".png")==OK)
	print("VOLUME_GPU: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
