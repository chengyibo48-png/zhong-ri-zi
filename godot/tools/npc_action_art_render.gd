extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 for i in range(6):await process_frame
func run()->void:
 create_timer(120).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_open=false
 state.appearance=load("res://scripts/character_art.gd").data().playerProfile.duplicate(true);state.appearance.weatherDress=false
 state.minutes=600;root.size=Vector2i(1280,800)
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.ui_open=false
 world.player.camera.zoom=Vector2(2,2);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
 var inventory:Dictionary=state.inventory.duplicate(true);var animals:Array=state.animals.duplicate(true)
 for actor_id in ["lin","chen"]:
  var npc:Node2D
  for row in world.npc_nodes:
   if str(row.npc_id)==actor_id:npc=row
  check(npc!=null,"actual farm scene has resident "+actor_id)
  if npc==null:continue
  var point:Vector2=world.player.global_position+Vector2(0,-64)
  state.npc_residents[actor_id]={"x":point.x,"y":point.y,"direction":"up","room":null}
  state.npc_movement.actors[actor_id]={"walking":true,"emotion":"calm","wait":0.0,"path":[],"inside":{}}
  var calls:Dictionary={"count":0}
  check(state.begin_action({"kind":"greet","duration":1.1},{"kind":"npc-task","npcId":actor_id,"x":point.x,"y":point.y},func():calls.count+=1),"actual NPC action starts "+actor_id)
  state.action_sequence.active.elapsed=float(state.action_sequence.active.spec.duration)*0.5
  state.npc_movement.update_actor(state,npc.npc_data,state.npc_catalog.find(npc.npc_data),0.1)
  npc.present_resident(state);state._sync_action_visual();state.action_sequence_changed.emit(state.action_snapshot());await settle();await RenderingServer.frame_post_draw
  check(npc.visible and npc.global_position==point,"resident stays at authoritative interaction point "+actor_id)
  check(not npc.character_visual.walking,"resident stops walking while addressed "+actor_id)
  check(npc.character_visual.sequence_managed and npc.character_visual.action_state=="greet","actual NPC receives greeting, not a preview snapshot "+actor_id)
  check(npc.character_visual.painted_active,"actual scene draws NPC painted greeting "+actor_id)
  check(world.player.character_visual.painted_active and world.player.character_visual.action_state=="greet","actual player uses painted greeting "+actor_id)
  var action_card:Control=world.hud.action_progress.card
  var actor_area:Rect2=npc.character_visual.get_global_transform_with_canvas()*Rect2(-25,-46,50,50)
  var player_area:Rect2=world.player.character_visual.get_global_transform_with_canvas()*Rect2(-25,-46,50,50)
  check(not action_card.get_global_rect().intersects(actor_area),"progress card does not hide NPC body "+actor_id)
  check(not action_card.get_global_rect().intersects(player_area),"progress card does not hide player body "+actor_id)
  check(root.get_visible_rect().encloses(action_card.get_global_rect()),"compact progress card stays in viewport "+actor_id)
  check(action_card.size.y<=120.0,"progress card remains compact "+actor_id)

  check(is_equal_approx(npc.character_visual.action_elapsed/npc.character_visual.action_duration,0.5),"actual scene shares precise sequence progress "+actor_id)
  var picture:=root.get_texture().get_image()
  check(picture!=null and not picture.is_empty(),"actual GPU scene available")
  if picture!=null:check(picture.save_png("res://artifacts/handpainted-live-npc-greeting-"+actor_id+"-1280.png")==OK,"actual NPC scene screenshot saved")
  state.cancel_action();await settle()
  check(not npc.character_visual.sequence_managed and npc.character_visual.action_state=="","actual cancelled greeting returns to idle "+actor_id)
  check(calls.count==0,"GPU presentation cannot commit cancelled interaction")
 check(state.inventory==inventory,"real NPC animation preserves inventory")
 check(state.animals==animals,"real NPC animation preserves animal data")
 print("NPC_ACTION_ART_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
