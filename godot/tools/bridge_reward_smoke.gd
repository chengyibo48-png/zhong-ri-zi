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
 create_timer(120).timeout.connect(func():push_error("Bridge reward smoke timed out");quit(1))
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BRIDGE_REWARD_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var seed:Dictionary
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入修桥状态")
  check(same(state.archives,row.loadedArchives),"原版读档不推断合照")
  var before:Dictionary=state._make_save_data().duplicate(true)
  if row.op=="repair" and row.variant=="ready":seed=before.duplicate(true)
  var ok:bool=state.repair_community_bridge() if row.op=="repair" else state.complete_community_project("bridge")
  var label:String=str(row.op)+"/"+str(row.variant)
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"修桥结果提示 "+label)
  for id in state.item_catalog:
   var qty:int=row.expected.bag.get(id,0)
   check(int(state.inventory.get(id,0))==qty,"材料 "+label+" "+id)
   var q:Array=row.expected.quality.get(id,[0,0,0])
   while q.size()<3:q.append(0)
   check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"品质 "+label+" "+id)
  check(same(state.archives,row.expected.archives),"合照时机与不重复 "+label)
  check(same(state.relations,row.expected.relations) and same(state.skills,row.expected.skills),"关系和手艺 "+label)
  check(same(state.known_recipes,row.expected.recipes),"修桥配方 "+label)
  check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"原版记录顺序 "+label)
  check(same(state.legacy_systems.discovered,row.expected.discovered),"发现次序 "+label)
  for id in row.expected.flags:check(state.flags.get(id)==row.expected.flags[id],"标记 "+label+" "+id)
  check(bool(state.community_projects.bridge)==bool(row.expected.projects.bridge),"项目完成 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["money","minutes","stamina","player_stats","npc_stories","partners","marriage","neighbors"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
 state.load_game_data(state.convert_external_save(fixture.snapshot))
 state._museum_sync()
 check(same(state.archives,fixture.loadedArchives) and not state.archives.has("photo"),"已修桥快照同步不补发合照")
 check(not state.collection.entries.has("archive:photo"),"未持有合照的图鉴不推断获得")
 check(state.save_game("user://bridge-no-photo.json",true) and state.load_game("user://bridge-no-photo.json") and not state.archives.has("photo"),"实际保存读回不补合照")
 check(not state.collection.entries.has("archive:photo"),"文件读回保留未获得合照图鉴")
 state.load_game_data(seed.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world);await process_frame;await process_frame
 world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.community_panel
 panel.open_panel("orders")
 var button:Button=panel.transaction_buttons["repair:"]
 check(not button.disabled and button.text=="和乡亲们动工","心愿页提供原版修桥卡")
 var quantity:int=state.inventory.wood
 button.pressed.emit()
 check(state.action_busy() and not panel.visible and not state.archives.has("photo") and state.inventory.wood==quantity,"修桥动作开始不结算")
 check(state.action_snapshot().kind=="build" and is_equal_approx(float(state.action_snapshot().duration),1.7) and not state.action_snapshot().has("item"),"原版无ID修桥动作")
 await escape();await process_frame
 check(panel.visible and panel.active_tab=="orders" and not state.archives.has("photo") and state.inventory.wood==quantity,"Esc恢复心愿页不发合照")
 check(root.gui_get_focus_owner()==panel.transaction_buttons["repair:"],"取消恢复修桥焦点")
 panel.transaction_buttons["repair:"].pressed.emit()
 finish(state);await process_frame
 check(state.flags.bridge and state.archives.count("photo")==1 and panel.visible,"修桥完成发一张合照")
 check(panel.transaction_buttons["repair:"].text=="去河边看看" and not panel.transaction_buttons["repair:"].disabled,"完成后切换原版河边入口")
 var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(saved is Dictionary and saved.archives.count("photo")==1,"成功立即保存合照")
 check(bool(state.collection.entries.get("archive:photo",{}).get("acquired",false)),"实际获得合照登记图鉴")
 panel.transaction_buttons["repair:"].pressed.emit()
 var destination:Dictionary=state.world_village.regionDestinations.river
 check(not panel.visible and not state.walking_target.is_empty() and is_equal_approx(float(state.walking_target.get("x",0)),float(destination.x)) and is_equal_approx(float(state.walking_target.get("y",0)),float(destination.y)),"完成入口沿路去河边")
 state.stop_walking()
 for reason in ["locked","load","room"]:
  state.load_game_data(seed.duplicate(true))
  panel.open_panel("orders");panel.transaction_buttons["repair:"].pressed.emit()
  if reason=="locked":state.economy.locked.append("wood")
  elif reason=="load":state.load_game_data(state._make_save_data().duplicate(true))
  else:state.current_interior="other"
  finish(state);await process_frame
  check(not state.flags.get("bridge",false) and not state.archives.has("photo") and not state.action_busy(),"完成重查及旧回调取消 "+reason)
  if reason=="locked":check(panel.visible and state.message=="需要的物品已锁定，请先在背包解除保护。","锁定完成提示")
  else:check(not panel.visible,"不恢复新状态旧卡 "+reason)
  state.current_interior="";panel.close()
 state.load_game_data(seed.duplicate(true));state.economy.locked.append("wood")
 panel.open_panel("orders")
 check(panel.transaction_buttons["repair:"].disabled,"原版心愿卡保护锁定材料")
 panel.close()
 state.economy.locked.clear();state.feedback.prefs.pace="brisk"
 panel.open_panel("orders");panel.transaction_buttons["repair:"].pressed.emit()
 check(is_equal_approx(float(state.action_snapshot().duration),1.105),"快速修桥动作")
 state.cancel_action();await process_frame;panel.close()
 print("BRIDGE_REWARD_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free();await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
