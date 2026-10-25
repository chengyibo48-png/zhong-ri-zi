extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 await process_frame
 await process_frame
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
  var dialogue=hud.npc_dialogue
  for person in state.npc_catalog:
   var id:=str(person.id)
   state.neighbors.people[id].last={"text":"当前台词 "+id,"emotion":"thought","category":"记忆"}
   hud.show_npc_dialogue(id)
   check(dialogue.quote.text=="当前台词 "+id,"latest persisted dialogue "+id)
   check(hud._gamepad_panel()==dialogue and root.gui_get_focus_owner()==dialogue.close_button,"dialogue focus "+id)
   check(dialogue.buttons.has("auto") and dialogue.buttons.has("memory") and dialogue.buttons.has("gift"),"topic and gift entries "+id)
   hud.close_top_panel();check(not dialogue.visible and not state.ui_open,"dialogue close "+id)
  var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NPC_DIALOGUE_FIXTURE")))
  for row in fixture.rows:
   var id:=str(row.id)
   state.neighbors.people[id].last={"text":"当前台词 "+id,"emotion":"thought","category":"记忆"} if row.latest else {}
   state.neighbors.people[id].event={} if row.status=="none" else {"status":row.status,"day":state.day,"method":"join","completed":state.day}
   hud.show_npc_dialogue(id)
   var labels:Array=[]
   for button in dialogue.buttons.values():labels.append(button.text)
   check(labels==row.buttons,"actual source button labels "+id+"/"+str(row.status))
   check(dialogue.quote.text==row.quote,"actual source quote "+id)
   hud.close_top_panel()
  for status in ["offered","accepted","postponed","done"]:
   state.neighbors.people.granny.event={"status":status,"day":state.day,"method":"join","completed":state.day}
   hud.show_npc_dialogue("granny")
   check(dialogue.buttons.has("join")==(status=="accepted"),"join status "+status)
   check(dialogue.buttons.has("accept")==(status in ["offered","postponed"]),"accept status "+status)
   check(dialogue.buttons.has("later")==(status!="done"),"later status "+status)
   hud.close_top_panel()
  world.player.global_position=Vector2(480,490) if room!="" else Vector2(2300,1600)
  if room=="":state.player_position=world.player.global_position;state.npc_positions.granny=world.player.global_position+Vector2(10,0)
  else:state.interior_position=world.player.global_position;state.interior_npc_positions.granny=world.player.global_position+Vector2(10,0)
  var target:Dictionary={"kind":"npc","id":"granny","name":state.npc_name("granny"),"x":world.player.global_position.x+10,"y":world.player.global_position.y}
  if room=="":
   for npc in world.npc_nodes:
    if str(npc.npc_id)=="granny":npc.visible=true;npc.global_position=world.player.global_position+Vector2(10,0)
  else:
   state.npc_residents.granny.room=room
   world._sync_room_residents()
   world.resident_nodes.granny.global_position=world.player.global_position+Vector2(10,0)
  world._interact_target(target,true)
  check(dialogue.visible and not hud.neighbor_journal.visible,"direct world interaction focused dialogue "+room)
  dialogue.buttons.daily.pressed.emit()
  check(state.action_busy() and not dialogue.visible,"topic starts deferred action "+room)
  for tick in range(60):state._process_action(0.1)
  check(dialogue.visible and not hud.neighbor_journal.visible,"topic returns focused dialogue "+room)
  check(dialogue.quote.text==str(state.neighbors.people.granny.last.text),"finished topic latest text "+room)
  dialogue.buttons.gift.pressed.emit()
  check(hud.gift_panel.visible and not dialogue.visible,"gift route "+room);hud.close_top_panel()
  hud.show_npc_dialogue("granny");dialogue.buttons.person.pressed.emit()
  check(hud.npc_history_panel.visible and hud.npc_history_panel.tab=="people" and hud.npc_history_panel.selected_person=="granny" and not dialogue.visible,"source person book route "+room);hud.close_top_panel()
  hud.show_npc_dialogue("granny");dialogue.buttons.history.pressed.emit()
  var history=hud.npc_history_panel
  check(history.visible and not dialogue.visible and history.selected_person=="granny","focused history route")
  state.neighbors.history=[
   {"id":"granny","category":"日常","text":"第一条","choice":"","day":0,"minute":601},
   {"id":"granny","category":"故事","text":"第二条","choice":"留下来","day":1,"minute":602},
   {"id":str(state.npc_catalog[1].id),"category":"故事","text":"第三条","choice":"","day":2,"minute":603}]
  history.refresh();check(history.filtered_rows().size()==2 and history.filtered_rows()[0].text=="第二条","history newest first and person filter")
  history.selected_category="故事";check(history.filtered_rows().size()==1,"history category filter")
  history.keyword="留下";check(history.filtered_rows().size()==1,"history choice search")
  history.keyword="找不到";history.refresh();check(history.filtered_rows().is_empty() and history.records.get_child_count()==1,"history empty state")
  history.clear_filters();check(history.filtered_rows().size()==3 and history.selected_person=="all","history clear filters")
  hud.close_top_panel()
  for size in [Vector2i(1280,800),Vector2i(640,360)]:
   root.size=size;await settle();hud.show_npc_dialogue("granny");await settle()
   check(dialogue.panel.get_global_rect().position.x>=0 and dialogue.panel.get_global_rect().end.x<=dialogue.get_viewport_rect().size.x,"panel horizontal bounds")
   check(dialogue.panel.get_global_rect().position.y>=0 and dialogue.panel.get_global_rect().end.y<=dialogue.get_viewport_rect().size.y,"panel vertical bounds")
   hud.close_top_panel()
 if OS.get_environment("NPC_DIALOGUE_SCREENSHOT")!="":
  root.size=Vector2i(960,600);await settle()
  current_scene.hud.show_npc_dialogue("granny")
  current_scene.hud.npc_dialogue.quote.visible_characters=-1
  await settle()
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("NPC_DIALOGUE_SCREENSHOT"))
 print("NPC dialogue UI: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
