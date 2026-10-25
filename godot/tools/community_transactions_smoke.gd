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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("COMMUNITY_TRANSACTIONS_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入乡里事务状态")
  var ok:=false
  match str(row.kind):
   "project":ok=state.complete_community_project(str(row.id))
   "favor":ok=state.complete_neighbor_favor(int(row.id))
   "deliver":ok=state.fulfill_legacy_order(str(row.id))
  var label:="%s/%s/%s"%[row.kind,str(row.id),row.variant]
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"结果与提示 "+label)
  for id in state.item_catalog:
   check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"库存 "+label+"/"+str(id))
   var q:Array=row.expected.quality.get(id,[0,0,0])
   var counts:Array=[maxi(0,int(row.expected.bag.get(id,0))-int(q[0])-int(q[1])-int(q[2])),int(q[0]),int(q[1]),int(q[2])]
   check(same(state._quality_counts(id),counts),"品质消耗 "+label+"/"+str(id))
  check(same(state.kitchen.lots,row.expected.lots),"食物批次 "+label)
  check(same(state.legacy_systems.get("discovered",[]),row.expected.discovered),"回礼发现顺序 "+label)
  for id in row.expected.flags:check(state.flags.get(id)==row.expected.flags[id],"事务标记 "+label+"/"+str(id))
  for id in state.community_projects:
   check(bool(state.community_projects[id])==bool(row.expected.projects.get(id,false)),"公共项目完成状态 "+label+"/"+str(id))
  for id in row.expected.projects:
   check(bool(state.community_projects.get(id,false))==bool(row.expected.projects[id]),"原版项目完成状态 "+label+"/"+str(id))
  check(same(state.relations,row.expected.relations),"关系奖励 "+label)
  check(same(state.skills,row.expected.skills),"手艺与社交经验 "+label)
  check(same(state.season_events,row.expected.seasonEvents),"帮助完成标记 "+label)
  check(same(state.archives,row.expected.archives),"旧照片 "+label)
  check(same(state.known_recipes,row.expected.knownRecipes),"配方解锁 "+label)
  check(state.money==int(row.expected.money) and state.minutes==int(row.expected.minutes),"金钱与帮摊时间 "+label)
  for id in row.expected.stats:check(state.player_stats.get(id,0)==row.expected.stats[id],"统计 "+label+"/"+str(id))
  check(same(state.journal_entries(),row.expected.journal),"生活日志顺序与60条保留 "+label)
  check(same(state.legacy_systems.get("eventLog",[]),row.expected.eventLog),"事件日志与200条保留 "+label)
  if str(row.variant) in ["base","log-cap"]:
   check(state.save_game("user://community-transactions.json",true),"事务真实文件保存 "+label)
   check(state.load_game("user://community-transactions.json"),"事务真实文件加载 "+label)
   check(same(state.journal_entries(),row.expected.journal),"文件保留生活日志顺序 "+label)
   check(same(state.legacy_systems.get("eventLog",[]),row.expected.eventLog),"文件保留独立事件日志 "+label)
   check(same(state.relations,row.expected.relations) and same(state.known_recipes,row.expected.knownRecipes),"文件保留关系与配方 "+label)
   check(same(state.legacy_systems.get("discovered",[]),row.expected.discovered),"文件保留回礼发现顺序 "+label)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.community_panel
 for kind in ["project","favor","deliver"]:
  var row:Dictionary={}
  for candidate in fixture.rows:
   if str(candidate.kind)==kind and candidate.variant=="base" and bool(candidate.result.ok):
    row=candidate
    break
  check(not row.is_empty(),"存在正常事务 "+kind)
  var base:Dictionary=state.convert_external_save(row.before)
  state.load_game_data(base.duplicate(true))
  state.current_interior=""
  state.npc_positions.clear()
  var tab:="projects" if kind=="project" else "favors" if kind=="favor" else "orders"
  var action:="e-project" if kind=="project" else "e-favor" if kind=="favor" else "deliver"
  var row_id:=str(int(row.id)) if kind=="favor" else str(row.id)
  var key:=action+":"+row_id
  var expected_kind:="build" if kind=="project" else "trade"
  var expected_seconds:=1.7 if kind=="project" else 1.6
  panel.open_panel(tab)
  await process_frame
  check(not panel.transaction_buttons[key].disabled,"正常按钮不附加位置/NPC条件 "+kind)
  var stock:Dictionary=state.inventory.duplicate(true)
  var cash:int=state.money
  panel.transaction_buttons[key].pressed.emit()
  check(state.action_busy() and not panel.visible and not state.ui_open,"进入世界事务动作 "+kind)
  check(same(state.inventory,stock) and state.money==cash,"动画开始不结算 "+kind)
  check(state.action_snapshot().kind==expected_kind and state.action_snapshot().item==row_id and is_equal_approx(float(state.action_snapshot().duration),expected_seconds),"原版动作种类与时长 "+kind)
  panel._begin_transaction(action,row_id)
  check(state.action_snapshot().item==row_id,"进行中不重复排入 "+kind)
  await escape()
  await process_frame
  check(panel.visible and panel.active_tab==tab and same(state.inventory,stock) and state.money==cash,"Esc 恢复原页且无消耗 "+kind)
  check(root.gui_get_focus_owner()==panel.transaction_buttons[key],"取消恢复事务按钮焦点 "+kind)
  panel.transaction_buttons[key].pressed.emit()
  panel.active_tab="year"
  finish(state)
  await process_frame
  check(panel.visible and panel.active_tab==tab,"完成恢复开始页签 "+kind)
  for id in state.item_catalog:check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"界面事务库存 "+kind+"/"+str(id))
  check(state.money==int(row.expected.money) and same(state.relations,row.expected.relations),"界面事务奖励 "+kind)
  check(panel.transaction_buttons[key].disabled,"完成禁止重复 "+kind)
  check(root.gui_get_focus_owner()==panel.tab_buttons[tab],"已完成恢复页签焦点 "+kind)
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  var needs:Dictionary=row.before.bag
  var def:Dictionary={}
  if kind=="project":def=state.content.projects[str(row.id)]
  else:
   for item in state.content.get("favors" if kind=="favor" else "orders",[]):
    if str(item.id)==str(row.id):def=item
  if not def.get("needs",{}).is_empty():
   var item_id:=str(def.needs.keys()[0])
   state.inventory[item_id]=0
   cash=state.money
   finish(state)
   await process_frame
   check(state.money==cash and panel.visible,"完成时重查材料不发回礼 "+kind)
  else:
   state.cancel_action()
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  var saved:Dictionary=state._make_save_data().duplicate(true)
  state.load_game_data(saved)
  finish(state)
  check(same(state.inventory,saved.inventory) and state.money==int(saved.money) and not state.action_busy(),"读档清除事务回调 "+kind)
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  stock=state.inventory.duplicate(true)
  state.current_interior="other"
  finish(state)
  check(same(state.inventory,stock) and not panel.visible and not state.action_busy(),"房间变化取消事务 "+kind)
  state.current_interior=""
  state.load_game_data(base.duplicate(true))
  state.feedback.prefs.pace="brisk"
  panel.open_panel(tab)
  panel.transaction_buttons[key].pressed.emit()
  check(is_equal_approx(float(state.action_snapshot().duration),expected_seconds*0.65),"快速节奏原版缩放 "+kind)
  state.ui_open=true
  state._process_action(0.1)
  check(float(state.action_snapshot().progress)>0.0,"原版面板保持事务动作进行 "+kind)
  state.ui_open=false
  state.cancel_action()
  await process_frame
  panel.close()
 print("COMMUNITY_TRANSACTIONS_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
