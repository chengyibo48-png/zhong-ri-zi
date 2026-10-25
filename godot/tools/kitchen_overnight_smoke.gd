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
 create_timer(180).timeout.connect(func():push_error("Kitchen overnight timeout");quit(1))
 var fixture=FileAccess.open(OS.get_environment("KITCHEN_OVERNIGHT_FIXTURE"),FileAccess.READ)
 if fixture==null:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 while not fixture.eof_reached():
  var line:=fixture.get_line()
  if line.strip_edges()=="":continue
  var row:Variant=JSON.parse_string(line)
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
   restored.free()
   load("res://tools/smoke_files.gd").remove(path)
 print("KITCHEN_OVERNIGHT_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
