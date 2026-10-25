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
 create_timer(150).timeout.connect(func():push_error("Legacy upgrade timeout");quit(1))
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LEGACY_UPGRADE_ACTION_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var seed:Dictionary
 for row in fixture.rows:
  var label:String=str(row.id)+"/"+str(row.variant)
  if bool(row.get("invalidLoad",false)):
   var rejected_before:Dictionary=state._make_save_data().duplicate(true)
   var rejected_path:String=load("res://tools/smoke_files.gd").create_path("upgrade_rejected")
   check(not state._import_external_save_to_paths(row.before,rejected_path,rejected_path+".recovery",rejected_path+".bak"),"source-invalid-load "+label)
   check(state.message==str(row.sourceError),"source-invalid-message "+label)
   check(not FileAccess.file_exists(rejected_path) and not FileAccess.file_exists(rejected_path+".recovery") and not FileAccess.file_exists(rejected_path+".bak"),"rejected-import-writes-no-files "+label)
   check(same(rejected_before,state._make_save_data()),"rejected-load-preserves-state "+label)
   continue
  check(state.load_game_data(state.convert_external_save(row.before)),"导入 "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  if row.id=="room" and row.variant=="ready":seed=before.duplicate(true)
  var ok:bool=state.perform_legacy_upgrade(str(row.id))
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版成功与提示 "+label)
  check(state.money==int(row.expected.money),"工钱 "+label)
  for id in state.item_catalog:
   var qty:int=row.expected.bag.get(id,0)
   check(int(state.inventory.get(id,0))==qty,"材料 "+label)
   var q:Array=row.expected.quality.get(id,[0,0,0])
   check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"四档品质 "+label)
  check(same(state.upgrades,row.expected.upgrades),"全部修缮状态 "+label)
  check(same(state.skills,row.expected.skills),"手艺经验 "+label)
  check(same(state.furniture,row.expected.furniture),"庭院赠品 "+label)
  check(same(state.building,row.expected.building),"老屋级别工程修订 "+label)
  check(same(state.ranch.barns,row.expected.barns),"棚舍床位自动食槽 "+label)
  check(same(state.farm.facilities,row.expected.facilities) and state.farm.water==int(row.expected.water) and int(state.legacy_systems.waterReserve)==int(row.expected.waterReserve),"喷灌与蓄水 "+label)
  check(same(state.kitchen.lots,row.expected.lots),"厨房批次 "+label)
  check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"只写普通日志且保留顺序 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["minutes","stamina","player_stats","npc_stories","partners","marriage","relations","neighbors","storage","known_recipes"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
 check(not seed.is_empty(),"厢房合法模板")
 state.load_game_data(seed.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world);await process_frame;await process_frame
 world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.neighbor_journal
 panel.story_open_id="qiao"
 panel.open_panel("qiao")
 var before:Dictionary=state._make_save_data().duplicate(true)
 check(panel.home_room_button.visible and not panel.home_room_button.disabled,"成年候选人厢房入口")
 panel.home_room_button.pressed.emit()
 check(state.action_busy() and not panel.visible and same(state.inventory,before.inventory) and state.money==int(before.money) and not bool(state.upgrades.get("room",false)),"开始尚未修缮")
 check(state.action_snapshot().kind=="build" and state.action_snapshot().item=="room" and is_equal_approx(float(state.action_snapshot().duration),1.7),"原版修缮动作ID时长")
 await escape()
 await process_frame
 check(panel.visible and panel._selected_npc_id()=="qiao" and panel.story_open_id=="qiao" and root.gui_get_focus_owner()==panel.home_room_button,"Esc恢复人物故事焦点")
 check(same(state.inventory,before.inventory) and state.money==int(before.money) and not bool(state.upgrades.get("room",false)),"取消不扣费材料")
 panel.home_room_button.pressed.emit()
 panel.refresh("lin")
 finish(state)
 await process_frame
 check(bool(state.upgrades.room) and state.money==int(before.money)-220 and int(state.inventory.wood)==int(before.inventory.wood)-10 and int(state.inventory.bamboo)==int(before.inventory.bamboo)-4,"完成原版厢房成本")
 check(panel.visible and panel._selected_npc_id()=="qiao" and panel.story_open_id=="qiao" and not panel.home_room_button.visible and root.gui_get_focus_owner()==panel.close_button,"完成恢复原人物故事与可用焦点")
 check(state.message=="整理厢房完成了！院子有了新的变化。","静默保存保留原文")
 var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(saved is Dictionary and saved.upgrades.room==true and int(saved.building.house)==2,"成功立即保存厢房与老屋")
 check(state.save_game("user://room-upgrade.json",true) and state.load_game("user://room-upgrade.json") and bool(state.upgrades.room),"文件存读保留修缮")
 panel.close()
 for reason in ["load","room","day","money","wood","bamboo","locked","busy","done"]:
  state.load_game_data(seed.duplicate(true))
  panel.open_panel("qiao")
  panel.home_room_button.pressed.emit()
  if reason=="load":
   var snapshot:Dictionary=state._make_save_data().duplicate(true)
   state.load_game_data(snapshot)
  elif reason=="room":state.current_interior="other"
  elif reason=="day":state.day+=1
  elif reason=="money":state.money=219
  elif reason=="wood":state.inventory.wood=9
  elif reason=="bamboo":state.inventory.bamboo=3
  elif reason=="locked":state.economy.locked.assign(["wood"])
  elif reason=="busy":state.building.jobs=[{"id":"house","level":1,"readyDay":state.day+1}]
  else:state.upgrades.room=true
  var snapshot:Dictionary=state._make_save_data().duplicate(true)
  finish(state)
  await process_frame
  check(same(state.inventory,snapshot.inventory) and state.money==int(snapshot.money) and same(state.building,snapshot.building) and same(state.skills,snapshot.skills),"取消或完成重查无费用 "+reason)
  check(not state.action_busy() and panel.visible==(reason not in ["load","room","day"]),"重查恢复取消不重开 "+reason)
  panel.close()
 state.load_game_data(seed.duplicate(true))
 state.feedback.prefs.pace="brisk"
 panel.open_panel("qiao")
 panel.home_room_button.pressed.emit()
 check(is_equal_approx(float(state.action_snapshot().duration),1.105),"快速修缮")
 state.cancel_action()
 await process_frame
 panel.close()
 for npc_id in ["qiao","lin","granny","lan"]:
  state.load_game_data(seed.duplicate(true))
  panel.open_panel(npc_id)
  check(panel.home_room_button.visible==(npc_id in ["qiao","lin"]),"厢房入口成年条件 "+npc_id)
  panel.close()
 state.load_game_data(seed.duplicate(true))
 state.economy.locked.assign(["wood"])
 panel.open_panel("qiao")
 check(panel.home_room_button.disabled,"材料保护时禁用入口")
 panel.close()
 var building_panel=world.hud.building_panel
 for row in fixture.rows:
  if row.variant!="ready" or not bool(row.result.ok):continue
  state.load_game_data(state.convert_external_save(row.before))
  building_panel.open_panel({},false)
  building_panel._set_tab("legacy")
  var button:Button=building_panel.legacy_buttons[str(row.id)]
  var old_money:int=state.money
  var old_inventory:Dictionary=state.inventory.duplicate(true)
  button.pressed.emit()
  check(state.action_busy() and not building_panel.visible and state.building_task.is_empty() and state.walking_target.is_empty(),"基础修缮原版UI直接动作 "+str(row.id))
  check(state.money==old_money and same(state.inventory,old_inventory),"基础修缮动作开始不结算")
  check(state.action_snapshot().kind=="build" and state.action_snapshot().item==str(row.id) and is_equal_approx(float(state.action_snapshot().duration),1.7),"基础修缮原版动作ID时长")
  await escape()
  await process_frame
  check(building_panel.visible and building_panel.tab=="legacy" and root.gui_get_focus_owner()==button,"基础修缮Esc恢复分页焦点")
  button.pressed.emit()
  finish(state)
  await process_frame
  check(state.money==int(row.expected.money) and same(state.upgrades,row.expected.upgrades) and same(state.building,row.expected.building),"基础修缮UI原版结算")
  check(state.message==str(row.result.msg) and same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"基础修缮UI提示日志")
  check(building_panel.visible and building_panel.tab=="legacy" and button.disabled and button.text=="已经修好" and root.gui_get_focus_owner()==building_panel.close_button,"完成原页与可用焦点")
  var file:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
  check(file is Dictionary and file.upgrades.get(str(row.id),false) and int(file.money)==int(row.expected.money),"基础修缮立即保存")
  building_panel.close()
 for reason in ["load","room","day","locked","poor"]:
  state.load_game_data(seed.duplicate(true))
  building_panel.open_panel({},false)
  building_panel._set_tab("legacy")
  building_panel.legacy_buttons.room.pressed.emit()
  if reason=="load":
   var snapshot:Dictionary=state._make_save_data().duplicate(true)
   state.load_game_data(snapshot)
  elif reason=="room":state.current_interior="other"
  elif reason=="day":state.day+=1
  elif reason=="locked":state.economy.locked.assign(["wood"])
  else:state.money=0
  var old_money:int=state.money
  var old_inventory:Dictionary=state.inventory.duplicate(true)
  finish(state)
  await process_frame
  check(not state.action_busy() and state.money==old_money and same(state.inventory,old_inventory) and not bool(state.upgrades.get("room",false)),"营造分页取消重查 "+reason)
  check(building_panel.visible==(reason in ["locked","poor"]),"营造分页恢复或不重开 "+reason)
  building_panel.close()
 state.load_game_data(seed.duplicate(true))
 state.feedback.prefs.pace="brisk"
 building_panel.open_panel({},false)
 building_panel._set_tab("legacy")
 building_panel.legacy_buttons.room.pressed.emit()
 check(is_equal_approx(float(state.action_snapshot().duration),1.105),"基础修缮分页快速节奏")
 state.cancel_action()
 await process_frame
 building_panel.close()
 print("LEGACY_UPGRADE_ACTION_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
