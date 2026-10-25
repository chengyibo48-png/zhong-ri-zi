extends SceneTree
const SAVE_JSON=preload("res://scripts/save_json.gd")
func _initialize() -> void:
	root.size=Vector2i(960,600)
	root.position=Vector2i(-2000,-2000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	call_deferred("_run")
func _run() -> void:
	var state=root.get_node("GameState")
	state.set_process(false)
	var file:=FileAccess.open(OS.get_environment("ATLAS_TARGETS_FIXTURE"),FileAccess.READ)
	if file==null or DisplayServer.get_name()=="headless":
		await root.get_node("AudioService").prepare_exit();quit(1);return
	var row:Dictionary=SAVE_JSON.decode(JSON.parse_string(file.get_line()))
	if not state.load_game_data(state.convert_external_save(row.before)):
		await root.get_node("AudioService").prepare_exit();quit(1);return
	var world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world);current_scene=world
	world.set_process(false);world.player.set_physics_process(false)
	await process_frame
	world.hud.show_map()
	world.hud.map_panel._type_changed(0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var captured:=root.get_texture().get_image()
	var code:=captured.save_png(OS.get_environment("ATLAS_MAP_SCREENSHOT"))
	print("Native atlas screenshot: "+str(captured.get_size())+" result "+str(code))
	current_scene=null;world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(0 if code==OK else 1)
