extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in range(6):await process_frame
func capture(name:String)->void:
 await settle();await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 check(image!=null and image.get_size()==Vector2i(1280,800),"real 1280x800 GPU frame")
 check(image.save_png("res://artifacts/polish-live-"+name+"-20261010.png")==OK,"actual gameplay frame retained")
func focus(world:Node,at:Vector2,zoom:float)->void:
 world.player.global_position=at;world.player.camera.zoom=Vector2(zoom,zoom);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
func run()->void:
 create_timer(240).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.day=0
 state.appearance.weatherDress=false
 var inventory:Dictionary=state.inventory.duplicate(true);var gold:int=state.money
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var crop_ids:Array=["radish","bean","tomato","rice"]
 for i in range(16):
  var id:String=crop_ids[i/4];var progress:float=[0.0,.4,.8,1.0][i%4]
  state.plots[i].crop=id;state.plots[i].tilled=true;state.plots[i].growth=state.crop_days(id)*progress;world.plot_nodes[i].queue_redraw()
 focus(world,state.farm_plot_position(7)+Vector2(12,45),3.0)
 await capture("crop-stages")
 for i in range(16):check(preload("res://scripts/world_art.gd").entries().get("crops/"+str(state.plots[i].crop),{}).get("baseReady",false),"live crop bound to its own sheet")
 state.plots[0].crop="";world.plot_nodes[0].queue_redraw()
 var callbacks:Dictionary={"count":0}
 check(state.begin_action(preload("res://scripts/action_rules.gd").spec("hoe"),{"kind":"farm-task","index":0,"x":state.farm_plot_position(0).x,"y":state.farm_plot_position(0).y},func():callbacks.count+=1),"actual hoe sequence started")
 for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
  for frame in range(6):
   state.action_sequence.active.elapsed=float(state.action_sequence.active.spec.duration)*(frame+.5)/6.0
   state._sync_action_visual();state.action_sequence_changed.emit(state.action_snapshot())
   world.player.character_visual.set_pose(direction,false)
   await settle();await RenderingServer.frame_post_draw
   check(world.player.character_visual.painted_active and world.player.character_visual.action_state=="hoe","actual action renders painted hoe pose")
   check(world.player.character_visual.sequence_managed,"frame controlled by real action clock")
   if frame==2:await capture("hoe-"+str([Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP].find(direction)))
 state.cancel_action();check(callbacks.count==0,"rendering and cancellation never commit an action")
 var effects=world.get_node("WorldEffects");effects.burst("harvest",world.player.global_position)
 await capture("harvest-leaves")
 for season in 4:
  state.day=season*28;call_group("seasonal_world_props","refresh_season")
  var house:Dictionary=preload("res://scripts/world_art.gd").entries()["buildings/home-an"]
  focus(world,Vector2(float(house.door.x),float(house.door.y)-30),2.7)
  await capture("home-an-season-"+str(season))
  check(preload("res://scripts/character_art.gd").texture(str(house.seasons[season]))!=null,"live seasonal house texture loads")
 state.day=0;world.hud.show();world.hud.show_market("inventory",false)
 await capture("inventory-paper")
 var styles:=0
 for control in world.hud.get_children():
  if control is Control:
   for panel in control.find_children("*","PanelContainer",true,false):
    if panel.get_theme_stylebox("panel") is StyleBoxTexture:styles+=1
 check(styles>0,"live UI consumes real paper panel texture")
 state.player_settings.contrast=true;state.changed.emit();await capture("inventory-high-contrast")
 state.player_settings.contrast=false;state.changed.emit()
 check(state.inventory==inventory and state.money==gold,"pure presentation never changes stock or gold")
 var home_id:=""
 for house in state.world_village.houses:
  if str(house.name)=="爷爷的老屋":home_id=str(house.id)
 check(home_id!="","original home remains available")
 state.ui_open=false;state.current_interior=home_id;state.interior_position=Vector2(480,450);state.building.style="wood"
 change_scene_to_file("res://scenes/interior.tscn");await settle()
 var room=current_scene;room.set_process(false);room.player.set_physics_process(false);room.hud.hide()
 check(room.painted_floor_active,"actual home selects wood surface")
 await capture("home-interior-wood")
 print("POLISH_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
