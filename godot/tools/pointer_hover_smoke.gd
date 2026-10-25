extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(120).timeout.connect(func():quit(1))
 var state=root.get_node("GameState")
 state.set_process(false)
 root.size=Vector2i(960,600)
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
  var points:Array=world._world_target_candidates() if room=="" else world._room_target_candidates()
  check(not points.is_empty(),"real target pool "+room)
  var point:Dictionary=points[0]
  var at:=Vector2(float(point.x),float(point.y))
  var screen:=root.get_canvas_transform()*at
  world.interaction_selection.manual="old/manual"
  world._hover_pointer(screen)
  check(world.pointer_screen==screen and world.interaction_selection.manual=="","pointer motion records screen coordinate and clears manual "+room)
  check(not world.pointer_hover.is_empty(),"actual pointer hits original candidate "+room)
  world.interaction_selection.manual="keep/manual"
  world._refresh_pointer_hover()
  check(world.interaction_selection.manual=="keep/manual","per-frame refresh preserves explicit selection "+room)
  var old_transform:Transform2D=root.canvas_transform
  root.canvas_transform=Transform2D(0,Vector2(100000,100000))
  world._refresh_pointer_hover()
  check(world.pointer_hover.is_empty(),"camera change refreshes stationary pointer hit "+room)
  root.canvas_transform=old_transform
  world._refresh_pointer_hover()
  check(not world.pointer_hover.is_empty(),"restoring camera re-hits without pointer movement "+room)
  var snapshot:Dictionary=world.pointer_hover.duplicate(true)
  state.ui_open=true
  root.canvas_transform=Transform2D(0,Vector2(100000,100000))
  world._refresh_pointer_hover()
  check(world.pointer_hover.is_empty() and world.pointer_screen==null,"opening panel clears hover and suspends per-frame refresh "+room)
  root.canvas_transform=old_transform
  state.ui_open=false
  var mode:String=state.source_input_mode
  root.mouse_exited.emit()
  check(world.pointer_screen==null and world.pointer_hover.is_empty(),"viewport exit clears screen and hover "+room)
  check(world.interaction_selection.manual=="keep/manual" and state.source_input_mode==mode,"leave preserves manual selection and input mode "+room)
  world._hover_pointer(screen)
  if room=="":world._cycle_world_target()
  else:world._cycle_room_target(1)
  check(world.pointer_screen==null and world.pointer_hover.is_empty(),"target cycle removes pointer preference "+room)
 await root.get_node("AudioService").prepare_exit()
 print("POINTER_HOVER_SMOKE: ",passed," passed, ",failed," failed")
 quit(0 if failed==0 else 1)
