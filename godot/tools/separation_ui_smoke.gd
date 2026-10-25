extends SceneTree
const VIEW=preload("res://scripts/separation_view.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=18:push_error(label)
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in b.size():
   if not same(a[i],b[i]):return false
  return true
 if (a is int or a is float) and (b is int or b is float):return float(a)==float(b)
 return a==b
func gameplay_same(a:Dictionary,b:Dictionary)->bool:
 for field in ["inventory","storage","quality","kitchen","money","minutes","player_stats","relations","npc_stories","neighbors","known_recipes","skills","marriage","partners"]:
  if not same(a.get(field),b.get(field)):return false
 return true
func stock_same(a:Dictionary,b:Dictionary)->bool:
 var keys:Array=a.keys()
 for key in b:
  if not keys.has(key):keys.append(key)
 for key in keys:
  if float(a.get(key,0))!=float(b.get(key,0)):return false
 return true
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
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SEPARATION_FIXTURE")))
 check(VIEW.describe()==fixture.view,"actual source separation view")
 var seed:Dictionary=state.convert_external_save(fixture.rows[0].before)
 for room in ["","home-granny"]:
  state.load_game_data(seed.duplicate(true));state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud;var panel=hud.separation_panel
  if hud.onboarding_open():hud.toggle_onboarding()
  hud.show_home();hud.home_panel._ask_separate()
  check(panel.visible and not hud.home_panel.visible and hud._gamepad_panel()==panel,"home independent separation route")
  check(panel.last_view==fixture.view and state.marriage.spouse==seed.marriage.spouse,"opening source content without effect")
  panel.cancel_button.pressed.emit()
  check(hud.home_panel.visible and not panel.visible and state.ui_open,"decline returns home")
  hud.close_top_panel()
  hud.show_neighbors(str(seed.marriage.spouse));hud.neighbor_journal._on_separate()
  check(panel.visible and not hud.neighbor_journal.visible,"journal independent separation route")
  await escape();check(not panel.visible and not state.ui_open,"page Esc returns world")
  for row in fixture.rows:
   check(state.load_game_data(state.convert_external_save(row.before)),"source seed imported")
   state.current_interior=room
   hud.show_separation()
   check(panel.z_index==20 and root.gui_get_focus_owner()==panel.cancel_button,"source modal layer and separate initial focus")
   var before:Dictionary=state._make_save_data().duplicate(true)
   panel.confirm_button.pressed.emit()
   check(state.action_busy() and not panel.visible and gameplay_same(state._make_save_data(),before),"separation deferred")
   check(state.action_snapshot().kind=="greet" and float(state.action_snapshot().duration)==1.1 and str(state.action_snapshot().item)=="","source empty-id separation action")
   await escape()
   check(panel.visible and gameplay_same(state._make_save_data(),before) and root.gui_get_focus_owner()==panel.confirm_button,"action Esc restores untouched page")
   panel.confirm_button.pressed.emit()
   state.day=int(row.mutation.day);state.marriage=row.mutation.marriage.duplicate(true)
   if state.marriage.spouse==null:state.marriage.spouse=""
   state.partners=row.mutation.partners.duplicate(true);state.relations=row.mutation.relations.duplicate(true)
   finish(state)
   var expected_marriage:Dictionary=row.expected.marriage.duplicate(true)
   if expected_marriage.spouse==null:expected_marriage.spouse=""
   var label:String=str(row.id)+"/"+str(row.mode)+"/"+room
   check(same(state.marriage,expected_marriage),"source marriage "+label)
   check(same(state.partners,row.expected.partners),"source current partner "+label)
   check(same(state.relations,row.expected.relations) and same(state.npc_stories,row.expected.stories),"relations and stories retained "+label)
   check(stock_same(state.inventory,row.expected.bag),"source inventory quantities "+label)
   check(same(state.inventory,before.inventory),"native inventory dictionary unchanged "+label)
   check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"source event and journal "+label)
   check(state.message==row.result.msg,"source result message "+label+" actual="+state.message+" expected="+str(row.result.msg))
   if row.opened=="home":
    check(hud.home_panel.visible and not panel.visible and state.ui_open,"success home route "+label)
    var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
    check(saved is Dictionary and saved.marriage.spouse=="","separation saved "+label)
   else:
    check(panel.visible and panel.column.get_node("ModalStatus/Message").text==row.result.msg,"failure remains readable "+label)
   hud.close_top_panel()
  for reason in ["load","room"]:
   state.load_game_data(seed.duplicate(true));state.current_interior=room
   hud.show_separation();panel.confirm_button.pressed.emit()
   if reason=="load":state.load_game_data(state._make_save_data())
   else:state.current_interior="other"
   finish(state)
   check(state.marriage.spouse==seed.marriage.spouse and not state.action_busy() and not panel.visible,"invalidated action "+reason)
   state.current_interior=room
  for size in [Vector2i(1280,800),Vector2i(640,360)]:
   root.size=size;await settle();hud.show_separation();await settle()
   var rect:Rect2=panel.panel.get_global_rect()
   check(rect.position.x>=0 and rect.end.x<=panel.get_viewport_rect().size.x,"separation horizontal bounds")
   check(rect.position.y>=0 and rect.end.y<=panel.get_viewport_rect().size.y,"separation vertical bounds")
   hud.close_top_panel()
 if OS.get_environment("SEPARATION_SCREENSHOT")!="":
  root.size=Vector2i(960,600);await settle();current_scene.hud.show_separation();await settle()
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("SEPARATION_SCREENSHOT"))
 print("Separation UI: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
