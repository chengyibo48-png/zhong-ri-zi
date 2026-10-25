extends SceneTree
const JS=preload("res://scripts/js_string.gd")
var passed:=0
var failed:=0
var cases:=0
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 root.get_node("GameState").set_process(false)
 var path:=OS.get_environment("ATLAS_PIN_FIXTURE")
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 while not file.eof_reached():
  var line:=file.get_line()
  if line.is_empty():continue
  if not line.contains('"kind":"number"'):continue
  var row:Dictionary=JSON.parse_string(line)
  var actual:=JS.number_text(Marshalls.base64_to_raw(row.bytes).decode_double(0))
  if actual==str(row.expected):passed+=1
  else:
   failed+=1
   if failed<=20:push_error("Number actual="+actual+" expected="+str(row.expected))
  cases+=1
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
 if cases==int(expected.numbers):passed+=1
 else:failed+=1
 await root.get_node("AudioService").prepare_exit()
 print("ECMAScript exact number: %d cases, %d passed, %d failed" % [cases,passed,failed])
 quit(1 if failed else 0)
