extends SceneTree
const M=preload("res://scripts/js_navigation_math.gd")
const CODEC=preload("res://scripts/save_json.gd")
func _initialize():call_deferred("_run")
func _run():
 var state=root.get_node("GameState");state.set_process(false)
 var input=CODEC.parse(FileAccess.get_file_as_string(OS.get_environment("NAVIGATION_ANGLE_FIXTURE")))
 if not input is Dictionary:
  await root.get_node("AudioService").prepare_exit();quit(1);return
 var passed:=0
 var failed:=0
 for row in input.rows:
  var x:float=Marshalls.base64_to_raw(row.x).decode_double(0) if row.get("bytes",false) else float(row.x)
  var y:float=Marshalls.base64_to_raw(row.y).decode_double(0) if row.get("bytes",false) else float(row.y)
  var result:=PackedByteArray();result.resize(8);result.encode_double(0,M.angle(y,x))
  var expected:=PackedByteArray();expected.resize(8)
  if row.get("bytes",false):expected=Marshalls.base64_to_raw(row.result)
  else:expected.encode_double(0,float(row.result))
  if result==expected:passed+=1
  else:failed+=1;push_error("Angle mismatch "+str(x)+","+str(y))
 await root.get_node("AudioService").prepare_exit()
 print("Original navigation angles passed=",passed," failed=",failed)
 print("NAVIGATION_ANGLE_SOURCE_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
