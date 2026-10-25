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
	state._reset_animals()
	_check(state.crop_profile("rice").preferred == "wetland" and state.crop_profile("carrot").preferred == "sand" and state.crop_profile("cabbage").preferred == "humus", "作物土质偏好与水分阈值")
	state.day = 0
	state.plots[0] = state._new_plot()
	state.plots[0].tilled = true
	state.inventory["bean_heirloom"] = 4
	state.set_farm_seed_kind("heirloom")
	state.set_farm_density("dense")
	state.selected_seed = "bean"
	state.selected_tool = "seed"
	var seed_before := int(state.inventory["bean_heirloom"])
	state.farm_plot_action(0)
	_check(int(state.inventory["bean_heirloom"]) == seed_before - 2 and str(state.plots[0].seed_kind) == "heirloom" and str(state.plots[0].density) == "dense", "乡传良种密植扣两粒并写入田块")
	_check(state.crop_compatibility("bean", "cabbage") == 1 and state.crop_compatibility("cabbage", "radish") == 1 and state.crop_compatibility("cabbage", "lettuce") == -1, "豆科互利、根叶搭配与同科竞争关系")
	state.set_farm_seed_kind("seasonal")
	_check(state.seed_variant_id("bean") == "bean_seasonal", "当前种子类型解析到对应物品")
	state.day = 0
	state.relations["qiao"].points = 0
	state.money = 500
	state.buy_item("cabbage_heirloom", 1)
	_check(int(state.inventory["cabbage_heirloom"]) == 0 and state.money == 500, "未解锁时不能购买乡传良种")
	state.day = 14
	state.buy_item("cabbage_heirloom", 1)
	_check(int(state.inventory["cabbage_heirloom"]) == 1 and state.money < 500, "春十五后开放乡传良种购买")
	state.plots[1] = state._new_plot()
	state.plots[1].tilled = true
	state.inventory["compost"] = 2
	state.money = 500
	state.change_plot_soil(1, "sand")
	_check(str(state.plots[1].soil_type) == "sand" and int(state.inventory["compost"]) == 0, "开垦后的空田更换土质消耗堆肥")
	state.money = 500
	state.inventory["cabbage_heirloom"] = 0
	state.inventory["cabbageSeed"] = 0
	state.quality["cabbage"] = [0, 0, 0]
	state.plots[2] = state._new_plot()
	state.plots[2].crop = "cabbage"
	state.plots[2].growth = state.crop_days("cabbage")
	state.plots[2].fertility = 100
	state.plots[2].health = 100
	state.plots[2].condition = 100.0
	state.plots[2].soil_type = "humus"
	state.plots[2].seed_kind = "normal"
	state.plots[2].ripe_days = 0
	state._harvest_plot(2)
	_check(int(state.quality["cabbage"][1]) == 2 and int(state.quality["cabbage"][2]) == 0, "普通种品质上限为上品")
	state.plots[3] = state._new_plot()
	state.plots[3].crop = "cabbage"
	state.plots[3].growth = state.crop_days("cabbage")
	state.plots[3].fertility = 100
	state.plots[3].health = 100
	state.plots[3].condition = 100.0
	state.plots[3].soil_type = "humus"
	state.plots[3].seed_kind = "heirloom"
	state.plots[3].ripe_days = 0
	state.farm.autoSeed = true
	state._harvest_plot(3)
	_check(int(state.quality["cabbage"][2]) == 2 and int(state.inventory["cabbage_heirloom"]) == 1, "乡传良种可达珍品并自动留种")
	var path := SMOKE_FILES.create_path("migration_farming_profile_smoke")
	state.save_game(path)
	var loaded = load("res://scripts/game_state.gd").new()
	loaded._load_content()
	loaded._load_initial_state()
	var read_back: bool = loaded.load_game(path)
	_check(read_back and str(loaded.farm.get("seedKind", "")) == "seasonal" and str(loaded.plots[1].get("soil_type", "")) == "sand" and bool(loaded.farm.autoSeed), "原生存档读回种子、土质与留种设置")
	var old_file := FileAccess.open(path, FileAccess.READ)
	var old_save: Dictionary = JSON.parse_string(old_file.get_as_text())
	old_file.close()
	old_save.version = 12
	for plot in old_save.plots:
		for key in ["soil_type", "seed_kind", "density", "companion", "fallow", "removed"]:
			plot.erase(key)
	var rewrite := FileAccess.open(path, FileAccess.WRITE)
	rewrite.store_string(JSON.stringify(old_save))
	rewrite.close()
	var migrated = load("res://scripts/game_state.gd").new()
	migrated._load_content()
	migrated._load_initial_state()
	var old_read: bool = migrated.load_game(path)
	_check(old_read and str(migrated.plots[1].soil_type) == "sand" and str(migrated.plots[3].seed_kind) == "heirloom", "v12 旧田块从 farm.beds 迁移土质与种子类型")
	SMOKE_FILES.remove(path)
	print("Farming profile migration: %d passed, %d failed" % [passed, failed])
	state.free()
	loaded.free()
	migrated.free()
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
