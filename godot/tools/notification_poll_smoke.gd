extends SceneTree
var passed:=0
var failed:=0
var emitted:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if (a is float or a is int) and (b is float or b is int):return float(a)==float(b)
 return a==b
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 state.feedback_toast_requested.connect(func(text:String,priority:int):emitted.append([text,priority]))
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NOTIFICATION_POLL_FIXTURE")))
 for row in fixture.rows:
  state.day=int(row.before.day);state.minutes=float(row.before.minutes)
  state.feedback=row.before.feedback.duplicate(true)
  state.kitchen=row.before.kitchen.duplicate(true);state.economy=row.before.economy.duplicate(true)
  state.animals.assign(row.before.animals.duplicate(true));state.farm=row.before.farm.duplicate(true)
  state.plots.assign(row.before.plots.duplicate(true))
  for plot in state.plots:
   if plot.crop==null:plot.crop=""
  state.neighbors=row.before.neighbors.duplicate(true)
  for person in state.neighbors.people.values():
   if person.event==null:person.event={}
  emitted.clear()
  var result:bool=state._feedback_poll()
  if failed==0 and not same(state.feedback,row.after):print("ACTUAL ",state.feedback," EXPECTED ",row.after)
  check(same(state.feedback,row.after),"actual source poll records and hashed tokens "+str(row.mask)+"/"+str(row.repeat))
  check(result==(row.notification!=null),"poll result "+str(row.mask))
  check(same(emitted,[] if row.notification==null else [row.notification]),"single highest-priority combined toast "+str(row.mask))
 print("Notification poll: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
