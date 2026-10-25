extends SceneTree

const SMOKE_FILES := preload("res://tools/smoke_files.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_browser_save(1, 1, "farm", 200.0, 100.0, Vector2(2600.0, 1540.0), false)
	_check_browser_save(2, 2, "river", 700.0, 300.0, Vector2(700.0, 2604.0), true)
	_check_browser_save(3, 3, "farm", 4173.0, 1596.0, Vector2(2253.0, 2748.0), true)
	_check_import_transaction()
	_check_sparse_inventory()
	print("Browser save migration: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check_browser_save(version: int, world_revision: int, scene: String, x: float, y: float, expected_position: Vector2, include_discovered: bool) -> void:
	var source := _legacy_fixture(version, world_revision, scene, x, y, include_discovered)
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	var converted: Dictionary = state.convert_external_save(source)
	_check(not converted.is_empty(), "浏览器 v%d 存档能转换" % version)
	if converted.is_empty():
		state.free()
		return
	_check(converted.get("legacy_archive", {}) == source, "浏览器 v%d 完整原档随转换结果保留" % version)
	var loaded: bool = state.load_game_data(converted)
	_check(loaded, "浏览器 v%d 转换结果能进入原生状态" % version)
	if loaded:
		_check(state.player_position.is_equal_approx(expected_position) and state.player_direction == "left", "浏览器 v%d 地图坐标与朝向按地图修订号换算" % version)
		_check(int(state.inventory.get("cabbageSeed", 0)) == 7 and int(state.inventory.get("rice", 0)) == 4, "浏览器 v%d 背包物品与种子别名保留" % version)
		_check(state.plots.size() == 72 and str(state.plots[0].get("crop", "")) == "cabbage" and int(state.plots[0].get("repeats", 0)) == 2, "浏览器 v%d 旧田块扩展并保留作物与轮作记录" % version)
		_check(int(state.animals[0].get("ready", 0)) == 3 and int(state.animals[0].get("qualityStock", [0])[0]) == 3, "浏览器 v%d 动物待收产物转为可读的品质库存" % version)
		_check(state.legacy_systems.get("discovered", []).has("cabbageSeed"), "浏览器 v%d 旧发现条目和下划线种子别名归一化" % version)
		_check(bool(state.legacy_systems.get("toolUpgrades", {}).get("hoe", false)) and int(state.legacy_systems.get("buffs", {}).get("laborDay", -1)) == 16, "浏览器 v%d 农具改良与劳动增益导入" % version)
		_check(int(state.legacy_systems.get("waterReserve", 0)) == 2 and bool(state.legacy_systems.get("greenhouse", false)), "浏览器 v%d 蓄水和温室旧字段导入" % version)
		_check(int(state.legacy_systems.get("animalCare", {}).get("hen-pet", -1)) == 12 and int(state.legacy_systems.get("resourcePressure", {}).get("bamboo", {}).get("count", 0)) == 3, "浏览器 v%d 动物照料与区域采集压力导入" % version)
		_check(not state.legacy_systems.get("eventLog", []).is_empty() and state.legacy_archive == source, "浏览器 v%d 事件记录与原始 JSON 可继续写回" % version)
	state.free()

func _check_import_transaction() -> void:
	var save_path := SMOKE_FILES.create_path("browser_import_save")
	var recovery_path := SMOKE_FILES.create_path("browser_import_recovery")
	var backup_path := SMOKE_FILES.create_path("browser_import_backup")
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state._reset_plots()
	state._reset_animals()
	state.day = 7
	state.money = 777
	state.save_game(save_path)
	var source:Dictionary = JSON.parse_string(JSON.stringify(_legacy_fixture(1, 1, "farm", 200.0, 100.0, false)))
	var imported: bool = state._import_external_save_to_paths(source, save_path, recovery_path, backup_path)
	_check(imported, "浏览器导入流程先留回退与备份，再写入原生存档")
	var loaded = load("res://scripts/game_state.gd").new()
	loaded._load_content()
	loaded._load_initial_state()
	var import_read_back: bool = loaded.load_game(save_path)
	_check(import_read_back and int(loaded.money) == 4321 and _same_json(loaded.legacy_archive, source), "写入后的自动档可读回完整导入进度与原档副本")
	var recovery = load("res://scripts/game_state.gd").new()
	recovery._load_content()
	recovery._load_initial_state()
	var recovery_read_back: bool = recovery.load_game(recovery_path)
	_check(recovery_read_back and int(recovery.money) == 777 and int(recovery.day) == 7, "导入前回退档保留原本进度")
	var backup = load("res://scripts/game_state.gd").new()
	backup._load_content()
	backup._load_initial_state()
	var backup_read_back: bool = backup.load_game(backup_path)
	_check(backup_read_back and int(backup.money) == 777 and int(backup.day) == 7, "导入前备份保留原本进度")
	var failed_path := SMOKE_FILES.create_path("missing-directory/browser_import_failure")
	var failed_import: bool = state._import_external_save_to_paths(source, failed_path, recovery_path, backup_path)
	_check(not failed_import and int(state.money) == 4321, "磁盘写入失败时拒绝报告为导入成功")
	state.money = 777
	state.day = 7
	var rollback_import: bool = state._import_external_save_to_paths(source, failed_path, recovery_path, backup_path)
	_check(not rollback_import and int(state.money) == 777 and int(state.day) == 7, "新存档落盘失败时恢复内存中的导入前状态")
	for path in [save_path, recovery_path, backup_path]:
		SMOKE_FILES.remove(path)
	state.free()
	loaded.free()
	recovery.free()
	backup.free()

func _legacy_fixture(version: int, world_revision: int, scene: String, x: float, y: float, include_discovered: bool) -> Dictionary:
	var plots: Array = []
	for index in range(24):
		plots.append({"tilled": index < 8, "crop": "cabbage" if index == 0 else null, "growth": 4.0 if index == 0 else 0.0, "watered": index == 0, "soil": 2, "lastGroup": "叶菜" if index == 0 else null, "repeats": 2 if index == 0 else 0})
	var source := {
		"version": version,
		"name": "迁移测试",
		"gender": "女",
		"day": 18,
		"minutes": 720,
		"stamina": 61,
		"money": 4321,
		"scene": scene,
		"player": {"x": x, "y": y, "direction": "left"},
		"seed": "bean",
		"bag": {"cabbage_seed": 7, "rice": 4, "wood": 3},
		"plots": plots,
		"animals": [{"id": "hen", "name": "点点", "ready": 3, "fed": false, "bond": 16}],
		"relations": {"granny": {"points": 42, "talked": 17, "gifted": 16, "returnGift": true}},
		"flags": {"bridge": true, "firstDish": true},
		"upgrades": {"greenhouse": true},
		"stats": {"harvested": 8, "fish": 3, "earned": 980},
		"collected": {"bamboo-1": 4},
		"festivals": ["1-0"],
		"processing": [{"id": "pickles", "qty": 2, "readyDay": 19}],
		"toolUpgrades": {"hoe": true},
		"buffs": {"laborDay": 16},
		"waterReserve": 2,
		"greenhouse": true,
		"animalCare": {"hen-pet": 12},
		"resourcePressure": {"bamboo": {"day": 18, "count": 3}},
		"marketDays": [{"day": 15, "demand": {"rice": 5}}],
		"eventLog": [{"day": 17, "text": "旧版生活记录"}]
	}
	if world_revision > 1:
		source["worldRevision"] = world_revision
	if include_discovered:
		source["discovered"] = ["cabbage_seed", "wildHerb"]
	return source

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func _same_json(left: Variant, right: Variant) -> bool:
	var left_json := JSON.stringify(JSON.parse_string(JSON.stringify(left)))
	var right_json := JSON.stringify(JSON.parse_string(JSON.stringify(right)))
	return left_json == right_json

func _check_sparse_inventory() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	_check(int(state._new_inventory().get("cabbageSeed",0))==8,"新游戏仍保留初始物资")
	state.load_game_data(state.convert_external_save(_legacy_fixture(3,3,"farm",4173.0,1596.0,true)))
	var save: Dictionary = state._make_save_data()
	save.inventory = {"rice":5}
	save.quality = {}
	_check(state.load_game_data(save),"原生稀疏背包可以读入")
	_check(int(state.inventory.get("rice",0))==5 and int(state.inventory.get("cabbageSeed",0))==0 and int(state.inventory.get("feed",0))==0 and int(state.inventory.get("egg",0))==0,"原生读档不补发已用完初始物资")
	var source := _legacy_fixture(3,3,"farm",4173.0,1596.0,true)
	source.bag = {}
	source.quality = {}
	_check(state.load_game_data(state.convert_external_save(source)),"原版空背包可以导入")
	_check(state.inventory.values().all(func(n): return int(n)==0),"原版空背包导入保持空库存")
	state.free()
