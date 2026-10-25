extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NOTIFICATION_FIXTURE")))
 var queue:RefCounted
 var inline:Array=[]
 var configuration:=""
 for row in fixture.rows:
  var key:String=str(row.seconds)+str(row.quiet)+str(row.modal)
  if key!=configuration:queue=load("res://scripts/notification_queue.gd").new();inline=[];configuration=key
  var op:Array=row.op
  if op[0]=="advance":queue.expire(float(row.now))
  elif bool(op[2]) or bool(op[3]) or not bool(row.quiet):
   if row.modal:inline=[{"text":op[1],"error":op[2]}]
   else:queue.append(str(op[1]),bool(op[2]),bool(op[3]),float(row.seconds),float(row.now))
  var actual:Array=[]
  for entry in queue.rows:actual.append({"text":entry.text,"error":entry.error,"important":entry.important})
  check(actual==row.world,"source world queue "+key+"/"+str(op))
  check(inline==row.inline,"source inline "+key+"/"+str(op))
 print("Notification source: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
