extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 create_timer(120).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn")
 for frame in 8:await process_frame
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var targets:Array=[]
 for prop in world.get_children():
  if prop.get_script()!=null and prop.get_script().resource_path=="res://scripts/world_prop.gd" and str(prop.data.get("kind","")) in ["pavilion","cart"]:targets.append(prop)
 check(targets.size()==5,"every original pavilion and cart reviewed individually")
 var count:=0
 for prop in targets:
  world.player.global_position=prop.position+Vector2(0,20);world.player.camera.zoom=Vector2(1.6,1.6);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  prop.queue_redraw()
  for frame in 8:await process_frame
  await RenderingServer.frame_post_draw
  check(prop.painted_active,"native object consumes its actual PNG")
  var image:=root.get_texture().get_image();check(image.get_size()==Vector2i(1280,800),"actual detail viewport")
  var row:Dictionary=preload("res://scripts/world_art.gd").entries()["props/"+str(prop.data.kind)]
  var r:Array=prop.data.get("_layout_rect",row.worldRect)
  var transform:Transform2D=prop.get_global_transform_with_canvas()
  var scale_factor:=Vector2(image.get_size())/root.get_visible_rect().size
  var a:Vector2=(transform*Vector2(float(r[0]),float(r[1])))*scale_factor
  var b:Vector2=(transform*Vector2(float(r[0])+float(r[2]),float(r[1])+float(r[3])))*scale_factor
  check(Rect2(Vector2.ZERO,Vector2(image.get_size())).encloses(Rect2(a,b-a)),"entire displayed outline fits the actual frame")
  check(image.save_png("res://artifacts/market-props-detail-"+str(count)+"-20261010.png")==OK,"actual individual object archived")
  count+=1
 print("MARKET_PROPS_DETAIL: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
