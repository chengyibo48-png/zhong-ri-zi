extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
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
func finish(state):
 for i in range(35):state._process_action(0.1)
func escape():
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 key=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=false
 Input.parse_input_event(key)
 await process_frame
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(240).timeout.connect(func():push_error("Full eating timeout");quit(1))
 var fixture=FileAccess.open(OS.get_environment("EATING_FULL_FIXTURE"),FileAccess.READ)
 if fixture==null:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 while not fixture.eof_reached():
  var line:=fixture.get_line()
  if line.strip_edges()=="":continue
  var row:Variant=JSON.parse_string(line)
  if not row is Dictionary:check(false,"invalid fixture");continue
  var label:String="eat/"+str(row.id)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"原版料理输入 "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  var ok:bool=state.eat_item(str(row.id))
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"料理原文结果 "+label)
  check(absf(state.minutes-float(row.expected.minutes))<0.00000001 and state.stamina==float(row.expected.stamina) and state.money==int(row.expected.money),"料理时间体力钱 "+label)
  check(same(state.kitchen,row.expected.kitchen),"完整加工工位队列批次 "+label)
  check(same(state.skills,row.expected.skills),"料理经验及封顶 "+label)
  check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"料理不增加原版没有的记录 "+label)
  check(same(state.known_recipes,row.expected.knownRecipes),"配方解锁 "+label)
  check(same(state.player_stats,row.expected.stats),"全部统计 "+label)
  check(same(state.upgrades,row.expected.upgrades),"设备解锁标记 "+label)
  check(same(state.legacy_systems.get("discovered",[]),row.expected.discovered),"物品发现顺序 "+label)
  check(state.kitchen_active_buff()==(str(row.expected.activeBuff.kind) if row.expected.activeBuff is Dictionary else ""),"原版增益到期判定 "+label)
  check(same(state.legacy_systems.buffs,row.expected.buffs),"原版增益字段 "+label)
  for id in row.expected.flags:check(state.flags.get(id)==row.expected.flags[id],"标记 "+label)
  for id in state.item_catalog:
   var qty:int=row.expected.bag.get(id,0)
   check(int(state.inventory.get(id,0))==qty,"库存 "+label)
   var q:Array=row.expected.quality.get(id,[0,0,0])
   check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"品质 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["storage","relations","neighbors","marriage","npc_stories","partners","building","toolkit"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
  if str(row.id) in ["summerDrink","winterMilk","greens"] and str(row.variant) in ["buff-before","buff-exact","buff-after"]:
   var file_path:String=load("res://tools/smoke_files.gd").create_path("eating_buff")
   check(state.save_game(file_path,true),"增益边界状态保存 "+label)
   var restored=load("res://scripts/game_state.gd").new()
   restored._load_content()
   check(restored.load_game(file_path),"增益边界状态读档 "+label)
   check(same(restored.kitchen,row.expected.kitchen),"分数截止及批次完整读档 "+label)
   check(restored.kitchen_active_buff()==state.kitchen_active_buff(),"增益有效状态读档 "+label)
   check(absf(restored.minutes-state.minutes)<0.00000001 and restored.stamina==state.stamina,"分数时间及体力读档 "+label)
   restored.free()
   load("res://tools/smoke_files.gd").remove(file_path)
 print("EATING_FULL_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
