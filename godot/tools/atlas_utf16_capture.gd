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
	var file:=FileAccess.open(OS.get_environment("ATLAS_PIN_FIXTURE"),FileAccess.READ)
	if file==null or DisplayServer.get_name()=="headless":
		await root.get_node("AudioService").prepare_exit();quit(1);return
	var row:Dictionary=SAVE_JSON.parse(file.get_line())
	if not state.load_game_data(state.convert_external_save(row.states[0])):
		await root.get_node("AudioService").prepare_exit();quit(1);return
	var raw_name:Variant=preload("res://scripts/js_string.gd").prefix("a".repeat(17)+"😀",18)
	state.atlas.pins=[{"id":"pin-1","x":2831,"y":1652,"label":raw_name},{"id":"pin-2","x":2840,"y":1670,"label":"谷雨 · 😀小路"}]
	state.atlas.nextId=3
	state.atlas.tracking={"id":"pin-1","name":raw_name,"x":2831,"y":1652}
	state.atlas.layer="pins"
	var world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world);current_scene=world
	world.set_process(false);world.player.set_physics_process(false)
	await process_frame
	world.hud.show_map()
	world.hud.map_panel.selected_id="pin-1"
	world.hud.map_panel.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var captured:=root.get_texture().get_image()
	var code:=captured.save_png(OS.get_environment("ATLAS_MAP_SCREENSHOT"))
	print("Native UTF16 atlas screenshot: "+str(captured.get_size())+" result "+str(code))
	current_scene=null;world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(0 if code==OK else 1)
