extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=20:push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func move_mouse(at:Vector2)->void:
 var motion:=InputEventMouseMotion.new()
 motion.relative=at-root.get_mouse_position()
 motion.position=at;motion.global_position=at;motion.device=0
 Input.parse_input_event(motion);Input.flush_buffered_events()
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 root.size=Vector2i(960,600)
 var state=root.get_node("GameState");state.set_process(false)
 for room in ["","home-granny","","home-granny","","home-granny"]:
  state.cancel_action();state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  state.ui_open=false
  var point:Dictionary={"kind":"plot","index":7,"x":world.plot_nodes[7].global_position.x,"y":world.plot_nodes[7].global_position.y} if room=="" else {}
  if room!="":
   for candidate in world._room_points():
    if str(candidate.get("kind",""))=="egg":point=candidate;break
  check(not point.is_empty(),"real clear-screen world object "+room)
  world.player.global_position=Vector2(float(point.x),float(point.y))+Vector2(0,50)
  state.player_position=world.player.global_position if room=="" else state.player_position
  if room!="":state.interior_position=world.player.global_position
  world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  await settle()
  var screen:Vector2=root.get_canvas_transform()*Vector2(float(point.x),float(point.y))
  move_mouse(screen);await settle()
  world._refresh_pointer_hover()
  hud.hover_card.refresh_world()
  if root.gui_get_hovered_control()!=null:print("GUI blocker: ",root.gui_get_hovered_control().get_path()," screen=",screen," bounds=",root.gui_get_hovered_control().get_global_rect())
  check(root.gui_get_hovered_control()==null,"world pointer has no GUI blocker "+room)
  check(world.pointer_screen!=null and not world.pointer_hover.is_empty() and hud.hover_card.visible,"native motion shows actual hover "+room)
  var saved:Dictionary=state._make_save_data().duplicate(true)
  var snapshot:Dictionary=world.pointer_hover.duplicate(true)
  var at:Vector2=hud.bag_button.get_global_rect().get_center()
  move_mouse(at);await settle()
  check(root.gui_get_hovered_control()==hud.bag_button,"native pointer enters actual HUD button "+room)
  world._refresh_pointer_hover();hud.hover_card.refresh_world()
  check(world.pointer_screen==null and world.pointer_hover.is_empty() and not hud.hover_card.visible,"HUD boundary clears stale world hint "+room)
  check(state._make_save_data()==saved,"hover boundary is read-only "+room)
  move_mouse(screen);await settle()
  world._refresh_pointer_hover();hud.hover_card.refresh_world()
  check(world.pointer_hover==snapshot and hud.hover_card.visible,"returning to world restores actual hover "+room)
  if room=="" and OS.get_environment("HOVER_SCREENSHOT")!="":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("HOVER_SCREENSHOT"))
  # The visual card is outside the target's hit box and must pass pointer input.
  var through:Vector2=hud.hover_card.get_global_rect().position+Vector2(5,5)
  move_mouse(through);await settle()
  check(root.gui_get_hovered_control()==null,"hover card itself passes native pointer "+room)
  # Open an actual native menu and verify the source opening behavior.
  move_mouse(screen);await settle();world._refresh_pointer_hover()
  hud.show_market("inventory",false)
  check(state.ui_open and world.pointer_hover.is_empty() and world.pointer_screen==null,"opening actual menu clears pointer "+room)
  hud.hover_card.refresh_world();check(not hud.hover_card.visible,"menu hides hover "+room)
  hud.close_top_panel();hud.hover_card.refresh_world()
  check(not state.ui_open and not hud.hover_card.visible,"closing menu cannot resurrect stale hover "+room)
  move_mouse(screen);await settle();world._refresh_pointer_hover();hud.hover_card.refresh_world()
  if not hud.hover_card.visible:print("Restore diagnostics room=",room," gui=",root.gui_get_hovered_control().get_path() if root.gui_get_hovered_control()!=null else "none"," pointer=",world.pointer_screen," target=",world.pointer_hover," screen=",screen," ui=",state.ui_open)
  check(hud.hover_card.visible,"fresh native pointer motion restores hint "+room)
 await root.get_node("AudioService").prepare_exit()
 print("HOVER_GUI_BOUNDARY_SMOKE: ",passed," passed, ",failed," failed")
 quit(0 if failed==0 else 1)
