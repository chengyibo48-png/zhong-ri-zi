extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state := root.get_node("GameState")
	state.set_process(false)
	var text := FileAccess.get_file_as_string(OS.get_environment("SCHEMA_INPUT"))
	var rows: Array = JSON.parse_string(text)
	for row: Dictionary in rows:
		var converted: Dictionary = state.convert_external_save(row.before)
		print(row.label,": ",preload("res://scripts/native_save_schema.gd").error(converted,state.initial_state))
	var legacy: RefCounted = load("res://tools/inspect_legacy_fixture.gd").new()
	var old: Dictionary = state.convert_external_save(legacy._legacy_fixture(1,1,"home",480,567,true))
	print("legacy: ",preload("res://scripts/native_save_schema.gd").error(old,state.initial_state))
	await root.get_node("AudioService").prepare_exit()
	quit(0)
