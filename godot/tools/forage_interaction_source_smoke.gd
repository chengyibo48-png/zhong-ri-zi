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
 var state=root.get_node("GameState")
 state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FORAGE_INTERACTION_FIXTURE"))))
 for row in fixture.rows:
  state.day=int(row.day)
  state.minutes=450.0
  state.stamina=int(row.stamina)
  state.forage=row.forage.duplicate(true)
  state.toolkit=row.toolkit.duplicate(true)
  state.skills=row.skills.duplicate(true)
  state.legacy_systems.buffs=row.buffs.duplicate(true)
  state.legacy_systems.toolUpgrades=row.toolUpgrades.duplicate(true)
  state.kitchen=row.kitchen.duplicate(true)
  state.gathered=row.collected.duplicate(true)
  var before:Dictionary=state._make_save_data().duplicate(true)
  var actual:Dictionary=DESCRIBE.describe(state,row.p,"hand")
  for field in ["name","verb","state","reason","detail","ready"]:
   check(actual.get(field)==row.expected[field],"forage "+str(row.day)+"/"+row.variant+"/"+row.p.item+" field "+field+" got "+str(actual.get(field))+" expected "+str(row.expected[field]))
  check(state._make_save_data()==before,"read-only forage description")
 check(fixture.rows.size()==112*state.system_catalog.forage.defs.size()*7,"full-year item/variant coverage")
 await root.get_node("AudioService").prepare_exit()
 print("FORAGE_INTERACTION_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",fixture.rows.size()," descriptions")
 quit(0 if failed==0 else 1)
