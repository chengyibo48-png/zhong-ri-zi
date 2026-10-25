extends SceneTree
var passed:=0
var failed:=0
var committed:=false
var state:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func prepare_route(world:Node)->void:
 state.walking_target={"kind":"walk","x":700.0,"y":600.0}
 state.farm_queue=[{"probe":true}]
 state.ranch_queue=[{"probe":true}]
 state.kitchen_task={"probe":true}
 state.building_task={"probe":true}
 world.player.walk_source_path=[{"x":700.0,"y":600.0}]
 world.player.walk_path.clear()
 world.player.walk_path.append(Vector2(700,600))
 world.player.walk_index=0
func clear(world:Node)->bool:
 return state.walking_target.is_empty() and state.farm_queue.is_empty() and state.ranch_queue.is_empty() and state.kitchen_task.is_empty() and state.building_task.is_empty() and world.player.walk_source_path.is_empty() and world.player.walk_path.is_empty()
func press_escape()->void:
 var event:=InputEventKey.new()
 event.keycode=KEY_ESCAPE
 event.pressed=true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 var release:=event.duplicate()
 release.pressed=false
 Input.parse_input_event(release)
 Input.flush_buffered_events()
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CANCEL_COMMAND_FIXTURE")))
 check(fixture.rows.size()==2,"original cancellation branches loaded")
 check(fixture.rows[0].expected.path.size()==1 and fixture.rows[1].expected.path.is_empty(),"source idle cancellation preserves route; active cancellation clears")
 create_timer(120).timeout.connect(func():quit(1))
 state=root.get_node("GameState")
 state.set_process(false)
 for room in ["","home-granny"]:
  state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await process_frame
  await process_frame
  var world=current_scene
  world.set_process(false)
  world.player.set_physics_process(false)
  if world.hud.onboarding_open():world.hud.toggle_onboarding()
  state.ui_open=false
  root.gui_release_focus()
  world.player.global_position=Vector2(-5000,-5000)
  prepare_route(world)
  world._interact()
  check(not state.action_busy() and not state.walking_target.is_empty(),"absent keyboard target preserves route "+room)
  check(state.farm_queue.size()==1 and state.kitchen_task.has("probe"),"absent target preserves pending work "+room)
  var before_message:String=state.message
  check(not state.cancel_player_action() and not clear(world) and state.message==before_message,"idle cancellation is no-op "+room)
  for method in ["Escape","button","pad"]:
   prepare_route(world)
   committed=false
   check(state.begin_action({"kind":"read","duration":2.0,"label":"路线回归"},{"kind":"probe","x":0.0,"y":0.0},func():committed=true),"start direct action with existing route "+room)
   check(not state.walking_target.is_empty() and world.player.walk_source_path.size()==1,"starting direct action keeps suspended route "+room)
   if method=="Escape":press_escape()
   elif method=="button":world.hud.action_progress.cancel_button.pressed.emit()
   else:
    var buttons:Array=[];buttons.resize(17);buttons.fill(false)
    state.poll_source_gamepad(1000,world.player,{"connected":true,"buttons":buttons,"axes":[0,0]})
    buttons[1]=true
    state.poll_source_gamepad(1001,world.player,{"connected":true,"buttons":buttons,"axes":[0,0]})
   check(not state.action_busy() and not committed,"cancel never commits "+method+"/"+room)
   check(clear(world),"cancel clears every suspended route and pending task "+method+"/"+room)
   check(not state.ui_open and state.message==fixture.rows[1].expected.calls[-1].toast,"cancel source toast without opening menu "+method+"/"+room)
   var note:Dictionary={}
   for row in state.feedback.get("rows",[]):
    if str(row.key)=="cancel/"+str(state.day):note=row
   check(not note.is_empty() and note.title==fixture.rows[1].expected.calls[2].note.title and note.type=="未完成","cancel records original feedback "+method+"/"+room)
  var candidates:Array=world._world_target_candidates() if room=="" else world._room_target_candidates()
  var point:Dictionary={}
  for candidate in candidates:
   if str(candidate.get("kind","")) in ["ambient","tea","bed-visit","pet","gather"]:
    point=candidate.duplicate(true)
    break
  check(not point.is_empty(),"actual non-modal nearby target exists "+room)
  if not point.is_empty():
   world.player.global_position=Vector2(float(point.x)-15,float(point.y))
   world.interaction_selection.manual=world.interaction_selection.target_key(point)
   prepare_route(world)
   world._interact()
   check(state.action_busy()==fixture.directExpected.started and (not state.walking_target.is_empty())==fixture.directExpected.pathKept and world.player.walk_path.size()==1,"actual keyboard interaction suspends existing route "+room)
   check((state.farm_queue.size()==1)==fixture.directExpected.farmKept and state.kitchen_task.has("probe")==fixture.directExpected.kitchenKept,"actual direct action keeps pending work "+room)
   state.cancel_player_action()
   prepare_route(world)
   world._click_at(Vector2(float(point.x),float(point.y)))
   check(state.action_busy() and clear(world),"near mouse hit starts action after clearing old route "+room)
   state.cancel_player_action()
  prepare_route(world)
  world._click_at(Vector2(-5000,-5000))
  check(state.farm_queue.is_empty() and state.ranch_queue.is_empty() and state.kitchen_task.is_empty() and state.building_task.is_empty(),"pointerdown replaces pending work "+room)
  state._interrupt_navigation_for_ui()
 await process_frame
 await process_frame
 check(not state._autosave_queued and FileAccess.file_exists(state.SAVE_PATH),"player cancellation autosave flushed in isolated user data")
 await root.get_node("AudioService").prepare_exit()
 print("Interaction route smoke: ",passed," passed, ",failed," failed.")
 quit(0 if failed==0 else 1)
