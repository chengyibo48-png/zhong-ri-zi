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
	if target.is_empty(): return {"ok":false,"message":"这份存档无效或属于旧任务版本；原文件、当前进度和回退档未改动。"}
	var previous: Dictionary = state._make_save_data().duplicate(true)
	var recovery := "user://saves/v38/zhenrizhi_godot_recovery.json"
	if STORE.absolute(path) == STORE.absolute(recovery): recovery = "user://saves/v38/zhenrizhi_godot_backup.json"
	if not STORE.write(recovery, previous): return {"ok":false,"message":"保护当前进度失败，没有切换存档。"}
	if not state.load_game_data(target): return {"ok":false,"message":"存档验证失败，当前进度未切换。"}
	if recovered and STORE.absolute(path) == STORE.absolute(state.SAVE_PATH): state._recovered_save_path = STORE.absolute(path)
	if not state.save_game(state.SAVE_PATH,false):
		state.load_game_data(previous)
		return {"ok":false,"message":"新进度写入失败，已恢复当前进度，保护档仍保留。"}
	return {"ok":true,"message":"已读取存档；此前进度保存在%s。" % ("操作前备份" if recovery.ends_with("backup.json") else "读取前回退档")}

static func _write(state:Node,path:String,snapshot:Dictionary)->bool:
	var result:Array=[false,false]
	state.autosave_coordinator.commit(snapshot,func(ok:bool):result[0]=true;result[1]=ok,path)
	while not bool(result[0]):await state.get_tree().process_frame
	return bool(result[1])
static func restore_async(state:Node,path:String)->Dictionary:
	await state.wait_for_saves()
	var target:Dictionary={};var recovered:bool=false
	for candidate:String in [path,path+".bak"]:
		var parsed:Variant=STORE.read(STORE.absolute(candidate))
		if parsed is Dictionary:
			target=state.convert_external_save(parsed)
			if not target.is_empty():recovered=candidate!=path;break
	if target.is_empty():return {"ok":false,"message":"这份存档无效或属于旧循环；原文件和当前进度未改动。"}
	var recovery:String="user://saves/v38/zhenrizhi_godot_recovery.json"
	if STORE.absolute(path)==STORE.absolute(recovery):recovery="user://saves/v38/zhenrizhi_godot_backup.json"
	if not await _write(state,recovery,state._make_save_data().duplicate(true)):return {"ok":false,"message":"未能保护当前进度，读取取消。"}
	if not await _write(state,state.SAVE_PATH,target.duplicate(true)):return {"ok":false,"message":"目标存档未写入成功，当前进度保持原样。"}
	state.transactions.publishing=true
	var ok:bool=state.load_game_data(target)
	state.transactions.publishing=false
	if recovered and ok:state._recovered_save_path=STORE.absolute(state.SAVE_PATH)
	return {"ok":ok,"message":"已读取；此前进度保存在读取前回退档。" if ok else "目标未通过载入校验。"}
