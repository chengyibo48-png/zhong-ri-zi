extends SceneTree
var s: Node
var w: Node
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i: int in range(12):await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ui-quests-20261017/"+name+".png")
func run() -> void:
	create_timer(60,true,false,true).timeout.connect(func():quit(2))
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.current_interior="";s.ui_open=false
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.player.set_physics_process(false);Input.warp_mouse(Vector2(2,2))
	root.size=Vector2i(960,600);s.changed.emit();await capture("preview-hud")
	w.hud.show_life_menu();await capture("preview-menu")
	w.hud.life_menu._group("经营");await capture("preview-menu-business")
	w.hud.life_menu._choose("plans");await capture("preview-tasks")
	w.hud.life_plan_panel._tab("available");await capture("preview-available")
	w.hud.show_market("inventory",false);await capture("preview-bag")
	w.hud.ui_stack.leave();await settle()
	print("UI preview completed")
	root.get_node("AudioService").prepare_exit();quit(0)
