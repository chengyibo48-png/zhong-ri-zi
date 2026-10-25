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
 var state=root.get_node("GameState")
 state.set_process(false)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.upgrades.storage=true
 state.inventory.rice=9
 state.storage.rice=2
 state.quality.rice=[2,2,2]
 state.storage_quality.rice=[0,1,0]
 state.kitchen.lots.bag.rice=[{"qty":8,"age":4.0},{"qty":1,"age":1.0}]
 state.kitchen.lots.storage.rice=[{"qty":2,"age":3.0}]
 state.economy.locked=["rice"]
 var panel=world.hud.market_panel
 panel.open_panel("inventory")
 panel.selected_id="rice"
 panel.quantity_box.value=2
 panel.grade_box.select(3)
 panel.refresh()
 check(panel.transfer_button.visible and not panel.transfer_button.disabled and panel.quantity_row.visible,"背包可选择数量与品质存取")
 panel.transfer_button.pressed.emit()
 check(state.action_busy() and not panel.visible and state.inventory.rice==9 and state.storage.rice==2,"存取先分拣不搬动")
 check(str(state.action_snapshot().kind)=="pack" and state.action_snapshot().item=="rice","原版 pack 携带物品")
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 check(panel.visible and panel.selected_id=="rice" and panel.quantity_box.value==2 and panel.grade_box.selected==3,"Esc 恢复物品数量与品质")
 check(state.inventory.rice==9 and state.storage.rice==2,"取消不搬动")
 panel.transfer_button.pressed.emit()
 panel.quantity_box.value=7
 panel.grade_box.select(1)
 finish(state)
 check(state.inventory.rice==7 and state.storage.rice==4,"捕获开始数量并完成搬动")
 check(state.storage_quality.rice==[0,3,0] and state.quality.rice==[2,0,2],"捕获上品选择独立于后改控件")
 check(state.economy.locked==["rice"],"锁定物品仍可搬动")
 check(panel.visible and panel.quantity_box.value==2 and panel.grade_box.selected==3,"完成恢复原表单")
 check(panel.transfer_button.disabled and root.gui_get_focus_owner()==panel.grade_box,"所选上品已搬空时禁止重复搬动并恢复品质焦点")
 check(is_equal_approx(float(state.food_freshness("rice",2,"storage").age),4.0),"搬动保留最老批次")
 panel._choose_inventory_side("storage")
 panel.selected_id="rice"
 panel.quantity_box.value=2
 panel.grade_box.select(3)
 panel.refresh()
 check(panel.action_button.disabled and panel.transfer_button.text=="取回随身" and panel.detail_label.text.contains("储物柜 4"),"储物侧显示库存并禁止直接食用")
 panel.transfer_button.pressed.emit()
 finish(state)
 check(state.inventory.rice==9 and state.storage.rice==2 and state.quality.rice==[2,2,2],"品质取回闭环")
 panel._choose_inventory_side("bag")
 panel.selected_id="rice"
 panel.category_box.select(2)
 panel.quantity_box.value=2
 panel.refresh()
 panel.tidy_button.pressed.emit()
 check(state.inventory.rice==9,"本类整理开始不搬动")
 finish(state)
 check(state.inventory.rice==5 and state.storage.rice==6 and panel.category_box.selected==2,"按所选食材分类留五份")
 panel._choose_inventory_side("storage")
 panel.selected_id="rice"
 panel.quantity_box.value=2
 panel.grade_box.select(0)
 panel.refresh()
 panel.transfer_button.pressed.emit()
 state.upgrades.storage=false
 finish(state)
 check(state.inventory.rice==5 and state.storage.rice==6 and state.message=="先添置储物柜，之后可存取。","完成时重新检查解锁")
 state.upgrades.storage=true
 panel.refresh()
 panel.transfer_button.pressed.emit()
 var saved:Dictionary=state._make_save_data()
 state.load_game_data(saved)
 finish(state)
 check(not state.action_busy() and state.inventory.rice==5 and state.storage.rice==6,"读档清除待搬回调")
 panel.open_panel("inventory")
 panel._choose_inventory_side("storage")
 panel.selected_id="rice"
 panel.refresh()
 panel.transfer_button.pressed.emit()
 state.current_interior="other"
 state._process_action(0.1)
 check(not state.action_busy() and not panel.visible and state.inventory.rice==5,"换房间清除旧搬动")
 world.queue_free()
 await process_frame
 print("Inventory storage UI migration: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)

func finish(state:Node):
 for step in range(30):
  if not state.action_busy():break
  state._process_action(0.1)
