extends SceneTree
var passed := 0
var failed := 0
var folder := "res://artifacts/quality-redesign-20261015/screenshots"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1;push_error(label)
func settle() -> void:
	for i in range(12): await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"capture "+label)
func run() -> void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"): quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	create_timer(180).timeout.connect(func():quit(1))
	var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
	var touch:=preload("res://scripts/performance_policy.gd").touch_device()
	var prefix: String="phone" if touch else "pc"
	root.size=Vector2i(844,390) if touch else Vector2i(1280,800)
	state.current_interior="";state.player_position=Vector2(2831,1652)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var world:=current_scene;world.player.set_physics_process(false)
	await capture(prefix+"-farm")
	world.hud.life_plan_panel.open_panel();await settle()
	check(world.hud.life_plan_panel.visible and state.ui_open,"life plans open and pause")
	check(world.hud.life_plan_panel.card_list.get_child_count()==5,"all intentions visible in scroll")
	await capture(prefix+"-plans")
	world.hud.close_top_panel();check(not state.ui_open,"close plans resumes")
	world.hud.show_farm_planner(false,0);await capture(prefix+"-farm-preview");world.hud.close_top_panel()
	world.hud.show_ranch();await capture(prefix+"-ranch-preview");world.hud.close_top_panel()
	state.begin_action({"kind":"read","duration":8.0,"label":"看看这段禾溪旧事"},{"kind":"probe","x":2831,"y":1652},Callable());await capture(prefix+"-action")
	var action_rect: Rect2=world.hud.action_progress.card.get_global_rect()
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(action_rect),"action card fits viewport")
	state.cancel_action()
	for size: Vector2i in [Vector2i(960,600),Vector2i(1280,800),Vector2i(844,390)]:
		root.size=size;await settle()
		world.hud.interaction_prompt.update_content({"verb":"查看","name":"一块需要照料的田","state":"可以慢慢安排","detail":"材料不足时，未做的项目不会扣材料","ready":true},"点按" if touch else "E",Vector2(300,200),root.get_visible_rect().size)
		await settle()
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(world.hud.interaction_prompt.get_global_rect()),"prompt fits actual resized window")
	root.size=Vector2i(844,390) if touch else Vector2i(1280,800)
	state.current_interior="home-an";state.interior_position=Vector2(480,480);change_scene_to_file("res://scenes/interior.tscn");await capture(prefix+"-home")
	state.current_interior="museum";state.interior_position=Vector2(480,480)
	# Resolve the actual museum house instead of inventing an entry identifier.
	for house: Dictionary in state.world_village.get("houses",[]):
		if "村史馆" in str(house.get("name","")): state.current_interior=str(house.id);break
	change_scene_to_file("res://scenes/interior.tscn");await capture(prefix+"-museum")
	current_scene.queue_free();await process_frame
	print("Quality acceptance: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
