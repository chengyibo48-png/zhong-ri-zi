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
 create_timer(100).timeout.connect(func():push_error("Ranch family UI timeout");quit(1))
 var file=FileAccess.open(OS.get_environment("RANCH_FAMILY_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 var rows:Array=[]
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var row:Variant=load("res://scripts/save_json.gd").decode(JSON.parse_string(line))
  if row.variant!="normal":continue
  if row.op=="buy" and row.breed=="local" and row.sex=="female" and row.young:rows.append(row)
  elif row.op=="breed" and row.id=="cow" and row.mb=="productive" and row.fb=="hardy":rows.append(row)
  elif row.op=="incubate":rows.append(row)
 check(rows.size()==8,"五物种购买、配对、两种孵化真实页面")
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in rows:
  var label:String=str(row.op)+"/"+str(row.id)
  check(state.load_game_data(state.convert_external_save(row.before)),"load "+label)
  var barn:String="poultry" if row.op=="incubate" else str(state.system_catalog.ranch.species[row.id].home)
  var house_id:String=str(state.system_catalog.ranch.barns[barn].house)
  var source_plan:Dictionary=state.interaction_route({"kind":"ranch-task","x":480,"y":490},{"x":480,"y":510},house_id)
  check(source_plan.reachable==row.insideRoute.reachable and source_plan.stand==row.insideRoute.stand,"source interior task accessibility "+label)
  # Original interiors block this hard-coded service point in three barns.
  # Exercise the successful source UI route from the actual outdoor barn entrance.
  state.current_interior=""
  var door:Dictionary=state.house_data(house_id).door
  state.player_position=Vector2(door.x,door.y+64)
  change_scene_to_file("res://scenes/main.tscn")
  await settle()
  current_scene.player.set_physics_process(false)
  state.minutes=float(row.before.minutes)
  current_scene.hud.close_top_panel()
  current_scene.hud.show_ranch()
  var panel=current_scene.hud.ranch_panel
  var animals_before:Array=state.animals.duplicate(true)
  var money_before:int=state.money
  match str(row.op):
   "buy":
    check(choose(panel.buy_species,str(row.id)) and choose(panel.buy_breed,str(row.breed)) and choose(panel.buy_sex,str(row.sex)),"实际购买选项 "+label)
    panel.buy_young.button_pressed=bool(row.young)
    panel._buy_animal()
   "breed":
    check(choose(panel.mother_option,str(row.mother)) and choose(panel.father_option,str(row.father)),"实际繁殖伙伴 "+label)
    panel._breed_selected()
   "incubate":
    check(choose(panel.incubation_species,str(row.id)),"实际受精蛋选项 "+label)
    panel._incubate_selected()
  check(same(state.animals,animals_before) and state.money==money_before,"出发不提前新增动物或扣钱 "+label)
  check(not state.ranch_active_task.is_empty() and not panel.visible,"实际点击开始走近工位 "+label)
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
 var cancel_row:Dictionary=rows.back()
 check(state.load_game_data(state.convert_external_save(cancel_row.before)),"取消孵化输入")
 state.current_interior=""
 var cancel_door:Dictionary=state.house_data(str(state.system_catalog.ranch.barns.poultry.house)).door
 state.player_position=Vector2(cancel_door.x,cancel_door.y+64)
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 current_scene.player.set_physics_process(false)
 state.minutes=float(cancel_row.before.minutes)
 current_scene.hud.close_top_panel()
 current_scene.hud.show_ranch()
 var panel=current_scene.hud.ranch_panel
 choose(panel.incubation_species,str(cancel_row.id))
 var before:Dictionary=state._make_save_data().duplicate(true)
 panel._incubate_selected()
 state.stop_walking()
 for i in range(20):state._process_action(0.1)
 check(state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.action_sequence.active.is_empty(),"取消清除孵化任务与动作")
 check(same(state.ranch,before.ranch) and same(state.animals,before.animals),"取消不创建幼崽或预留床位")
 check(same(state.inventory,before.inventory) and same(state.quality,before.quality) and same(state.kitchen,before.kitchen),"取消保留受精蛋、品质与批次")
 check(state.minutes==before.minutes and state.stamina==before.stamina and state.money==before.money,"取消不扣时间体力与钱")
 if current_scene!=null:current_scene.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("RANCH_FAMILY_UI_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
