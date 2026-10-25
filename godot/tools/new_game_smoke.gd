extends SceneTree

const FILES := preload("res://tools/smoke_files.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		push_error("新生活验证需隔离临时 APPDATA。")
		quit(1)
		return
	create_timer(45.0).timeout.connect(func(): push_error("New game smoke timed out"); quit(1))
	var state = root.get_node("GameState")
	state.day = 55
	state.money = 987
	state.inventory.rice = 99
	state.upgrades.room = true
	state.flags["old_progress"] = true
	state.legacy_archive = {"marker": "old"}
	state.walking_target = {"id": "walk", "x": 2900, "y": 1652}
	var previous: Dictionary = state._make_save_data().duplicate(true)
	var auto_path := FILES.create_path("new_game_auto")
	var backup_path := FILES.create_path("new_game_backup")
	state._write_json_atomically(auto_path, previous)
	var previous_bytes := FileAccess.get_file_as_string(auto_path)
	var invalid_backup := backup_path.path_join("missing").path_join("save.json")
	_check(not state._start_new_game_to_paths(auto_path, invalid_backup) and state.day == 55 and state.money == 987 and not state.walking_target.is_empty() and FileAccess.get_file_as_string(auto_path) == previous_bytes, "备份写入失败时不更改当前日子或自动档")
	DirAccess.make_dir_absolute(auto_path + ".tmp")
	_check(not state._start_new_game_to_paths(auto_path, backup_path) and state.day == 55 and state.inventory.rice == 99 and not state.walking_target.is_empty() and FileAccess.get_file_as_string(auto_path) == previous_bytes, "新档落盘失败时保留进度、导航和原自动档")
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(backup_path))
	_check(backup is Dictionary and int(backup.day) == 55 and int(backup.money) == 987 and backup.legacy_archive.marker == "old", "失败后仍有可读取的当前进度备份")
	DirAccess.remove_absolute(auto_path + ".tmp")
	_check(state._start_new_game_to_paths(auto_path, backup_path), "完整写入后才开始新生活")
	_check(state.day == int(state.initial_state.day) and state.money == int(state.initial_state.money) and state.inventory.rice != 99 and not state.flags.has("old_progress") and state.legacy_archive.is_empty(), "新生活重新载入初始日期、钱物和记录")
	_check(state.plots.size() == state.initial_state.plots.size() and state.animals.size() == state.initial_state.animals.size() and state.current_interior == "" and not state.riding and state.walking_target.is_empty(), "农田动物和室内骑行导航状态均重置")
	_check(int(state.skills.farming.xp) == 0 and state.year_plans.is_empty() and state.marriage.spouse == "" and not bool(state.flags.godot_onboarding.hidden), "手艺、关系和年度计划重置并恢复新手手记")
	var new_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(auto_path))
	_check(int(new_disk.day) == 0 and not new_disk.flags.has("old_progress"), "自动档实际写入新的进度")
	backup = JSON.parse_string(FileAccess.get_file_as_string(backup_path))
	_check(int(backup.day) == 55 and int(backup.inventory.rice) == 99, "新生活保留开始前完整备份")
	FILES.remove(auto_path)
	FILES.remove(backup_path)
	state.day = 12
	state.money = 777
	var manual_bytes: Array[String] = []
	for slot in range(1, 4):
		var path := "user://zhenrizhi_godot_slot_%d.json" % slot
		state.save_game(path)
		manual_bytes.append(FileAccess.get_file_as_string(path))
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var panel = load("res://scripts/save_panel.gd").new()
	world.add_child(panel)
	panel.open_panel()
	panel._request_new_game()
	_check(panel.new_game_confirmation.visible and panel.new_game_confirmation.extra_button.visible and state.day == 12 and state.money == 777, "确认页提供导出入口，打开页面不重置进度")
	panel.new_game_confirmation.cancel_button.pressed.emit()
	_check(panel.visible and state.ui_open and not panel.new_game_confirmation.visible and state.day == 12, "取消后留在现有存档簿与生活")
	panel._request_new_game()
	panel.new_game_confirmation.confirm_button.pressed.emit()
	for frame in range(5): await process_frame
	_check(state.day == 0 and current_scene != world and current_scene.scene_file_path == "res://scenes/main.tscn" and not state.ui_open, "确认后切换到新的原生农场场景")
	var unchanged := true
	for slot in range(1, 4):
		unchanged = unchanged and FileAccess.get_file_as_string("user://zhenrizhi_godot_slot_%d.json" % slot) == manual_bytes[slot - 1]
	_check(unchanged, "三份手动档逐字保留")
	backup = JSON.parse_string(FileAccess.get_file_as_string("user://zhenrizhi_godot_backup.json"))
	_check(int(backup.day) == 12 and int(backup.money) == 777, "实际界面重开生活前保留原进度备份")
	print("New game migration: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
