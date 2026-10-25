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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GIFT_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  state.load_game_data(state.convert_external_save(row.before))
  state.npc_positions={str(row.npc):Vector2(2831+(81 if str(row.variant)=="far" else 0),1652)}
  var ok:bool=state.gift_npc(str(row.npc),str(row.id))
  var label:=str(row.npc)+"/"+str(row.id)+"/"+str(row.variant)
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版送礼结果 "+label)
  check(same(state.relations,row.expected.relations),"原版送礼关系 "+label)
  check(same(state.last_gifts,row.expected.lastGifts),"原版礼物偏好记录 "+label)
  check(same(state.skills,row.expected.skills),"原版送礼经验 "+label)
  check(same(state.kitchen.lots,row.expected.lots),"原版礼物新鲜度 "+label)
  check(same(state.neighbors.people[str(row.npc)],row.expected.people),"原版居民送礼记录 "+label)
  check(same(state.neighbors.history,row.expected.history),"原版送礼历史 "+label)
  check(int(state.player_stats.gifts)==int(row.expected.gifts),"原版送礼计数 "+label)
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
 state.npc_positions={str(row.npc):world.player.global_position}
 var panel=world.hud.neighbor_journal
 panel.open_panel(str(row.npc))
 for i in range(panel.gift_item_option.item_count):
  if str(panel.gift_item_option.get_item_metadata(i))==str(row.id):panel.gift_item_option.select(i);break
 var food_before:int=state.inventory.get(row.id,0)
 panel.gift_button.pressed.emit()
 check(state.action_busy() and not panel.visible and not state.ui_open,"真实送礼按钮播放交接动作")
 check(state.inventory.get(row.id,0)==food_before,"送礼动画前不消耗")
 state.cancel_action()
 check(panel.visible and state.ui_open and state.inventory.get(row.id,0)==food_before,"取消恢复人物面板不扣礼物")
 check(str(panel.gift_item_option.get_item_metadata(panel.gift_item_option.selected))==str(row.id),"取消保留所选物品")
 panel.gift_button.pressed.emit()
 for i in range(17):state._process_action(0.1)
 check(not state.action_busy() and panel.visible and state.ui_open,"送礼完成恢复人物面板")
 check(state.inventory.get(row.id,0)==food_before-1,"送礼完成才扣物品")
 panel.close()
 state.load_game_data(state.convert_external_save(row.before))
 state.npc_positions={str(row.npc):state.player_position}
 panel.open_panel(str(row.npc))
 for i in range(panel.gift_item_option.item_count):
  if str(panel.gift_item_option.get_item_metadata(i))==str(row.id):panel.gift_item_option.select(i);break
 panel.gift_button.pressed.emit()
 state.npc_positions[str(row.npc)]=state.player_position+Vector2(81,0)
 for i in range(17):state._process_action(0.1)
 check(state.inventory.get(row.id,0)==int(row.before.bag[row.id]) and state.message=="先走近对方，再把心意交到手中。","交接结束时居民离开则不扣礼物")
 panel.close()
 state.load_game_data(state.convert_external_save(row.before))
 state.npc_positions={str(row.npc):state.player_position}
 panel.open_panel(str(row.npc))
 for i in range(panel.gift_item_option.item_count):
  if str(panel.gift_item_option.get_item_metadata(i))==str(row.id):panel.gift_item_option.select(i);break
 panel.gift_button.pressed.emit()
 state.inventory[str(row.id)]=0
 for i in range(17):state._process_action(0.1)
 check(state.message=="背包里没有这份礼物。" and int(state.relations[str(row.npc)].gifted)!=state.day,"交接时重新检查礼物库存")
 panel.close()
 world.queue_free()
 await process_frame
 print("Gift migration: %d passed, %d failed; source rows %d"%[passed,failed,fixture.rows.size()])
 quit(0 if failed==0 else 1)
