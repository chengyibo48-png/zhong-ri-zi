extends RefCounted
class_name FishingRules

static func available(fish: Dictionary, water: String, season: int, weather: String, minutes: float, method: String = "rod") -> bool:
	if not fish.get("waters", []).has(water) or not fish.get("seasons", []).any(func(value: Variant):return int(value)==season) or not fish.get("methods", []).has(method): return false
	var weather_rules: Array = fish.get("weather", [])
	if not weather_rules.is_empty() and not weather_rules.has(weather): return false
	for interval in fish.get("times", [[0, 1440]]):
		if minutes >= float(interval[0]) and minutes < float(interval[1]): return true
	return false

static func pool(water: Dictionary, species: Dictionary, season: int, weather: String, minutes: float, bait: String, method: String = "rod", water_id: String = "") -> Array[String]:
	var result: Array[String] = []
	for raw_id in water.get("ids", []):
		var id := str(raw_id)
		var fish: Dictionary = species.get(id, {})
		var location := water_id if water_id != "" else str(fish.get("waters", [""])[0])
		if not available(fish, location, season, weather, minutes, method): continue
		var weight := int(fish.get("weight", 1))
		weight *= int(fish.get("baitWeights",{}).get(bait,1))
		for index in range(weight): result.append(id)
	return result

static func next_random(seed_value: int) -> int:
	return int((seed_value * 48271) % 2147483647)

static func hotspot(catalog: Dictionary, day: int) -> String:
	var spots: Array = catalog.get("spots", [])
	return str(spots[posmod(day * 7 + 3, spots.size())].id) if not spots.is_empty() else ""

static func predict(water_id: String, catalog: Dictionary, fishing: Dictionary, day: int, season: int, weather: String, minutes: float, method: String = "rod") -> Dictionary:
	var water: Dictionary = catalog.get("waters", {}).get(water_id, {})
	if water.is_empty(): return {}
	var bait := str(fishing.get("bait", "plain"))
	var choices := pool(water, catalog.get("species", {}), season, weather, minutes, bait, method, water_id)
	if choices.is_empty(): return {}
	var seed_value := next_random(maxi(1, int(fishing.get("rng", 172917))))
	var fish_id: String = choices[seed_value % choices.size()]
	var fish: Dictionary = catalog.species[fish_id]
	var size_roll := float(next_random(seed_value) % 10000) / 9999.0
	var length := snappedf(lerpf(float(fish.sizeMin), float(fish.sizeMax), size_roll), 0.1)
	return {"id":int(fishing.get("nextId",1)),"fish":fish_id,"length":length,"water":water_id,"bait":bait,"release":false,"mode":str(fishing.get("mode","relaxed")),"inputStyle":str(fishing.get("inputStyle","hold")),"depth":int(fishing.get("depth",1)),"movement":str(fish.get("movement","smooth")),"difficulty":float(fish.get("difficulty",20)),"speed":float(fish.get("speed",1.0)),"pause":float(fish.get("pause",0)),"warning":float(fish.get("warning",0)),"seed":seed_value,"wait":2.0+float(seed_value%180)/100.0,"duration":45.0,"method":method,"tutorial":not bool(fishing.get("tutorialDone",false))}

static func grade(plan: Dictionary, safe: float, total: float) -> int:
	var ratio := safe / maxf(0.01, total)
	var value := 0
	if int(plan.get("rod",0)) > 0 or ratio >= 0.65: value = 1
	if int(plan.get("depth",1)) == 2 and (int(plan.get("rod",0)) >= 1 or ratio >= 0.86): value = 2
	if str(plan.get("branch","broad")) == "care" and int(plan.get("rod",0)) == 2: value = mini(2,value+1)
	if str(plan.get("mode","relaxed")) == "standard" and not bool(plan.get("tutorial",false)) and ratio >= 0.95 and value >= 2: value = 3
	return mini(value, 2) if str(plan.get("mode","relaxed")) == "relaxed" or str(plan.get("method","rod")) == "trap" else value
