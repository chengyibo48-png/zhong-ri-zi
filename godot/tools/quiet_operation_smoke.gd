extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 var sounds:Array=[]
 state.sound_requested.connect(func(kind:String):sounds.append(kind))
 var messages:Array=[]
 state.message_requested.connect(func(text:String):messages.append(text))
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QUIET_OPERATION_FIXTURE")))
 for row in fixture.rows:
  sounds.clear();messages.clear();state.current_interior="" if row.get("room")==null else str(row.room);state.riding=bool(row.get("riding",false)) if row.kind!="bike" else not bool(row.riding) if row.get("room")==null else false
  if row.kind=="tool":state.select_toolbar_tool(str(row.id));check(state.selected_tool==row.tool,"source selected tool")
  elif row.kind=="bike":state.toggle_bicycle();check(state.riding==row.riding,"source bicycle toggle")
  else:state.stop_walking()
  check(messages==row.toasts,"source messages "+str(row.kind)+"/"+str(row.get("id",row.get("room",""))))
  check(sounds==row.sounds,"source operation sounds "+str(row.kind))
 print("Quiet operation: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
