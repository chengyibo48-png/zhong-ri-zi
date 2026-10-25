extends RefCounted
## File transaction only. Domain snapshots and schema migrations belong to callers.
const CODEC := preload("res://scripts/save_json.gd")
static func absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	if file.get_length() > preload("res://scripts/native_save_schema.gd").MAX_BYTES:
		file.close()
		return null
	var parsed: Variant = CODEC.parse(file.get_as_text())
	file.close()
	return parsed
static func write(path: String, data: Dictionary, preserve_recovery: bool = false) -> bool:
	if not preload("res://scripts/native_save_schema.gd").safe_tree(data): return false
	var encoded := CODEC.encode(data)
	if encoded.is_empty() or encoded.to_utf8_buffer().size() > preload("res://scripts/native_save_schema.gd").MAX_BYTES: return false
	var target := absolute(path)
	# Identical repeated writes must not rotate away the useful previous version.
	if FileAccess.file_exists(target):
		var existing := FileAccess.open(target,FileAccess.READ)
		if existing != null:
			var equal := existing.get_length() == encoded.to_utf8_buffer().size() and existing.get_as_text() == encoded
			existing.close()
			if equal and FileAccess.file_exists(target+".bak"): return true
	var temporary := target+".tmp"
	var displaced := target+(".failed" if preserve_recovery else ".bak")
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_string(encoded);file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return false
	var exists := FileAccess.file_exists(target)
	if exists:
		if FileAccess.file_exists(displaced) and DirAccess.remove_absolute(displaced) != OK:
			DirAccess.remove_absolute(temporary);return false
		if DirAccess.rename_absolute(target,displaced) != OK:
			DirAccess.remove_absolute(temporary);return false
	if DirAccess.rename_absolute(temporary,target) != OK:
		if exists and not FileAccess.file_exists(target): DirAccess.rename_absolute(displaced,target)
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
		return false
	if preserve_recovery and exists and FileAccess.file_exists(displaced): DirAccess.remove_absolute(displaced)
	return true
