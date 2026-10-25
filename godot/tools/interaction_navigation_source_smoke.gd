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
 var file:=FileAccess.open(OS.get_environment("INTERACTION_NAVIGATION_FIXTURE"),FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit();quit(1);return
 var header:Dictionary=CODEC.parse(file.get_line())
 var index:=-1
 var cases:=0
 while not file.eof_reached():
  var line:=file.get_line()
  if line.is_empty():continue
  var row:Dictionary=CODEC.parse(line)
  var source:Dictionary=header.states[int(row.index)]
  if int(row.index)!=index:
   index=int(row.index)
   var seed:Dictionary=source.duplicate(true)
   seed.village.interior=null;seed.player={"x":2831,"y":1652,"direction":"down"}
   check(state.load_game_data(state.convert_external_save(seed)),"base loaded")
   state.current_interior="" if source.village.interior==null else str(source.village.interior)
   var navigation=preload("res://scripts/npc_navigation.gd").new()
   navigation.refresh(state)
   for probe in header.geometry[index].probes:
    check(navigation.blocked(state,state.current_interior,probe.x,probe.y)==probe.blocked,"source blocker boundary index "+str(index))
  var result:Dictionary=state.interaction_route(row.target,source.player,state.current_interior)
  same(result.stand,row.stand,"case "+str(cases)+" stand")
  same(result.path,row.path,"case "+str(cases)+" path")
  check(result.reachable==not row.path.is_empty(),"exact reachable")
  cases+=1
 await root.get_node("AudioService").prepare_exit()
 print("Original interaction navigation cases=",cases," passed=",passed," failed=",failed)
 print("INTERACTION_NAVIGATION_SOURCE_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
