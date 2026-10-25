extends SceneTree
var passed:=0
var failed:=0
var failure_fields:Dictionary={}
var diff_count:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  var key:String=label.get_slice(" ",0)
  if key=="家畜" or key=="农田":key+=" "+label.get_slice(" ",1)
  failure_fields[key]=int(failure_fields.get(key,0))+1
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
func diff(a:Variant,b:Variant,path:String):
 if same(a,b) or diff_count>=25:return
 if a is Dictionary and b is Dictionary:
  for k in b:
   if not a.has(k):print("RANCH_DIFF ",path,"/",k," missing");diff_count+=1
   else:diff(a[k],b[k],path+"/"+str(k))
  for k in a:
   if not b.has(k):print("RANCH_DIFF ",path,"/",k," extra");diff_count+=1
 elif a is Array and b is Array:
  for i in range(mini(a.size(),b.size())):diff(a[i],b[i],path+"/"+str(i))
  if a.size()!=b.size():print("RANCH_DIFF ",path," size ",a.size()," vs ",b.size());diff_count+=1
 else:print("RANCH_DIFF ",path," actual=",var_to_str(a)," expected=",var_to_str(b));diff_count+=1
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(180).timeout.connect(func():push_error("Ranch overnight timeout");quit(1))
 var fixture=FileAccess.open(OS.get_environment("RANCH_OVERNIGHT_FIXTURE"),FileAccess.READ)
 if fixture==null:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 while not fixture.eof_reached():
  var line:=fixture.get_line()
  if line.strip_edges()=="":continue
  var row:Variant=load("res://scripts/save_json.gd").decode(JSON.parse_string(line))
  if not row is Dictionary:check(false,"invalid fixture");continue
  var label:String=str(row.day)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"跨日原版输入 "+label)
  for step in row.steps:
   state.advance_day()
   check(state.day==int(step.expected.day) and absf(state.minutes-float(step.expected.minutes))<0.00000001 and state.stamina==int(step.expected.stamina),"跨日日历体力时间 "+label)
   check(state.message==str(step.result.msg),"跨日原文 "+label+" actual="+state.message)
   check(same(state.kitchen,step.expected.kitchen),"跨日完整厨房 "+label)
   check(same(state.legacy_processing,step.expected.processing),"旧加工队列 "+label)
   check(same(state.player_stats,step.expected.stats),"完整跨日统计 "+label)
   check(same(state.journal_entries(),step.expected.journal),"完整原版跨日日记 "+label)
   check(same(state.legacy_systems.eventLog,step.expected.eventLog),"完整原版跨日事件 "+label)
   check(same(state.legacy_systems.discovered,step.expected.discovered),"跨日物产发现 "+label)
   check(same(state.letters,step.expected.letters),"跨日来信 "+label)
   check(same(state.building,step.expected.building),"营造完整状态 "+label)
   check(same(state.upgrades,step.expected.upgrades),"营造解锁顺序 "+label)
   state._sync_farm_beds_from_plots()
   for key in step.expected.farm:
    if key=="beds":
     for i in range(step.expected.farm.beds.size()):
      for field in step.expected.farm.beds[i]:
       var actual:Variant=state.farm.beds[i].get(field)
       var expected:Variant=step.expected.farm.beds[i][field]
       check((expected==null and actual is Dictionary and actual.is_empty()) or same(actual,expected),"农田 "+field+" "+label+"/"+str(i)+" actual="+str(actual)+" expected="+str(expected))
    else:check(same(state.farm.get(key),step.expected.farm[key]),"农场 "+key+" "+label)
   diff(state.ranch,step.expected.ranch,label+"/ranch")
   diff(state.animals,step.expected.animals,label+"/animals")
   check(same(state.ranch,step.expected.ranch),"牧场完整状态 "+label)
   check(same(state.pet_state,step.expected.pet),"宠物完整状态 "+label)
   check(state.money==step.expected.money,"跨日金钱 "+label)
   check(state.animals.size()==step.expected.animals.size(),"家畜数量 "+label)
   for i in range(mini(state.animals.size(),step.expected.animals.size())):
    for key in step.expected.animals[i]:
     check(same(state.animals[i].get(key),step.expected.animals[i][key]),"家畜 "+key+" "+label+"/"+str(i)+" actual="+str(state.animals[i].get(key))+" expected="+str(step.expected.animals[i][key]))
   for i in range(mini(state.plots.size(),step.expected.plots.size())):
    check(str(state.plots[i].get("crop",""))==str(step.expected.plots[i].crop if step.expected.plots[i].crop!=null else ""),"种植作物 "+label)
    check(absf(float(state.plots[i].growth)-float(step.expected.plots[i].growth))<0.00000001,"生长进度 "+label)
   for id in step.expected.flags:check(state.flags.get(id)==step.expected.flags[id],"跨日标记 "+label)
   for id in state.item_catalog:
    var qty:int=step.expected.bag.get(id,0)
    check(int(state.inventory.get(id,0))==qty,"跨日库存 "+label)
    var q:Array=step.expected.quality.get(id,[0,0,0])
    check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"跨日品质 "+label)
  if int(row.day) in [27,51,99,111,223]:
   var path:String=load("res://tools/smoke_files.gd").create_path("overnight_roundtrip")
   check(state.save_game(path,true),"两晚完整状态保存 "+label)
   var restored=load("res://scripts/game_state.gd").new()
   restored._load_content()
   check(restored.load_game(path),"两晚完整状态读档 "+label)
   check(same(restored.kitchen,state.kitchen),"跨日厨房完整读档 "+label)
   check(same(restored.legacy_processing,state.legacy_processing),"未完成旧队列读档 "+label)
   check(same(restored.quality,state.quality) and same(restored.inventory,state.inventory),"跨日库存品质读档 "+label)
   check(same(restored.journal_entries(),state.journal_entries()) and same(restored.legacy_systems.eventLog,state.legacy_systems.eventLog),"跨日记录读档 "+label)
   check(same(restored.farm,state.farm) and same(restored.plots,state.plots),"全部农田分数数值读档 "+label)
   check(same(restored.ranch,state.ranch) and same(restored.animals,state.animals) and same(restored.building,state.building),"全部家畜与营造读档 "+label)
   check(same(restored.pet_state,state.pet_state),"宠物跨日读档 "+label)
   restored.free()
   load("res://tools/smoke_files.gd").remove(path)
 print("Integration failure fields: ",failure_fields)
 print("RANCH_OVERNIGHT_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
