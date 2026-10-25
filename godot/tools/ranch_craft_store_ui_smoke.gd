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
 create_timer(100).timeout.connect(func():push_error("Ranch craft/store UI timeout");quit(1))
 var file=FileAccess.open(OS.get_environment("RANCH_CRAFT_STORE_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 var rows:Array=[]
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var row:Variant=JSON.parse_string(line)
  if row.op=="craft" and row.id in ["cream","yogurt"] and row.variant=="normal":rows.append(row)
  elif row.op=="craft" and row.id=="cream" and row.variant=="locked" and row.deviceOpen:rows.append(row)
  elif row.op=="craft" and row.id=="compost" and row.variant=="premium":rows.append(row)
  elif row.op=="store" and row.id=="hay" and row.variant=="premium":rows.append(row)
 check(rows.size()==8,"八类实际面板输入")
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in rows:
  var label:String=str(row.op)+"/"+str(row.id)+"/"+str(row.variant)+"/"+str(row.get("deviceOpen",false))
  check(state.load_game_data(state.convert_external_save(row.before)),"load "+label)
  var house:String=""
  for building in state.world_village.houses:
   if str(building.name)=="禾溪小灶":house=str(building.id)
  state.current_interior=house if row.id in ["cream","yogurt"] else str(state.system_catalog.ranch.barns.cattle.house)
  state.interior_position=Vector2(560,510) if row.id in ["cream","yogurt"] else Vector2(480,510)
  change_scene_to_file("res://scenes/interior.tscn")
  await settle()
  current_scene.player.set_physics_process(false)
  state.minutes=float(row.before.minutes)
  current_scene.hud.close_top_panel()
  current_scene.hud.show_ranch()
  var panel=current_scene.hud.ranch_panel
  if row.op=="craft":
   check(choose(panel.recipe_option,str(row.id)),"实际配方选项 "+label)
   panel.recipe_amount.value=row.quantity
   var stock:Dictionary=state.inventory.duplicate(true)
   panel._craft_recipe()
   check(same(state.inventory,stock),"出发不提前扣材料 "+label)
   if row.id in ["cream","yogurt"]:
    check((not state.kitchen_task.is_empty())==bool(row.result.ok) and state.ranch_queue.is_empty(),"乳品走向实际小灶工位 "+label)
    if not row.result.ok:check(panel.visible,"缺设备或锁原料保留面板 "+label)
   for frame in range(900):
    if state.kitchen_task.is_empty() and state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.walking_target.is_empty() and state.action_sequence.active.is_empty():break
    state._process_action(0.1)
    if state.kitchen_task.is_empty() and state.ranch_active_task.is_empty() and state.ranch_queue.is_empty() and state.walking_target.is_empty() and state.action_sequence.active.is_empty():break
    var prior_minutes:float=state.minutes
    current_scene.player._physics_process(1.0/60.0)
    state.minutes=prior_minutes
    await physics_frame
   await settle()
  else:
   check(choose(panel.store_item,str(row.id)),"实际料仓选项 "+label)
   panel.store_amount.value=row.quantity
   panel._store(bool(row.withdraw))
  check(state.message==str(row.result.msg),"实际原文 "+label+" actual="+state.message)
  check(same(state.kitchen,row.expected.kitchen),"完整厨房与批次 "+label)
  check(same(state.legacy_processing,row.expected.processing),"完整原版加工队列 "+label)
  check(same(state.skills,row.expected.skills),"实际经验 "+label)
  check(state.minutes==row.expected.minutes and state.stamina==row.expected.stamina,"实际时钟体力 "+label)
  check(same(state.ranch,row.expected.ranch),"实际完整料仓 "+label)
  check(same(state.legacy_systems.discovered,row.expected.discovered),"实际发现记录 "+label)
  for id in state.item_catalog:
   var qty:int=row.expected.bag.get(id,0)
   var q:Array=row.expected.quality.get(id,[0,0,0])
   check(state.inventory.get(id,0)==qty and same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"实际库存品质 "+label)
  current_scene.hud.close_top_panel()
 if current_scene!=null:current_scene.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("RANCH_CRAFT_STORE_UI_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
