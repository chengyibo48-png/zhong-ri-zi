extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	var previous_riding := bool(state.riding)
	var previous_interior := str(state.current_interior)
	state.current_interior = ""
	state.riding = false
	_check(state.player_movement_speed() == 195.0 and state.player_movement_speed(true) == 265.0, "步行和 Shift 快走沿用原版速度")
	_check(state.toggle_bicycle() and state.riding and state.player_movement_speed() == 355.0, "户外骑车切换到原版骑行速度")
	_check(state.player_movement_speed(true) == 355.0, "骑车时 Shift 不叠加快走速度")
	state.current_interior = "home-granny"
	_check(not state.toggle_bicycle() and state.riding, "室内不能重新切换骑车状态")
	_check(state.player_movement_speed() == 195.0, "室内始终使用步行速度")
	state.current_interior = ""
	_check(state.toggle_bicycle() and not state.riding, "户外可下车恢复步行")
	var saved: Dictionary = state._make_save_data()
	_check(int(saved.get("version", 0)) == 31 and not bool(saved.get("riding", true)), "schema v31 保存骑行状态")
	saved.riding = true
	var restored = load("res://scripts/game_state.gd").new()
	restored._load_content()
	restored._load_initial_state()
	_check(restored.load_game_data(saved) and restored.riding, "原生存档读回户外骑行状态")
	saved.version = 30
	saved.erase("riding")
	_check(restored.load_game_data(saved) and not restored.riding, "旧 v30 存档缺少骑行字段时默认步行")
	var old_plots: Array = []
	for index in range(24):
		old_plots.append({"tilled": false, "crop": null, "growth": 0, "watered": false, "soil": 2})
	var source := {"version": 3, "bag": {}, "plots": old_plots, "village": {"riding": true}}
	var converted: Dictionary = restored.convert_external_save(source)
	_check(int(converted.get("version", 0)) == 31 and bool(converted.get("riding", false)), "浏览器 v3 骑行状态迁入原生字段")
	state.current_interior = previous_interior
	state.riding = previous_riding
	restored.free()
	print("Bicycle migration: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
