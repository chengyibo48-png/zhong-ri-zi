extends SceneTree
const TEXT = preload("res://scripts/js_string.gd")
const CODEC = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
 if ok:passed += 1
 else:
  failed += 1
  if failed < 15:push_error(label)
func same(a: Variant, b: Variant) -> bool:
 if TEXT.is_string(a) or TEXT.is_string(b):return TEXT.equal(a,b)
 if a is Dictionary and b is Dictionary:
  if a.size() != b.size():return false
  for key in a:
   if not b.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size() != b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if (a is float or a is int) and (b is float or b is int):return float(a)==float(b)
 return a==b
func run() -> void:
 await process_frame
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var state := root.get_node("GameState")
 state.set_process(false)
 var fixture: Dictionary = CODEC.parse(FileAccess.get_file_as_string(OS.get_environment("FEEDBACK_UTF16_FIXTURE")))
 for row in fixture.rows:
  if row.mode == "note":
   state.day = int(row.day)
   state.minutes = float(row.minute)
   state.feedback = row.before.duplicate(true)
   check(same(state._feedback_note(row.data),row.first),"source first note "+str(row.i))
   state.feedback.rows[0].read = true
   state.minutes = 629.25
   check(same(state._feedback_note(row.next),row.second),"source note merge/update "+str(row.i)+"/"+str(row.merge))
   check(same(state.feedback,row.after),"whole UTF16 feedback "+str(row.i))
  else:
   state.day = int(row.before.day);state.minutes = float(row.before.minutes)
   state.feedback = row.before.feedback.duplicate(true)
   state.kitchen = row.before.kitchen.duplicate(true);state.economy = row.before.economy.duplicate(true)
   state.animals.assign(row.before.animals.duplicate(true));state.farm = row.before.farm.duplicate(true)
   state.plots.assign(row.before.plots.duplicate(true))
   for plot in state.plots:
    if plot.crop == null:plot.crop = ""
   state.neighbors = row.before.neighbors.duplicate(true)
   for person in state.neighbors.people.values():
    if person.event == null:person.event = {}
   state._feedback_poll(false)
   check(state._feedback_poll_added.size() == int(row.count),"source poll count")
   check(same(state.feedback,row.after),"source notice hash/token "+str(row.size))
   state._feedback_poll(false)
   check(state._feedback_poll_added.size() == int(row.repeatCount) and same(state.feedback,row.repeatAfter),"value duplicate token "+str(row.size))
  var expected: Dictionary = state.feedback.duplicate(true)
  check(same(state._normalize_feedback(expected),expected),"normalize retains UTF16")
  var encoded: String = CODEC.encode(state._make_save_data())
  check(same(CODEC.parse(encoded).feedback,expected),"JSON retains exact units")
  check(state.save_game(state.SAVE_PATH,true),"actual disk write")
  var saved: Dictionary = CODEC.parse(FileAccess.get_file_as_string(state.SAVE_PATH))
  check(same(saved.feedback,expected),"disk retains exact units")
  check(state.load_game_data(saved),"actual load: "+preload("res://scripts/native_save_schema.gd").error(saved,state.initial_state))
  check(same(state.feedback,expected),"load retains exact units")
 print("Feedback UTF16: %d passed, %d failed" % [passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
