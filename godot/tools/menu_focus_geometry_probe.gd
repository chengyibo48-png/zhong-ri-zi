extends SceneTree
func _initialize()->void:
	root.size=Vector2i(960,600)
	call_deferred("run")
func report(menu:Control,label:String)->void:
	print(label," home=",menu.home_button.get_global_rect()," scroll=",menu.content_scroll.get_global_rect()," offset=",menu.content_scroll.scroll_vertical," focus=",root.gui_get_focus_owner())
func run()->void:
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	var state=root.get_node("GameState")
	state.set_process(false)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world=current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	state.player_settings.textScale=1.4
	state.changed.emit()
	world.hud.show_life_menu()
	world.hud.life_menu.home_button.grab_focus()
	await process_frame
	await process_frame
	var menu=world.hud.life_menu
	await process_frame
	await process_frame
	report(menu,"immediate focus after layout")
	if not root.get_visible_rect().encloses(menu.home_button.get_global_rect()):
		push_error("Immediate large-font focus remains outside viewport")
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	menu.home_button.grab_focus()
	await process_frame
	await process_frame
	report(menu,"focus")
	menu.content_scroll.ensure_control_visible(menu.home_button)
	await process_frame
	await process_frame
	report(menu,"ensure")
	menu._ensure_focus_after_layout(null)
	world.queue_free()
	current_scene=null
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	quit(0)
