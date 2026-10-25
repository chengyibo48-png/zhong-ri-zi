extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
 if ok: passed += 1
 else: failed += 1; push_error(label)
func same(a: Variant, b: Variant) -> bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size(): return false
  for key in b:
   if not a.has(key) or not same(a[key],b[key]): return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size(): return false
  for i in range(a.size()):
   if not same(a[i],b[i]): return false
  return true
 return a==b
func run():
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
 var file=FileAccess.open(OS.get_environment("INTERIOR_INSPECT_FIXTURE"),FileAccess.READ)
 if file==null: quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var row:Dictionary=JSON.parse_string(line)
  var label:=str(row.house)+"/"+str(row.point.id)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"load "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  var feedback_before:Dictionary=state.feedback_action_snapshot(row.point)
  check(state.inspect_interior_point(row.point)==bool(row.result.ok) and state.message==str(row.result.msg),"original outcome "+label)
  check(same(state.interior_state.memories,row.expected.memories),"original first/repeat memories "+label)
  check(same(state.relations,row.expected.relations),"original relationships including owner null "+label)
  check(not state.relations.has("<null>"),"no phantom public owner "+label)
  check(same(state.journal_entries(),row.expected.journal),"original ordered journal limit "+label)
  check(same(state.legacy_systems.eventLog,row.expected.eventLog),"original event log limit "+label)
  check(same(state.feedback_action_runtime.get("stories",[]),row.expected.bubbles),"complete original authored story feedback "+label)
  if row.result.ok:state.finish_action_feedback(feedback_before,row.point,{"kind":"inspect","label":"看看旧物"})
  var after:Dictionary=state._make_save_data()
  for key in ["inventory","quality","money","stamina","minutes","animals","ranch","farm","plots","building","marriage"]:
   check(same(before[key],after[key]),"unrelated state "+key+" "+label)
  state.tick_feedback_floats(0.1)
  if row.result.ok:check(state.feedback_action_runtime.stories.size()==1,"story remains visible "+label)
  for frame in range(41):state.tick_feedback_floats(0.1)
  check(state.feedback_action_runtime.get("stories",[]).is_empty(),"story expires after original four seconds "+label)
 print("INTERIOR_INSPECT_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
