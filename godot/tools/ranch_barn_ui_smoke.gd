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
 for key in e.flags:check(state.flags.get(key)==e.flags[key],"flags "+label)
 for id in state.item_catalog:
  var qty:int=e.bag.get(id,0)
  check(state.inventory.get(id,0)==qty,"inventory "+label)
  var q:Array=e.quality.get(id,[0,0,0])
  check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"quality "+label)
func settle():
 await process_frame
 await process_frame
 await physics_frame
func choose(box:OptionButton,id:String)->bool:
 for i in range(box.item_count):
  if str(box.get_item_metadata(i))==id:box.select(i);return true
 return false
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(200).timeout.connect(func():push_error("Ranch barn UI timeout");quit(1))
 var file=FileAccess.open(OS.get_environment("RANCH_BARN_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 var rows:Array=[]
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var raw:Variant=JSON.parse_string(line)
  if not raw is Dictionary:push_error("Malformed source fixture row");quit(1);return
  if not ((raw.variant=="normal" and raw.result.ok) or (raw.variant in ["enabled","installed"] and raw.action in ["autoFeed","autoClean","autoCollect"])):continue
  var row:Variant=load("res://scripts/save_json.gd").decode(raw)
  if row.variant=="normal" and row.result.ok:rows.append(row)
  elif row.variant in ["enabled","installed"] and row.action in ["autoFeed","autoClean","autoCollect"]:rows.append(row)
 check(rows.size()==68,"四种畜舍十一操作与自动设施暂停/重启")
 var state=root.get_node("GameState")
 state.set_process(false)
 var row_index := 0
 for row in rows:
  row_index += 1
  print("RANCH_BARN_UI_CASE ",row_index,"/",rows.size()," ",row.id,"/",row.action)
  var label:String=str(row.id)+"/"+str(row.action)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"load "+label)
  var barn:String=str(row.id)
  if row.action=="build":
   state.current_interior=""
   var house:Dictionary=state.house_data(str(state.system_catalog.ranch.barns[barn].house))
   state.player_position=Vector2(float(house.door.x),float(house.door.y))+Vector2(0,75)
   change_scene_to_file("res://scenes/main.tscn")
  else:
   state.current_interior=str(state.system_catalog.ranch.barns[barn].house)
   state.interior_position=Vector2(480,510)
   change_scene_to_file("res://scenes/interior.tscn")
  await settle()
  current_scene.set_process(false)
  current_scene.player.set_physics_process(false)
  state.minutes=float(row.before.minutes)
  current_scene.hud.close_top_panel()
  current_scene.hud.show_ranch()
  var panel=current_scene.hud.ranch_panel
  var before:Dictionary=state._make_save_data().duplicate(true)
  panel.selected_barn_id=barn
  panel._fill_barn_list()
  check(choose(panel.barn_action,str(row.action)),"实际畜舍操作选项 "+label)
  panel._run_barn_action()
  check(same(state.ranch,before.ranch) and same(state.inventory,before.inventory) and same(state.animals,before.animals) and state.money==before.money,"出发不提前建设或扣材料 "+label)
  check(not state.ranch_active_task.is_empty() and not panel.visible,"实际点击开始走近工位 "+label)
  for frame in range(900):
   if state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.walking_target.is_empty() and state.action_sequence.active.is_empty():break
   state._process_action(0.1)
   if state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.walking_target.is_empty() and state.action_sequence.active.is_empty():break
   var prior_minutes:float=state.minutes
   current_scene.player._physics_process(1.0/60.0)
   state.minutes=prior_minutes
   if frame%30==0:await process_frame
  await settle()
  check(state.ranch_completed==1 and state.ranch_active_task.is_empty(),"实际抵达后完成一次 "+label)
  check(state.message==str(row.result.msg),"实际完整原文 "+label)
  compare(state,row.expected,label)
  current_scene.hud.close_top_panel()
 if current_scene!=null:current_scene.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("RANCH_BARN_UI_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
