extends SceneTree

const SMOKE_FILES := preload("res://tools/smoke_files.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first_state = _new_state()
	var path := SMOKE_FILES.create_path("migration_atomic_save")
	first_state.money = 111
	_check(first_state.save_game(path), "首次存档成功写入")
	first_state.money = 222
	_check(first_state.save_game(path), "重复存档通过临时文件提交")
	_check(_read_money(path) == 222 and _read_money(path + ".bak") == 111, "重复存档保留上一份有效版本")
	_write_text(path, "{invalid")
	var recovered = _new_state()
	var did_recover: bool = recovered.load_game(path)
	_check(did_recover and recovered.money == 111, "损坏的主档自动回退到最近有效版本")
	recovered.money = 333
	_check(recovered.save_game(path), "从回退档恢复后可以继续保存")
	_check(_read_money(path) == 333 and _read_money(path + ".bak") == 111, "修复主档时保留已恢复的有效备份")
	var damaged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	damaged["_float64_roundtrip"] = {"version": 1, "entries": [{"path": ["missing"], "bytes": "AAAAAAAAAAA="}]}
	_write_text(path, JSON.stringify(damaged))
	var precision_recovered = _new_state()
	_check(precision_recovered.load_game(path) and precision_recovered.money == 111, "损坏精度数据同样回退有效备份")
	_check(not precision_recovered._read_save_json(path) is Dictionary, "无效精度数据不会部分进入游戏状态")
	precision_recovered.free()
	var missing_dir_path := SMOKE_FILES.create_path("missing-directory/atomic_failure")
	var rejected: bool = first_state.save_game(missing_dir_path)
	_check(not rejected and not FileAccess.file_exists(missing_dir_path + ".tmp"), "目标目录不可写时拒绝成功并清理临时文件")
	for target in [path, missing_dir_path]:
		SMOKE_FILES.remove(target)
	first_state.free()
	recovered.free()
	print("Atomic save migration: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _new_state():
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state.inventory = state._new_inventory()
	state.storage = {}
	state.storage_quality = {}
	state._reset_plots()
	state._reset_animals()
	return state

func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "测试可写入损坏样本")
		return
	file.store_string(contents)
	file.close()
	_check(true, "测试可写入损坏样本")

func _read_money(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return int(parsed.get("money", -1)) if parsed is Dictionary else -1

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)
