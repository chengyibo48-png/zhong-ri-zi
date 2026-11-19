extends SceneTree
var passed := 0
var failed := 0
var state: Node
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func settle() -> void:
	for i in range(8):await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"Actual scene capture "+name)
func place(player: Node2D,at: Vector2) -> void:
	player.global_position=at;state.player_position=at
func run() -> void:
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	create_timer(100,true,false,true).timeout.connect(func():quit(1))
	state=root.get_node("GameState");state.set_process(false)
	state.flags.introDone=true;state.ui_hud_visible=false;state.minutes=720
	output=OS.get_environment("ZRZ_ART_OUTPUT")
	if output=="":output="user://player-rig-integration"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
	var world:Node=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	var player:Node2D=world.player;player.set_physics_process(false)
	var visual:Node=player.character_visual;visual.set_process(false)
	var money:int=state.money;var inventory:Dictionary=state.inventory.duplicate(true)
	var start:=Vector2(3150,2185)
	var distances:Array[float]=[]
	for fast in [false,true]:
		place(player,start);visual.set_locomotion_sample(Vector2(500,0),.016)
		state.source_keyboard.keys={"arrowright":true}
		if fast:state.source_keyboard.keys.shift=true
		var traveled:=0.0
		for i in range(15):
			var before:Vector2=player.global_position
			player.advance_player_frame(1.0/60.0);visual._process(1.0/60.0)
			traveled+=player.global_position.distance_to(before)
		check(traveled>1,"Actual controller moves "+str(fast))
		check(is_equal_approx(float(visual.player_locomotion.stride_phase),fposmod(traveled/float(visual.player_locomotion.effective_stride),1.0)),"Actual distance owns gait phase "+str(fast))
		distances.append(traveled)
	check(distances[1]>distances[0],"Fast movement produces proportionally faster gait")
	state.source_keyboard.clear();player.advance_player_frame(1.0/60.0);visual._process(.12)
	check(is_zero_approx(float(visual.player_locomotion.walk_weight)),"Actual stop settles to standing")
	var phase:float=visual.player_locomotion.stride_phase
	for i in range(10):player.pause_player_frame();visual._process(1.0/60.0)
	check(is_equal_approx(phase,float(visual.player_locomotion.stride_phase)),"Paused player cannot shuffle feet")
	# Scene replacement creates a new presentation instance, with no old stride.
	var home:Node=load("res://scripts/interior_world.gd").new()
	var home_id:String=home._grandfather_house_id();home.free()
	state.current_interior=home_id;state.interior_position=Vector2(480,540)
	change_scene_to_file("res://scenes/interior.tscn");await settle()
	world=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	player=world.player;player.set_physics_process(false);visual=player.character_visual;visual.set_process(false)
	check(is_zero_approx(float(visual.player_locomotion.stride_phase)),"New room starts without teleport stride")
	visual.set_pose(Vector2.DOWN,false);visual.queue_redraw();await capture("player-home-normal")
	visual.redraw_count=0;visual.walk_clock=0;visual.last_animation_frame=-1
	for i in range(60):
		visual.set_sequence_snapshot({"kind":"hoe","duration":1.0,"progress":float(i)/60.0})
		visual._process(1.0/60.0)
	check(visual.redraw_count<=25 and visual.redraw_count>=23,"Steady action presentation stays at 24 Hz")
	visual.set_sequence_snapshot({});visual.action_state="";visual.queue_redraw()
	var wardrobe:Node=visual.wardrobe
	var art:Script=load("res://scripts/painted_wardrobe.gd")
	var manifest:Dictionary=art.data();var original:Dictionary=manifest.packs.field.parts.down.arm_right
	art._resolved.clear();manifest.packs.field.parts.down.erase("arm_right")
	check(not wardrobe.present(state.appearance,visual.appearance,"idle","down",0,-1),"Missing part rejects whole layered render for original fallback")
	manifest.packs.field.parts.down.arm_right=original;art._resolved.clear()
	check(wardrobe.present(state.appearance,visual.appearance,"idle","down",0,-1),"Restored atlas renders complete body")
	visual.queue_redraw();await settle()
	check(art._limb_meshes.size()<=art.LIMB_CACHE_LIMIT,"Pose mesh cache stays bounded")
	check(visual.painted_active and wardrobe.painted_active,"Live scene uses complete handpainted rig")
	state.current_interior="";change_scene_to_file("res://scenes/main.tscn");await settle()
	world=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	player=world.player;player.set_physics_process(false);visual=player.character_visual;visual.set_process(false)
	place(player,start);visual.set_pose(Vector2.RIGHT,false);visual.queue_redraw()
	player.camera.zoom=Vector2(1.35,1.35);player.camera.reset_smoothing();player.camera.force_update_scroll()
	await capture("player-farm-normal")
	player.camera.zoom=Vector2(3.3,3.3);player.camera.reset_smoothing();player.camera.force_update_scroll()
	await capture("player-farm-closeup")
	check(state.money==money and state.inventory==inventory,"Presentation preserves economy")
	print("PLAYER_RIG_GPU: %d passed, %d failed; normal_distance=%.3f fast_distance=%.3f"%[passed,failed,distances[0],distances[1]])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
