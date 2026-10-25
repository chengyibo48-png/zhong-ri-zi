extends SceneTree
const RULES=preload("res://scripts/context_action_rules.gd")
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=15:push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CONTEXT_ACTION_FIXTURE"))))
 var before:Dictionary=state._make_save_data().duplicate(true)
 for row in fixture.rows:
  var near:Dictionary=row.near if row.near is Dictionary else {}
  var actual:Dictionary=RULES.describe(near,row.verb,row.house,row.room,row.riding,row.walking,int(row.choices),row.mode,row.menu,row.locked)
  check(actual.hidden==row.expected.hidden,"source context hidden")
  check(actual.buttons==row.expected.buttons,"source context buttons "+str(near)+"/"+row.mode)
  check(RULES.progress(state,{"x":100.0,"y":100.0},row.path,row.pending,row.riding,row.exiting)==row.expected.progress,"source route progress")
 check(fixture.rows.size()==6480,"6480 actual source contexts")
 check(state._make_save_data()==before,"context models are read-only")
 await root.get_node("AudioService").prepare_exit()
 print("CONTEXT_ACTIONS_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",fixture.rows.size()," contexts")
 quit(0 if failed==0 else 1)
