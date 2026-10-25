extends SceneTree
const VIEW=preload("res://scripts/wedding_view.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=15:push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func finish(state:Node)->void:
 for tick in range(60):state._process_action(0.1)
func escape()->void:
 var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true
 Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
 key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=false
 Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("WEDDING_FIXTURE")))
 var transactions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RELATIONSHIP_ACTION_FIXTURE")))
 var seed:Dictionary={}
 for row in transactions.rows:
  if row.op=="marry" and row.id=="qiao" and row.variant=="ready":seed=state.convert_external_save(row.before);break
 check(not seed.is_empty(),"source legal wedding seed")
 for row in fixture.rows:
  var before:Dictionary=state._make_save_data()
  check(VIEW.describe(state,str(row.id))==row.expected,"actual source wedding copy "+str(row.id))
  check(state._make_save_data()==before,"wedding model readonly")
 for room in ["","home-granny"]:
  state.load_game_data(seed.duplicate(true));state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  var panel=hud.wedding_panel
  for row in fixture.rows:
   var before:Dictionary=state._make_save_data()
   hud.show_wedding(str(row.id))
   check(panel.last_view==row.expected and panel.confirm_button.text==row.expected.confirm and panel.cancel_button.text==row.expected.cancel,"source panel contents "+str(row.id))
   check(hud._gamepad_panel()==panel and root.gui_get_focus_owner()==panel.cancel_button,"wedding initial focus")
   check(state._make_save_data()==before,"opening is readonly")
   panel.cancel_button.pressed.emit();check(not panel.visible and not state.ui_open,"decline closes wedding to world")
  hud.show_npc_story("qiao");hud.npc_story_panel.relationship_button.pressed.emit()
  check(panel.visible and not hud.npc_story_panel.visible and not hud.neighbor_journal.visible,"story routes wedding directly")
  await escape();check(not panel.visible and not state.ui_open,"Esc closes wedding before confirmation")
  hud.show_npc_dialogue("qiao");hud.npc_dialogue.buttons.relationship.pressed.emit()
  check(panel.visible and not hud.npc_dialogue.visible,"dialogue routes wedding directly")
  var prior:Dictionary=state.marriage.duplicate(true)
  var inventory:Dictionary=state.inventory.duplicate(true)
  panel.confirm_button.pressed.emit()
  check(state.action_busy() and not panel.visible and state.marriage==prior and state.inventory==inventory,"wedding confirmation deferred")
  check(state.action_snapshot().kind=="trade" and str(state.action_snapshot().item)=="qiao" and float(state.action_snapshot().duration)==1.6,"actual source wedding action")
  await escape()
  check(panel.visible and state.marriage==prior and root.gui_get_focus_owner()==panel.confirm_button,"animation Esc restores wedding and focus")
  panel.confirm_button.pressed.emit();state.relations.qiao.points=69;finish(state)
  check(panel.visible and state.marriage.spouse=="" and state.inventory==inventory,"completion rechecks trust")
  check(state.message=="需要双方确认心意、走完前四章，并达到信任。","failed wedding source message")
  print("WEDDING_INLINE room=",room," actual=",panel.column.get_node("ModalStatus/Message").text," expected=",state.message," index=",panel.column.get_node("ModalStatus").get_index())
  check(panel.column.get_node("ModalStatus/Message").text==state.message and panel.column.get_node("ModalStatus").get_index()==2,"failed wedding inline source status")
  var world_toasts:Array=state.notification_queue.rows.duplicate(true)
  hud._show_feedback_toast("手边回响测试",1)
  check(panel.column.get_node("ModalStatus/Message").text=="手边回响测试" and state.notification_queue.rows==world_toasts,"modal feedback is inline and preserves existing world notification")
  check(panel.z_index==20 and hud.notification_stack.z_index==5,"source modal/world toast layer order")
  panel.show_status_message("替换提示",true)
  check(panel.column.find_children("ModalStatus","PanelContainer",false,false).size()==1 and panel.column.get_node("ModalStatus/Message").text=="替换提示","modal status replaces previous")
  state.relations.qiao.points=70;panel.confirm_button.pressed.emit()
  panel.open_panel("lin");finish(state)
  check(state.marriage.spouse=="qiao" and hud.home_panel.visible and not panel.visible and not hud.neighbor_journal.visible,"success captured NPC and home route")
  check(state.inventory==inventory,"wedding consumes no items")
  var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
  check(saved is Dictionary and saved.marriage.spouse=="qiao","wedding saved after completion")
  hud.close_top_panel()
  state.partners.qiao="friend";state.marriage={"spouse":"","day":-1,"weekly":{},"memories":[]}
  hud.show_npc_story("qiao")
  var story=hud.npc_story_panel
  var old:Dictionary=state.partners.duplicate(true)
  story.relationship_button.pressed.emit()
  check(state.action_busy() and not story.visible and state.partners==old and not hud.neighbor_journal.visible,"story intent starts directly")
  await escape()
  check(story.visible and state.partners==old and root.gui_get_focus_owner()==story.relationship_button,"intent cancellation restores actual origin")
  story.relationship_button.pressed.emit();finish(state)
  check(state.partners.qiao=="dating" and story.visible and story.npc_id=="qiao" and story.relationship_button.text=="商量婚礼","intent completion returns story")
  hud.close_top_panel()
  state.partners.qiao="friend";hud.show_npc_dialogue("qiao")
  var dialogue=hud.npc_dialogue
  dialogue.buttons.relationship.pressed.emit();await escape()
  check(dialogue.visible and state.partners.qiao=="friend" and root.gui_get_focus_owner()==dialogue.buttons.relationship,"dialogue intent cancellation returns dialogue")
  dialogue.buttons.relationship.pressed.emit();finish(state)
  check(story.visible and not dialogue.visible and state.partners.qiao=="dating","dialogue intent completion opens story")
  hud.close_top_panel()
  for size in [Vector2i(1280,800),Vector2i(640,360)]:
   root.size=size;await settle();hud.show_wedding("qiao");await settle()
   var rect:Rect2=panel.panel.get_global_rect()
   check(rect.position.x>=0 and rect.end.x<=panel.get_viewport_rect().size.x,"wedding horizontal bounds")
   check(rect.position.y>=0 and rect.end.y<=panel.get_viewport_rect().size.y,"wedding vertical bounds")
   hud.close_top_panel()
 if OS.get_environment("WEDDING_SCREENSHOT")!="":
  root.size=Vector2i(960,600);await settle();current_scene.hud.show_wedding("qiao");await settle()
  await create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("WEDDING_SCREENSHOT"))
 print("Wedding UI: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
