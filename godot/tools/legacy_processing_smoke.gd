extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_external_conversion()
	_check_native_round_trip_and_completion()
	_check_legacy_archive_fallback()
	_check_rain_delay()
	await _check_processing_ui()
	print("Legacy processing migration: %d passed, %d failed" % [passed, failed])
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

func _check_external_conversion() -> void:
	var state = _new_state()
	var source := {
		"version": 3,
		"day": 18,
		"money": 100,
		"minutes": 720,
		"stamina": 80,
		"scene": "farm",
		"bag": {"mustard": 1},
		"plots": _empty_legacy_plots(),
		"processing": [
			{"id": "pickles", "qty": 2, "readyDay": 19},
			{"id": "compost", "qty": 3, "readyDay": 20, "station": "堆肥箱", "cooking": false, "farmGrade": 1}
		]
	}
	var converted: Dictionary = state.convert_external_save(source)
	_check(int(converted.get("version", 0)) == 31, "浏览器旧档转换到 schema v31")
	_check(converted.get("legacy_processing", []).size() == 2, "转换器把旧加工队列迁入可结算字段")
	_check(converted.get("legacy_archive", {}).get("processing", []) == source.get("processing", []), "原始 processing 仍保存在原档档案")
	var loaded: bool = state.load_game_data(converted)
	_check(loaded and state.legacy_processing.size() == 2, "迁移后的旧工序可以载入原生状态")
	if loaded and state.legacy_processing.size() == 2:
		_check(str(state.legacy_processing[0].station) == "腌菜坛" and bool(state.legacy_processing[0].cooking), "老腌菜条目补全旧版默认工位与烹饪统计")
		_check(not bool(state.legacy_processing[1].cooking) and int(state.legacy_processing[1].farmGrade) == 1, "非烹饪加工与农事品质字段保留")
	state.free()

func _check_native_round_trip_and_completion() -> void:
	var state = _new_state()
	state.day = 18
	state.legacy_processing.clear()
	state.legacy_processing.append({"id": "pickles", "qty": 2, "readyDay": 19, "station": "腌菜坛", "cooking": true, "farmGrade": 2})
	var saved: Dictionary = state._make_save_data()
	_check(int(saved.get("version", 0)) == 31 and saved.get("legacy_processing", []).size() == 1, "schema v31 原生存档明确保存旧加工队列")
	var restored = _new_state()
	var loaded: bool = restored.load_game_data(saved)
	_check(loaded and restored.legacy_processing.size() == 1 and int(restored.legacy_processing[0].farmGrade) == 2, "v31 存档读回队列、到期日和品质")
	if loaded:
		var dry_day := _find_day_with_weather(restored, false)
		restored.day = dry_day + 1
		restored.legacy_processing[0].readyDay = restored.day
		var cooked_before: int = int(restored.player_stats.get("cooked", 0))
		var journal_before: int = restored.player_journal.size()
		restored._advance_legacy_processing(dry_day)
		_check(restored.legacy_processing.is_empty(), "到期工序完成后从等待队列移除")
		_check(int(restored.inventory.get("pickles", 0)) == 2, "到期工序产品自动进入背包")
		_check(int(restored.quality.get("pickles", [0, 0, 0])[1]) == 2, "旧农事品质映射到成品品质账")
		_check(int(restored.player_stats.get("cooked", 0)) == cooked_before + 2, "烹饪型旧工序累计熟食统计")
		_check(restored.player_journal.size() == journal_before + 1, "旧工序完成写入生活记录")
	state.free()
	restored.free()

func _check_legacy_archive_fallback() -> void:
	var state = _new_state()
	var saved: Dictionary = state._make_save_data()
	saved.version = 29
	saved.erase("legacy_processing")
	saved["legacy_archive"] = {"processing": [{"id": "pickles", "qty": 1, "readyDay": 1}]}
	saved.day = 0
	var loaded: bool = state.load_game_data(saved)
	_check(loaded and state.legacy_processing.size() == 1, "v29 档缺少新版字段时从原档档案恢复加工队列")
	state.free()

func _check_rain_delay() -> void:
	var state = _new_state()
	var rain_day := -1
	for candidate in range(0, 112):
		var today := str(state.weather_profile(candidate).kind)
		var tomorrow := str(state.weather_profile(candidate + 1).kind)
		if today in ["雨", "台风"] and tomorrow not in ["雨", "台风"]:
			rain_day = candidate
			break
	_check(rain_day >= 0, "天气表中存在可验证的雨后转晴日期")
	if rain_day >= 0:
		state.day = rain_day + 1
		state.legacy_processing.clear()
		state.legacy_processing.append({"id": "driedMushroom", "qty": 2, "readyDay": state.day, "station": "晾晒架", "cooking": false})
		state._advance_legacy_processing(rain_day)
		_check(state.legacy_processing.size() == 1 and int(state.legacy_processing[0].readyDay) == rain_day + 2, "雨或台风后的晾晒工序顺延一日")
		state.day = rain_day + 2
		state._advance_legacy_processing(rain_day + 1)
		_check(state.legacy_processing.is_empty() and int(state.inventory.get("driedMushroom", 0)) == 2, "雨后转晴的次日完成晾晒并自动入包")
	state.free()

func _check_processing_ui() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	var legacy_queue: Array = game_state.get("legacy_processing")
	legacy_queue.clear()
	legacy_queue.append({"id": "pickles", "qty": 2, "readyDay": int(game_state.get("day")) + 1, "station": "腌菜坛", "cooking": true})
	world.hud.call("show_kitchen", true, "jobs")
	var panel: Control = world.hud.get("kitchen_panel")
	var list: ItemList = panel.get("list")
	_check(list.item_count == 1 and list.get_item_text(0).begins_with("旧工序"), "厨房待收页显示迁入的旧版工序")
	var detail: Label = panel.get("detail_label")
	var action: Button = panel.get("action_button")
	_check(detail.text.contains("旧版工序") and detail.text.contains("自动放入背包"), "旧队列详情说明到期后会自动入包")
	_check(action.disabled and action.text == "到期自动入袋", "旧队列不会误用新版手动收取操作")
	world.hud.call("close_kitchen")
	world.queue_free()
	await process_frame

func _find_day_with_weather(state, rainy: bool) -> int:
	for candidate in range(0, 112):
		var is_rainy := str(state.weather_profile(candidate).kind) in ["雨", "台风"]
		if is_rainy == rainy:
			return candidate
	return 0

func _empty_legacy_plots() -> Array:
	var plots: Array = []
	for _index in range(24):
		plots.append({"tilled": false, "crop": null, "growth": 0, "watered": false, "soil": 2})
	return plots

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)
