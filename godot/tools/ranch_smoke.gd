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
	state._reset_animals()
	_check(state.animals.size() == 3, "初始鸡鸭牛完整导入")
	_check(int(state.animals[0].ready) == 1, "初始待收鸡蛋")
	state.tend_animal(0)
	_check(int(state.inventory.get("egg", 0)) == 3, "收取鸡蛋进入背包")
	_check(int(state.animals[0].ready) == 0 and int(state.animals[0].qualityStock[0]) == 0, "收取后清空待收分级库存")
	state.selected_animal_action = "feed"
	state.tend_animal(2)
	_check(int(state.inventory.get("feed", 0)) == 6, "牛按旧版规则消耗三份饲料")
	_check(int(state.animals[2].hunger) > 65 and int(state.animals[2].care.feed) == 0, "喂食记录饱食与当日照料")
	state.selected_animal_action = "pet"
	state.tend_animal(1)
	var bond_after_pet := int(state.animals[1].bond)
	state.tend_animal(1)
	_check(int(state.animals[1].bond) == bond_after_pet, "一天不可重复抚摸获益")
	state._advance_ranch(0, "晴")
	_check(int(state.animals[1].age) == 21 and int(state.animals[1].ready) >= 1, "每日年龄与产出推进")
	_check(int(state.ranch.barns.poultry.clean) < 90, "畜舍卫生随照料日结算")
	state.animals.clear()
	state.animals.append({"id": "hen", "name": "点点", "species": "鸡", "product": "egg", "bond": 0, "fed": false, "ready": 4})
	state._normalize_animals()
	_check(int(state.animals[0].ready) == 4 and int(state.animals[0].qualityStock[0]) == 4, "旧切片存档保留待收产物")
	print("Ranch migration: %d passed, %d failed" % [passed, failed])
	state.free()
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
