extends SceneTree
const DESCRIBE=preload("res://scripts/interaction_description.gd")
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
 root.size=Vector2i(1280,800)
 for room in ["","home-granny"]:
  state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene
  world.set_process(false);world.player.set_physics_process(false)
  if world.hud.onboarding_open():world.hud.toggle_onboarding()
  state.ui_open=false
  var prompt=world.hud.interaction_prompt
  prompt.set_process(false)
  var target:Dictionary={"kind":"tools","id":"probe","name":"农具台","x":100,"y":100}
  for scenery in [false,true]:
   target={"kind":"weather","id":"probe","name":"风向旗","x":100,"y":100,"top":20,"scenery":true,"story":"风向与田间天气"} if scenery else {"kind":"tools","id":"probe","name":"农具台","x":100,"y":100}
   if room=="":world.selected_world_target=target
   else:world.selected_room_target=target
   world.player.global_position=Vector2(200,300)
   for mode in ["keyboard","pad","touch"]:
    state.set_source_input_mode(mode)
    prompt.refresh_world();await settle();prompt.refresh_world()
    var info:Dictionary=DESCRIBE.describe(state,target,state.selected_tool)
    check(prompt.visible,"prompt visible "+room+"/"+mode)
    check(prompt.heading.text==info.verb+" · "+info.name,"prompt heading")
    check(prompt.input_label.text==state.interaction_input_label(),"prompt input")
    check(prompt.description.text==info.state+("\n"+info.detail if info.detail!="" else ""),"prompt state and detail")
    var at:Vector2=Vector2(100,10) if scenery else Vector2(200,257)
    var screen:Vector2=world.get_canvas_transform()*at
    var view:Vector2=prompt.get_viewport_rect().size
    check(prompt.screen_anchor==Vector2(maxf(125,minf(view.x-125,screen.x)),maxf(110,minf(view.y-145,screen.y))),"source scenery/player anchor")
  state.ui_open=true;prompt.refresh_world();prompt.advance_visibility(0.14);check(not prompt.visible,"prompt hidden by menu")
  state.ui_open=false
  state.begin_action({"kind":"read","duration":2.0},{"kind":"probe","x":0.0,"y":0.0},Callable())
  prompt.refresh_world();prompt.advance_visibility(0.14);check(not prompt.visible,"prompt hidden by busy action");state.cancel_action()
  if room=="":world.selected_world_target={}
  else:world.selected_room_target={}
  prompt.refresh_world();prompt.advance_visibility(0.14);check(not prompt.visible,"empty target hides prompt")
  check(prompt.mouse_filter==Control.MOUSE_FILTER_IGNORE and prompt.focus_mode==Control.FOCUS_NONE,"prompt does not intercept world input")
  for node in prompt.find_children("*","Control",true,false):check(node.mouse_filter==Control.MOUSE_FILTER_IGNORE,"prompt child passes pointer")
  for viewport in [Vector2(1280,800),Vector2(960,600),Vector2(640,360)]:
   for at in [Vector2(-1000,-1000),Vector2(5000,5000),Vector2(300,200)]:
    var info:Dictionary={"name":"七号田 · 白萝卜","verb":"播种","state":"已经松土","reason":"缺少白萝卜种子 ×2","detail":"水分 20 · 肥力 80 · 白萝卜种子 ×2","ready":false}
    prompt.update_content(info,"点按",at,viewport)
    await settle();prompt.update_content(info,"点按",at,viewport)
    check(not prompt.available,"unavailable style state")
    check(prompt.description.text==info.reason+"\n"+info.detail,"reason overrides state with detail")
    check(prompt.position.x>=0 and prompt.position.y>=0 and prompt.position.x+prompt.size.x<=viewport.x and prompt.position.y+prompt.size.y<=viewport.y,"card fits viewport "+str(viewport))
  # Screenshot uses a real rendered Godot viewport when explicitly requested.
  var screenshot:String=OS.get_environment("PROMPT_SCREENSHOT")
  if screenshot!="" and room=="":
   state.set_source_input_mode("keyboard")
   world.player.global_position=world.plot_nodes[7].global_position+Vector2(0,20)
   state.player_position=world.player.global_position
   world.player.camera.reset_smoothing()
   world.player.camera.force_update_scroll()
   state.selected_tool="seed";state.selected_seed="radish";state.stamina=100
   state.plots[7].tilled=true;state.plots[7].crop="";state.inventory[state.seed_variant_id("radish")]=0
   world.selected_world_target={"kind":"plot","index":7,"x":world.plot_nodes[7].global_position.x,"y":world.plot_nodes[7].global_position.y}
   prompt.refresh_world();await settle();prompt.refresh_world()
   prompt.advance_visibility(0.14)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(screenshot)
 await root.get_node("AudioService").prepare_exit()
 print("INTERACTION_PROMPT_SMOKE: ",passed," passed, ",failed," failed")
 quit(0 if failed==0 else 1)
