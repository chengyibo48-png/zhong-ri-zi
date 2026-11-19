extends SceneTree
var trace:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.minutes=720;state.current_interior=""
	state.player_position=Vector2(3150,2185);state.ui_hud_visible=false
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(8):await process_frame
	var world:Node=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	var player:Node2D=world.player;player.set_physics_process(false)
	player.camera.zoom=Vector2(2,2);player.camera.position_smoothing_enabled=false
	var visual:Node=player.character_visual;visual.set_process(false)
	var stage:=OS.get_environment("ZRZ_REVIEW_STAGE")
	var folder:=OS.get_environment("ZRZ_ART_OUTPUT")+"/grounded-"+stage;DirAccess.make_dir_recursive_absolute(folder)
	for frame in range(240):
		state.source_keyboard.clear()
		var key:=""
		if frame<48:key="arrowright"
		elif frame>=60 and frame<96:key="arrowleft" if (frame/4)%2==0 else "arrowright"
		elif frame>=96 and frame<132:key="arrowleft";state.source_keyboard.keys.shift=true
		elif frame>=192:key="arrowup"
		if key!="":state.source_keyboard.keys[key]=true
		player.advance_player_frame(1.0/24)
		if frame>=144 and frame<192:
			var at:Vector2=player.global_position+Vector2(20,0)
			visual.set_pose(Vector2.RIGHT,false)
			visual.set_sequence_snapshot({"kind":"hoe","duration":2.0,"progress":(frame-144)/48.0,"x":at.x,"y":at.y})
		elif frame==192:visual.set_sequence_snapshot({})
		visual._process(1.0/24);visual.set_process(false)
		player.camera.force_update_scroll()
		await process_frame;await RenderingServer.frame_post_draw
		var feet:Array=[]
		for foot:Vector2 in visual.wardrobe.rig_frame.get("feet",[]):
			var at:Vector2=visual.wardrobe.to_global(foot);feet.append([at.x,at.y])
		trace.append({"frame":frame,"position":[player.global_position.x,player.global_position.y],"feet":feet,"phase":visual.player_locomotion.stride_phase,"direction":[visual.facing.x,visual.facing.y],"turn_weight":visual.player_locomotion.snapshot().get("turn_weight",1)})
		assert(root.get_texture().get_image().save_png(folder+"/frame-%04d.png"%frame)==OK)
	var file:=FileAccess.open(folder+"/trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace));file.close()
	print("GROUNDED_REVIEW 240 native frames at 24Hz; real controller, quick reversals, stop, fast walk, tool recovery; stage=",stage)
	await root.get_node("AudioService").prepare_exit();quit()
