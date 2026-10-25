extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := OS.get_environment("BROWSER_SAVE_FILE")
	var state := root.get_node("GameState")
	state.set_process(false)
	var parsed:Variant=preload("res://scripts/save_json.gd").parse(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:push_error("Browser download is invalid JSON");quit(1);return
	var decoded:Dictionary=preload("res://scripts/save_json.gd").decode(parsed.duplicate(true))
	if not state._import_external_save_to_paths(parsed,"user://browser-import.json","user://browser-recovery.json","user://browser-backup.json"):
		push_error("Actual browser export cannot be imported natively: "+state.message);quit(1);return
	var items_equal := true
	for item in decoded.inventory:
		if int(state.inventory.get(item,0)) != int(decoded.inventory[item]):items_equal=false
	for item in state.inventory:
		if int(state.inventory[item]) != int(decoded.inventory.get(item,0)):items_equal=false
	if state.day != decoded.day or state.money != decoded.money or not items_equal:
		push_error("Browser-to-native progress mismatch");quit(1);return
	if not state.save_game("user://browser-roundtrip.json",true) or not state.load_game("user://browser-roundtrip.json"):
		push_error("Browser import cannot roundtrip on native");quit(1);return
	print("BROWSER_SAVE_ROUNDTRIP: 4 passed, 0 failed")
	await root.get_node("AudioService").prepare_exit();quit(0)
