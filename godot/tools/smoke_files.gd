extends RefCounted

static func create_path(prefix: String) -> String:
	var filename := "%s_%d.json" % [prefix, Time.get_ticks_usec()]
	var smoke_dir := OS.get_environment("MIGRATION_SMOKE_DIR")
	if smoke_dir.is_empty():
		return "user://" + filename
	DirAccess.make_dir_recursive_absolute(smoke_dir)
	return smoke_dir.path_join(filename)

static func remove(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
	for candidate in [absolute_path, absolute_path + ".tmp", absolute_path + ".bak", absolute_path + ".failed"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
