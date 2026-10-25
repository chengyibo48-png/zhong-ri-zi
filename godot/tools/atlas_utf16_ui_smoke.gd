extends SceneTree
const JS=preload("res://scripts/js_string.gd")
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func _initialize() -> void:
 root.size=Vector2i(960,600)
 call_deferred("_run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error("FAIL "+label)
func _run() -> void:
 var state=root.get_node("GameState")
 state.set_process(false)
 var file:=FileAccess.open(OS.get_environment("ATLAS_PIN_FIXTURE"),FileAccess.READ)
 if file==null:
  await root.get_node("AudioService").prepare_exit()
  quit(1)
  return
 var row:Dictionary=CODEC.parse(file.get_line())
 var source:Dictionary=row.states[0].duplicate(true)
 check(state.load_game_data(state.convert_external_save(source)),"valid source loaded")
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world);current_scene=world
 world.set_process(false);world.player.set_physics_process(false)
 await process_frame
 world.hud.show_map()
 var map=world.hud.map_panel
 var full_name:="a".repeat(17)+"😀"
 var short_name:Variant=JS.prefix(full_name,18)
 map.custom_target={"x":2831.499999999,"y":1652.499999999,"name":full_name}
 map.selected_id=""
 map._refresh_detail()
 await process_frame
 await process_frame
 print("Layout root=",root.size," viewport=",root.get_visible_rect()," field=",map.pin_name_box.get_global_rect())
 check(root.get_visible_rect().size==Vector2(960,600),"logical canvas is exactly 960x600")
 check(root.get_visible_rect().encloses(map.pin_name_box.get_global_rect()),"pin name field fully inside 960x600 viewport")
 check(map.detail_label.text.contains("沿路约 1 秒"),"near map target preview has source minimum one second")
 var plan:Dictionary=world.player.preview_walk(map.custom_target)
 check(plan.path.back().y==1657.499999999,"real player map plan retains exact source target y+5")
 check(map.pin_name_box.text=="a".repeat(17)+String.chr(0xfffd),"source default name displays substituted glyph")
 check(JS.equal(map.p_in_name(),short_name),"untouched default retains original high surrogate")
 map.pin_button.pressed.emit()
 check(state.atlas.pins.size()==1,"actual pin button adds one")
 check(state.atlas.pins[0].x==2831 and state.atlas.pins[0].y==1652,"actual button keeps binary64 rounding boundary")
 check(JS.equal(state.atlas.pins[0].label,short_name),"actual button exact UTF16 slice")
 var stored:Dictionary=state._read_save_json(state.SAVE_PATH)
 check(JS.equal(stored.atlas.pins[0].label,short_name),"pin button saves actual original code units")
 map.custom_target.clear();map.selected_id="pin-1";map.refresh()
 check(map.detail_label.text.contains("a".repeat(17)+String.chr(0xfffd)),"real detail displays raw name")
 map.track_button.pressed.emit()
 check(JS.equal(state.atlas.tracking.name,short_name),"tracking preserves raw name")
 check(state.load_game(state.SAVE_PATH),"reload actual tracked pin")
 check(JS.equal(state.atlas.tracking.name,short_name),"tracked name restored")
 map.refresh()
 map.pin_name_box.text="a".repeat(17)+String.chr(0xfffd)
 map.pin_name_box.text_changed.emit(map.pin_name_box.text)
 check(JS.equal(map.p_in_name(),"a".repeat(17)+String.chr(0xfffd)),"explicit edited replacement becomes literal")
 map.pin_button.pressed.emit()
 check(state.atlas.pins.size()==2,"second actual pin added")
 check(not JS.equal(state.atlas.pins[0].label,state.atlas.pins[1].label),"source surrogate and literal replacement remain distinct")
 # The source leaves the pin action available at its limit so it can explain the failure.
 for i in range(3,13):state.atlas.pins.append({"id":"pin-"+str(i),"x":2831,"y":1652,"label":"记号"})
 state.atlas.nextId=13
 map.refresh()
 check(not map.pin_button.disabled,"pin limit leaves feedback action available")
 map.pin_button.pressed.emit()
 check(state.message=="手绘标记最多十二个，先擦去不需要的标记。","actual limit feedback")
 # Import and export go through the real SavePanel JSON file selection callback.
 world.hud.close_top_panel()
 source.atlas={"version":1,"visited":["farm"],"pins":[{"id":"pin-1","x":2831.125,"y":1652.75,"label":short_name}],"nextId":2,"tracking":{"id":null,"name":short_name,"x":2831.125,"y":1652.75},"layer":"pins","minimap":false}
 var import_path:=ProjectSettings.globalize_path("user://browser-utf16-import.json")
 var import_file:=FileAccess.open(import_path,FileAccess.WRITE)
 import_file.store_string(CODEC.encode(source));import_file.close()
 world.hud.show_saves()
 var panel=world.hud.save_panel
 panel.file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
 panel._file_selected(import_path)
 check(JS.equal(state.atlas.pins[0].label,short_name),"actual import callback accepts browser raw surrogate")
 check(JS.equal(state.atlas.tracking.name,short_name),"actual import preserves raw tracking")
 var recovery:Dictionary=state._read_save_json("user://zhenrizhi_godot_recovery.json")
 check(recovery is Dictionary and recovery.atlas.pins.size()==12,"import creates previous progress recovery")
 await process_frame
 await process_frame
 world=current_scene
 world.set_process(false);world.player.set_physics_process(false)
 world.hud.show_saves()
 panel=world.hud.save_panel
 var export_path:=ProjectSettings.globalize_path("user://godot-utf16-export.json")
 panel.file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 panel._file_selected(export_path)
 var exported:Dictionary=CODEC.parse(FileAccess.get_file_as_string(export_path))
 check(JS.equal(exported.atlas.pins[0].label,short_name),"actual export preserves source code units")
 check(exported.atlas.pins[0].x==2831.125 and exported.atlas.pins[0].y==1652.75,"actual export exact coordinates")
 check(FileAccess.get_file_as_string(export_path).contains("\\ud83d"),"export is raw JSON escape, not object text")
 check(panel._summary(export_path)!="文件损坏","save summary reads raw UTF16 file")
 current_scene=null;world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("UTF16 actual map and save UI: %d passed, %d failed" % [passed,failed])
 quit(1 if failed else 0)
