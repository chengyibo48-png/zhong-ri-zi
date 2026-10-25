extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1;push_error(label)
func run() -> void:
	await process_frame
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
	var state:=root.get_node("GameState");state.set_process(false)
	var baseline: Dictionary=state._make_save_data().duplicate(true)
	var panel: Control=load("res://scripts/save_panel.gd").new();root.add_child(panel)
	var recovery: String=panel.SLOT_PATHS.recovery
	state.money=222;check(state.save_game(recovery,true),"prepare target")
	state.money=333
	panel._load_slot("recovery")
	check(state.money==222,"actual panel loads the old recovery rather than current progress")
	var store:=preload("res://scripts/save_repository.gd")
	check(int(store.read(recovery).money)==222,"recovery target is not overwritten")
	check(int(store.read(panel.SLOT_PATHS.backup).money)==333,"current progress gets a distinct protection file")
	await process_frame;await process_frame
	state.set_process(false)
	var before: String=FileAccess.get_file_as_string(recovery)
	var broken:=FileAccess.open(panel.SLOT_PATHS.one,FileAccess.WRITE);broken.store_string("broken");broken.close()
	var restored:=preload("res://scripts/save_session.gd").restore(state,panel.SLOT_PATHS.one)
	check(not restored.ok and state.money==222,"invalid slot does not switch memory")
	check(FileAccess.get_file_as_string(recovery)==before,"invalid slot does not overwrite recovery")
	var data: Dictionary=baseline.duplicate(true);data.money=111
	check(store.write("user://same.json",data),"first write")
	data.money=222;check(store.write("user://same.json",data),"second write")
	check(store.write("user://same.json",data) and int(store.read("user://same.json.bak").money)==111,"identical writes preserve the useful previous backup")
	state.load_game_data(baseline)
	panel.file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	panel._file_selected("user://export.json")
	check(store.read("user://export.json") is Dictionary,"actual export reads back")
	var export_before:=FileAccess.get_file_as_string("user://export.json")
	state.legacy_archive={"large":"x".repeat(16*1024*1024)}
	panel._file_selected("user://export.json")
	check(panel.notice.text.contains("失败") and FileAccess.get_file_as_string("user://export.json")==export_before,"oversized export reports failure and preserves destination")
	state.load_game_data(baseline)
	var unicode:= "禾".repeat(6000000)
	panel._import_text(unicode)
	check(panel.notice.text.contains("16 MiB") and state.day==int(baseline.day),"import byte limit handles multibyte text")
	var valid: Dictionary=baseline.duplicate(true);valid.legacy_archive={"padding":"x".repeat(2100000)}
	panel._import_text(preload("res://scripts/save_json.gd").encode(valid))
	check(state.legacy_archive.get("padding","").length()==2100000,"valid export over old two-MB limit imports through actual panel")
	state.load_game_data(baseline)
	var cards:=preload("res://scripts/life_plans.gd").cards(state)
	check(cards.size()==5,"five linked intentions")
	var original: Dictionary=state._make_save_data().duplicate(true)
	for i in range(3): preload("res://scripts/life_plans.gd").cards(state)
	check(state.money==original.money and state.inventory==original.inventory and state.flags==original.flags,"viewing intentions grants no reward or progress")
	var completed: Array[Dictionary]=cards.duplicate(true)
	state.flags.firstDish=true
	check(preload("res://scripts/life_plans.gd").cards(state)[3].done,"intention completion follows existing delivery record")
	state.load_game_data(baseline)
	var clock_calls: Array[int]=[0];state.clock_changed.connect(func():clock_calls[0]+=1)
	state._source_update_tick=1.1;state._advance_frame_time(0.01)
	check(clock_calls[0]==1,"clock has its own view event")
	state.load_game_data(baseline)
	panel.queue_free()
	await process_frame;await process_frame
	if current_scene!=null: current_scene.queue_free()
	await process_frame
	print("Quality safety: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
