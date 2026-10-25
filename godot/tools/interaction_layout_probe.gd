extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 for frame in range(5): await process_frame
func run() -> void:
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state := root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 root.size=Vector2i(1280,800)
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.ui_open=false
 var stock=world.hud.interaction_prompt;stock.set_process(false);stock.hide()
 for strategy in ["baseline","pre_size_labels","deferred_fit"]:
  var prompt=load("res://scripts/interaction_prompt.gd").new();prompt.set_process(false);world.hud.add_child(prompt);await settle()
  var info: Dictionary={"verb":"播种","name":"七号田 · 韭菜","ready":true,"state":"可以操作","reason":"","detail":"水分 20 · 肥力 80"}
  if strategy=="pre_size_labels":
   prompt.heading.size.x=240
   prompt.description.size.x=284
  prompt.update_content(info,"E",Vector2(480,330),root.get_visible_rect().size)
  print("LAYOUT_CALL ",strategy," panel=",prompt.size," labels=",prompt.heading.size,"/",prompt.description.size)
  if strategy=="deferred_fit":
   prompt.call_deferred("update_content",info,"E",Vector2(480,330),root.get_visible_rect().size)
  await settle()
  print("LAYOUT_SETTLED ",strategy," panel=",prompt.size," labels=",prompt.heading.size,"/",prompt.description.size," combined=",prompt.get_combined_minimum_size())
  prompt.queue_free();await settle()
 await root.get_node("AudioService").prepare_exit();quit()
