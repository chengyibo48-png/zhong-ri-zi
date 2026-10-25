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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("INVENTORY_MARK_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"源背包输入")
  var before_inventory:Dictionary=state.inventory.duplicate(true)
  var ok:bool=state.toggle_item_lock(str(row.id)) if row.op=="lock" else state.toggle_item_pin(str(row.id))
  var label:="%s/%s/%s"%[row.op,row.id,row.variant]
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版标记结果 "+label)
  check(same(state.economy,row.expected.economy),"原版标记顺序和上限 "+label)
  check(same(state.inventory,before_inventory),"标记不消耗物品 "+label)
  for id in state.item_catalog:check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"原版库存 "+label+"/"+id)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.inventory.rice=8
 state.economy.locked=[]
 state.economy.pinned=[]
 var panel=world.hud.market_panel
 panel.open_panel("inventory")
 panel.selected_id="rice"
 panel.search_box.text="米"
 panel.refresh()
 panel.lock_button.pressed.emit()
 check(state.action_busy() and not panel.visible and not state.ui_open,"锁定按钮先分拣")
 check(state.economy.locked.is_empty(),"锁定动画前不修改")
 check(str(state.action_snapshot().kind)=="pack" and state.action_snapshot().item=="rice" and is_equal_approx(float(state.action_snapshot().duration),1.2),"捕获物品与原版动作")
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 check(not state.action_busy() and panel.visible and panel.selected_id=="rice" and panel.search_box.text=="米","Esc 恢复物品与搜索")
 check(state.economy.locked.is_empty() and root.gui_get_focus_owner()==panel.lock_button,"取消不标记并恢复焦点")
 panel.lock_button.pressed.emit()
 finish(state)
 check(state.economy.locked==["rice"] and panel.visible and panel.selected_id=="rice","完成提交锁定并恢复")
 panel.pin_button.pressed.emit()
 check(state.economy.pinned.is_empty(),"加入常用篮动作前不提交")
 finish(state)
 check(state.economy.pinned==["rice"] and panel.pin_shortcuts[0].visible and panel.pin_shortcuts[0].text.contains("×8"),"常用篮按顺序显示数量")
 state.inventory.rice=0
 panel.refresh()
 check(panel.pin_shortcuts[0].text.contains("×0") and state.economy.pinned==["rice"],"耗尽保留位置")
 panel.selected_id="wood"
 panel.refresh()
 panel.pin_shortcuts[0].pressed.emit()
 check(panel.selected_id=="rice" and not panel.pin_button.disabled and panel.action_button.disabled,"耗尽常用篮仍可选中详情并移出")
 panel.pin_button.pressed.emit()
 finish(state)
 check(state.economy.pinned.is_empty() and panel.selected_id=="rice","耗尽物品可移出且保留详情")
 state.economy.pinned=["wood","bamboo","egg","milk","fish","cabbage"]
 state.inventory.rice=8
 panel.refresh()
 panel.pin_button.pressed.emit()
 finish(state)
 check(state.economy.pinned.size()==6 and state.message=="常用篮已放六样，先取消一项。" and panel.visible,"第七样完成时拒绝并恢复")
 panel.lock_button.pressed.emit()
 finish(state)
 check(not state.economy.locked.has("rice"),"完成解除锁定")
 panel.pin_button.pressed.emit()
 var saved:Dictionary=state._make_save_data()
 state.load_game_data(saved)
 finish(state)
 check(not state.economy.pinned.has("rice") and not state.action_busy(),"读档清除未提交标记")
 panel.open_panel("inventory")
 panel.selected_id="rice"
 panel.refresh()
 panel.lock_button.pressed.emit()
 state.current_interior="changed-room"
 state._process_action(0.1)
 check(not state.action_busy() and not panel.visible and not state.economy.locked.has("rice"),"换房间取消旧标记")
 state.current_interior=""
 state.economy.pinned=["milk","rice","wood"]
 state.inventory.rice=0
 saved=state._make_save_data()
 check(state.load_game_data(saved) and state.economy.pinned==["milk","rice","wood"],"存档保留篮子顺序及耗尽项")
 world.queue_free()
 await process_frame
 print("Inventory marks migration: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)

func finish(state:Node):
 for step in range(30):
  if not state.action_busy():break
  state._process_action(0.1)
