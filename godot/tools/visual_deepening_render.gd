extends SceneTree
var passed:=0
var failed:=0
var state: Node
var output: String
var metrics: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(6):await process_frame
func capture(name: String) -> void:
	await settle()
	if current_scene.has_method("_refresh_pointer_hover"):
		current_scene.hud.restore_hud_button.hide()
		for key: String in ["interaction_prompt","context_actions","hover_card"]:
			var item: Variant=current_scene.hud.get(key)
			if item!=null:item.hide()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"Capture actual GPU "+name)
func hide_hud(world: Node) -> void:
	world.player.set_physics_process(false)
	world.hud.show();world.hud.ambient_hud.hide()
	for key: String in ["notification_stack","interaction_prompt","context_actions","action_progress","hover_card","restore_hud_button"]:
		var item: Variant=world.hud.get(key)
		if item!=null:item.hide()
func outdoor(at: Vector2, day: int, minutes: float) -> void:
	state.day=day;state.minutes=minutes;state.player_position=at
	current_scene.player.global_position=at
	current_scene.player.camera.reset_smoothing();current_scene.player.camera.force_update_scroll()
	state.world_changed.emit();state.clock_changed.emit();state.changed.emit()
func interior(id: String) -> void:
	state.current_interior=id;state.interior_position=Vector2(480,480)
	change_scene_to_file("res://scenes/interior.tscn");await settle();hide_hud(current_scene)
func collider_signature(world: Node) -> int:
	var rows: Array=[]
	for shape: Node in world.find_children("*","CollisionShape2D",true,false):
		if shape.get_parent() is StaticBody2D and not shape.disabled:
			rows.append([shape.global_position,str(shape.shape)])
	return hash(rows)
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():quit(1))
	state=root.get_node("GameState");state.set_process(false)
	var initial: Dictionary=state._make_save_data().duplicate(true)
	state.flags.introDone=true;state.ui_open=false;state.ui_hud_visible=false
	output=OS.get_environment("ZRZ_ART_OUTPUT")
	if output=="":output="user://visual-deepening"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,800)
	state.current_interior="";state.player_position=Vector2(1060,1832)
	change_scene_to_file("res://scenes/main.tscn");await settle();hide_hud(current_scene)
	var banks: Node=current_scene.get_node("PaintedShoreline")
	check(banks.chunks.size()>0 and banks.chunks.size()<150,"Shore geometry is batched into bounded world chunks")
	var triangles:=0
	for chunk: MeshInstance2D in banks.chunks:triangles+=chunk.mesh.surface_get_array_index_len(0)/3
	check(triangles>0 and triangles<30000,"World shore geometry stays below its fixed triangle budget")
	metrics.shore_chunks=banks.chunks.size();metrics.shore_triangles=triangles
	outdoor(Vector2(1060,1832),0,720);await capture("pond-spring")
	outdoor(Vector2(1060,1832),84,720);await capture("pond-winter")
	outdoor(Vector2(1015,2820),0,720);await capture("bridge-clear")
	check(current_scene.ground_layer.get_cell_atlas_coords(Vector2i(31,88)).x==9,"Actual bridge deck uses wood tile 9")
	state.minutes=720
	await interior("building-farm-12")
	var floor_layer: Node
	for node: Node in current_scene.get_children():
		if node.get_script()==load("res://scripts/interior_ground.gd"):floor_layer=node;break
	check(floor_layer!=null,"New floor material is attached to the actual home")
	check(current_scene.has_node("InteriorAtmosphere"),"Window light and wall details are present in the actual home")
	var collisions:=collider_signature(current_scene)
	await capture("home-day-v2")
	var old_style: String=str(state.building.get("style","wood"))
	state.building.style="blue";state.world_changed.emit();await settle()
	check(floor_layer.floor_material.get_shader_parameter("wood_tint")==Vector3(.88,.99,1.03),"Saved blue house style immediately changes the new floor palette")
	state.building.style=old_style;state.world_changed.emit()
	state.minutes=1260;state.clock_changed.emit();await capture("home-night-v2")
	check(float(floor_layer.floor_material.get_shader_parameter("night_amount"))>.99,"Floor follows the real night clock")
	check(collider_signature(current_scene)==collisions,"Material and light changes do not alter room blockers")
	for floor_name: String in ["青砖","水磨石"]:
		for id: String in state.system_catalog.interiors.layouts:
			if str(state.system_catalog.interiors.layouts[id].get("floor",""))!=floor_name:continue
			state.minutes=720;await interior(id);await capture("floor-"+("brick" if floor_name=="青砖" else "terrazzo"));break
	current_scene.queue_free();await process_frame
	var stage:=Node2D.new();root.add_child(stage);current_scene=stage
	var backdrop:=ColorRect.new();backdrop.color=Color("e4ddc8");backdrop.size=Vector2(960,600);stage.add_child(backdrop)
	var poses: Array[Node2D]=[]
	var clips: Array[String]=["idle","walk","greet","gather","read","brush"]
	for row: int in range(4):
		for col: int in range(clips.size()):
			var actor: Node2D=load("res://scripts/character_visual.gd").new()
			stage.add_child(actor);actor.position=Vector2(80+col*155,110+row*140);actor.scale=Vector2.ONE*1.7
			actor.set_process(false);poses.append(actor)
	var title:=Label.new();title.position=Vector2(20,8);title.add_theme_font_size_override("font_size",15);stage.add_child(title)
	for id: String in ["an","granny","mei"]:
		title.text=id+" · idle / walk / greet / gather / read / brush"
		for i: int in range(poses.size()):
			var node: Node2D=poses[i];var col:=i%clips.size();var row:=int(i/clips.size())
			node.configure(id);node.scale=Vector2.ONE*1.7
			node.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][row]
			node.walking=col==1;node.action_state=clips[col] if col>1 else "";node.action_duration=1.0;node.action_elapsed=.5;node.walk_clock=.03
			node.set_process(false);node.queue_redraw()
		await capture("resident-poses-"+id)
		for node: Node2D in poses:check(node.painted_active,"Actual resident uses the authored master mesh "+id)

	var rig: Script=load("res://scripts/canonical_character.gd")
	check(rig.meshes.size()<=rig.CACHE_LIMIT,"Resident mesh resources obey their cache limit")
	metrics.resident_cache=rig.meshes.size();metrics.device=RenderingServer.get_video_adapter_name()
	check(state.inventory==initial.inventory and state.money==initial.money and state.plots==initial.plots,"GPU art review preserves inventory, money and crops")
	FileAccess.open(output+"/visual-deepening-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	stage.queue_free();await process_frame
	print("VISUAL_DEEPENING_GPU: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
