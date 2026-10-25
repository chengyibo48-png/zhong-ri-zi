extends SceneTree
func _initialize():call_deferred("run")
func run():
 var state=root.get_node("GameState");state.set_process(false)
 var file=FileAccess.open(OS.get_environment("SOURCE_SAVE_VALIDATION_FIXTURE"),FileAccess.READ)
 while not file.eof_reached():
  var row:Variant=preload("res://scripts/save_json.gd").parse(file.get_line())
  if not row is Dictionary or row.get("label")!="valid":continue
  var actual:String=preload("res://scripts/source_save_validation.gd").error(row.before,state.item_catalog,state.crop_catalog,state.content.scenes,state.content,state.system_catalog,state.world_village)
  print("VALID_ACTUAL: ",actual," EXPECTED: ",row.error)
  print("COLLECTION: ",JSON.stringify(row.before.get("collection")))
  print("FEEDBACK: ",JSON.stringify(row.before.get("feedback")))
  print("APPEARANCE: ",JSON.stringify(row.before.get("appearance")))
  print("UI: ",JSON.stringify(row.before.get("uiArt")))
  print("FX: ",JSON.stringify(row.before.get("visualFx")))
  break
 await root.get_node("AudioService").prepare_exit()
 quit()
