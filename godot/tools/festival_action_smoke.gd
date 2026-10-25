extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<10:push_error(label)
func same(a:Variant,b:Variant)->bool:
 if b==null:return a==null or a is Dictionary and a.is_empty()
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
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FESTIVAL_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"源节庆输入")
  var label:="%s/%s/%s/%s"%[row.year,row.season,row.choice,row.variant]
  var ok:bool=state.attend_festival(str(row.dish),int(row.choice),int(row.season))
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版节庆结果 "+label)
  check(same(state.relations,row.expected.relations),"原版节庆全村关系 "+label)
  check(same(state.festivals,row.expected.festivals) and same(state.season_events,row.expected.seasonEvents),"原版参与记录 "+label)
  check(same(state.known_recipes,row.expected.knownRecipes),"原版全部节令菜谱 "+label)
  check(same(state.skills,row.expected.skills),"原版节庆经验 "+label)
  check(same(state.kitchen.lots,row.expected.lots),"原版料理与米粮批次 "+label)
  check(same(state.legacy_systems.eventLog,row.expected.eventLog),"原版节庆与学习日志 "+label)
  for id in row.expected.bag:check(int(state.inventory.get(id,0))==int(row.expected.bag[id]),"库存 "+label)
 var row:Dictionary=fixture.rows[0]
 state.load_game_data(state.convert_external_save(row.before))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.festival_panel
 panel.open_panel()
 panel.dish_option.select(panel.dish_ids.find(str(row.dish)))
 var quantity:int=state.inventory.get(row.dish,0)
 panel.choice_buttons[0].pressed.emit()
 check(state.action_busy() and not panel.visible and not state.ui_open,"真实节庆按钮先进行交接动作")
 check(str(state.action_snapshot().kind)=="trade" and state.action_snapshot().item==row.dish,"捕获原版动作与所选料理")
 check(state.inventory.get(row.dish,0)==quantity and state.festivals.is_empty(),"开始未消耗料理或登记参与")
 state.cancel_action()
 check(panel.visible and state.ui_open and state.inventory.get(row.dish,0)==quantity,"取消恢复节庆页不消耗")
 check(panel.dish_ids[panel.dish_option.selected]==row.dish and panel.season_option.selected==0,"取消保留季节与料理")
 panel.choice_buttons[0].pressed.emit()
 for i in range(17):state._process_action(0.1)
 check(not state.action_busy() and panel.visible and state.ui_open,"交接完成恢复节庆页")
 check(state.message==str(row.result.msg) and state.inventory.get(row.dish,0)==quantity-1,"实际按钮结算对照原版")
 panel.close()
 world.queue_free()
 await process_frame
 print("Festival migration: %d passed, %d failed; source rows %d"%[passed,failed,fixture.rows.size()])
 quit(0 if failed==0 else 1)
