extends SceneTree
var passed:=0
var failed:=0
var errors:Dictionary={}
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  var key:=label.get_slice(" ",0)
  errors[key]=int(errors.get(key,0))+1
  if failed<18:push_error(label)
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
func compare(state,e:Dictionary,label:String):
 var fields:Dictionary={"day":"day","minutes":"minutes","stamina":"stamina","money":"money","kitchen":"kitchen","skills":"skills","stats":"player_stats","ranch":"ranch","animals":"animals","pet":"pet_state","processing":"legacy_processing","toolkit":"toolkit","storage":"storage","storageQuality":"storage_quality","upgrades":"upgrades","knownRecipes":"known_recipes"}
 for key in fields:check(same(state.get(fields[key]),e[key]),key+" "+label)
 check(same(state.journal_entries(),e.journal),"journal "+label)
 check(same(state.legacy_systems.eventLog,e.eventLog),"eventLog "+label)
 check(same(state.legacy_systems.discovered,e.discovered),"discovered "+label)
 state._sync_farm_beds_from_plots()
 for key in e.farm:
  if key=="beds":
   for i in range(e.farm.beds.size()):
    for field in e.farm.beds[i]:
     var expected:Variant=e.farm.beds[i][field]
     var actual:Variant=state.farm.beds[i].get(field)
     check((field=="companion" and expected==null and actual is Dictionary and actual.is_empty()) or same(actual,expected),"farm "+field+" "+label)
  else:check(same(state.farm.get(key),e.farm[key]),"farm "+key+" "+label)
 for i in range(e.plots.size()):
  for key in e.plots[i]:
   var expected:Variant=e.plots[i][key]
   var actual:Variant=state.plots[i].get(key)
   check((key=="crop" and expected==null and actual=="") or same(actual,expected),"plots "+str(key)+" "+label)
 check(state.legacy_systems.freeRange==e.freeRange,"freeRange "+label)
 for key in e.flags:check(state.flags.get(key)==e.flags[key],"flags "+label)
 for id in state.item_catalog:
  var qty:int=e.bag.get(id,0)
  check(state.inventory.get(id,0)==qty,"inventory "+label)
  var q:Array=e.quality.get(id,[0,0,0])
  check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"quality "+label)
func settle():
 await process_frame
 await process_frame
func choose(box:OptionButton,id:String):
 for i in range(box.item_count):
  if str(box.get_item_metadata(i))==id:
   box.select(i)
   box.item_selected.emit(i)
   return true
 return false
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var path:=OS.get_environment("RANCH_SCHEDULE_FIXTURE")
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:quit(1);return
 var rows:Array=[]
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var raw:Variant=JSON.parse_string(line)
  if not raw is Dictionary:push_error("Malformed source fixture row");quit(1);return
  if not (int(raw.day)==0):continue
  var row:Variant=load("res://scripts/save_json.gd").decode(raw)
  if int(row.day)==0:rows.append(row)
 check(rows.size()==48,"三种策略两区四饲料与两种旧标记")
 var state=root.get_node_or_null("GameState")
 if state==null:quit(1);return
 state.set_process(false)
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 current_scene.set_process(false)
 current_scene.player.set_physics_process(false)
 for row in rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"load")
  state.minutes=float(row.before.minutes)
  current_scene.hud.show_ranch()
  var panel=current_scene.hud.ranch_panel
  var before:Dictionary=state._make_save_data().duplicate(true)
  check(choose(panel.policy_option,str(row.policy)) and choose(panel.zone_option,str(int(row.zone))) and choose(panel.feed_preference,str(row.feed)),"实际设置选项")
  check(same(state._make_save_data(),before),"选择草稿不提前改变游戏状态")
  state.changed.emit()
  check(panel._metadata(panel.policy_option)==str(row.policy) and panel._metadata(panel.feed_preference)==str(row.feed) and int(panel.zone_option.get_item_metadata(panel.zone_option.selected))==int(row.zone),"其他刷新保留未提交草稿")
  panel.remember_schedule.pressed.emit()
  check(state.message==str(row.result.msg),"统一提交保留原版提示")
  compare(state,row.expected,"实际设置")
  var restored=load("res://scripts/game_state.gd").new()
  restored._load_content()
  check(restored.load_game(state.SAVE_PATH),"实际按钮保存原生文件")
  check(same(restored.ranch,state.ranch) and restored.legacy_systems.freeRange==state.legacy_systems.freeRange,"读回设置和旧放牧标记")
  restored.free()
  current_scene.hud.close_ranch()
 # Closing the page discards unfinished choices; the saved schedule reappears.
 var panel=current_scene.hud.ranch_panel
 current_scene.hud.show_ranch()
 var before:Dictionary=state._make_save_data().duplicate(true)
 choose(panel.policy_option,"inside" if state.ranch.policy!="inside" else "safe")
 current_scene.hud.close_ranch()
 current_scene.hud.show_ranch()
 check(same(state._make_save_data(),before) and panel._metadata(panel.policy_option)==str(state.ranch.policy),"关闭不提交且重开恢复已保存设置")
 var guide:Variant=JSON.parse_string(FileAccess.get_file_as_string(path+".guide.json"))
 state.ranch.notices=guide.notices.duplicate(true)
 panel.handbook_button.pressed.emit()
 check(panel.handbook_open() and state.ui_open,"实际手册按钮保持游戏暂停")
 check(panel.handbook_close.has_focus(),"手册初始键盘焦点")
 var texts:Array=[]
 for child in panel.handbook_content.get_children():texts.append(child.text)
 check(texts==guide.blocks.map(func(block):return block.text),"完整原版手册与动态近况逐字一致")
 check(panel.handbook_close.focus_next==panel.handbook_scroll.get_path() and panel.handbook_scroll.focus_next==panel.handbook_close.get_path(),"手册焦点在内容和返回之间循环")
 panel.handbook_close.pressed.emit()
 check(panel.visible and not panel.handbook_open() and state.ui_open,"返回按钮关闭手册并保留名册")
 panel.open_handbook()
 var escape:=InputEventKey.new()
 escape.keycode=KEY_ESCAPE
 escape.pressed=true
 Input.parse_input_event(escape)
 await settle()
 check(not panel.visible and not panel.handbook_open() and not state.ui_open,"原版 Esc 关闭整个牧场面板")
 current_scene.hud.show_ranch()
 panel.open_handbook()
 panel.close()
 check(not panel.visible and not panel.handbook_open() and not state.ui_open,"关闭名册同步关闭手册并恢复游戏")
 current_scene.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("RANCH_SCHEDULE_UI_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
