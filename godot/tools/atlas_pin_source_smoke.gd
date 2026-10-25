extends SceneTree
const CODEC = preload("res://scripts/save_json.gd")
const JS = preload("res://scripts/js_string.gd")
var passed:=0
var failed:=0
var active_kind:="setup"
var fail_kinds:Dictionary={}
var number_failures:=0
var counts:Dictionary={"pin":0,"remove":0,"number":0}
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:
  failed+=1
  fail_kinds[active_kind]=int(fail_kinds.get(active_kind,0))+1
  if failed<=30:push_error("FAIL "+label)
func compare(actual:Variant,expected:Variant,label:String) -> void:
 if JS.is_string(actual) or JS.is_string(expected):
  check(JS.equal(actual,expected),label+" exact UTF-16")
 elif actual is Dictionary and expected is Dictionary:
  check(actual.size()==expected.size(),label+" fields")
  for key in expected:
   check(actual.has(key),label+" key "+str(key))
   if actual.has(key):compare(actual[key],expected[key],label+"/"+str(key))
 elif actual is Array and expected is Array:
  check(actual.size()==expected.size(),label+" length")
  for i in range(mini(actual.size(),expected.size())):compare(actual[i],expected[i],label+"/"+str(i))
 elif (actual is int or actual is float) and (expected is int or expected is float):check(float(actual)==float(expected),label+" exact number")
 else:check(typeof(actual)==typeof(expected) and actual==expected,label+" value")
func coordinate(value:Dictionary) -> Variant:
 if value.has("value"):return value.value
 return NAN if value.special=="NaN" else INF if value.special=="Infinity" else -INF
func _run() -> void:
 var state=root.get_node("GameState")
 state.set_process(false)
 var path:=OS.get_environment("ATLAS_PIN_FIXTURE")
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 var states:Array=[]
 var active:=-1
 var index:=0
 while not file.eof_reached():
  var line:=file.get_line()
  if line.is_empty():continue
  var parsed:Variant=CODEC.parse(line)
  check(parsed is Dictionary,"fixture parsed "+str(index))
  if not parsed is Dictionary:
   await root.get_node("AudioService").prepare_exit()
   quit(1)
   return
  var row:Dictionary=parsed
  if row.kind=="states":states=row.states;continue
  active_kind=str(row.kind)
  var label:=str(index)+"/"+str(row.kind)
  if row.kind=="number":
   var actual_number:=JS.number_text(Marshalls.base64_to_raw(row.bytes).decode_double(0))
   if actual_number!=str(row.expected):
    number_failures+=1
    if number_failures<=10: print("NUMBER MISMATCH actual=",actual_number," expected=",row.expected)
   check(actual_number==str(row.expected),label+" ECMAScript number "+str(row.expected))
  else:
   if active!=int(row.state):
    check(state.load_game_data(state.convert_external_save(states[int(row.state)])),label+" source state")
    compare(state.building.layout,states[int(row.state)].building.layout,label+" exact obstacle layout")
    active=int(row.state)
   state.atlas=row.before.duplicate(true)
   if row.kind=="pin":
    var result:Dictionary=state.atlas_pin_coordinates(coordinate(row.x),coordinate(row.y),row.label)
    compare(result,row.result,label+" transaction")
    check(state.message==str(row.result.msg),label+" feedback")
   else:state.atlas_remove_pin(row.id)
   compare(state.atlas,row.after,label+" full atlas")
   if index%53==0:
    var raw:=CODEC.encode({"atlas":state.atlas})
    var restored:Dictionary=CODEC.parse(raw)
    compare(restored.atlas,row.after,label+" raw JSON roundtrip")
   if row.kind=="pin" and bool(row.result.ok):
    var found:Dictionary={}
    for target in state.atlas_targets():
     if target.get("id")==row.result.pin.id:found=target;break
    check(not found.is_empty(),label+" new pin target")
    if not found.is_empty():compare(found.name,row.result.pin.label,label+" target label preserves UTF-16")
  counts[row.kind]=int(counts[row.kind])+1
  index+=1
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
 check(states.size()==int(expected.states),"state count")
 check(int(counts.pin)==int(expected.pins),"pin count")
 check(int(counts.remove)==int(expected.removes),"remove count")
 check(int(counts.number)==int(expected.numbers),"number count")
 check(index==int(expected.total),"total count")
 await root.get_node("AudioService").prepare_exit()
 print("Failure categories ",JSON.stringify(fail_kinds))
 print("Source atlas pin: %s; %d passed, %d failed" % [JSON.stringify(counts),passed,failed])
 quit(1 if failed else 0)
