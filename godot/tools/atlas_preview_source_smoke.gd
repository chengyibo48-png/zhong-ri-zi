extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
const JS=preload("res://scripts/js_string.gd")
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error("FAIL "+label)
func same(a:Variant,b:Variant,path:String) -> void:
 if a is Dictionary and b is Dictionary:
  check(a.size()==b.size(),path+" field count")
  for key in b:
   check(a.has(key),path+" key "+str(key))
   if a.has(key):same(a[key],b[key],path+"/"+str(key))
 elif a is Array and b is Array:
  check(a.size()==b.size(),path+" array length")
  for i in range(mini(a.size(),b.size())):same(a[i],b[i],path+"/"+str(i))
 elif JS.is_string(a) or JS.is_string(b):check(JS.equal(a,b),path+" text")
 else:check(a==b,path+" value "+str(a)+" expected "+str(b))
func _run() -> void:
 var state=root.get_node("GameState");state.set_process(false)
 var file:=FileAccess.open(OS.get_environment("ATLAS_PREVIEW_FIXTURE"),FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit();quit(1);return
 var cases:=0
 while not file.eof_reached():
  var line:=file.get_line()
  if line.is_empty():continue
  var row:Dictionary=CODEC.parse(line)
  # The source probes run directly on a valid base state, without another load normalization.
  var seed:Dictionary=row.state.duplicate(true)
  var room:Variant=seed.village.interior
  seed.village.interior=null
  seed.player={"x":2831,"y":1652,"direction":"down"}
  check(state.load_game_data(state.convert_external_save(seed)),"base loaded")
  state.current_interior="" if room==null else str(room)
  state.riding=bool(row.state.village.riding)
  var actual:Dictionary=state.atlas_preview(row.target,row.state.player)
  for key in ["reachable","points","room_points","next"]:actual.erase(key)
  same(actual,row.expected,"case "+str(cases))
  cases+=1
 await root.get_node("AudioService").prepare_exit()
 print("Original atlas preview cases=",cases," passed=",passed," failed=",failed)
 print("ATLAS_PREVIEW_SOURCE_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
