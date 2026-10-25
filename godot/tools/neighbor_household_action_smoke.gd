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
 var seeds:Dictionary={}
 for row in fixture.rows:
  if row.variant=="base" and row.dish=="greens" and bool(row.result.ok):
   seeds[str(row.kind)+"/"+str(row.id)]=row
 check(seeds.size()==28,"24家宴与四类共同安排模板")
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.neighbor_journal
 for row in seeds.values():
  var native:Dictionary=state.convert_external_save(row.before)
  state.load_game_data(native.duplicate(true))
  var npc_id:String=str(row.id) if row.kind=="host" else str(state.marriage.spouse)
  panel.story_open_id=npc_id
  panel.open_panel(npc_id)
  panel._select_neighbor_dish(panel.host_meal_option,"greens")
  panel._select_neighbor_dish(panel.shared_meal_option,"greens")
  var button:Button=panel.host_meal_button if row.kind=="host" else panel.shared_buttons[str(row.id)]
  var before:Dictionary=state._make_save_data().duplicate(true)
  check(button.is_visible_in_tree() and not button.disabled,"实际入口可用 "+str(row.id))
  button.pressed.emit()
  check(state.action_busy() and not panel.visible and same(state.marriage,before.marriage) and same(state.relations,before.relations) and same(state.inventory,before.inventory),"开始不结算")
  var action:Dictionary=state.action_snapshot()
  check(action.kind=="trade" and is_equal_approx(float(action.duration),1.6),"原版交接动作时长")
  check(str(action.get("item",""))==(str(row.id) if row.kind=="shared" else ""),"共餐携带活动家宴无ID")
  await escape()
  await process_frame
  check(panel.visible and panel._selected_npc_id()==npc_id and panel.story_open_id==npc_id and root.gui_get_focus_owner()==button,"Esc恢复原人物故事与焦点")
  check(same(state.marriage,before.marriage) and same(state.relations,before.relations) and same(state.inventory,before.inventory),"取消不结算")
  button.pressed.emit()
  panel.refresh("lin" if npc_id!="lin" else "qiao")
  panel._select_neighbor_dish(panel.host_meal_option,"eggRice")
  panel._select_neighbor_dish(panel.shared_meal_option,"eggRice")
  finish(state)
  await process_frame
  check(panel.visible and panel._selected_npc_id()==npc_id and panel.story_open_id==npc_id,"完成恢复捕获人物与故事")
  check(state.message==str(row.result.msg),"原版完成提示")
  var expected:Dictionary=row.expected.marriage.duplicate(true)
  if expected.spouse==null:expected.spouse=""
  check(same(state.marriage,expected),"周安排与记忆")
  check(same(state.relations,row.expected.relations),"原版关系")
  check(same(state.skills,row.expected.skills) and same(state.known_recipes,row.expected.recipes),"经验与学菜")
  check(same(state.season_events,row.expected.seasonEvents),"家宴周标记")
  check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"原版日志")
  check(same(state.kitchen.lots,row.expected.lots),"捕获料理批次")
  check(same(state.neighbors.people,before.neighbors.people),"不附加NPC记忆")
  check(state.money==int(row.expected.money) and state.minutes==int(row.expected.minutes),"不额外费用时间")
  for id in state.item_catalog:
   check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"完整库存")
   var q:Array=row.expected.quality.get(id,[0,0,0])
   check(same(state._quality_counts(id),[maxi(0,int(row.expected.bag.get(id,0))-int(q[0])-int(q[1])-int(q[2])),int(q[0]),int(q[1]),int(q[2])]),"完整品质")
  check(root.gui_get_focus_owner()==panel.close_button and button.disabled,"本周完成后转可用焦点")
  check(panel._neighbor_dish_id(panel.host_meal_option)=="greens" and panel._neighbor_dish_id(panel.shared_meal_option)=="greens","恢复捕获料理选择")
  check(state.save_game("user://neighbor-household.json",true) and state.load_game("user://neighbor-household.json"),"实际文件存读")
  check(same(state.marriage,expected) and same(state.season_events,row.expected.seasonEvents),"文件保留周安排")
  panel.close()
 # UI lifecycle checks use the same base templates, one per kind/activity.
 var cases:Array=[seeds["host/qiao"],seeds["shared/meal"],seeds["shared/visit"],seeds["shared/objects"],seeds["shared/plan"]]
 for row in cases:
  var native:Dictionary=state.convert_external_save(row.before)
  var npc_id:String=str(row.id) if row.kind=="host" else str(row.before.marriage.spouse)
  for reason in ["load","room","day","locked","repeat","no-room"]:
   if reason=="no-room" and row.kind!="host":continue
   state.load_game_data(native.duplicate(true))
   panel.open_panel(npc_id)
   panel._select_neighbor_dish(panel.host_meal_option,"greens")
   panel._select_neighbor_dish(panel.shared_meal_option,"greens")
   var button:Button=panel.host_meal_button if row.kind=="host" else panel.shared_buttons[str(row.id)]
   button.pressed.emit()
   var before:Dictionary=state._make_save_data().duplicate(true)
   if reason=="load":state.load_game_data(before.duplicate(true))
   elif reason=="room":state.current_interior="other"
   elif reason=="day":state.day+=1
   elif reason=="locked":
    if row.kind=="host" or row.id=="meal":state.economy.locked.assign(["greens"])
    else:state.marriage.spouse=""
   elif reason=="repeat":
    if row.kind=="host":state.season_events["meal-%d-%s"%[int(state.day/7),npc_id]]=true
    else:state.marriage.weekly["%d-%s"%[int(state.day/7),str(row.id)]]=true
   elif reason=="no-room":state.upgrades.room=false
   finish(state)
   await process_frame
   check(not state.action_busy() and same(state.inventory,before.inventory) and same(state.relations,before.relations) and same(state.marriage.memories,before.marriage.memories),"取消或条件重查不结算 "+reason+"/"+str(row.id))
   check(panel.visible==(reason not in ["load","room","day"]),"失败恢复取消不重开 "+reason)
   panel.close()
  state.load_game_data(native.duplicate(true))
  state.feedback.prefs.pace="brisk"
  panel.open_panel(npc_id)
  panel._select_neighbor_dish(panel.host_meal_option,"greens")
  panel._select_neighbor_dish(panel.shared_meal_option,"greens")
  var button:Button=panel.host_meal_button if row.kind=="host" else panel.shared_buttons[str(row.id)]
  button.pressed.emit()
  check(is_equal_approx(float(state.action_snapshot().duration),1.04),"快速节奏")
  state.cancel_action()
  await process_frame
  panel.close()
 print("NEIGHBOR_HOUSEHOLD_ACTION_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
