extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 create_timer(180).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn")
 for frame in 8:await process_frame
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var families:Dictionary={"blossom":[],"orchard":[]}
 for node in world.get_children():
  if node.get_script()!=null and node.get_script().resource_path=="res://scripts/world_prop.gd" and families.has(str(node.data.get("kind",""))):families[node.data.kind].append(node)
 check(families.blossom.size()==4 and families.orchard.size()==8,"all original flowering and fruit trees remain")
 for season in 4:
  state.day=28*season;call_group("seasonal_world_props","refresh_season")
  for kind in families:
   var tree:Node2D=families[kind][0]
   world.player.global_position=tree.position+Vector2(50,30);world.player.camera.zoom=Vector2(3,3);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
   for frame in 8:await process_frame
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png("res://artifacts/seasonal-tree-"+kind+"-"+str(season)+"-20261010.png")==OK,"actual seasonal viewport saved")
   for candidate in families[kind]:check(candidate.painted_active,"every original tree uses actual seasonal PNG")
 print("SEASONAL_TREE_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
