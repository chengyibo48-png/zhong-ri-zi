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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("INVENTORY_BROWSE_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(fixture.states[int(row.state)])),"源浏览输入")
  var ids:Array=state.inventory_item_ids(str(row.side),str(row.category),str(row.search),str(row.sort))
  check(same(ids,row.ids),"原版筛选排序 %s/%s/%s/%s/%s"%[row.state,row.side,row.category,row.sort,row.search])
 for id in fixture.metadata:
  var actual:Dictionary=state.inventory_metadata[id].duplicate(true)
  actual.erase("rank")
  check(same(actual,fixture.metadata[id]),"原版来源用途偏好 "+id)
 state.load_game_data(state.convert_external_save(fixture.states[0]))
 var expected_counts:Array=state.inventory_item_ids("bag","全部","","count")
 var save_path:="user://browse-order.json"
 check(state.save_game(save_path,true),"保存排序状态")
 check(state.load_game(save_path),"读取排序状态")
 check(same(state.inventory_item_ids("bag","全部","","count"),expected_counts),"文件存读保留同数量插入顺序")
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.market_panel
 panel.open_panel("inventory")
 var all:Array=state.inventory_item_ids()
 check(panel.item_ids.size()==18 and same(panel.item_ids,all.slice(0,18)),"实际第一页十八项中文排序")
 panel.next_page.pressed.emit()
 check(panel.inventory_page==1 and same(panel.item_ids,all.slice(18,36)),"下一页显示对应十八项")
 panel.previous_page.pressed.emit()
 check(panel.inventory_page==0 and same(panel.item_ids,all.slice(0,18)),"上一页")
 panel.sort_box.select(1)
 panel.sort_box.item_selected.emit(1)
 check(same(panel.item_ids,state.inventory_item_ids("bag","全部","","count").slice(0,18)),"数量排序实际控件")
 panel.search_box.text="材料"
 panel.search_box.text_changed.emit("材料")
 check(same(panel.item_ids,state.inventory_item_ids("bag","全部","材料","count").slice(0,18)),"按类别文字搜索")
 panel.search_box.text=""
 panel.search_box.text_changed.emit("")
 panel.selected_id="wood"
 panel.refresh()
 var meta:Dictionary=fixture.metadata.wood
 check(panel.detail_label.text.contains(str(meta.sources)) and panel.detail_label.text.contains("、".join(meta.uses)),"实际来源用途详情")
 panel._choose_inventory_side("storage")
 check(same(panel.item_ids,state.inventory_item_ids("storage","全部","","count").slice(0,18)),"储物柜数量排序")
 panel.inventory_page=100
 panel.refresh()
 check(panel.inventory_page==10 and panel.next_page.disabled,"末页自动夹取并禁用继续")
 panel.search_box.text="missing"
 panel.search_box.text_changed.emit("missing")
 check(panel.item_ids.is_empty() and panel.previous_page.disabled and panel.next_page.disabled and panel.inventory_page==0,"空结果页规则")
 world.queue_free()
 await process_frame
 print("Inventory browse migration: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
