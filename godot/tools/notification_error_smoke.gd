extends SceneTree
const TEXT=preload("res://scripts/js_string.gd")
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func same(a:Variant,b:Variant)->bool:
 if TEXT.is_string(a) or TEXT.is_string(b):return TEXT.equal(a,b)
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
 var fixture:Dictionary=CODEC.parse(FileAccess.get_file_as_string(OS.get_environment("NOTIFICATION_ERROR_FIXTURE")))
 change_scene_to_file("res://scenes/main.tscn");await process_frame;await process_frame
 current_scene.set_process(false);current_scene.player.set_physics_process(false)
 var hud=current_scene.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 for row in fixture.rows:
  state.feedback=row.before.duplicate(true);state.day=int(row.day);state.minutes=float(row.minute)
  var gameplay:Dictionary=state._make_save_data().duplicate(true);gameplay.erase("feedback")
  hud.life_menu.open_panel()
  state.notification_queue.rows.clear()
  var before_message:String=state.message
  var previous_file:String=FileAccess.get_file_as_string(state.SAVE_PATH) if row.mode=="failed" else ""
  var failed_temp_path:String=ProjectSettings.globalize_path(state.SAVE_PATH+".tmp")
  if row.mode=="failed":check(DirAccess.make_dir_recursive_absolute(failed_temp_path)==OK,"prepare isolated write failure")
  hud.show_notification(str(row.message),true)
  check(same(state.feedback,row.after),"actual source error record "+str(row.mode)+"/"+str(row.quiet))
  var saved:Dictionary=CODEC.parse(FileAccess.get_file_as_string(state.SAVE_PATH))
  if row.mode=="failed":
   check(FileAccess.get_file_as_string(state.SAVE_PATH)==previous_file and not same(saved.feedback,row.saves[0]) and not state._writing_save and not state._suppress_message_notifications,"failed write retains old file and restores notification delivery")
   check(DirAccess.remove_absolute(failed_temp_path)==OK,"remove isolated write obstruction")
  else:check(same(saved.feedback,row.saves[0]),"error immediately saved "+str(row.mode))
  check(state.message==before_message,"silent save keeps operation message")
  check(state.notification_queue.rows.is_empty() and hud.life_menu.get_meta("notification_column").get_node("ModalStatus/Message").text==row.message,"error inline even quiet")
  var after:Dictionary=state._make_save_data().duplicate(true);after.erase("feedback")
  check(same(gameplay,after),"error has no gameplay charge "+str(row.mode))
  hud.life_menu.close()
 state.feedback=state._feedback_default()
 var toasts:Array=[]
 state.feedback_toast_requested.connect(func(text:String,priority:int):toasts.append([text,priority]))
 var now_message:String=state.message
 state._feedback_note({"key":"silent","title":"只记下一件事","text":"记录","priority":2})
 check(toasts.is_empty() and state.message==now_message,"note alone is silent")
 print("Notification error: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
