extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(45).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 state.toolkit.tools.hoe.level=2
 state.toolkit.tools.hoe.branch="broad"
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame;await process_frame
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 world.hud.show_tools(true)
 world.hud.tool_panel.selected_id="hoe"
 world.hud.tool_panel.refresh()
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 var path:=OS.get_environment("TOOL_SETTINGS_SHOT")
 if path=="":quit(1);return
 var result:int=root.get_texture().get_image().save_png(path)
 print("Tool settings screenshot result ",result)
 await root.get_node("AudioService").prepare_exit()
 quit(0 if result==OK else 1)
