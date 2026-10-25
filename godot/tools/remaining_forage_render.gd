extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func snap(tag:String)->void:
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://artifacts/remaining-forage-"+tag+"-20261010.png")==OK,"actual viewport saved")
func run()->void:
 create_timer(180).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn")
 for frame in 8:await process_frame
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var willows:Array=[]
 for node in world.get_children():
  if node.get_script()!=null and node.get_script().resource_path=="res://scripts/world_prop.gd" and str(node.data.get("kind",""))=="willow":willows.append(node)
 check(not willows.is_empty(),"existing willow nodes")
 var first:Node2D=willows[0]
 for season in 4:
  world.player.global_position=first.position+Vector2(0,25);world.player.camera.zoom=Vector2(2,2);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  for willow in willows:willow._season=season;willow.queue_redraw()
  await snap("willow-season-"+str(season))
  for willow in willows:check(willow.painted_active,"real seasonal world renderer")
 world.player.global_position=first.position+Vector2(0,-20)
 for frame in 25:await process_frame
 check(first.modulate.a<.5,"willow fades when player behind canopy")
 await snap("willow-player-behind")
 world.player.global_position=first.position+Vector2(0,35)
 for frame in 25:await process_frame
 check(first.modulate.a>.95,"willow recovers when player leaves")
 for item in ["mushroom","wood","shoot","berry","tea","wildHerb","bamboo"]:
  var node:Node2D
  for candidate in world.gather_nodes:
   if candidate.item_id==item:node=candidate;break
  check(node!=null,"real harvest node for "+item)
  if node==null:continue
  world.player.global_position=node.position+Vector2(50,30);world.player.camera.zoom=Vector2(3,3);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  var before:Dictionary=state.forage.duplicate(true)
  node.queue_redraw();await snap(item)
  check(state.forage==before,"render preserves ecological inventory and regeneration state")
 print("WILLOW_FORAGE_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
