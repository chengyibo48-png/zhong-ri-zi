extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<12:push_error(label)
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
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("MAIL_REWARDS_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入信件与纪念物源状态")
  var ok:bool=state.claim_letter(str(row.id)) if row.kind=="mail" else state.claim_legacy_achievement(str(row.id))
  check(ok==bool(row.result.ok),"领取成功条件 %s/%s"%[row.kind,row.id])
  check(state.message==str(row.result.msg),"原版提示 %s/%s"%[row.kind,row.id])
  for id in state.item_catalog:
   check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"随信数量 "+str(id))
  check(same(state.kitchen.lots,row.expected.lots),"新鲜与陈放批次 "+str(row.id))
  check(same(state.legacy_systems.get("discovered",[]),row.expected.discovered),"发现序列 "+str(row.id))
  check(same(state.mail_read,row.expected.mailRead),"已读名单")
  check(same(state.achievements,row.expected.achievements),"纪念物领取名单")
  check(same(state.furniture,row.expected.furniture),"家具奖励")
  check(same(state.legacy_systems.get("eventLog",[]),row.expected.eventLog),"不添加事件日志")
  check(same(state.player_journal,row.expected.journal),"不添加生活日志")
 var base:Dictionary=state.convert_external_save(fixture.rows[0].before)
 check(state.load_game_data(base),"UI 基准")
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.current_interior=""
 state.letters.assign([{"id":"one","from":"邻居","title":"第一封","text":"问候","gift":{"rice":3}},{"id":"two","from":"邻居","title":"第二封","text":"问候","gift":{"wood":2}}])
 state.mail_read.clear()
 var panel=world.hud.mail_panel
 panel.open_panel()
 panel.selected_id="one"
 panel.refresh()
 var rice:int=state.inventory.get("rice",0)
 panel.claim_button.pressed.emit()
 check(state.action_busy() and not panel.visible and not state.ui_open,"读信进入世界动作")
 check(state.inventory.get("rice",0)==rice and state.mail_read.is_empty(),"动作开始不发礼物或标已读")
 check(state.action_snapshot().kind=="pack" and state.action_snapshot().item=="one","捕获信件与原版 pack")
 check(is_equal_approx(float(state.action_snapshot().duration),1.2),"分拣持续原版1.2秒")
 await escape()
 check(panel.visible and panel.selected_id=="one" and state.mail_read.is_empty(),"Esc 恢复信件且无结算")
 check(root.gui_get_focus_owner()==panel.claim_button,"取消恢复领取焦点")
 panel.claim_button.pressed.emit()
 panel.selected_id="two"
 finish(state)
 check(state.mail_read==["one"] and state.inventory.rice==rice+3,"完成领取开始选中的信")
 check(panel.visible and panel.selected_id=="one" and panel.claim_button.disabled,"领取后仍可阅读且禁止重复")
 check(root.gui_get_focus_owner()==panel.list,"已读时恢复列表焦点")
 panel.selected_id="two"
 panel.refresh()
 panel.claim_button.pressed.emit()
 state.mail_read.append("two")
 var wood:int=state.inventory.get("wood",0)
 finish(state)
 check(state.inventory.get("wood",0)==wood and state.message=="这封信已经好好收好了。","完成时重查已读")
 state.mail_read.erase("two")
 panel.refresh()
 panel.claim_button.pressed.emit()
 var saved:Dictionary=state._make_save_data().duplicate(true)
 state.load_game_data(saved)
 finish(state)
 check(not state.action_busy() and not state.mail_read.has("two"),"读档清除旧来信回调")
 panel.open_panel()
 panel.selected_id="two"
 panel.refresh()
 panel.claim_button.pressed.emit()
 state.current_interior="other"
 state._process_action(0.1)
 finish(state)
 check(not state.mail_read.has("two") and not panel.visible,"切换房间不收信或恢复旧面板")
 state.current_interior=""
 state.ui_open=false
 var awards=world.hud.community_panel
 var a:Dictionary=state.content.achievements[0]
 var id:=str(a.id)
 state.achievements.erase(id)
 state.player_stats[a.stat]=int(a.target)
 var reward:=str(a.reward)
 var owned:int=state.furniture.get(reward,0)
 awards.open_panel("records")
 awards.achievement_buttons[id].pressed.emit()
 check(state.action_busy() and not awards.visible and state.furniture.get(reward,0)==owned,"纪念物开始不发奖励")
 check(state.action_snapshot().kind=="pack" and state.action_snapshot().item==id,"纪念物 pack 携带记录ID")
 await escape()
 await process_frame
 check(awards.visible and awards.active_tab=="records" and not state.achievements.has(id),"纪念物取消保留页签")
 check(root.gui_get_focus_owner()==awards.achievement_buttons[id],"取消恢复纪念物按钮焦点")
 awards.achievement_buttons[id].pressed.emit()
 finish(state)
 await process_frame
 check(state.furniture.get(reward,0)==owned+1 and state.achievements.has(id),"纪念物完成只发一件")
 check(awards.visible and awards.achievement_buttons[id].disabled,"完成后按钮禁止重复")
 check(root.gui_get_focus_owner()==awards.tab_buttons.records,"完成恢复四季页签焦点")
 state.achievements.erase(id)
 awards.open_panel("archives")
 awards.achievement_buttons[id].pressed.emit()
 state.player_stats[a.stat]=int(a.target)-1
 finish(state)
 await process_frame
 check(state.furniture.get(reward,0)==owned+1 and not state.achievements.has(id),"完成时重查统计目标")
 check(awards.active_tab=="archives" and state.message=="这页记录还没有完成，或纪念物已经领过。","旧物柜领取恢复原页与失败提示")
 state.player_stats[a.stat]=int(a.target)
 awards.refresh()
 awards.achievement_buttons[id].pressed.emit()
 saved=state._make_save_data().duplicate(true)
 state.load_game_data(saved)
 finish(state)
 check(not state.achievements.has(id) and state.furniture.get(reward,0)==owned+1,"纪念物读档清除回调")
 print("MAIL_REWARDS_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
