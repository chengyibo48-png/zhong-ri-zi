extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<40:push_error(label)
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
 create_timer(180).timeout.connect(func():push_error("Tool transactions timeout");quit(1))
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOOL_TRANSACTIONS_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var seeds:Dictionary={}
 for row in fixture.rows:
  var label:String=str(row.op)+"/"+str(row.id)+"/"+str(row.variant)+"/"+str(row.field)+"/"+str(row.value)
  check(state.load_game_data(state.convert_external_save(row.before)),"导入 "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  if row.op=="upgrade" and row.variant=="0/ready" and bool(row.result.ok):seeds[str(row.id)]=row
  check(same(state.tool_quote(str(row.id)),row.quote if row.quote is Dictionary else {}),"完整报价及解锁 "+label)
  var updates:Dictionary={"count":0}
  var listener:=func():updates.count+=1
  state.changed.connect(listener)
  var ok:bool=state.upgrade_tool(str(row.id)) if row.op=="upgrade" else state.configure_tool(str(row.id),str(row.field),str(row.value))
  state.changed.disconnect(listener)
  check(int(updates.count)==1,"事务单次通知无通用疲劳提示 "+label)
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版结果提示 "+label)
  check(same(state.toolkit,row.expected.toolkit),"完整六种工具等级专长范围 "+label)
  check(same(state.legacy_systems.toolUpgrades,row.expected.toolUpgrades),"斧镰关联及旧升级标记 "+label)
  check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"普通记录事件不增 "+label)
  check(same(state.kitchen.lots,row.expected.lots),"批次 "+label)
  check(state.money==int(row.expected.money) and state.minutes==int(row.expected.minutes) and state.stamina==int(row.expected.stamina),"体力时间工钱 "+label)
  for id in state.item_catalog:
   var qty:int=row.expected.bag.get(id,0)
   check(int(state.inventory.get(id,0))==qty,"材料 "+label)
   var q:Array=row.expected.quality.get(id,[0,0,0])
   check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"品质 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["player_stats","npc_stories","partners","marriage","relations","neighbors","storage","known_recipes","skills","building"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
 check(seeds.size()==6,"六件工具实际UI模板")
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world);await process_frame;await process_frame
 world.set_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.tool_panel
 for row in seeds.values():
  var native:Dictionary=state.convert_external_save(row.before)
  state.load_game_data(native.duplicate(true))
  var target:Dictionary=state.building_task_destination({"op":"tool","id":str(row.id)})
  state.player_position=Vector2(float(target.x),float(target.y))+Vector2(0,70)
  world.player.global_position=state.player_position
  panel.selected_id=str(row.id)
  panel.open_panel(false)
  var old_money:int=state.money
  var old_inventory:Dictionary=state.inventory.duplicate(true)
  panel.upgrade_button.pressed.emit()
  check(not panel.visible and state.building_task.get("id")==str(row.id) and state.money==old_money and same(state.inventory,old_inventory),"远程工具UI排队不结算 "+str(row.id))
  for frame in range(300):
   if state.action_busy():break
   await physics_frame
  check(state.action_busy() and state.building_task.get("id")==str(row.id),"实际行走到农具间启动工具动作")
  check(state.action_snapshot().kind=="build" and state.action_snapshot().item==str(row.id) and is_equal_approx(float(state.action_snapshot().duration),1.7),"工地原版build动作ID时长")
  var action_minutes:float=state.minutes
  finish(state)
  check(is_equal_approx(state.minutes,minf(1320.0,action_minutes+float(row.expected.minutes)-float(row.before.minutes))),"实际工地原版劳动分钟增量 "+str(row.id))
  await process_frame
  check(state.money==int(row.expected.money),"实际工地工钱 "+str(row.id))
  check(state.stamina==int(row.expected.stamina),"实际工地体力 "+str(row.id))
  check(same(state.toolkit,row.expected.toolkit),"实际工地工具字段 "+str(row.id))
  if not same(state.toolkit,row.expected.toolkit):print("TOOL_UI_DIFF ",str(row.id)," native=",JSON.stringify(state.toolkit)," source=",JSON.stringify(row.expected.toolkit))
  check(state.message==str(row.result.msg) and same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"实际工地原文记录")
  check(state.building_task.is_empty() and not state.action_busy(),"完成清除待办")
  check(state.save_game("user://tool-transactions.json",true) and state.load_game("user://tool-transactions.json") and same(state.toolkit,row.expected.toolkit),"真实文件保留工具")
  state.load_game_data(native.duplicate(true))
  state.player_position=Vector2(float(target.x),float(target.y))+Vector2(0,70)
  world.player.global_position=state.player_position
  panel.selected_id=str(row.id)
  panel.open_panel(false)
  panel.upgrade_button.pressed.emit()
  for frame in range(300):
   if state.action_busy():break
   await physics_frame
  await escape()
  await process_frame
  check(not state.action_busy() and state.building_task.is_empty() and not panel.visible and state.money==old_money and same(state.inventory,old_inventory),"工地Esc取消不结算")
  state.stop_walking()
 var seed:Dictionary=state.convert_external_save(seeds.hoe.before)
 seed.toolkit.tools.hoe.level=2
 seed.toolkit.tools.hoe.shape="cross"
 state.load_game_data(seed.duplicate(true))
 panel.selected_id="hoe"
 panel.open_panel(false)
 check(state.save_game(state.SAVE_PATH,true),"记录工具动作前存档")
 var before_config_file:=FileAccess.get_file_as_string(state.SAVE_PATH)
 panel.branch_button.pressed.emit()
 check(state.action_busy() and state.tool_data("hoe").branch=="broad" and state.tool_data("hoe").shape=="cross" and FileAccess.get_file_as_string(state.SAVE_PATH)==before_config_file,"动作前工具与文件不修改")
 finish(state)
 check(not state.action_busy() and state.tool_data("hoe").branch=="care" and state.tool_data("hoe").shape=="row","设置专长动作完成并降十字范围")
 var file:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(file is Dictionary and file.toolkit.tools.hoe.branch=="care" and file.toolkit.tools.hoe.shape=="row","专长结算后静默保存")
 panel.shape_button.pressed.emit()
 check(state.action_busy() and state.tool_data("hoe").shape=="row","范围设置动作前不结算")
 finish(state)
 file=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(state.tool_data("hoe").shape=="single" and file.toolkit.tools.hoe.shape=="single","范围结算后切换并保存")
 check(state.message=="已记住这件工具的用法，随时可以调整。","设置保存保留原文")
 panel.close()
 print("TOOL_TRANSACTIONS_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
