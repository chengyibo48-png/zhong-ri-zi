extends SceneTree
const JS=preload("res://scripts/js_string.gd")
var passed:=0
var failed:=0
func _initialize() -> void:
 call_deferred("_run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error("FAIL "+label)
func _run() -> void:
 var file:=FileAccess.open(OS.get_environment("ATLAS_INPUT_BROWSER_FIXTURE"),FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 var envelope:Variant=JSON.parse_string(file.get_as_text())
 if not envelope is Dictionary or not envelope.get("success",false):
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 var rows:Array=envelope.data.result.rows
 check(rows.size()==2109,"all original DOM cases present")
 var state=root.get_node("GameState")
 state.set_process(false)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world);current_scene=world
 world.set_process(false);world.player.set_physics_process(false)
 await process_frame
 world.hud.show_map()
 var map=world.hud.map_panel
 for row in rows:
  var name:Variant=JS.from_units(PackedInt32Array(row.name))
  var expected:=PackedInt32Array(row.expected)
  check(JS.units(JS.html_input_default(name,18))==expected,"source input default "+row.label)
  map.custom_target={"x":2831,"y":1652,"name":name}
  map.selected_id=""
  map._refresh_detail()
  check(JS.units(map.p_in_name())==expected,"actual panel input "+row.label)
  check(map.pin_name_box.text==str(JS.from_units(expected)),"actual visible input "+row.label)
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("ATLAS_INPUT_BROWSER_SOURCE_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
