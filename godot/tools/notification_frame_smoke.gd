extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 await process_frame
 root.get_node("GameState").set_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NOTIFICATION_FRAME_FIXTURE")))
 var probe:Node
 var last:Variant=null
 for row in fixture.rows:
  if last!=row.added:
   if probe!=null:probe.free()
   probe=load("res://tools/notification_frame_probe.gd").new();probe.added=bool(row.added)
   probe.changed.connect(func():probe.calls.append("update"))
   probe.feedback_toast_requested.connect(func(text:String,_priority:int):probe.calls.append(["toast",text,false,true]))
   last=row.added
  probe.calls.clear()
  var result:bool=probe._poll_feedback_frame(float(row.at),bool(row.hidden))
  check(probe._feedback_poll_at==float(row.after),"source next timestamp")
  check(probe.calls==row.calls,"source frame call order "+str(row.at)+"/"+str(row.hidden))
  check(result==(float(row.after)!=float(row.before)),"source poll gate")
 probe.free()
 print("Notification frame: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
