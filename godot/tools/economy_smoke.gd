extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state.inventory = state._new_inventory()
	state.inventory["cabbage"] = 3
	state.quality["cabbage"] = [1, 1, 0]
	var quoted: int = state.sale_quote("cabbage", 2)
	_check(quoted > 0, "品质与季节可计算售价")
	state.sell_item("cabbage", 2)
	_check(int(state.inventory["cabbage"]) == 1, "出售减少正确数量")
	_check(state.quality["cabbage"] == [0, 1, 0], "出售优先消耗普通和较低品质")
	_check(int(state.economy.receipts.size()) == 1 and int(state.economy.receipts[0].price) == quoted, "收据保留报价")
	var receipt_key := int(state.economy.receipts[0].key)
	state.buyback_item(receipt_key)
	_check(int(state.inventory["cabbage"]) == 3 and state.quality["cabbage"] == [1, 1, 0], "回购恢复原数量与品质")
	_check(state.economy.receipts.is_empty(), "回购后移除货签")
	state.toggle_item_lock("cabbage")
	state.cook_selected_recipe()
	_check(int(state.inventory["cabbage"]) == 3, "锁定食材不能用于烹饪")
	state.toggle_item_lock("cabbage")
	state.cook_selected_recipe()
	_check(int(state.inventory["cabbage"]) == 1 and state.quality["cabbage"] == [0, 1, 0], "烹饪消耗后品质账仍与背包一致")
	var seeds_before := int(state.inventory["cabbageSeed"])
	var money_before: int = state.money
	state.buy_item("cabbageSeed", 1)
	_check(int(state.inventory["cabbageSeed"]) == seeds_before + 1 and state.money < money_before, "购买种子扣款并入包")
	state.toggle_item_lock("egg")
	var eggs_before := int(state.inventory["egg"])
	state.sell_item("egg", 1)
	_check(int(state.inventory["egg"]) == eggs_before, "锁定物品不可出售")
	state.toggle_item_lock("egg")
	state.sell_item("egg", 1)
	_check(int(state.inventory["egg"]) == eggs_before - 1, "解除锁定后可出售")
	state.day += 3
	state._refresh_economy_day()
	_check(not state.buyback_item(int(state.economy.receipts[0].key)), "回购货签两日后失效")
	print("Economy migration: %d passed, %d failed" % [passed, failed])
	state.free()
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
