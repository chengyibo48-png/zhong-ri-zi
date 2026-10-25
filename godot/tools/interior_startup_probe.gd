extends SceneTree
var ready_timings: Array = []
func _initialize() -> void: call_deferred("run")
func added(node: Node) -> void:
 var script: Variant=node.get_script()
 if script==null:return
 var path: String=script.resource_path
 if not path.begins_with("res://scripts/"):return
 var started := Time.get_ticks_usec()
 node.ready.connect(func():
  var elapsed := Time.get_ticks_usec()-started
  if elapsed>1000:ready_timings.append({"script":path,"ready_us":elapsed})
 )
func run() -> void:
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 state.flags.introDone=true
 state.current_interior="ranch-poultry"
 state.interior_position=Vector2(480,550)
 var service=root.get_node("UIArtService")
 service.set_script(load("res://tools/theme_timing_probe.gd"))
 service._rebuild_theme()
 node_added.connect(added)
 var started := Time.get_ticks_usec()
 change_scene_to_file("res://scenes/interior.tscn")
 for frame in range(5):
  await process_frame
  print("STARTUP_FRAME ",frame," elapsed_us=",Time.get_ticks_usec()-started," theme_us=",service.profile_us," theme_calls=",service.profile_calls)
  if current_scene!=null:
   current_scene.set_process(false);current_scene.player.set_physics_process(false)
 ready_timings.sort_custom(func(a,b):return a.ready_us>b.ready_us)
 print("STARTUP_READY ",JSON.stringify(ready_timings))
 await root.get_node("AudioService").prepare_exit()
 quit()
