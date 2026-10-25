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
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 for room in ["","home-granny"]:
  state.cancel_action();state._interrupt_navigation_for_ui();state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  var panel=hud.npc_story_panel
  state.day=10;state.minutes=600;state.stamina=100
  state.marriage.spouse=""
  for person in state.npc_catalog:
   var id:=str(person.id)
   var arc:Array=state.content.arcs[id]
   state.npc_stories[id]={"step":arc.size(),"choices":[],"lastDay":-1}
   for i in arc.size():state.npc_stories[id].choices.append(i%2)
   hud.show_npc_story(id)
   check(panel.visible and hud._gamepad_panel()==panel and root.gui_get_focus_owner()==panel.close_button,"story focused "+id)
   check(panel.choice_buttons.is_empty() and panel.memory_buttons.size()==arc.size(),"completed archive "+id)
   if not panel.memory_buttons.is_empty():
    panel.memory_buttons[0].pressed.emit()
    check(panel.column.get_child(panel.memory_buttons[0].get_index()+1).visible,"memory expand "+id)
    panel.memory_buttons[0].pressed.emit()
    check(not panel.column.get_child(panel.memory_buttons[0].get_index()+1).visible,"memory collapse "+id)
   hud.close_top_panel();check(not panel.visible and not state.ui_open,"story closes "+id)
  state.npc_stories.granny={"step":0,"choices":[],"lastDay":10}
  state.relations.granny.points=100
  hud.show_npc_dialogue("granny");hud.npc_dialogue.buttons.story.pressed.emit()
  check(panel.visible and panel.find_button!=null and panel.choice_buttons.is_empty(),"locked story opens from dialogue")
  check(panel.quote!=null and panel.quote.text==state.content.arcs.granny[0].text,"locked story remains readable")
  hud.close_top_panel()
  hud.show_neighbors("granny");hud.neighbor_journal._on_story_open()
  check(panel.visible and not hud.neighbor_journal.visible,"journal story route")
  hud.close_top_panel()
  state.npc_stories.granny.lastDay=-1
  world.player.global_position=Vector2(480,490) if room!="" else Vector2(2300,1600)
  if room=="":state.player_position=world.player.global_position;state.npc_positions.granny=world.player.global_position+Vector2(10,0)
  else:state.interior_position=world.player.global_position;state.interior_npc_positions.granny=world.player.global_position+Vector2(10,0)
  hud.show_npc_story("granny");check(panel.choice_buttons.size()==2,"ready story choices")
  var inventory_before:Dictionary=state.inventory.duplicate(true)
  panel.choice_buttons[1].pressed.emit()
  check(state.action_busy() and not panel.visible and int(state.npc_stories.granny.step)==0 and state.inventory==inventory_before,"choice settlement deferred")
  state.cancel_action()
  check(int(state.npc_stories.granny.step)==0 and state.inventory==inventory_before,"choice cancellation preserves chapter/materials")
  hud.show_npc_story("granny");panel.choice_buttons[1].pressed.emit()
  for tick in range(60):state._process_action(0.1)
  check(panel.visible and not hud.neighbor_journal.visible and int(state.npc_stories.granny.step)==1,"completed choice returns story")
  check(state.npc_stories.granny.choices==[1] and int(state.npc_stories.granny.lastDay)==10,"choice index and day stored")
  check(panel.memory_buttons.size()==1 and panel.choice_buttons.is_empty() and panel.find_button!=null,"completed chapter recalled and same day locked")
  hud.close_top_panel()
  state.marriage.spouse="granny";hud.show_home();hud.home_panel._open_story()
  check(panel.visible and not hud.home_panel.visible,"home story route")
  hud.close_top_panel();state.marriage.spouse=""
  for size in [Vector2i(1280,800),Vector2i(640,360)]:
   root.size=size;await settle();hud.show_npc_story("granny");await settle()
   var rect:Rect2=panel.panel.get_global_rect()
   check(rect.position.x>=0 and rect.end.x<=panel.get_viewport_rect().size.x,"story horizontal bounds")
   check(rect.position.y>=0 and rect.end.y<=panel.get_viewport_rect().size.y,"story vertical bounds")
   hud.close_top_panel()
 if OS.get_environment("NPC_STORY_SCREENSHOT")!="":
  root.size=Vector2i(960,600);await settle();current_scene.hud.show_npc_story("granny");await settle()
  var panel=current_scene.hud.npc_story_panel
  if is_instance_valid(panel.quote):panel.quote.visible_characters=-1
  if not panel.memory_buttons.is_empty():panel.memory_buttons[0].pressed.emit()
  await create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("NPC_STORY_SCREENSHOT"))
 print("NPC story UI: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
