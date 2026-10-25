extends SceneTree
const VIEW=preload("res://scripts/npc_story_view.gd")
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
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NPC_STORY_FIXTURE")))
 state.day=10;state.minutes=600;state.current_interior="";state.player_position=Vector2(2831,1652)
 for row in fixture.rows:
  var id:=str(row.id)
  state.npc_stories[id]=row.story.duplicate(true);state.relations[id].points=int(row.points)
  state.marriage.spouse=str(row.spouse);state.partners[id]=str(row.partner)
  state.inventory=row.bag.duplicate(true)
  state.npc_positions[id]=Vector2(2912,1652) if row.mode=="far" else Vector2(2831,1652)
  state.npc_residents[id]={"x":2912 if row.mode=="far" else 2831,"y":1652,"room":null}
  var before:Dictionary=state._make_save_data()
  var actual:=VIEW.describe(state,id)
  for field in row.expected:
   check(actual[field]==row.expected[field],id+"/"+str(row.step)+"/"+str(row.mode)+"/"+field+" actual="+str(actual[field])+" expected="+str(row.expected[field]))
  check(state._make_save_data()==before,"story view readonly")
 print("NPC story source: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
