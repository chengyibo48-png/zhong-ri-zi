extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
var state:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=20:push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 root.size=Vector2i(960,600)
 state=root.get_node("GameState")
 state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("INPUT_MODE_FIXTURE"))))
 for row in fixture.rows:
  state.cancel_action()
  state.source_gamepad=load("res://scripts/source_gamepad.gd").new()
  state.set_source_input_mode(str(row.initial))
  state.player_settings.bindings.interact=row.binding
  state.player_settings.gamepad=row.mode!="disabled"
  state.ui_open=row.mode=="panel"
  for item in row.samples:
   state.cancel_action()
   if row.mode=="action":state.begin_action({"kind":"read","duration":2.0},{"kind":"probe","x":0.0,"y":0.0},Callable())
   if item.step.kind=="pad":
    if row.mode=="hidden":
     # Headless has no minimized native window; exercise the source sampler flag.
     state.source_gamepad.poll(item.sample,true,true,false,false,float(item.now))
     if state.source_gamepad.used:state.set_source_input_mode("pad")
    else:state.poll_source_gamepad(float(item.now),null,item.sample)
   elif item.step.kind=="key":
    var event:=InputEventKey.new()
    event.keycode=KEY_F1
    event.pressed=item.step.pressed
    state._input(event)
   else:state.set_source_input_mode("touch" if item.step.pointerType=="touch" else "keyboard")
   check(state.source_input_mode==item.expected.mode,"persistent source mode "+row.mode+"/"+str(item.step))
   check(state.interaction_input_label()==item.expected.prompt,"source prompt label")
   check(state.cancel_input_label()==item.expected.cancel,"source action cancellation label")
   check(state.target_cycle_input_label()==item.expected.cycle,"source cycle label")
 state.cancel_action()
 state.player_settings.gamepad=true
 state.player_settings.bindings.interact="z"
 check(fixture.rows.size()==36,"36 persistent input contexts")
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
  world.player.global_position=Vector2(-5000,-5000)
  var touch:=InputEventScreenTouch.new()
  touch.pressed=true
  touch.position=world.get_viewport().get_canvas_transform()*Vector2(-5000,-5000)
  world._unhandled_input(touch)
  check(state.source_input_mode=="touch" and state.interaction_input_label()=="点按","world screen touch sets mode "+room)
  var old_target:Dictionary=state.walking_target.duplicate(true)
  var mouse:=InputEventMouseButton.new()
  mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.device=-1;mouse.position=touch.position
  world._unhandled_input(mouse)
  check(state.source_input_mode=="touch" and state.walking_target==old_target,"emulated mouse does not duplicate touch "+room)
  mouse.device=0
  world._unhandled_input(mouse)
  check(state.source_input_mode=="keyboard" and state.interaction_input_label()=="Z","real world mouse restores rebound key label "+room)
  var candidates:Array=world._world_target_candidates() if room=="" else world._room_target_candidates()
  var near:Dictionary={}
  for point in candidates:
   if str(point.get("kind","")) in ["ambient","tea","bed-visit","pet","gather"]:
    near=point.duplicate(true)
    break
  check(not near.is_empty(),"nearby touch target exists "+room)
  if not near.is_empty():
   world.player.global_position=Vector2(float(near.x)-15,float(near.y))
   # The selected room object can sit beneath the toolbar; exercise a world tap
   # with the real H hide-HUD option, rather than accidentally tapping a tool.
   state.ui_hud_visible=false
   world.hud.refresh()
   world.player.camera.reset_smoothing()
   world.player.camera.force_update_scroll()
   await process_frame
   await process_frame
   touch.position=world.get_viewport().get_canvas_transform()*Vector2(float(near.x),float(near.y))
   Input.parse_input_event(touch)
   Input.flush_buffered_events()
   check(state.source_input_mode=="touch" and state.action_busy(),"parsed native touch starts actual nearby action "+room+" at "+str(touch.position)+" mode "+state.source_input_mode)
   mouse.device=-1;mouse.position=touch.position
   world._unhandled_input(mouse)
   check(state.source_input_mode=="touch" and state.action_busy(),"touch emulation preserves active action and touch label "+room)
   var touch_release:=touch.duplicate();touch_release.pressed=false
   Input.parse_input_event(touch_release);Input.flush_buffered_events()
   state.set_source_input_mode("pad")
   var active_snapshot:Dictionary=state.action_snapshot().duplicate(true)
   var suspended_route:Dictionary=state.walking_target.duplicate(true)
   var outside_touch:=InputEventScreenTouch.new()
   outside_touch.position=Vector2(800,400);outside_touch.pressed=true
   Input.parse_input_event(outside_touch);Input.flush_buffered_events()
   check(state.source_input_mode=="touch","locked action world touch still switches input mode "+room)
   check(state.action_snapshot()==active_snapshot and state.walking_target==suspended_route,"locked world touch does not restart action or replace route "+room)
   var outside_release:=outside_touch.duplicate();outside_release.pressed=false
   Input.parse_input_event(outside_release);Input.flush_buffered_events()
   var outside_mouse:=InputEventMouseButton.new()
   outside_mouse.position=Vector2(800,400);outside_mouse.button_index=MOUSE_BUTTON_LEFT;outside_mouse.pressed=true
   Input.parse_input_event(outside_mouse);Input.flush_buffered_events()
   check(state.source_input_mode=="keyboard","locked action real world mouse restores keyboard mode "+room)
   check(state.action_snapshot()==active_snapshot,"locked world mouse leaves action unchanged "+room)
   var mouse_release:=outside_mouse.duplicate();mouse_release.pressed=false
   Input.parse_input_event(mouse_release);Input.flush_buffered_events()
   await process_frame
   await process_frame
   var cancel_button:Button=world.hud.action_progress.cancel_button
   check(cancel_button.is_visible_in_tree(),"cancel button remains visible through pointer-transparent root "+room)
   var cancel_press:=InputEventMouseButton.new()
   cancel_press.button_index=MOUSE_BUTTON_LEFT;cancel_press.pressed=true
   cancel_press.position=cancel_button.get_global_rect().get_center()
   Input.parse_input_event(cancel_press);Input.flush_buffered_events()
   var cancel_release:=cancel_press.duplicate();cancel_release.pressed=false
   Input.parse_input_event(cancel_release);Input.flush_buffered_events()
   check(not state.action_busy() and state.message=="已停下手边的动作，未结算这次操作。","native GUI mouse click cancels from inside action card "+room)
   state.set_source_input_mode("touch")
   state.begin_action({"kind":"read","duration":2.0},{"kind":"probe","x":0.0,"y":0.0},Callable())
   await process_frame
   await process_frame
   var card_touch:=InputEventScreenTouch.new()
   card_touch.pressed=true;card_touch.position=cancel_button.get_global_rect().get_center()
   Input.parse_input_event(card_touch);Input.flush_buffered_events()
   var card_release:=card_touch.duplicate();card_release.pressed=false
   Input.parse_input_event(card_release);Input.flush_buffered_events()
   check(not state.action_busy(),"native GUI touch cancels from inside action card "+room)
   check(state.source_input_mode=="touch","touch on cancel card does not become a world keyboard click "+room)
   state.cancel_player_action()
   state.ui_hud_visible=true
   world.hud.refresh()
  for mode in ["pad","touch","keyboard"]:
   state.set_source_input_mode(mode)
   state.begin_action({"kind":"read","duration":2.0},{"kind":"probe","x":0.0,"y":0.0},Callable())
   check(world.hud.action_progress.cancel_button.text=="停下 · "+state.cancel_input_label(),"actual action HUD label "+room+"/"+mode)
   check(world.hud.fishing_panel.fishing_cancel_button.text=="收竿取消 · "+state.cancel_input_label(),"actual fishing cancel label "+room+"/"+mode)
   state.cancel_player_action()
  state.set_source_input_mode("pad")
  var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_F1
  Input.parse_input_event(event);Input.flush_buffered_events()
  check(state.source_input_mode=="keyboard","parsed native keydown restores mode "+room)
  var release:=event.duplicate();release.pressed=false
  Input.parse_input_event(release);Input.flush_buffered_events()
  check(not state._make_save_data().has("source_input_mode"),"runtime mode not persisted "+room)
  state._interrupt_navigation_for_ui()
 await process_frame
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("INPUT_MODE_SOURCE_SMOKE: ",passed," passed, ",failed," failed; 36 cases, 720 steps")
 quit(0 if failed==0 else 1)
