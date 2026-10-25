extends RefCounted
## Restore from an immutable, validated target before touching recovery files.
const STORE := preload("res://scripts/save_repository.gd")
static func restore(state: Node, path: String) -> Dictionary:
	var target: Dictionary = {}
	var recovered := false
	for candidate: String in [path, path + ".bak"]:
		var parsed: Variant = STORE.read(STORE.absolute(candidate))
		if parsed is Dictionary:
			target = state.convert_external_save(parsed)
			if not target.is_empty():
				recovered = candidate != path
				break
	if target.is_empty(): return {"ok":false,"message":"这份存档无法读取；当前进度和回退档未改动。"}
	var previous: Dictionary = state._make_save_data().duplicate(true)
	var recovery := "user://zhenrizhi_godot_recovery.json"
	if STORE.absolute(path) == STORE.absolute(recovery): recovery = "user://zhenrizhi_godot_backup.json"
	if not STORE.write(recovery, previous): return {"ok":false,"message":"保护当前进度失败，没有切换存档。"}
	if not state.load_game_data(target): return {"ok":false,"message":"存档验证失败，当前进度未切换。"}
	if recovered and STORE.absolute(path) == STORE.absolute(state.SAVE_PATH): state._recovered_save_path = STORE.absolute(path)
	if not state.save_game(state.SAVE_PATH,true):
		state.load_game_data(previous)
		return {"ok":false,"message":"新进度写入失败，已恢复当前进度，保护档仍保留。"}
	return {"ok":true,"message":"已读取存档；此前进度保存在%s。" % ("操作前备份" if recovery.ends_with("backup.json") else "读取前回退档")}
