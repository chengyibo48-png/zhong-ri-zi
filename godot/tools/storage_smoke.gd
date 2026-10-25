extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state.inventory = state._new_inventory()
	state._reset_plots()
	state._normalize_building(null)
	state.inventory["rice"] = 12
	state.quality["rice"] = [2, 1, 0]
	state.kitchen.lots.bag["rice"] = [{"qty": 12, "age": 4.0}]
	state.inventory["cabbageSeed"] = 8
	state.inventory["wood"] = 9
	state.inventory["feed"] = 7
	state.inventory["egg"] = 3
	_check(not state.sort_building_storage("food"), "粮仓未改良时拒绝分类周转")
	state.building.levels.granary = 1
	state.upgrades.storage = true
	_check(state.sort_building_storage("food"), "粮仓一阶可批量存入食材")
	_check(int(state.inventory.get("rice", 0)) == 5 and int(state.storage.get("rice", 0)) == 7, "批量存入为每种物品保留 5 份随身余量")
	_check(state._storage_quality_counts("rice") == [7, 0, 0, 0], "批量周转保留各批品质分布")
	_check(is_equal_approx(float(state.food_freshness("rice", 7, "storage").age), 4.0), "批量周转保留食材陈放年龄")
	_check(not state.sort_building_storage("seed", true), "粮仓一阶不能一键取回")
	_check(state.sort_building_storage("seed") and int(state.inventory.get("cabbageSeed", 0)) == 5, "种子分类只整理种子并保留五份")
	_check(state.sort_building_storage("feed") and int(state.inventory.get("feed", 0)) == 5, "牧场补给分类独立周转")
	_check(state.sort_building_storage("material") and int(state.inventory.get("wood", 0)) == 5, "建设材料分类独立周转")
	_check(int(state.inventory.get("egg", 0)) == 3, "少于随身余量的食品不会被搬走")
	state.building.levels.granary = 2
	state.building.modes.granary = "supply"
	state.inventory["rice"] = int(state.inventory.get("rice", 0)) - 2
	_check(state.sort_building_storage("food", true), "二阶周转补给开放一键取回")
	_check(int(state.inventory.get("rice", 0)) == 5 and int(state.storage.get("rice", 0)) == 5, "取回只补到五份随身余量且不搬空粮仓")
	_check(state._quality_counts("rice") == [2, 2, 1, 0], "取回继续保留品质分布")
	state.free()
	print("Building storage migration: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
