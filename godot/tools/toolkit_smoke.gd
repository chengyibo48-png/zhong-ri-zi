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
	state._reset_plots()
	state._reset_animals()
	_check(state.tool_data("hoe").get("level", -1) == 0, "读取六件初始工具")
	state.inventory["wood"] = 30
	state.inventory["bamboo"] = 30
	state.inventory["wool"] = 5
	state.money = 2000
	state.upgrade_tool("hoe")
	_check(int(state.tool_data("hoe").get("level", 0)) == 1 and state.money == 1920, "一级工具扣除材料与金币")
	state.configure_tool("hoe", "shape", "row")
	_check(state._farm_targets(7, "hoe") == [7, 6, 8], "横排作业不跨田垄")
	var untilled := 0
	for index in [7, 6, 8]:
		if not bool(state.plots[index].tilled):
			untilled += 1
	state.selected_tool = "hoe"
	state.farm_plot_action(7)
	_check(bool(state.plots[6].tilled) and bool(state.plots[7].tilled) and bool(state.plots[8].tilled), "横排锄地作用于三格")
	_check(int(state.tool_data("hoe").get("xp", 0)) == untilled, "工具熟练度只计成功作业")
	state.day = 7
	state.stamina = 100
	state.upgrade_tool("hoe")
	state.configure_tool("hoe", "shape", "cross")
	_check(state._farm_targets(7, "hoe").size() == 5, "二阶广作十字五格")
	state.configure_tool("hoe", "branch", "care")
	_check(str(state.tool_data("hoe").get("shape", "")) == "row", "切换细作限制十字范围")
	state.upgrade_tool("rod")
	_check(state.fishing_energy_cost() == 5, "鱼竿升级减少体力消耗")
	state.upgrade_tool("care")
	_check(int(state.tool_data("care").get("level", 0)) == 1, "牧场护理工具可改良")
	state.upgrade_tool("axe")
	_check(int(state.tool_data("sickle").get("level", 0)) == 1, "斧镰共享首次修磨")
	var path := SMOKE_FILES.create_path("migration_toolkit_smoke")
	state.save_game(path)
	var loaded = load("res://scripts/game_state.gd").new()
	loaded._load_content()
	loaded._load_initial_state()
	var read_back: bool = loaded.load_game(path)
	_check(read_back and int(loaded.tool_data("hoe").get("level", 0)) == 2 and str(loaded.tool_data("hoe").get("branch", "")) == "care", "原生存档读回工具等级与专长")
	SMOKE_FILES.remove(path)
	print("Tool migration: %d passed, %d failed" % [passed, failed])
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
