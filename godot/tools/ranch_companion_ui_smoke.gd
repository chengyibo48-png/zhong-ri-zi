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
 create_timer(180).timeout.connect(func():push_error("Ranch companion UI timeout");quit(1))
 var file=FileAccess.open(OS.get_environment("RANCH_COMPANION_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 var rows:Array=[]
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var row:Variant=load("res://scripts/save_json.gd").decode(JSON.parse_string(line))
  if row.variant!="normal":continue
  if row.op=="pet" and row.action in ["feed","train","play","home","follow","patrol"]:rows.append(row)
  elif row.op in ["rehome","adopt"] and row.breed=="local" and row.sex=="female":rows.append(row)
 check(rows.size()==22,"猫狗六项操作与五物种送养接回")
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in rows:
  var label:String=str(row.op)+"/"+str(row.id)+"/"+str(row.get("action",""))
  check(state.load_game_data(state.convert_external_save(row.before)),"load "+label)
  state.current_interior=""
  if row.op=="pet":
   var p:Dictionary=state.ranch.pet.position
   state.player_position=Vector2(float(p.x),float(p.y))+Vector2(0,75)
  else:state.player_position=Vector2(2600,1700)
  change_scene_to_file("res://scenes/main.tscn")
  await settle()
  current_scene.player.set_physics_process(false)
  state.minutes=float(row.before.minutes)
  current_scene.hud.close_top_panel()
  current_scene.hud.show_ranch()
  var panel=current_scene.hud.ranch_panel
  var before:Dictionary=state._make_save_data().duplicate(true)
  var queued:=false
  match str(row.op):
   "pet":
    panel._pet_action(str(row.action))
    queued=str(row.action) in ["feed","train","play"]
   "rehome":
    panel.selected_animal_id=str(row.animal)
    panel._request_rehome()
    check(panel.confirm_rehome.visible,"实际送养确认对话框 "+label)
    check(same(state._make_save_data(),before),"确认前没有状态变化 "+label)
    panel.confirm_rehome.canceled.emit()
    panel.confirm_rehome.hide()
    check(same(state._make_save_data(),before),"取消送养保留完整状态 "+label)
    panel._request_rehome()
    panel.confirm_rehome.confirmed.emit()
    panel.confirm_rehome.hide()
   "adopt":
    var chosen:=false
    for i in range(panel.rehomed_list.item_count):
     if str(panel.rehomed_list.get_item_metadata(i))==str(row.animal):
      panel.rehomed_list.select(i)
      chosen=true
      break
    check(chosen,"真实接回记录选项 "+label)
    panel._adopt_selected()
  if queued:
   check(same(state.ranch,before.ranch) and same(state.inventory,before.inventory) and same(state.pet_state,before.pet) and state.stamina==before.stamina,"走近前不提前照料或扣料 "+label)
   check(not state.ranch_active_task.is_empty() and not panel.visible,"实际点击开始走近伙伴 "+label)
   for frame in range(900):
    if state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.walking_target.is_empty() and state.action_sequence.active.is_empty():break
    state._process_action(0.1)
    if state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.walking_target.is_empty() and state.action_sequence.active.is_empty():break
    var prior_minutes:float=state.minutes
    current_scene.player._physics_process(1.0/60.0)
    state.minutes=prior_minutes
    await physics_frame
   await settle()
   check(state.ranch_completed==1 and state.ranch_active_task.is_empty(),"实际抵达后完成一次 "+label)
  check(state.message==str(row.result.msg),"实际完整原文 "+label)
  compare(state,row.expected,label)
  current_scene.hud.close_top_panel()
 var cancel_row:Dictionary={}
 for row in rows:
  if row.op=="pet" and row.id=="cat" and row.action=="play":cancel_row=row;break
 check(not cancel_row.is_empty(),"取消陪玩输入存在")
 check(state.load_game_data(state.convert_external_save(cancel_row.before)),"取消陪玩状态")
 state.current_interior=""
 var pet_position:Dictionary=state.ranch.pet.position
 state.player_position=Vector2(float(pet_position.x),float(pet_position.y))+Vector2(0,75)
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 current_scene.player.set_physics_process(false)
 state.minutes=float(cancel_row.before.minutes)
 current_scene.hud.close_top_panel()
 current_scene.hud.show_ranch()
 var panel=current_scene.hud.ranch_panel
 var before:Dictionary=state._make_save_data().duplicate(true)
 panel._pet_action("play")
 state.stop_walking()
 for i in range(20):state._process_action(0.1)
 check(state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.action_sequence.active.is_empty(),"取消清除陪玩任务")
 check(same(state.pet_state,before.pet) and same(state.ranch,before.ranch),"取消不改变亲近精力与今日陪玩记录")
 check(same(state.inventory,before.inventory) and same(state.quality,before.quality) and state.stamina==before.stamina and state.minutes==before.minutes and state.money==before.money,"取消保留资源与时间")
 if current_scene!=null:current_scene.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("RANCH_COMPANION_UI_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
