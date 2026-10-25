extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<8:push_error(label)
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 var state=root.get_node("GameState")
 state.set_process(false)
 var rows:Array=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FORAGE_STATUS_FIXTURE")))
 var names:Dictionary={"eventReady":"event_ready","inSeason":"in_season","readyDay":"ready_day","qty":"quantity"}
 for row in rows:
  state.day=int(row.day)
  state.forage=row.forage.duplicate(true)
  state.gathered=row.collected.duplicate(true)
  state.toolkit=row.toolkit.duplicate(true)
  var actual:Dictionary=state.forage_status(str(row.point.id),str(row.point.item))
  for key in row.expected:
   if str(key)=="key":continue
   var native_key:=str(names.get(key,key))
   var expected:Variant=row.expected[key]
   var found:Variant=actual.get(native_key,null)
   var same:bool=is_equal_approx(float(found),float(expected)) if (found is float or found is int) and (expected is float or expected is int) else found==expected
   check(same,"原版采集状态 %s/%s/%s/%s"%[row.day,row.point.item,row.variant,key])
  check(state.forage_description(str(row.point.id),str(row.point.item))==str(row.description),"原版采集提示 %s/%s/%s"%[row.day,row.point.item,row.variant])
 await root.get_node("AudioService").prepare_exit()
 print("Forage status smoke: %d passed, %d failed; source rows %d"%[passed,failed,rows.size()])
 quit(0 if failed==0 else 1)
