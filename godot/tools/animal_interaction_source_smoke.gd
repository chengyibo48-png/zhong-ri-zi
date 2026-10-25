extends SceneTree
const DESCRIBE=preload("res://scripts/interaction_description.gd")
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=20:push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(120).timeout.connect(func():quit(1))
 var state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ANIMAL_INTERACTION_FIXTURE"))))
 for row in fixture.rows:
  state.day=int(row.day);state.minutes=450;state.stamina=int(row.stamina)
  state.animals.assign(row.animals.duplicate(true));state.ranch=row.ranch.duplicate(true);state.inventory=row.bag.duplicate(true)
  state.toolkit=row.toolkit.duplicate(true);state.skills=row.skills.duplicate(true)
  state.legacy_systems.buffs=row.buffs.duplicate(true);state.legacy_systems.toolUpgrades=row.toolUpgrades.duplicate(true)
  state.kitchen=row.kitchen.duplicate(true)
  var before:Dictionary=state._make_save_data().duplicate(true)
  var actual:Dictionary=DESCRIBE.describe(state,row.p)
  var label:String=row.type+"/"+row.breed+"/"+row.feed+"/"+row.variant
  for field in ["name","verb","state","reason","detail","ready"]:
   check(actual.get(field)==row.expected[field],label+" "+field+" got "+str(actual.get(field))+" expected "+str(row.expected[field]))
  check(DESCRIBE.animal_status(state,state.animals[0])==row.status,"ordered full status "+label)
  check(state._make_save_data()==before,"read-only animal description "+label)
 check(fixture.rows.size()==state.system_catalog.ranch.species.size()*state.system_catalog.ranch.breeds.size()*4*25,"all species breed feed variants")
 await root.get_node("AudioService").prepare_exit()
 print("ANIMAL_INTERACTION_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",fixture.rows.size()," descriptions")
 quit(0 if failed==0 else 1)
