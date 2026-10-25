extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state := root.get_node("GameState")
	state.set_process(false)
	var data: Dictionary = state._make_save_data().duplicate(true)
	var schema := preload("res://scripts/native_save_schema.gd")
	print("TREE: ",schema.safe_tree(data))
	print("BAD TREE: ",find_bad(data,"root"))
	print("SCHEMA: ",schema.error(data,state.initial_state))
	print("RELATION: ",data.relations.granny)
	await root.get_node("AudioService").prepare_exit()
	quit(0)
func find_bad(value: Variant, path: String) -> String:
	var text := preload("res://scripts/js_string.gd")
	if value is Dictionary:
		for key: Variant in value:
			if not text.is_string(key): return path + ": key type " + type_string(typeof(key)) + " " + str(key)
			var bad := find_bad(value[key],path + "." + str(key))
			if not bad.is_empty(): return bad
	elif value is Array:
		for i: int in range(value.size()):
			var bad := find_bad(value[i],"%s[%d]" % [path,i])
			if not bad.is_empty(): return bad
	elif not (value == null or value is bool or value is int or value is float or text.is_string(value)):
		return path + ": " + type_string(typeof(value))
	return ""
