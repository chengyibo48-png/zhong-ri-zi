extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.minutes=720
	var folder:=OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-work";DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var checks:=0;var inverted:=0
	for id:String in ["chen","ning","luo"]:
		var room:="home-"+id;state.current_interior=room;state.interior_position=Vector2(400,530)
		var station:Dictionary=state.system_catalog.interiors.layouts[room].rows[0]
		var at:=Vector2(float(station.x),float(station.y)+24)
		change_scene_to_file("res://scenes/interior.tscn")
		for i in range(8):await process_frame
		var world:Node=current_scene;world.set_process(false);world.player.set_physics_process(false);world.player.hide();world.hud.hide();state.ui_open=false
		if world.owner_npc!=null:world.owner_npc.hide()
		world.player.camera.position_smoothing_enabled=false;world.player.global_position=at;world.player.camera.zoom=Vector2(2,2);world.player.camera.force_update_scroll()
		var actor:Node2D=load("res://scripts/character_visual.gd").new();world.add_child(actor);actor.configure(id);actor.position=at
		actor.work_contact=load("res://scripts/resident_work_pose.gd").describe(state,id,at,room,{"walking":false,"plan":{"key":"work"}})
		actor.set_pose(Vector2.UP,false);actor.set_working(true);actor.set_process(false)
		if actor.work_contact.is_empty():push_error("Authored workstation missing "+id);quit(1);return
		for frame in range(24):
			actor._process(1.0/24);actor.set_process(false)
			await process_frame;await RenderingServer.frame_post_draw
			var mesh:ArrayMesh=actor.get_meta("resident_mesh_ref");var vertices:PackedVector2Array=mesh.get_meta("vertices");var indices:PackedInt32Array=mesh.get_meta("indices")
			for i in range(0,indices.size(),3):
				var a:=vertices[indices[i]];var b:=vertices[indices[i+1]];var c:=vertices[indices[i+2]]
				if not a.is_finite() or (b-a).cross(c-a)>=0:inverted+=1
			if not actor.has_meta("resident_work_hand"):push_error("Work hand missing "+id);quit(1);return
			assert(root.get_texture().get_image().save_png(folder+"/"+id+"-%03d.png"%frame)==OK);checks+=1
		actor.set_sequence_snapshot({"kind":"greet","duration":1.0,"progress":.35})
		actor._process(1.0/24);actor.set_process(false);await process_frame;await RenderingServer.frame_post_draw
		if str(actor.get_meta("resident_clip",""))!="greet" or actor.has_meta("resident_work_target"):
			push_error("Explicit interaction must override ambient work "+id);quit(1);return
		checks+=1
	print("RESIDENT_WORK_GPU frames=",checks," identities=3 inverted=",inverted)
	await root.get_node("AudioService").prepare_exit();quit(1 if inverted else 0)
