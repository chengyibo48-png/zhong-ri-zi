extends SceneTree
func _initialize()->void:
	root.size=Vector2i(960,600)
	root.position=Vector2i(-2000,-2000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	call_deferred("run")
func run()->void:
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/") or DisplayServer.get_name()=="headless":quit(1);return
	var directory:=OS.get_environment("MENU_CAPTURE_DIR")
	if directory=="":quit(1);return
	var state=root.get_node("GameState")
	state.set_process(false)
	state.current_interior=""
	var world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	world.player.set_physics_process(false)
	await process_frame
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	world.hud.show_life_menu()
	var codes:Array=[]
	for bottom in [false,true]:
		if bottom:world.hud.life_menu.expansion_buttons["item-icons"].grab_focus()
		await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var captured:=root.get_texture().get_image()
		var dimensions:=captured.get_size()
		var path:=directory.path_join(("menu-native-bottom-%dx%d.png" if bottom else "menu-native-top-%dx%d.png")%[dimensions.x,dimensions.y])
		codes.append(captured.save_png(path))
		print("Native menu screenshot: "+str(captured.get_size())+" result "+str(codes.back()))
	current_scene=null
	world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(0 if codes==[OK,OK] else 1)
