extends SceneTree

const SMOKE_FILES := preload("res://tools/smoke_files.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state._reset_plots()
	state.inventory = state._new_inventory()
	state.farm = state.initial_state.get("farm", {}).duplicate(true)
	state._normalize_farm()
	state.inventory["wood"] = 30
	state.inventory["bamboo"] = 30
	state.money = 3000
	state.manage_farm_facility(7, "sprinkler", "build")
	_check(state.farm.facilities.size() == 1 and state.money == 2930, "建造竹管喷灌并扣除材料")
	_check(state.farm_facility_coverage(7, "sprinkler") and state.farm_facility_indices(7, "sprinkler").size() > 1, "设施范围覆盖相邻田格")
	state.fill_farm_water()
	_check(int(state.farm.water) == 120, "水箱可补满并设上限")
	state.manage_farm_facility(7, "sprinkler", "toggle")
	_check(not state.farm_facility_coverage(7, "sprinkler") and state.farm_facility_status(state.farm.facilities[0]) == "暂停", "暂停设施后覆盖效果关闭")
	state.manage_farm_facility(7, "sprinkler", "toggle")
	state.manage_farm_facility(7, "sprinkler", "upgrade")
	_check(int(state.farm.facilities[0].level) == 1 and state.farm_facility_indices(7, "sprinkler").size() > 4, "加固提升覆盖半径")
	state.manage_farm_facility(7, "sprinkler", "move", 10)
	_check(int(state.farm.facilities[0].anchor) == 10, "搬迁保留设施状态")
	state.farm.facilities[0].durability = 70.0
	state.manage_farm_facility(10, "sprinkler", "repair")
	_check(is_equal_approx(float(state.farm.facilities[0].durability), 100.0), "维修恢复设施耐久")
	state.manage_farm_facility(10, "sprinkler", "recover")
	_check(state.farm.facilities.is_empty() and state.farm.stock.size() == 1, "收纳保留升级和耐久")
	state.manage_farm_facility(12, "sprinkler", "build")
	_check(state.farm.facilities.size() == 1 and state.farm.stock.is_empty() and int(state.farm.facilities[0].level) == 1, "重放库存设施无损保留改良")
	state.set_farm_threshold(99)
	_check(int(state.farm.threshold) == 65, "自动灌溉阈值限制在有效范围")
	state.day = 20
	state.plots[12].tilled = true
	state.plots[12].crop = "cabbage"
	state.plots[12].growth = 0.0
	state.plots[12].moisture = 5
	state.farm.water = 10
	state._advance_farm(19)
	_check(int(state.farm.water) < 10 and int(state.plots[12].moisture) == 65 and int(state.plots[12].irrigated) == 20, "日结算按覆盖作物消耗储水并灌溉")
	var path := SMOKE_FILES.create_path("migration_farm_facility_smoke")
	state.save_game(path)
	var loaded = load("res://scripts/game_state.gd").new()
	loaded._load_content()
	loaded._load_initial_state()
	var read_back: bool = loaded.load_game(path)
	_check(read_back and loaded.farm.facilities.size() == 1 and int(loaded.farm.facilities[0].level) == 1 and loaded.farm.stock.is_empty(), "原生存档读回设施、加固和储水状态")
	SMOKE_FILES.remove(path)
	print("Farm facility migration: %d passed, %d failed" % [passed, failed])
	state.free()
	loaded.free()
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
