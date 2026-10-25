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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOUSEHOLD_ACTION_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"原版家庭状态导入")
  var people:Dictionary=state.neighbors.people.duplicate(true)
  var ok:bool=state.host_meal(str(row.id),str(row.dish)) if row.kind=="host" else state.share_life(str(row.id),str(row.dish))
  var label:="%s/%s/%s/%s"%[row.kind,str(row.id),row.dish,row.variant]
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版结果 "+label)
  for id in state.item_catalog:
   check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"库存 "+label+"/"+str(id))
   var q:Array=row.expected.quality.get(id,[0,0,0])
   check(same(state._quality_counts(id),[maxi(0,int(row.expected.bag.get(id,0))-int(q[0])-int(q[1])-int(q[2])),int(q[0]),int(q[1]),int(q[2])]),"品质 "+label+"/"+str(id))
  var expected:Dictionary=row.expected.marriage.duplicate(true)
  if expected.spouse==null:expected.spouse=""
  check(same(state.marriage,expected),"周安排与80条记忆 "+label)
  check(same(state.relations,row.expected.relations),"关系奖励 "+label)
  check(same(state.skills,row.expected.skills),"经验 "+label)
  check(same(state.known_recipes,row.expected.recipes),"学菜谱 "+label)
  check(same(state.kitchen.lots,row.expected.lots),"料理陈放批次 "+label)
  check(same(state.season_events,row.expected.seasonEvents),"家宴周标记 "+label)
  check(same(state.journal_entries(),row.expected.journal),"普通日志 "+label)
  check(same(state.legacy_systems.eventLog,row.expected.eventLog),"事件记录 "+label)
  check(same(state.neighbors.people,people),"不写额外NPC对话记录 "+label)
  check(state.money==int(row.expected.money) and state.minutes==int(row.expected.minutes),"不额外收费或加时间 "+label)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.home_panel
 for kind in ["host","shared"]:
  var row:Dictionary={}
  for r in fixture.rows:
   if r.kind==kind and r.variant=="base" and r.dish=="greens" and (r.id=="granny" if kind=="host" else r.id=="meal"):
    row=r
    break
  var base:Dictionary=state.convert_external_save(row.before)
  state.load_game_data(base.duplicate(true))
  panel.open_panel()
  panel._select_option_id(panel.guest_option,"granny")
  panel._select_option_id(panel.host_dish,"greens")
  panel._select_option_id(panel.shared_dish,"greens")
  var button:Button=panel.host_button if kind=="host" else panel.shared_buttons.meal
  var stock:Dictionary=state.inventory.duplicate(true)
  button.pressed.emit()
  check(state.action_busy() and not panel.visible and same(state.inventory,stock),"开始交接不消费 "+kind)
  check(state.action_snapshot().kind=="trade" and is_equal_approx(float(state.action_snapshot().duration),1.6),"原版1.6秒交接 "+kind)
  await escape()
  await process_frame
  check(panel.visible and same(state.inventory,stock) and panel._dish_id(panel.host_dish)=="greens" and panel._dish_id(panel.shared_dish)=="greens","取消恢复料理及库存 "+kind)
  button.pressed.emit()
  panel._select_option_id(panel.host_dish,"eggRice")
  panel._select_option_id(panel.shared_dish,"eggRice")
  panel._select_option_id(panel.guest_option,"lin")
  finish(state)
  await process_frame
  check(state.inventory.greens==int(row.expected.bag.greens) and state.inventory.eggRice==int(row.expected.bag.eggRice),"使用捕获料理 "+kind)
  check(same(state.relations,row.expected.relations) and same(state.season_events,row.expected.seasonEvents),"使用捕获客人与安排 "+kind)
  check(panel.visible and button.disabled,"完成恢复面板及周上限 "+kind)
  check(state.save_game("user://household-action.json",true) and state.load_game("user://household-action.json"),"家庭事务真实文件存读 "+kind)
  check(same(state.journal_entries(),row.expected.journal) and same(state.kitchen.lots,row.expected.lots),"文件保留日志和批次 "+kind)
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel()
  panel._select_option_id(panel.host_dish,"greens")
  panel._select_option_id(panel.shared_dish,"greens")
  panel._select_option_id(panel.guest_option,"granny")
  button.pressed.emit()
  state.economy.locked=["greens"]
  finish(state)
  await process_frame
  check(state.inventory.greens==int(row.before.bag.greens) and state.message==("需要备好一道料理。" if kind=="host" else "共餐需要一道料理。"),"完成重查锁定 "+kind)
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel()
  panel._select_option_id(panel.host_dish,"greens")
  panel._select_option_id(panel.shared_dish,"greens")
  panel._select_option_id(panel.guest_option,"granny")
  button.pressed.emit()
  var saved:Dictionary=state._make_save_data().duplicate(true)
  state.load_game_data(saved)
  finish(state)
  check(state.inventory.greens==int(row.before.bag.greens) and not state.action_busy(),"读档清除交接回调 "+kind)
  panel.open_panel()
  button.pressed.emit()
  state.current_interior="other"
  finish(state)
  check(not panel.visible and not state.action_busy(),"换房不恢复或结算 "+kind)
  state.current_interior=""
 print("HOUSEHOLD_ACTION_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
