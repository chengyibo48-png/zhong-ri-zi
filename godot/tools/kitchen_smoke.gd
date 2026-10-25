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
	state.inventory = state._new_inventory()
	state.inventory["cabbage"] = 4
	_check(state.known_recipes.has("greens"), "初始已知菜谱读取")
	state.cook_recipe("greens", 1, 50)
	_check(int(state.inventory.get("cabbage", 0)) == 2 and int(state.inventory.get("greens", 0)) == 1, "灶台消耗原料并产出料理")
	_check(int(state.kitchen.get("mastery", {}).get("greens", 0)) == 1, "烹饪熟练度记入厨房状态")
	state.inventory["cabbage"] = 8
	state.cook_recipe("greens", 4)
	_check(state.known_recipes.has("springBowl") and int(state.player_stats.get("cooked", 0)) >= 5, "做过五道菜领会节令试配配方")
	var energy_before: int = state.stamina
	state.cook_recipe("winterMilk")
	_check(state.stamina == energy_before, "反季节令做法不消耗体力")
	state.upgrades.mill = true
	state.inventory["wheat"] = 3
	state.process_recipe("flour", 2)
	var jobs: Array = state.kitchen.get("jobs", [])
	_check(jobs.size() == 1 and int(state.inventory.get("wheat", 0)) == 1 and int(jobs[0].get("qty", 0)) == 4, "加工按批投料并记录产出")
	var job_key := int(jobs[0].get("key", 0))
	state.collect_kitchen_job(job_key)
	_check(int(state.inventory.get("flour", 0)) == 0 and state.kitchen.get("jobs", []).size() == 1, "未完成的加工不能提前收取")
	state.minutes = int(jobs[0].get("ready", 0)) - state.day * 1440
	state.collect_kitchen_job(job_key)
	_check(int(state.inventory.get("flour", 0)) == 4 and state.kitchen.get("jobs", []).is_empty(), "完成后主动收取成品")
	_check(int(state.kitchen.get("mastery", {}).get("flour", 0)) == 1, "加工收取提高熟练度")
	var first_age := float(state.food_freshness("rice").age)
	state._advance_kitchen(50)
	_check(float(state.food_freshness("rice").age) > first_age, "隔日按天气增加食材年龄")
	state.day = 36
	state.minutes = 390
	state.upgrades.yard = true
	state.inventory["mushroom"] = 2
	state.process_recipe("driedMushroom", 1)
	var drying_job: Dictionary = state.kitchen.get("jobs", []).back()
	_check(int(drying_job.ready) > int(drying_job.start) + 1440, "梅雨天晾晒加工延后完成")
	var equipment: Dictionary = state.kitchen.get("equipment", {}).get("dry", {})
	_check(int(equipment.get("clean", 100)) < 100, "加工降低工位清洁度")
	state.clean_kitchen_station("dry")
	_check(int(state.kitchen.get("equipment", {}).get("dry", {}).get("clean", 0)) == 100, "擦洗工位恢复清洁度")
	state.day = 0
	state.minutes = 390
	state.upgrades["kitchen"] = true
	state.inventory["mustard"] = 2
	state.cook_recipe("pickles", 1)
	var pickle_job: Dictionary = state.kitchen.get("jobs", []).back()
	_check(bool(pickle_job.get("cooking", false)) and int(state.inventory.get("pickles", 0)) == 0, "腌菜配方进入隔日队列而非即时出锅")
	var advanced = load("res://scripts/game_state.gd").new()
	advanced._load_content()
	advanced._load_initial_state()
	advanced._reset_plots()
	advanced.inventory = advanced._new_inventory()
	advanced.storage = {}
	advanced.upgrades.storage = true
	advanced.inventory["berry"] = 2
	advanced.quality["berry"] = [2, 0, 0]
	advanced._reconcile_kitchen_lots()
	var berry_lots: Array = advanced.kitchen.get("lots", {}).get("bag", {}).get("berry", [])
	berry_lots[0].age = 3.0
	_check(advanced.transfer_storage("berry", 2, true), "已解锁储物柜可存入食材")
	_check(int(advanced.storage.get("berry", 0)) == 2 and int(advanced.storage_quality.get("berry", [0, 0, 0])[0]) == 2, "存入食橱保留优质库存")
	_check(is_equal_approx(float(advanced.food_freshness("berry", 1, "storage").age), 3.0), "存入食橱保留批次年龄")
	_check(advanced.transfer_storage("berry", 1, false), "已解锁储物柜可取回食材")
	_check(int(advanced.inventory.get("berry", 0)) == 1 and int(advanced.quality.get("berry", [0, 0, 0])[0]) == 1, "取回背包保留优质等级")
	advanced.inventory["bamboo"] = 6
	advanced.build_cold_pantry()
	_check(bool(advanced.kitchen.get("cold", false)) and advanced.money == 30, "阴凉食橱消耗材料与金币")
	var stored_age := float(advanced.food_freshness("berry", 1, "storage").age)
	advanced._advance_kitchen(50)
	_check(is_equal_approx(float(advanced.food_freshness("berry", 1, "storage").age) - stored_age, 0.25), "阴凉储藏按四分之一速度陈放")
	advanced.money = 200
	advanced.inventory["wood"] = 6
	advanced.inventory["bamboo"] = 4
	advanced.upgrade_kitchen_station("stove")
	_check(int(advanced.kitchen.get("equipment", {}).get("stove", {}).get("level", 0)) == 1 and advanced.money == 110, "工位升级增加等级并扣除货币")
	advanced.inventory["wildHerb"] = 1
	advanced.inventory["shoot"] = 1
	advanced.experiment_recipe("wildHerb", "shoot")
	_check(advanced.known_recipes.has("springBowl") and int(advanced.inventory.get("wildHerb", 0)) == 1, "匹配已知配方只领会做法不耗材")
	advanced.inventory["wheat"] = 1
	advanced.inventory["tea"] = 1
	advanced.experiment_recipe("wheat", "tea")
	_check(int(advanced.inventory.get("gardenSoup", 0)) == 1 and advanced.kitchen.get("experiments", []).size() == 1, "新搭配消耗食材并记录田园汤")
	advanced.stamina = 40
	advanced.inventory["summerDrink"] = 1
	advanced.eat_item("summerDrink")
	_check(advanced.kitchen_active_buff() == "轻快" and advanced.travel_speed_multiplier() > 1.0, "食用轻快料理提高移动速度")
	advanced.inventory["winterMilk"] = 1
	advanced.stamina = 40
	advanced.eat_item("winterMilk")
	var stamina_before: int = advanced.stamina
	advanced.spend_energy(3, 0)
	_check(advanced.kitchen_active_buff() == "暖胃" and advanced.stamina == stamina_before - 2, "暖胃料理降低劳动体力消耗")
	var save_path := SMOKE_FILES.create_path("migration_kitchen_smoke")
	advanced.save_game(save_path)
	var loaded = load("res://scripts/game_state.gd").new()
	loaded._load_content()
	var read_back: bool = loaded.load_game(save_path)
	_check(read_back and int(loaded.storage.get("berry", 0)) == 1 and bool(loaded.kitchen.get("cold", false)), "原生存档写入并读回储物与食橱")
	_check(read_back and loaded.known_recipes.has("springBowl") and int(loaded.kitchen.get("equipment", {}).get("stove", {}).get("level", 0)) == 1, "读档保留菜谱与工位升级")
	_check(read_back and loaded.kitchen_active_buff() == "暖胃" and loaded.kitchen.get("experiments", []).size() == 1, "读档保留料理增益和试配手札")
	SMOKE_FILES.remove(save_path)
	print("Kitchen migration: %d passed, %d failed" % [passed, failed])
	state.free()
	advanced.free()
	loaded.free()
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
