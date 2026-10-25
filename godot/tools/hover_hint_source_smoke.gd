extends SceneTree
const RULES=preload("res://scripts/interaction_hint_rules.gd")
const CODEC=preload("res://scripts/save_json.gd")
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
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOVER_HINT_FIXTURE"))))
 var before:Dictionary=state._make_save_data().duplicate(true)
 for row in fixture.rows:
  var actual:Dictionary=RULES.hover_content(row.info,row.key)
  check(actual.name==row.expected.name,"original hover name")
  check(actual.body==row.expected.body,"original hover state/reason/verb/detail/binding")
 for row in fixture.positions:
  var actual:Vector2=RULES.hover_position(Vector2(row.pointer.x,row.pointer.y),Vector2(row.width,row.height),Vector2(row.view.width,row.view.height))
  check(float(actual.x)==float(row.x) and float(actual.y)==float(row.y),"original pointer offset and bounds")
 check(state._make_save_data()==before,"hover model is read-only")
 for room in ["","home-granny"]:
  state.current_interior=room;state.cancel_action()
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  var card=hud.hover_card;card.set_process(false)
  for row in fixture.guards:
   state.ui_open=row.menu;state.cancel_action()
   if row.locked:state.begin_action({"kind":"read","duration":2.0},{"x":0.0,"y":0.0},Callable())
   world.pointer_hover={"kind":"tools","id":"tools","name":"农具台"} if row.hasTarget else {}
   world.pointer_screen=Vector2(300,200)
   card.refresh_world()
   check(card.visible!=bool(row.hidden),"source hover visibility "+room)
  state.cancel_action();state.ui_open=false
  for mode in ["keyboard","pad","touch"]:
   state.set_source_input_mode(mode);state.player_settings.bindings.interact="z"
   world.pointer_hover={"kind":"tools","id":"tools","name":"农具台"};world.pointer_screen=Vector2(900,550)
   card.refresh_world();await settle();card.refresh_world()
   check(card.visible and card.description.text.ends_with("点击走近 · Z 交互"),"hover always uses actual keyboard binding "+room+"/"+mode)
   check(card.position==RULES.hover_position(Vector2(900,550),card.size,card.get_viewport_rect().size),"actual control size anchors hover")
  check(card.mouse_filter==Control.MOUSE_FILTER_IGNORE and card.focus_mode==Control.FOCUS_NONE,"hover passes input")
  for child in card.find_children("*","Control",true,false):check(child.mouse_filter==Control.MOUSE_FILTER_IGNORE,"hover child passes input")
  world._pointer_leave();card.refresh_world();check(not card.visible,"window exit hides hover")
  var prompt=hud.interaction_prompt;prompt.set_process(false)
  state.feedback.prefs.motion="full"
  prompt._set_presence(false);prompt.advance_visibility(0.14)
  prompt._set_presence(true)
  check(prompt.visible and prompt.modulate.a==0.0,"fade starts visible at zero opacity")
  prompt.advance_visibility(0.035)
  check(absf(prompt.modulate.a-RULES.css_ease(0.25))<0.000001,"CSS ease first quarter")
  prompt.advance_visibility(0.035)
  var alpha:float=prompt.modulate.a
  check(absf(alpha-RULES.css_ease(0.5))<0.000001,"CSS ease halfway")
  prompt._set_presence(false)
  check(prompt.modulate.a==alpha and absf(prompt.tween_duration-0.14*RULES.css_ease(0.5))<0.000001,"reverse remains continuous and shortens duration")
  prompt.advance_visibility(0.14)
  check(not prompt.visible and prompt.modulate.a==0.0,"fade-out completes hidden")
  prompt._set_presence(true);prompt.advance_visibility(0.14)
  check(prompt.visible and prompt.modulate.a==1.0,"fade-in completes opaque")
  state.feedback.prefs.motion="reduced";prompt._set_presence(false)
  check(not prompt.visible and prompt.modulate.a==0.0,"reduced mode hides immediately")
  prompt._set_presence(true)
  check(prompt.visible and prompt.modulate.a==1.0,"reduced mode shows immediately")
  check(RULES.css_ease(0)==0 and RULES.css_ease(1)==1,"ease endpoints exact")
 await root.get_node("AudioService").prepare_exit()
 print("HOVER_HINT_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",fixture.rows.size()," texts, ",fixture.positions.size()," positions")
 quit(0 if failed==0 else 1)
