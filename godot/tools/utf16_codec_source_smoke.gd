extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
const JS=preload("res://scripts/js_string.gd")
var passed:=0
var failed:=0
var cases:=0
var groups:Dictionary={}
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:
  failed+=1
  if failed<=25:push_error("FAIL "+label)
func signature(value:Variant) -> Dictionary:
 if JS.is_string(value):
  var result:Array=[]
  for unit in JS.units(value):result.append(unit)
  return {"string":result}
 if value is Array:
  var result:Array=[]
  for child in value:result.append(signature(child))
  return {"array":result}
 if value is Dictionary:
  var result:Array=[]
  for key in value:
   var key_units:Array=[]
   for unit in JS.units(key):key_units.append(unit)
   result.append({"key":key_units,"value":signature(value[key])})
  return {"object":result}
 if value is int or value is float:
  var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,float(value))
  return {"number":Marshalls.raw_to_base64(bytes)}
 return {"literal":value}
func compare(actual:Variant,expected:Variant,label:String) -> void:
 if actual is Dictionary and expected is Dictionary:
  check(actual.size()==expected.size(),label+" fields")
  for key in expected:
   check(actual.has(key),label+" key")
   if actual.has(key):compare(actual[key],expected[key],label+"/"+str(key))
 elif actual is Array and expected is Array:
  check(actual.size()==expected.size(),label+" length")
  for i in range(mini(actual.size(),expected.size())):compare(actual[i],expected[i],label+"/"+str(i))
 elif (actual is int or actual is float) and (expected is int or expected is float):check(float(actual)==float(expected),label+" number")
 else:check(typeof(actual)==typeof(expected) and actual==expected,label+" value")
func _run() -> void:
 var state=root.get_node("GameState")
 state.set_process(false)
 var base:Dictionary=state._make_save_data().duplicate(true)
 var path:=OS.get_environment("UTF16_CODEC_FIXTURE")
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 while not file.eof_reached():
  var line:=file.get_line()
  if line.is_empty():continue
  var row:Dictionary=JSON.parse_string(line)
  var data:Variant=CODEC.parse(str(row.raw))
  compare(signature(data),row.expected,str(row.label)+" parse exact code units/binary64")
  var encoded:String=CODEC.encode(data)
  compare(signature(CODEC.parse(encoded)),row.expected,str(row.label)+" reversible JSON")
  var count:int=int(groups.get(row.group,0))
  if row.group=="unit" and count>=0xd800 and count<=0xdfff and count%64==0:
   var saved:Dictionary=base.duplicate(true)
   saved.atlas={"version":1,"visited":["farm"],"pins":[{"id":"pin-1","x":2831.125,"y":1652.75,"label":data.text}],"nextId":2,"tracking":{"id":null,"x":2831.125,"y":1652.75,"name":data.text},"layer":"pins","minimap":false}
   check(state.load_game_data(saved),str(row.label)+" native loader")
   check(state.save_game("user://utf16-file.json",true),str(row.label)+" actual file write")
   check(state.load_game("user://utf16-file.json"),str(row.label)+" actual file load")
   check(JS.equal(state.atlas.pins[0].label,data.text),str(row.label)+" label file units")
   check(JS.equal(state.atlas.tracking.name,data.text),str(row.label)+" tracking file units")
   check(state.atlas.pins[0].x==2831.125 and state.atlas.pins[0].y==1652.75,str(row.label)+" coordinates file exact")
  groups[row.group]=count+1
  cases+=1
 var original:Variant=JS.from_units(PackedInt32Array([0xd800]))
 var exposed:PackedInt32Array=JS.units(original);exposed[0]=97
 check(JS.units(original)[0]==0xd800,"immutable units copy")
 check(not JS.equal(original,String.chr(0xfffd)),"raw surrogate differs from literal replacement")
 check(JS.length(JS.from_units(PackedInt32Array([0])))==1,"NUL is one preserved code unit")
 var counts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
 check(cases==int(counts.cases),"case count")
 check(int(groups.get("unit",0))==int(counts.units),"all 65536 code units")
 check(int(groups.get("pair",0))==int(counts.pairs),"valid pair count")
 check(int(groups.get("keys",0))==int(counts.keys),"unpaired key count")
 await root.get_node("AudioService").prepare_exit()
 print("UTF-16 JSON source: %d cases %s; %d passed, %d failed" % [cases,JSON.stringify(groups),passed,failed])
 quit(1 if failed else 0)
