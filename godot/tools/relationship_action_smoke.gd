extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for k in b:
   if not a.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in range(a.size()):
   if not same(a[i],b[i]):return false
  return true
 return a==b
func finish(state):
 for i in range(35):state._process_action(0.1)
func escape():
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 key=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=false
 Input.parse_input_event(key)
 await process_frame
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RELATIONSHIP_ACTION_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var unmarried:Dictionary
 var married:Dictionary
 for row in fixture.rows:
  var label:String=str(row.op)+"/"+str(row.id)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"导入 "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  if row.id=="qiao" and row.variant=="ready":
   if row.op=="marry":unmarried=before.duplicate(true)
   else:married=before.duplicate(true)
  var ok:bool=state.marry_npc(str(row.id)) if row.op=="marry" else state.separate_from_partner()
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"结果提示 "+label)
  var expected:Dictionary=row.expected.marriage.duplicate(true)
  if expected.spouse==null:expected.spouse=""
  check(same(state.marriage,expected),"伴侣日期每周安排记忆 "+label)
  check(same(state.partners,row.expected.partners),"交往状态 "+label)
  check(same(state.journal_entries(),row.expected.journal),"原版60条生活记录 "+label)
  check(same(state.legacy_systems.eventLog,row.expected.eventLog),"原版200条事件记录 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["inventory","storage","quality","kitchen","money","minutes","player_stats","relations","npc_stories","neighbors","known_recipes","skills"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
 check(not unmarried.is_empty() and not married.is_empty(),"存在合法未婚婚后样例")
 state.load_game_data(unmarried.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var neighbor=world.hud.neighbor_journal
 var home=world.hud.home_panel
 for entry in ["neighbor-separate","home-separate"]:
  state.load_game_data(married.duplicate(true))
  var origin=home if entry=="home-separate" else neighbor
  if origin==home:origin.open_panel();origin._ask_separate()
  else:origin.open_panel("qiao");origin._on_separate()
  var panel=world.hud.separation_panel
  var old:Dictionary=state.marriage.duplicate(true)
  check(panel.visible and not origin.visible and same(state.marriage,old),"确认页未结算 "+entry)
  panel.cancel_button.pressed.emit()
  check(not panel.visible and home.visible and state.ui_open and same(state.marriage,old),"暂不决定返回家庭 "+entry)
  home.close();world.hud.show_separation()
  await escape()
  check(not panel.visible and not state.ui_open and same(state.marriage,old),"真实Esc回到世界 "+entry)
  world.hud.show_separation();panel.confirm_button.pressed.emit()
  check(state.action_busy() and not panel.visible and same(state.marriage,old),"确认后开始动作仍未结算 "+entry)
  check(state.action_snapshot().kind=="greet" and is_equal_approx(float(state.action_snapshot().duration),1.1),"原版动作时长 "+entry)
  check(str(state.action_snapshot().get("item",""))=="","原版空物品ID "+entry)
  await escape();await process_frame
  check(panel.visible and same(state.marriage,old),"动作取消回到独立确认页 "+entry)
  check(root.gui_get_focus_owner()==panel.confirm_button,"动作取消恢复确认焦点 "+entry)
  panel.confirm_button.pressed.emit();finish(state);await process_frame
  check(state.marriage.spouse=="" and home.visible and not neighbor.visible and not panel.visible and state.ui_open,"成功打开家庭页 "+entry)
  var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
  check(saved is Dictionary and saved.marriage.spouse=="","成功立即自动保存 "+entry)
  check(state.save_game("user://relationship-action.json",true) and state.load_game("user://relationship-action.json"),"真实文件存读 "+entry)
  home.close()
  for reason in ["load","room"]:
   state.load_game_data(married.duplicate(true));world.hud.show_separation();panel.confirm_button.pressed.emit()
   if reason=="load":state.load_game_data(state._make_save_data())
   else:state.current_interior="other"
   finish(state)
   check(not state.action_busy() and same(state.marriage,old) and not panel.visible,"旧回调失效 "+reason+"/"+entry)
   state.current_interior=""
  state.load_game_data(married.duplicate(true));state.feedback.prefs.pace="brisk"
  world.hud.show_separation();panel.confirm_button.pressed.emit()
  check(is_equal_approx(float(state.action_snapshot().duration),0.715),"快速节奏 "+entry)
  state.cancel_action();panel.cancel_button.pressed.emit();home.close()
 # Completion rechecks trust and keeps the failed wedding confirmation available.
 state.load_game_data(unmarried.duplicate(true))
 neighbor.open_panel("qiao");neighbor._on_marry()
 world.hud.wedding_panel.confirm_button.pressed.emit()
 state.relations.qiao.points=69
 finish(state)
 await process_frame
 check(state.marriage.spouse=="" and not neighbor.visible and world.hud.wedding_panel.visible,"婚礼完成重查信任")
 check(state.message=="需要双方确认心意、走完前四章，并达到信任。","婚礼失败原版提示")
 world.hud.wedding_panel.cancel_button.pressed.emit()
 neighbor.close()
 state.load_game_data(unmarried.duplicate(true))
 state.npc_stories.qiao.step=3
 neighbor.open_panel("qiao")
 check(not neighbor.marry_button.visible,"未过四章不显示婚礼入口")
 neighbor.close()
 print("RELATIONSHIP_ACTION_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
