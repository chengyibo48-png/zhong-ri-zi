extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
func json(v:Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BUILDING_CONFIG_FIXTURE")))
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"source config import")
  var ok:=false
  if row.op=="configure":
   # Preserve exact operation input; import may normalize fields unrelated to this operation.
   state.legacy_systems.discovered=row.before.discovered.duplicate()
   ok=state.configure_building(str(row.id),row.value)
  elif row.op=="mode":ok=state.set_building_mode(str(row.id),str(row.value))
  else:ok=state.transfer_storage(str(row.id),int(row.value),true)
  check(ok==bool(row.result.ok) and state.message==row.result.msg,"source config result "+str(row.op)+"/"+str(row.id))
  check(json(state.building)==row.expected.building,"exact building state including revision")
  if row.op=="storage":
   for id in state.item_catalog:
    check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)) and int(state.storage.get(id,0))==int(row.expected.storage.get(id,0)),"public transfer quantity "+str(id))
   check(json(state.kitchen.lots)==row.expected.lots and json(state.economy)==row.expected.economy,"public transfer preserves freshness and locks")
 print("Building config: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
