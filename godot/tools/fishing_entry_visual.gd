extends SceneTree
func _initialize()->void:
 DisplayServer.window_set_title("种日子 · 钓点画面验证（自动关闭）")
 call_deferred("run")
func run()->void:
 create_timer(60).timeout.connect(func():quit(2))
 var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
 s.current_interior="";s.ui_open=false;s.selected_tool="rod";s.minutes=600;s.flags.introDone=true
 var bank:Dictionary=s.system_catalog.fishing.spots[2]
 s.player_position=Vector2(float(bank.x),float(bank.y))+Vector2(0,-65)
 change_scene_to_file("res://scenes/main.tscn")
 for i:int in 8:await process_frame
 var world:Node=current_scene
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 s.ui_open=false;s.set_player_direction_from_vector(Vector2.DOWN)
 world.player.camera.reset_smoothing();world._refresh_world_target()
 world.hud.interaction_prompt.refresh_world();world.hud.context_actions.refresh_world()
 for dimensions:Vector2i in [Vector2i(960,600),Vector2i(1280,800)]:
  root.size=dimensions
  for i:int in 5:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("ZRZ_ART_OUTPUT")+"/pond-"+str(dimensions.x)+".png")
 var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/visual.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"bank":bank.id,"dimensions":["960x600","1280x800"],"isolated":true}));file.close()
 current_scene.queue_free();await process_frame
 await s.wait_for_saves();await root.get_node("AudioService").prepare_exit();quit()
