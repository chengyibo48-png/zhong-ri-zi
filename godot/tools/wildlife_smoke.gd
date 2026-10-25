extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state.inventory = state._new_inventory()
	state.day = 4
	var rainy: Dictionary = state.forage_status("mushroom-1", "mushroom")
	_check(bool(rainy.ready) and int(rainy.bonus) == 1 and int(rainy.quantity) == 3, "雨后菌床增加一份")
	state.gather_node("mushroom-1", "mushroom")
	_check(int(state.inventory.get("mushroom", 0)) == 3 and int(state.forage.get("xp", 0)) == 1, "轻采结算数量与经历")
	_check(int(state.forage_status("mushroom-1", "mushroom").wait) == 2, "采后按物种天数再生")
	state.gather_node("mushroom-1", "mushroom")
	_check(int(state.inventory.get("mushroom", 0)) == 3, "未恢复的同一采集点不能重复获得物品")
	state.inventory["compost"] = 1
	state.care_forage("mushroom-1", "mushroom")
	_check(int(state.inventory.get("compost", 0)) == 0 and int(state.forage_status("mushroom-1", "mushroom").wait) == 1, "覆土消耗堆肥并提前恢复")
	state.day = 5
	_check(bool(state.forage_status("mushroom-1", "mushroom").ready), "提前恢复后次日可采")
	state.toggle_forage_mode()
	state.gather_node("mushroom-1", "mushroom")
	_check(int(state.inventory.get("mushroom", 0)) == 6 and int(state.forage_status("mushroom-1", "mushroom").wait) == 4, "多采多得一份且增加两天休养")
	state.day = 46
	_check(not bool(state.forage_status("drift-wood", "wood", "storm").ready), "漂木不在台风当天开放")
	state.day = 47
	_check(bool(state.forage_status("drift-wood", "wood", "storm").ready) and int(state.forage_status("drift-wood", "wood", "storm").bonus) == 1, "台风后漂木开放并增加产量")
	state.day = 0
	_check(not bool(state.forage_status("mist-tea", "tea", "mist").ready), "雾茶只在雾天开放")
	state.day = 5
	_check(bool(state.forage_status("mist-tea", "tea", "mist").ready), "雾天可采茶梢")
	var fishing_catalog: Dictionary = state.system_catalog.get("fishing", {})
	var river: Dictionary = fishing_catalog.get("waters", {}).get("river", {})
	var pool: Array[String] = load("res://scripts/fishing_rules.gd").pool(river, fishing_catalog.get("species", {}), 3, "晴", 700, "plain")
	_check(not pool.has("perch") and not pool.has("crab"), "冬季常规河流鱼池排除鲈鱼与河蟹")
	state.day = 0
	state.minutes = 390
	state.set_fishing_option("bait", "grain")
	_check(state.fishing_has_bait("grain"), "米粒饵读取背包材料")
	var first_plan: Dictionary = state.fishing_plan("river")
	_check(not first_plan.is_empty() and str(first_plan.bait) == "grain" and float(first_plan.length) > 0.0, "水域预测读取鱼饵和尺寸")
	first_plan.mode = "standard"
	var fish_id := str(first_plan.fish)
	var rice_before := int(state.inventory.get("rice", 0))
	state.finish_fishing(first_plan, true, 1.0, 1.0)
	_check(int(state.inventory.get("rice", 0)) == rice_before - 1 and int(state.inventory.get(fish_id, 0)) >= 1, "钓获消耗鱼饵并进入背包")
	_check(int(state.fishing.get("records", {}).get(fish_id, {}).get("count", 0)) == 1 and int(state.quality.get(fish_id, [0, 0, 0])[0]) >= 1, "安全收线记入鱼种记录与优质库存")
	state.set_fishing_option("release", true)
	var release_plan: Dictionary = state.fishing_plan("river")
	var release_id := str(release_plan.fish)
	var before_release := int(state.inventory.get(release_id, 0))
	state.finish_fishing(release_plan, true, 1.0, 1.0)
	_check(int(state.inventory.get(release_id, 0)) == before_release and bool(state.fishing.get("last", {}).get("released", false)), "放流登记鱼种而不增加背包")
	_check(int(state.fishing.get("waters", {}).get("river", {}).get("casts", -1)) == 0, "放流减轻当日水域压力")
	print("Wildlife migration: %d passed, %d failed" % [passed, failed])
	state.free()
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
