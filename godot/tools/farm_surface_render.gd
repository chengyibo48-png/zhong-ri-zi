extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in range(8):await process_frame
func run()->void:
 create_timer(120).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 var initial:Array=state.plots.duplicate(true)
 var world_json:=FileAccess.get_file_as_bytes("res://data/world.json")
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 for i in world.plot_nodes.size():
  check(world.plot_nodes[i].position==state.farm_plot_position(i),"original plot position")
  check(world.plot_nodes[i].find_children("*","CollisionShape2D",true,false).is_empty(),"soil art creates no extra collision")
 for mode in ["uncultivated","dry","wet","mixed","stages"]:
  state.plots=initial.duplicate(true)
  for i in state.plots.size():
   state.plots[i].tilled=mode!="uncultivated"
   state.plots[i].moisture=0 if mode=="dry" else (100 if mode=="wet" else i*100.0/maxi(1,state.plots.size()-1))
   if mode!="mixed":state.plots[i].crop=""
   if mode=="stages":
    state.plots[i].crop="cabbage"
    state.plots[i].growth=[0.0,0.3,0.75,1.0][i%4]*state.crop_days("cabbage")
  var fixture:Array=state.plots.duplicate(true)
  world.queue_redraw()
  for node in world.plot_nodes:node.queue_redraw()
  for group in range(2):
   var nodes:Array=world.plot_nodes.slice(0,24) if group==0 else world.plot_nodes.slice(24)
   check(not nodes.is_empty(),"original main and extended fields both examined")
   var centre:=Vector2.ZERO
   for node in nodes:centre+=node.global_position
   centre/=nodes.size()
   world.player.global_position=centre+Vector2(-150,0)
   world.player.camera.position=Vector2(150,0)
   world.player.camera.zoom=Vector2(2,2) if group==0 else Vector2(1.5,1.5)
   world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
   await settle();await RenderingServer.frame_post_draw
   for node in nodes:
    var drawing:=Rect2(node.global_position+Vector2(-17,-25),Vector2(34,38))
    check(root.get_visible_rect().encloses(world.get_global_transform_with_canvas()*drawing),"every whole plot and crop remains inside native viewport")
   check(state.plots==fixture,"drawing leaves every plot field unchanged "+mode)
   var image:=root.get_texture().get_image();check(image!=null and image.get_size()==Vector2i(1280,800),"real actual game viewport")
   var suffix:="" if group==0 else "-extension"
   check(image.save_png("res://artifacts/farm-earth-"+mode+suffix+"-20261009.png")==OK,"actual farm image saved")
 state.plots=initial.duplicate(true)
 for node in world.plot_nodes:node.queue_redraw()
 world.player.camera.position=Vector2.ZERO;world.player.global_position=Vector2(2542,1770);world.player.camera.zoom=Vector2(2,2);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
 await settle();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://artifacts/farm-earth-counter-20261009.png")==OK,"original live general counter captured")
 check(state.plots==initial,"all fixture plot states restored")
 check(FileAccess.get_file_as_bytes("res://data/world.json")==world_json,"world positions and collisions source bytes unchanged")
 print("FARM_SURFACE_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
