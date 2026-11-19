extends SceneTree
var passed:int=0
var failures:Array=[]
var s:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failures.append(label);printerr("FAIL ",label)
func frames(n:int)->void:
 for i:int in n:await physics_frame
func key(code:Key,down:bool)->void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 Input.parse_input_event(e)
 Input.flush_buffered_events()
func run()->void:
 create_timer(90).timeout.connect(func():quit(2))
 s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
 s.flags.introDone=true;s.current_interior="";s.ui_open=false;s.selected_tool="rod"
 change_scene_to_file("res://scenes/main.tscn");await frames(10)
 DisplayServer.window_set_title("种日子 · 钓鱼入口隔离验证")
 var world:Node=current_scene
 var player:Node2D=world.player
 var hud:Node=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 await s.wait_for_saves();s.ui_open=false
 var selector:RefCounted=load("res://scripts/interaction_selection.gd").new()
 var fixture:Dictionary={"kind":"fish","id":"range-fixture","x":0.0,"y":0.0}
 for distance:float in [53.0,65.0,75.0]:
  selector.clear();check(not selector.choose(Vector2(distance,0),Vector2.LEFT,[fixture]).is_empty(),"fishing hint matches cast range "+str(distance))
 selector.clear();check(selector.choose(Vector2(75.01,0),Vector2.LEFT,[fixture]).is_empty(),"outside fishing range remains rejected")
 fixture.kind="npc";selector.clear();check(selector.choose(Vector2(53,0),Vector2.LEFT,[fixture]).is_empty(),"other interaction ranges unchanged")
 player.position=Vector2(3364.0614351877284,1607.4528774399012);s.player_position=player.position
 world.interaction_selection.clear();world._refresh_world_target();hud.context_actions.refresh_world();await frames(2)
 var bank_button:Button=null
 for button:Button in hud.context_actions.buttons:
  if button.text=="前往最近钓点":bank_button=button
 check(bank_button!=null and bank_button.is_visible_in_tree(),"rod at actual reported area offers a visible bank route")
 if bank_button!=null:
  bank_button.pressed.emit();await frames(2)
  check(not s.walking_target.is_empty(),"bank button starts real walking navigation")
  for i:int in 1000:
   if s.walking_target.is_empty():break
   await physics_frame
  check(s.walking_target.is_empty(),"bank route completes without teleport")
  var nearest:float=INF
  for point:Dictionary in s.system_catalog.fishing.spots:nearest=minf(nearest,player.position.distance_to(Vector2(float(point.x),float(point.y))))
  check(nearest<=75,"bank route ends inside actual cast range")
 for point:Dictionary in s.system_catalog.fishing.spots:
  s.cancel_player_action();await s.wait_for_saves();s.ui_open=false
  player.position=Vector2(float(point.x),float(point.y))+Vector2(0,-65);s.player_position=player.position
  s.set_player_direction_from_vector(Vector2.DOWN);world.interaction_selection.clear();world.pointer_hover.clear()
  var selected:Dictionary=world._refresh_world_target()
  check(str(selected.get("kind",""))=="fish" and str(selected.get("id",""))==str(point.id),"real bank selected from 65 px "+str(point.id))
  hud.interaction_prompt.refresh_world();hud.context_actions.refresh_world();await frames(2)
  check(hud.interaction_prompt.presence_wanted and hud.interaction_prompt.heading.text.contains("抛竿"),"real bank presents fishing key hint "+str(point.id))
 # Native key input enters fishing from the existing pond bank.
 var point:Dictionary=s.system_catalog.fishing.spots[2]
 player.position=Vector2(float(point.x),float(point.y))+Vector2(0,-35);s.player_position=player.position
 s.stamina=100;s.minutes=600;s.fishing.bait="plain";s.fishing.mode="relaxed";s.fishing.inputStyle="hold";s.ui_open=false;s.fishing_focus_paused=false
 world.interaction_selection.clear();world.pointer_hover.clear();world._refresh_world_target();await s.wait_for_saves()
 key(KEY_E,true);key(KEY_E,false);await frames(3)
 check(s.fishing_active(),"E at pond bank starts a real fishing session")
 if s.fishing_active():
  key(KEY_SPACE,true)
  await frames(1);s._process_action(.1);key(KEY_SPACE,false);await frames(1)
  check(str(s.fishing_session.game.stage)=="cast","space press/release launches cast")
  for frame:int in 5000:
   if not s.fishing_active():break
   if s.transactions.busy():await s.wait_for_saves();await frames(1);continue
   var g:Dictionary=s.fishing_session.game
   if g.stage=="bite":key(KEY_SPACE,true);key(KEY_SPACE,false)
   if g.stage=="fight":
    if bool(g.holding) and float(g.tension)>=65:key(KEY_SPACE,false)
    elif not bool(g.holding) and float(g.tension)<=25:key(KEY_SPACE,true)
   s._process_action(1.0/60)
  key(KEY_SPACE,false);await s.wait_for_saves();await frames(3)
  check(not s.fishing.pending.is_empty(),"bank entry leads through native controls to a pending fish")
  if not s.fishing.pending.is_empty():
   var id:String=str(s.fishing.pending.fish);var before:int=int(s.inventory.get(id,0))
   hud.fishing_panel._resolve(false);await s.wait_for_saves();await frames(3)
   check(int(s.inventory.get(id,0))==before+1 and s.fishing.pending.is_empty(),"keep fish awards exactly one item")
   check(not s.ui_open and not s.action_busy(),"catch returns to playable world")
 var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/entry.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failures":failures,"isolated":true},"  "));file.close()
 print("FISHING_ENTRY passed=",passed," failures=",failures.size())
 current_scene.queue_free();await process_frame
 await s.wait_for_saves();await root.get_node("AudioService").prepare_exit();quit(0 if failures.is_empty() else 1)
