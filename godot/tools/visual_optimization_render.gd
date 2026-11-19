extends SceneTree
var passed := 0
var failed := 0
class AnimalBoard extends Node2D:
	func _draw() -> void:
		var species: Array=["hen","duck","cow","sheep","goat","pig","rabbit"]
		for i: int in range(species.size()):
			for column: int in range(3):
				var pose: Dictionary={"direction":"left","walking":false,"young":false,"eating":column==1,"sleepy":column==2,"dirty":false,"sick":false,"happy":false}
				var at:=Vector2(150+column*270,70+i*70)
				preload("res://scripts/animal_art.gd").draw(self,{"type":species[i],"breed":"local"},pose,at,0)
				draw_string(ThemeDB.fallback_font,at+Vector2(-70,24),str(species[i])+" / "+["standing","eating","sleeping"][column],HORIZONTAL_ALIGNMENT_LEFT,220,14,Color("2d4234"))
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(6):await process_frame
func run() -> void:
	create_timer(100,true,false,true).timeout.connect(func():quit(1))
	var s: Node=root.get_node("GameState");s.set_process(false);s.flags.introDone=true
	var output:=OS.get_environment("ZRZ_ART_OUTPUT")
	if output=="":output="user://visual-optimization-20261026"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,800)
	s.current_interior="home-an";s.interior_position=Vector2(482,312)
	change_scene_to_file("res://scenes/interior.tscn");await settle()
	var world: Node=current_scene;world.player.set_physics_process(false);world.hud.hide()
	check(world.y_sort_enabled and world.furniture_visuals.size()==world._room_layout().rows.size(),"Each actual furnishing participates in actor depth sorting")
	for node: Node2D in world.furniture_visuals:
		check(node.position==node.get_meta("floor_anchor"),"Sorted origin matches ground contact")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/depth-behind.png")==OK,"Capture player behind the shelf")
	world.player.global_position=Vector2(482,405);s.interior_position=world.player.global_position
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/depth-front.png")==OK,"Capture player in front of the shelf")
	world.queue_free();await process_frame
	var scene:=Node2D.new();root.add_child(scene);current_scene=scene
	var backdrop:=ColorRect.new();backdrop.color=Color("e3ddc5");backdrop.size=Vector2(1280,1000);scene.add_child(backdrop)
	var board:=AnimalBoard.new();board.scale=Vector2.ONE;scene.add_child(board)
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/animal-poses.png")==OK,"Actual renderer displays all seven species and three states")
	scene.queue_free();await process_frame
	print("Visual optimization GPU: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
