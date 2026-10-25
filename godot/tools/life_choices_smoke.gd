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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LIFE_CHOICES_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入生活选择")
  var ok:=false
  match str(row.kind):
   "chapter":ok=state.record_legacy_chapter(int(row.id),int(row.choice))
   "gathering":ok=state.attend_small_gathering(str(row.id))
   "year":ok=state.record_year_plan(int(row.choice))
  var label:="%s/%s/%s/day%d/%s"%[row.kind,str(row.id),str(row.choice),int(row.before.day),row.variant]
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版结果 "+label)
  check(same(state.legacy_chapters,row.expected.chapters),"四季回应 "+label)
  check(same(state.year_plans,row.expected.yearPlans),"来年计划 "+label)
  check(same(state.season_events,row.expected.seasonEvents),"每周小聚标记 "+label)
  check(same(state.relations,row.expected.relations),"关系与上限 "+label)
  check(same(state.skills,row.expected.skills),"经验与风格 "+label)
  check(same(state.journal_entries(),row.expected.journal),"生活日志与60条保留 "+label)
  check(same(state.legacy_systems.get("eventLog",[]),row.expected.eventLog),"事件日志与200条保留 "+label)
  check(state.money==int(row.expected.money) and state.minutes==int(row.expected.minutes),"不增加金钱或时间消耗 "+label)
  for id in state.item_catalog:check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"不消耗库存 "+label+"/"+str(id))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.community_panel
 for kind in ["chapter","gathering","year"]:
  var row:Dictionary={}
  for candidate in fixture.rows:
   if candidate.kind==kind and candidate.variant=="fresh" and int(candidate.before.day)==(28 if kind=="chapter" else 7 if kind=="gathering" else 112) and (int(candidate.id)==1 and int(candidate.choice)==1 if kind=="chapter" else candidate.id=="repair" if kind=="gathering" else int(candidate.choice)==2):
    row=candidate
    break
  check(not row.is_empty(),"可执行UI样例 "+kind)
  var base:Dictionary=state.convert_external_save(row.before)
  var tab:="records" if kind=="chapter" else "gatherings" if kind=="gathering" else "year"
  var action:="e-chapter" if kind=="chapter" else "e-small-event" if kind=="gathering" else "e-year-plan"
  var item_id:=str(row.id) if kind=="gathering" else str(int(row.id))
  var key:=action+":"+item_id+(":"+str(int(row.choice)) if kind=="chapter" else "")
  state.load_game_data(base.duplicate(true))
  state.current_interior=""
  state.player_position=Vector2(2831,500)
  panel.open_panel(tab)
  await process_frame
  panel.transaction_buttons[key].pressed.emit()
  check(state.action_busy() and not panel.visible,"生活选择进入read动作 "+kind)
  check(state.action_snapshot().kind=="read" and state.action_snapshot().item==item_id and is_equal_approx(float(state.action_snapshot().duration),0.7),"原版0.7秒动作 "+kind)
  check(same(state.legacy_chapters,row.before.chapters) and same(state.year_plans,row.before.yearPlans) and same(state.season_events,row.before.seasonEvents),"开始不记录选择 "+kind)
  await escape()
  await process_frame
  check(panel.visible and panel.active_tab==tab and not state.action_busy(),"Esc 恢复开始页签 "+kind)
  check(root.gui_get_focus_owner()==panel.transaction_buttons[key],"恢复选择焦点 "+kind)
  panel.transaction_buttons[key].pressed.emit()
  panel.active_tab="journal"
  finish(state)
  await process_frame
  check(panel.visible and panel.active_tab==tab,"完成恢复开始页签 "+kind)
  check(same(state.legacy_chapters,row.expected.chapters) and same(state.year_plans,row.expected.yearPlans) and same(state.season_events,row.expected.seasonEvents),"完成才记录原选择 "+kind)
  check(state.message==str(row.result.msg),"完成显示原版提示 "+kind)
  check(same(state.journal_entries(),row.expected.journal),"UI 只记一条原日志 "+kind)
  check(state.save_game("user://life-choices.json",true) and state.load_game("user://life-choices.json"),"选择真实文件存读 "+kind)
  check(same(state.legacy_chapters,row.expected.chapters) and same(state.year_plans,row.expected.yearPlans) and same(state.season_events,row.expected.seasonEvents) and same(state.journal_entries(),row.expected.journal),"真实文件保留选择与日志 "+kind)
  panel.close()
  state.load_game_data(base.duplicate(true))
  state.player_position=Vector2(2831,500)
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  if kind=="chapter":state.legacy_chapters["%d-%d"%[int(state.day/112)+1,int(row.id)]]=0
  elif kind=="gathering":state.season_events["%s-%d"%[item_id,int(state.day/7)]]=true
  else:state.year_plans[str(int(state.day/112))]=0
  finish(state)
  await process_frame
  check(panel.visible,"完成时重新检查后恢复页签 "+kind)
  if kind=="chapter":
   check(state.legacy_chapters["%d-%d"%[int(state.day/112)+1,int(row.id)]]==0 and state.message=="这一页已经写好，可以在旧事回看中再次阅读。","已有回应不被待完成选择覆盖")
  elif kind=="gathering":
   check(same(state.relations,row.before.relations) and state.message=="这周已经留下了这段小聚，下周再来。","已经参加时不重复增加关系")
  else:
   check(state.year_plans[str(int(state.day/112))]==int(row.choice),"原版yearPlan允许覆盖当前计划")
  panel.close()
  state.load_game_data(base.duplicate(true))
  state.player_position=Vector2(2831,500)
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  var saved:Dictionary=state._make_save_data().duplicate(true)
  state.load_game_data(saved)
  finish(state)
  check(same(state.legacy_chapters,row.before.chapters) and same(state.year_plans,row.before.yearPlans) and same(state.season_events,row.before.seasonEvents),"读档清除生活选择回调 "+kind)
  panel.close()
  state.load_game_data(base.duplicate(true))
  state.player_position=Vector2(2831,500)
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  state.current_interior="other"
  finish(state)
  check(not panel.visible and not state.action_busy() and same(state.legacy_chapters,row.before.chapters) and same(state.year_plans,row.before.yearPlans) and same(state.season_events,row.before.seasonEvents),"切换房间不完成选择 "+kind)
  state.current_interior=""
  state.load_game_data(base.duplicate(true))
  state.player_position=Vector2(2831,500)
  state.feedback.prefs.pace="brisk"
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  check(is_equal_approx(float(state.action_snapshot().duration),0.455),"read快速节奏 "+kind)
  state.cancel_action()
  await process_frame
  panel.close()
 for pair in [["tea","mountain"],["repair","town"],["lost","river"]]:
  state.player_position=world.player.global_position
  panel.open_panel("gatherings")
  var key:="e-small-event:"+str(pair[0])
  check(panel.transaction_buttons[key].text=="去附近看看","不同区域显示导航按钮 "+str(pair[1]))
  var target:Dictionary=fixture.destinations[str(pair[1])]
  panel.transaction_buttons[key].pressed.emit()
  check(not panel.visible and not state.action_busy() and not state.walking_target.is_empty(),"导航不直接参加小聚 "+str(pair[1]))
  check(is_equal_approx(float(state.walking_target.get("x",0)),float(target.x)) and is_equal_approx(float(state.walking_target.get("y",0)),float(target.y)),"小聚导航目的地与原版一致 "+str(pair[1]))
  state.stop_walking()
 print("LIFE_CHOICES_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
