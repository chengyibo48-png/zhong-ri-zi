extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state.inventory = state._new_inventory()
	state._reset_plots()
	_check(state.crop_in_season("cabbage"), "JSON 季节编号允许适季播种")
	state.selected_tool = "seed"
	state.farm_plot_action(2)
	_check(str(state.plots[2].crop) == "cabbage" and int(state.inventory["cabbageSeed"]) == 7, "适季种子可实际播入田块")
	_check(state.weather_for(0) == "晴", "基础天气循环起点")
	var plum_rain: Dictionary = state.weather_profile(36)
	_check(str(plum_rain.label) == "梅雨" and int(plum_rain.rain) == 26 and int(plum_rain.remaining) == 4, "梅雨事件覆盖基础天气")
	state.day = 35
	_check(state.weather_warning().contains("提前提醒：明日梅雨"), "事件提前一天预警")
	_check(str(state.weather_forecast(4)[1].label) == "梅雨", "四日预报读取同一事件")
	var typhoon: Dictionary = state.weather_profile(46)
	_check(str(typhoon.kind) == "台风" and int(typhoon.rain) == 48 and bool(typhoon.extreme), "台风的降水和极端状态")
	var heat: Dictionary = state.weather_profile(50)
	_check(str(heat.kind) == "高温" and float(heat.evaporation) > 1.5, "高温增强蒸发")
	var cold: Dictionary = state.weather_profile(98)
	_check(str(cold.kind) == "寒潮" and bool(cold.snow), "寒潮产生雪地状态")
	state.day = 37
	_check(state.travel_speed_multiplier() < 1.0, "雨天地面影响出行速度")
	state.day = 4
	var moisture_before := int(state.plots[2].moisture)
	state._advance_farm(3)
	_check(int(state.plots[2].moisture) > moisture_before, "雨日实际补充田块湿度")
	state.day = 51
	state.plots[2].moisture = 45
	state.plots[2].health = 100
	state._advance_farm(50)
	_check(int(state.plots[2].health) < 100, "高温夜结算损伤缺水作物")
	state.day = 4
	state.gather_node("rain_mushroom", "mushroom")
	_check(int(state.inventory.get("mushroom", 0)) == 3, "雨后菌子采集加一")
	state.day = 46
	state._remember_weather()
	var history: Array = state.environment.get("history", [])
	_check(str(history.back().get("kind", "")) == "台风", "天气历史记录真实日况")
	print("Environment migration: %d passed, %d failed" % [passed, failed])
	state.free()
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
