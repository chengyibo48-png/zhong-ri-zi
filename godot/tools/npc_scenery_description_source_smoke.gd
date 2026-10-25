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
 var state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NPC_SCENERY_DESCRIPTION_FIXTURE"))))
 var samples:=0
 for row in fixture.rows:
  state.day=int(row.day);state.minutes=float(row.get("minutes",450))
  if row.kind=="npc":
   state.npc_residents=row.residents.duplicate(true)
   state._normalize_neighbors(row.neighbors)
   state.collection=row.collection.duplicate(true)
   state.community_projects=row.projects.duplicate(true)
   for sample in row.samples:state.npc_movement.actors[sample.p.id]={"walking":bool(row.walking)}
  var before:Dictionary=state._make_save_data().duplicate(true)
  for sample in row.samples:
   var actual:Dictionary=DESCRIBE.describe(state,sample.p)
   for field in ["name","verb","state","reason","detail","ready"]:
    check(actual.get(field)==sample.expected[field],row.kind+"/"+str(row.day)+"/"+str(sample.p.id)+" "+field+" got "+str(actual.get(field))+" expected "+str(sample.expected[field]))
   samples+=1
  check(state._make_save_data()==before,"read-only "+row.kind+" description")
 check(fixture.rows.size()==200,"112 scenery days and 88 NPC contexts")
 await root.get_node("AudioService").prepare_exit()
 print("NPC_SCENERY_DESCRIPTION_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",samples," descriptions")
 quit(0 if failed==0 else 1)
