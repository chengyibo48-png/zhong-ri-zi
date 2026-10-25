extends RefCounted
class_name EnvironmentRules

const BASE_WEATHER := ["晴", "晴", "阴", "雨", "晴", "雾", "晴", "雨", "阴", "晴", "晴", "雨", "晴", "阴"]
const TEMPERATURES := {"晴": 3, "阴": -1, "雨": -3, "雾": -2, "台风": -4, "高温": 8, "寒潮": -9, "小雪": -5}
const TIPS := {
	"雨": "雨水替田地补水，检查低洼田块；雨后可去竹影山坞找菌子。",
	"雾": "山路起雾，沿村道慢行；店铺照常开门。",
	"小雪": "雪日可安心在屋里加工串门，牧场伙伴会避寒。",
	"晴": "适合晾晒与出门，留意土壤水分。"
}

static func profile(target_day: int, minutes: float, events: Array) -> Dictionary:
	var safe_day := maxi(0, target_day)
	var year_day := safe_day % 112
	var season := int(year_day / 28)
	var current_event: Dictionary = {}
	for candidate in events:
		if year_day >= int(candidate.get("from", 0)) and year_day <= int(candidate.get("to", -1)):
			current_event = candidate
			break
	var kind := str(current_event.get("kind", "小雪" if year_day in [95,105] else BASE_WEATHER[safe_day % BASE_WEATHER.size()]))
	var rain: int = 48 if kind == "台风" else (26 if not current_event.is_empty() else 34) if kind == "雨" else 0
	var snow := kind in ["小雪", "寒潮"]
	var mean_temperature: int = int([18, 29, 20, 5][season]) + int(TEMPERATURES.get(kind, 0))
	var temperature := roundi(float(mean_temperature) - 5.0 + 9.0 * (1.0 + sin((float(minutes) - 540.0) / 720.0 * PI)) / 2.0)
	var sunlight: float = 0.08 if kind == "台风" else 0.22 if rain > 0 else 0.42 if kind == "阴" or snow else 0.5 if kind == "雾" else 1.0
	var evaporation: float = 1.55 if kind == "高温" else 0.55 if rain > 0 else 0.45 if snow else 0.75 if kind in ["阴", "雾"] else 1.0
	return {
		"day": safe_day,
		"kind": kind,
		"label": str(current_event.get("name", kind)),
		"season": season,
		"event": str(current_event.get("name", "")),
		"remaining": int(current_event.get("to", year_day)) - year_day + 1,
		"temperature": temperature,
		"mean_temperature": mean_temperature,
		"low": mean_temperature - 5,
		"high": mean_temperature + 4,
		"humidity": 94 if rain > 0 else 78 if snow else 92 if kind == "雾" else 70 if kind == "阴" else 48,
		"rain": rain,
		"snow": snow,
		"wind": 28 if kind == "台风" else 13 if kind == "寒潮" else 8 if rain > 0 else 4,
		"visibility": 0.48 if kind == "雾" else 0.65 if kind == "台风" else 1.0,
		"sunlight": sunlight,
		"evaporation": evaporation,
		"sunrise": [375, 345, 390, 425][season],
		"sunset": [1095, 1155, 1065, 1020][season],
		"shelter": rain > 0 or snow or kind == "高温",
		"extreme": kind in ["台风", "高温", "寒潮"],
		"tip": str(current_event.get("tip", TIPS.get(kind, "阴云下水分散得慢，适合照料田间与串门。")))
	}

static func forecast(start_day: int, minutes: float, events: Array, count: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offset in range(maxi(0, count)):
		result.append(profile(start_day + offset, minutes, events))
	return result

static func warning(target_day: int, events: Array) -> String:
	var today := profile(target_day, 720, events)
	var tomorrow := profile(target_day + 1, 720, events)
	if bool(today.extreme) or str(today.event) != "":
		return "%s · 还将持续 %d 天。%s" % [today.label, today.remaining, today.tip]
	if bool(tomorrow.extreme) or str(tomorrow.event) != "":
		return "提前提醒：明日%s，预计 %d 天。%s" % [tomorrow.label, tomorrow.remaining, tomorrow.tip]
	if bool(profile(maxi(0, target_day - 1), 720, events).extreme):
		return "天气转稳，可以查看设施与伙伴。"
	return "明日%s · %d～%d°。%s" % [tomorrow.label, tomorrow.low, tomorrow.high, tomorrow.tip]

static func ground(target_day: int, events: Array) -> Dictionary:
	var today := profile(target_day, 720, events)
	var prior := profile(maxi(0, target_day - 1), 720, events)
	return {
		"wet": 1.0 if int(today.rain) > 0 else clampf(0.65 / float(today.evaporation), 0.0, 0.85) if int(prior.rain) > 0 else 0.0,
		"snow": 1.0 if bool(today.snow) else 0.4 if bool(prior.snow) and int(today.temperature) < 8 else 0.0
	}

static func daylight(target_day: int, minutes: float, events: Array) -> Dictionary:
	var today := profile(target_day, minutes, events)
	var rise := int(today.sunrise)
	var sunset := int(today.sunset)
	var dawn := clampf((float(minutes - rise) + 45.0) / 90.0, 0.0, 1.0)
	var dusk := clampf((float(minutes - sunset) + 45.0) / 90.0, 0.0, 1.0)
	return {
		"night": clampf((1.0 - dawn + dusk) * 0.58, 0.0, 0.58),
		"warm": (sin(dawn * PI) + sin(dusk * PI)) * 0.22 * float(today.sunlight)
	}
