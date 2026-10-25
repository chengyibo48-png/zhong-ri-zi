extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=15:push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func button_for(bar:Node,action:String,op:String="")->Button:
 for i in range(bar.last_buttons.size()):
  var row:Dictionary=bar.last_buttons[i]
  if row.action==action and (op=="" or row.op==op):return bar.buttons[i]
 return null
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 for room in ["","home-granny"]:
  state.cancel_action();state._interrupt_navigation_for_ui()
  state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  state.ui_open=false
  var bar=hud.context_actions;bar.set_process(false)
  var target:Dictionary={"kind":"plot","index":7}
  target.x=100;target.y=100
  if room=="":world.selected_world_target=target
  else:world.selected_room_target=target
  bar.refresh_world()
  check(bar.visible and button_for(bar,"f-inspect")!=null,"plot context appears "+room)
  button_for(bar,"f-inspect").pressed.emit()
  check(hud.farm_planner_open() and int(hud.farm_planner_panel.plot_box.value)==8,"inspect selects actual plot")
  bar.refresh_world();check(not bar.visible,"context hidden by menu")
  hud.close_farm_planner()
  bar.refresh_world()
  button_for(bar,"farmcare").pressed.emit()
  check(hud.farm_planner_open() and int(hud.farm_planner_panel.plot_box.value)==8,"farmcare preserves inspected plot")
  hud.close_farm_planner()
  target={"kind":"animal","id":str(state.animals[-1].id),"name":str(state.animals[-1].name)}
  target.x=100;target.y=100
  if room=="":world.selected_world_target=target
  else:world.selected_room_target=target
  bar.refresh_world()
  hud.ranch_panel.animal_filter.select(1)
  button_for(bar,"r-open").pressed.emit()
  check(hud.ranch_open() and hud.ranch_panel.selected_animal_id==target.id and hud.ranch_panel.animal_filter.selected==0,"r-open restores all and selects target")
  hud.ranch_panel.close()
  bar.refresh_world()
  for operation in ["feed","pet"]:
   var feed_before:int=int(state.inventory.get(str(state.ranch.get("feed","feed")),0))
   button_for(bar,"r-task",operation).pressed.emit()
   check(str(state.ranch_active_task.get("animalId",""))==target.id and str(state.ranch_active_task.get("action",""))==operation and str(state.ranch_active_task.get("arg",""))==str(state.ranch.get("feed","feed")),"context queues correct ranch task")
   check(int(state.inventory.get(str(state.ranch.get("feed","feed")),0))==feed_before,"queued ranch task does not deduct early")
   state._interrupt_navigation_for_ui()
  for item in [["fish","fishing"],["gather","forage"]]:
   target={"kind":item[0],"id":"probe"}
   if item[0]=="gather":target.item="berry";target.event=""
   target.x=100;target.y=100
   if room=="":world.selected_world_target=target
   else:world.selected_room_target=target
   bar.refresh_world()
   button_for(bar,item[1]).pressed.emit()
   check(hud.fishing_open() if item[0]=="fish" else hud.forage_open(),"context opens correct handbook")
   hud.close_top_panel()
  target={"kind":"npc","id":"granny","name":state.npc_name("granny")}
  target.x=100;target.y=100
  if room=="":world.selected_world_target=target
  else:world.selected_room_target=target
  bar.refresh_world()
  check(button_for(bar,"v-npc-gift")!=null and bar.home_of("granny")=="home-granny","NPC gift and actual home entry")
  button_for(bar,"v-npc-gift").pressed.emit()
  check(hud.gift_panel.visible and hud._gamepad_panel()==hud.gift_panel and root.gui_get_focus_owner()==hud.gift_panel.close_button,"focused gift screen")
  var dishes:Dictionary={}
  for id in state.item_catalog:
   if str(state.item_catalog[id].get("kind",""))=="料理":dishes[id]=0
  state.inventory.merge(dishes,true);state.inventory.wood=3
  hud.gift_panel.refresh();await settle()
  check(hud.gift_panel.items.get_child_count()==1 and hud.gift_panel.items.get_child(0) is Label,"gift screen empty state excludes non-food")
  state.inventory.fishSoup=2;state.quality.fishSoup=[2,0,0,0]
  state.relations.granny.gifted=-1
  state.minutes=600;state.stamina=100
  world.player.global_position=Vector2(480,490) if room!="" else Vector2(2300,1600)
  if room=="":state.player_position=world.player.global_position;state.npc_positions.granny=world.player.global_position+Vector2(10,0)
  else:state.interior_position=world.player.global_position;state.interior_npc_positions.granny=world.player.global_position+Vector2(10,0)
  hud.gift_panel.refresh();await settle()
  var sends:Array=hud.gift_panel.items.find_children("*","Button",true,false)
  check(sends.size()==1 and str(sends[0].get_meta("item_id",""))=="fishSoup","gift screen lists only owned dishes")
  if room=="" and OS.get_environment("GIFT_SCREENSHOT")!="":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("GIFT_SCREENSHOT"))
  var points:int=int(state.relations.granny.points)
  sends[0].pressed.emit()
  check(state.action_busy() and not hud.gift_panel.visible and int(state.inventory.fishSoup)==2,"gift defers settlement until action")
  state.cancel_action()
  check(hud.gift_panel.visible and int(state.inventory.fishSoup)==2 and int(state.relations.granny.points)==points,"gift cancellation restores screen and resources")
  await settle()
  sends=hud.gift_panel.items.find_children("*","Button",true,false)
  sends[0].pressed.emit()
  for i in range(60):
   if not state.action_busy():break
   state._process_action(0.1)
  check(not state.action_busy() and hud.gift_panel.visible and int(state.inventory.fishSoup)==1 and int(state.relations.granny.gifted)==state.day,"gift finishes once and restores screen")
  await settle()
  sends=hud.gift_panel.items.find_children("*","Button",true,false)
  sends[0].pressed.emit()
  for i in range(60):
   if not state.action_busy():break
   state._process_action(0.1)
  check(int(state.inventory.fishSoup)==1,"second same-day gift preserves item")
  hud.close_top_panel()
  check(not hud.gift_panel.visible and not state.ui_open,"gift closes through shared adapter")
  target={"kind":"npc","id":"granny","name":state.npc_name("granny"),"x":world.player.global_position.x+10,"y":world.player.global_position.y}
  if room=="":world.selected_world_target=target
  else:world.selected_room_target=target
  bar.refresh_world()
  button_for(bar,"v-npc-talk").pressed.emit()
  check(state.action_busy() and str(state.npc_task.get("npcId",""))=="granny" and str(state.npc_task.get("op",""))=="talk","context starts actual NPC talk sequence")
  state.cancel_action();state._interrupt_navigation_for_ui()
  var visit_id:String=str(state.npc_catalog[1].id)
  target={"kind":"npc","id":visit_id,"name":state.npc_name(visit_id),"x":100,"y":100}
  if room=="":world.selected_world_target=target
  else:world.selected_room_target=target
  bar.refresh_world()
  button_for(bar,"v-walk-house").pressed.emit()
  check(str(state.walking_target.get("id",""))==bar.home_of(visit_id) and str(state.walking_target.get("kind",""))=="enter","context plans real home visit")
  check(world.player.walk_is_exit==(room!=""),"home visit exits current room first")
  state._interrupt_navigation_for_ui()
  target={"kind":"tools","id":"tools","name":"农具台"}
  target.x=100;target.y=100
  if room=="":world.selected_world_target=target
  else:world.selected_room_target=target
  world.player.walk_source_path=[{"x":500,"y":500}]
  world.player.walk_path.append(Vector2(500,500))
  state.walking_target={"name":"标记"}
  bar.refresh_world()
  check(button_for(bar,"v-stop")!=null and bar.progress_label.visible,"walking context shows stop and progress")
  button_for(bar,"v-stop").pressed.emit()
  check(state.walking_target.is_empty() and world.player.walk_source_path.is_empty() and world.player.walk_path.is_empty(),"stop clears native route immediately")
  bar.refresh_world()
  if room=="":
   var snapshot_path:String=OS.get_environment("CONTEXT_SCREENSHOT")
   world.player.global_position=world.plot_nodes[7].global_position+Vector2(0,20)
   state.player_position=world.player.global_position;state.player_direction="up"
   world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
   world._refresh_world_target()
   bar.refresh_world()
   if button_for(bar,"fb-cycle")!=null:
    var chosen:String=world.interaction_selection.key
    button_for(bar,"fb-cycle").pressed.emit()
    check(world.interaction_selection.key!=chosen and world.interaction_selection.manual!="","context cycles actual nearby targets")
   else:check(false,"nearby real plots offer cycle")
   bar.refresh_world()
   await settle();bar.refresh_world()
   check(hud.notification_stack.z_index==5 and hud.notification_stack.column.get_global_rect().end.y<=hud.notification_stack.get_viewport_rect().size.y,"source notification layer and bounds")
   if snapshot_path!="":
    hud.interaction_prompt.refresh_world()
    await settle()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(snapshot_path)
   # A plain service context offers the bicycle action.
   world.selected_world_target={"kind":"tools","id":"tools","name":"农具台","x":100,"y":100}
   bar.refresh_world()
   var was_riding:bool=state.riding
   button_for(bar,"v-bike").pressed.emit()
   check(state.action_busy() and state.riding==was_riding and str(state.action_snapshot().get("kind",""))=="bike","bicycle context waits for source bike animation")
   state.cancel_action()
   check(state.riding==was_riding,"cancelling bicycle action preserves riding mode")
   button_for(bar,"v-bike").pressed.emit()
   for i in range(30):
    if not state.action_busy():break
    state._process_action(0.1)
   check(state.riding!=was_riding,"context toggles bicycle after completion")
  else:check(button_for(bar,"v-bike")==null,"no bicycle indoors")
  state.begin_action({"kind":"read","duration":2.0},{"kind":"probe","x":0.0,"y":0.0},Callable())
  bar.refresh_world();check(not bar.visible,"context hidden while busy")
  state.cancel_action()
 await root.get_node("AudioService").prepare_exit()
 print("CONTEXT_ACTIONS_UI_SMOKE: ",passed," passed, ",failed," failed")
 quit(0 if failed==0 else 1)
