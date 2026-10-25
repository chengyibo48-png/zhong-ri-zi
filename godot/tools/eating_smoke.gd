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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("EATING_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  state.load_game_data(state.convert_external_save(row.before))
  state.eat_item(str(row.id))
  var label:=str(row.id)+"/"+str(row.variant)
  check(state.message==str(row.result.msg),"原版食用文案 "+label+" actual="+state.message)
  check(state.stamina==int(row.expected.stamina),"原版食用回复 "+label)
  check(same(state.kitchen.lots,row.expected.lots),"原版食用批次 "+label)
  check(same(state.kitchen.buff,row.expected.buff),"原版食用增益 "+label)
  check(int(state.legacy_systems.buffs.laborDay)==int(row.expected.laborDay),"原版增益替换 "+label)
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
 var panel=world.hud.market_panel
 panel.open_panel("inventory")
 panel.selected_id=str(row.id)
 panel.refresh()
 var food_before:int=state.inventory.get(row.id,0)
 panel.action_button.pressed.emit()
 check(state.action_busy() and not panel.visible and not state.ui_open,"背包食用按钮先播放动作")
 check(state.inventory.get(row.id,0)==food_before,"动作前不消耗食物")
 state.cancel_action()
 check(panel.visible and state.ui_open and state.inventory.get(row.id,0)==food_before,"取消恢复原背包不消耗")
 panel.action_button.pressed.emit()
 for i in range(15):state._process_action(0.1)
 check(not state.action_busy() and panel.visible and state.ui_open,"完成恢复背包")
 check(state.inventory.get(row.id,0)==food_before-1 and state.stamina==int(row.expected.stamina),"真实背包完成才消耗与回复")
 panel.close()
 var pantry=world.hud.kitchen_panel
 pantry.open_panel(true,"pantry")
 pantry.selected_id="bag:"+str(row.id)
 pantry.refresh()
 var pantry_before:int=state.inventory.get(row.id,0)
 pantry.clean_button.pressed.emit()
 check(state.action_busy() and not pantry.visible,"食橱按钮接入实际吃东西动作")
 state.cancel_action()
 check(pantry.visible and state.ui_open and int(state.inventory.get(row.id,0))==pantry_before,"食橱取消恢复所选条目且不消耗")
 pantry.clean_button.pressed.emit()
 for i in range(15):state._process_action(0.1)
 check(not state.action_busy() and pantry.visible and int(state.inventory.get(row.id,0))==pantry_before-1,"食橱完成后消耗一份并恢复")
 pantry.close()
 # Change protection during the real animation; arrival must recheck it.
 state.stamina=20
 state.economy.locked=[]
 panel.open_panel("inventory")
 panel.selected_id=str(row.id)
 panel.refresh()
 var protected_before:Dictionary=state._make_save_data().duplicate(true)
 panel.action_button.pressed.emit()
 check(state.action_busy(),"锁定变化验证先开始实际动画")
 state.economy.locked=[str(row.id)]
 for i in range(15):state._process_action(0.1)
 check(not state.action_busy() and panel.visible and state.ui_open,"原料锁定后动画完成恢复背包")
 check(state.message=="需要的物品已锁定，请先在背包解除保护。","动画结算重查保护锁")
 check(same(state.inventory,protected_before.inventory) and same(state.kitchen,protected_before.kitchen) and state.stamina==20,"锁定结算保留全部食物品质批次与体力")
 panel.close()
 # Persist the consumed batches, buff deadline and protection together.
 var snapshot:Dictionary=state._make_save_data().duplicate(true)
 var path: String=load("res://tools/smoke_files.gd").create_path("eating_roundtrip")
 check(state.save_game(path,true),"食用状态写入原生文件")
 var restored=load("res://scripts/game_state.gd").new()
 restored._load_content()
 check(restored.load_game(path),"食用状态读回原生文件")
 check(same(restored.kitchen,snapshot.kitchen),"读档保留食用批次与分数增益截止")
 check(same(restored.economy,snapshot.economy) and same(restored.quality,snapshot.quality),"读档保留食材保护锁与品质")
 check(restored.stamina==int(snapshot.stamina) and absf(restored.minutes-float(snapshot.minutes))<0.00000001,"读档保留体力与分数分钟")
 load("res://tools/smoke_files.gd").remove(path)
 restored.free()
 world.queue_free()
 await process_frame
 print("Eating migration: %d passed, %d failed; source rows %d"%[passed,failed,fixture.rows.size()])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
