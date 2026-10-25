extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("run")
func run():
 var state=root.get_node("GameState");state.set_process(false)
 var file=FileAccess.open(OS.get_environment("SOURCE_SAVE_VALIDATION_FIXTURE"),FileAccess.READ)
 while not file.eof_reached():
  var line:String=file.get_line()
  if line=="":continue
  var row:Variant=preload("res://scripts/save_json.gd").parse(line)
  if not row is Dictionary:push_error("Invalid fixture");quit(1);return
  if row.has("caseCount"):continue
  var actual:String=preload("res://scripts/source_save_validation.gd").error(row.before,state.item_catalog,state.crop_catalog,state.content.scenes,state.content,state.system_catalog,state.world_village)
  if actual==row.error:passed+=1
  else:failed+=1;push_error(str(row.label)+" got "+actual+" expected "+str(row.error))
 print("SOURCE_PREFLIGHT_ONLY: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
