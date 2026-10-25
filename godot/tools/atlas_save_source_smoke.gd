extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
const JS=preload("res://scripts/js_string.gd")
var passed := 0
var failed := 0
var cases := 0
var accepted := 0
var rejected := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
 if ok: passed+=1
 else:
  failed+=1
  if failed<=30: push_error("FAIL "+label)
func compare(actual: Variant,expected: Variant,label: String) -> void:
 if JS.is_string(actual) or JS.is_string(expected):
  check(JS.equal(actual,expected),label+" exact UTF-16")
 elif actual is Dictionary and expected is Dictionary:
  check(actual.size()==expected.size(),label+" fields")
  for field in expected:
   check(actual.has(field),label+"/"+str(field)+" exists")
   if actual.has(field): compare(actual[field],expected[field],label+"/"+str(field))
 elif actual is Array and expected is Array:
  check(actual.size()==expected.size(),label+" length")
  for i in range(mini(actual.size(),expected.size())): compare(actual[i],expected[i],label+"/"+str(i))
 elif (actual is int or actual is float) and (expected is int or expected is float): check(float(actual)==float(expected),label+" exact")
 else: check(typeof(actual)==typeof(expected) and actual==expected,label+" value")
func _run() -> void:
 var state=root.get_node("GameState")
 state.set_process(false)
 var path:=OS.get_environment("ATLAS_SAVE_FIXTURE")
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 var base:Dictionary=state._make_save_data().duplicate(true)
 while not file.eof_reached():
  var line:=file.get_line()
  if line.is_empty(): continue
  var row:Dictionary=SAVE_JSON.parse(line)
  check(state.load_game_data(base),"clean baseline")
  state.year_review_pending=true
  var previous:Dictionary=state._make_save_data().duplicate(true)
  var input:Dictionary=state.convert_external_save(row.before)
  var input_copy:Dictionary=input.duplicate(true)
  var ok:bool=state.load_game_data(input)
  check(ok==bool(row.ok),str(row.label)+" acceptance")
  compare(input,input_copy,str(row.label)+" caller unchanged")
  if ok:
   accepted+=1
   compare(state.atlas,row.expected,str(row.label)+" saved atlas")
   compare(state.atlas_scope(),row.scope,str(row.label)+" source scope")
   var save_path:="user://atlas-rule-roundtrip.json"
   check(state.save_game(save_path,true),str(row.label)+" actual file save")
   check(state.load_game(save_path),str(row.label)+" actual file load")
   compare(state.atlas,row.expected,str(row.label)+" file roundtrip")
  else:
   rejected+=1
   compare(state._make_save_data(),previous,str(row.label)+" live state unchanged")
   check(state.year_review_pending,str(row.label)+" pending flag unchanged")
   check(state.message==preload("res://scripts/atlas_rules.gd").ERROR_MESSAGE,str(row.label)+" source rejection message")
  cases+=1
 # Invalid primary saves must recover from a valid backup without touching it.
 check(state.load_game_data(base),"backup baseline")
 var backup_expected:Dictionary=state.atlas.duplicate(true)
 var recovery:="user://atlas-recovery.json"
 check(state.save_game(recovery,true),"write primary baseline")
 check(state.save_game(recovery,true),"produce actual atomic backup")
 var backup_text:=FileAccess.get_file_as_string(recovery+".bak")
 var corrupt:Dictionary=state._make_save_data().duplicate(true)
 corrupt.atlas.pins=[{"id":"pin-bad","x":2831,"y":1652,"label":"坏标记"}]
 var bad_file:=FileAccess.open(recovery,FileAccess.WRITE)
 bad_file.store_string(SAVE_JSON.encode(corrupt))
 bad_file.close()
 check(state.load_game(recovery),"invalid atlas primary recovers backup")
 compare(state.atlas,backup_expected,"recovered atlas")
 check(FileAccess.get_file_as_string(recovery+".bak")==backup_text,"recovery preserves backup bytes")
 check(state.message=="主存档无法读取，已从最近一次有效存档恢复。","recovery feedback")
 # Visit records the house's region, even while local coordinates resemble another region.
 state.atlas.visited=[]
 state.current_interior="home-granny"
 state.player_position=Vector2(480,570)
 state.atlas_visit()
 compare(state.atlas.visited,["farm"],"room visit region")
 state.current_interior=""
 state.player_position=Vector2(500,570)
 state.atlas_visit()
 state.atlas_visit()
 compare(state.atlas.visited,["farm","mountain"],"outdoor visit and dedup")
 var counts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
 check(cases==int(counts.cases),"case total")
 check(accepted==int(counts.accepted),"accepted total")
 check(rejected==int(counts.rejected),"rejected total")
 await root.get_node("AudioService").prepare_exit()
 print("Atlas source save: %d cases (%d accepted, %d rejected), %d passed, %d failed" % [cases,accepted,rejected,passed,failed])
 quit(1 if failed else 0)
