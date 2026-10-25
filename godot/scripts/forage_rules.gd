extends RefCounted
class_name ForageRules

static func status(point: Dictionary, definition: Dictionary, forage: Dictionary, day: int, season: int, today_kind: String, prior_kind: String, collected_today: bool = false, tool_bonus: int = 0) -> Dictionary:
	var patches: Dictionary = forage.get("patches", {})
	var patch: Dictionary = patches.get(str(point.get("id", "")), {})
	var in_season := false
	for value in definition.get("seasons", [0, 1, 2, 3]):
		if int(value) == season:
			in_season = true
			break
	var event := str(point.get("event", ""))
	var event_ready := event == "" or (event == "storm" and prior_kind == "台风") or (event == "rain" and prior_kind in ["雨", "台风"]) or (event == "mist" and today_kind == "雾")
	var ready_day := int(patch.get("readyDay", day + 1 if collected_today else day))
	var wait := maxi(0, ready_day - day)
	var pressure := maxi(0, int(patch.get("pressure", 0)) - floori(float(maxi(0, day - int(patch.get("lastDay", day)))) / 2.0))
	var item_id := str(point.get("item", ""))
	var bonus := 1 if (item_id == "mushroom" and prior_kind in ["雨", "台风"]) or (item_id == "wood" and prior_kind == "台风") or (item_id == "tea" and today_kind == "雾") else 0
	var full := str(forage.get("mode", "gentle")) == "full"
	var days := int(definition.get("days", 1)) + (2 if full else 0) + (1 if pressure >= 4 else 0)
	return {
		"ready": event_ready and in_season and wait == 0,
		"event_ready": event_ready,
		"in_season": in_season,
		"wait": wait,
		"ready_day": ready_day,
		"pressure": pressure,
		"bonus": bonus,
		"quantity": 2 + bonus + tool_bonus + (1 if full else 0),
		"days": days,
		"grade": 1 if item_id not in ["wood", "bamboo"] and int(forage.get("xp", 0)) >= 20 and bonus > 0 else 0,
		"stage": maxf(0.15, 1.0 - float(wait) / float(maxi(1, int(definition.get("days", 1)) + 3))) if wait > 0 else 1.0 if in_season else 0.2
	}

static func describe(point: Dictionary, definition: Dictionary, result: Dictionary) -> String:
	if not bool(result.event_ready):
		return {"storm": "风暴后留意漂木", "rain": "雨后再来找新菌", "mist": "雾天观察嫩茶梢"}.get(str(point.get("event", "")), "条件尚未满足")
	if not bool(result.in_season):
		var seasons: Array[String] = []
		for value in definition.get("seasons", []):
			seasons.append(["春", "夏", "秋", "冬"][int(value) % 4])
		return "休养季 · %s可采" % "、".join(seasons)
	if int(result.wait) > 0:
		return "正在再生 · %d 天后可采" % int(result.wait)
	return "可收 %d 份 · %d 天再生%s" % [int(result.quantity), int(result.days), " · 天气加成" if int(result.bonus) > 0 else ""]
