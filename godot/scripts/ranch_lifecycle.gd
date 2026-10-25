extends RefCounted
const CARE = preload("res://scripts/ranch_care.gd")
const PRODUCTS = preload("res://scripts/ranch_products.gd")
static func advance(s: Node, previous_day: int, weather: String, _previous_minutes: float = 1050.0) -> void:
	if int(s.ranch.get("settledDay",-1)) >= previous_day: return
	s.ranch.settledDay = previous_day
	var catalog: Dictionary = s.system_catalog.get("ranch", {})
	var species_catalog: Dictionary = catalog.get("species", {})
	var breeds: Dictionary = catalog.get("breeds", {})
	var barns: Dictionary = s.ranch.get("barns", {})
	var stores: Dictionary = s.ranch.get("stores", {})
	var grass: Array = s.ranch.get("grass", [100, 100])
	var wet := weather in ["雨", "台风"]
	var extreme := weather in ["台风", "寒潮", "高温"]
	var pet: Dictionary = s.ranch.get("pet", {})
	var pet_type := str(s.pet_state.get("type", "cat"))
	var dog_help := pet_type == "dog" and str(pet.get("mode", "home")) == "patrol" and float(pet.get("training", 0)) >= 20 and float(pet.get("hunger", 0)) >= 35
	var cat_help := pet_type == "cat" and float(pet.get("training", 0)) >= 20 and float(pet.get("hunger", 0)) >= 35
	var prior_illness: Dictionary = {}
	for animal in s.animals: prior_illness[str(animal.id)] = float(animal.get("illness", 0))
	for barn_id in barns:
		var barn: Dictionary = barns[barn_id]
		if not bool(barn.get("built", false)): continue
		var residents: Array[Dictionary] = []
		for animal in s.animals:
			if str(species_catalog.get(str(animal.type), {}).get("home", "")) == str(barn_id): residents.append(animal)
		var crowd := maxi(0, residents.size() - s.ranch_barn_capacity(str(barn_id)))
		barn.clean = clampf(float(barn.clean) - residents.size() * (4 if str(barn_id) == "pigpen" else 2) - (5 if wet else 1) - crowd * 5, 0.0, 100.0)
		barn.waste = mini(99, int(barn.waste) + residents.size())
		barn.durability = clampf(float(barn.durability) - (maxi(1, 5 - int(barn.protection)) if weather == "台风" else 1 if previous_day % 7 == 0 else 0), 0.0, 100.0)
		if not residents.is_empty() and bool(barn.autoClean) and float(barn.durability) > 0 and (float(barn.clean) < 65 or residents.any(func(a):return float(a.clean)<65)) and int(stores.bedding) > 0:
			stores.bedding = int(stores.bedding) - 1
			CARE.clean_barn(s,str(barn_id),true,previous_day)
			barn.beddingDay = previous_day
		for animal in residents:
			var spec: Dictionary = species_catalog[str(animal.type)]
			var breed: Dictionary = breeds[str(animal.breed)]
			if int(animal.get("postpartumUntil",-1)) == previous_day: animal.rest = false
			animal.age = mini(100000, int(animal.age) + 1)
			animal.hunger = clampf(float(animal.hunger) - (16.0 + float(spec.feed) * 2.0) * (1.15 if str(animal.trait) == "hungry" else 1.0), 0.0, 100.0)
			animal.clean = clampf(float(animal.clean) - (8 if str(barn_id) == "pigpen" else 4) - (3 if wet else 0) + (2 if int(barn.protection) > 0 else 0), 0.0, 100.0)
			var mature := int(animal.age) >= int(spec.adult)
			var ranging := str(s.ranch.policy) != "inside" and not extreme and weather != "小雪" and not (wet and str(s.ranch.policy) == "safe") and mature and not bool(animal.rest) and not bool(animal.retired) and float(animal.health) >= 45 and not bool(animal.lost)
			var zone := 0 if str(animal.type) == "duck" else int(s.ranch.zone)
			CARE.settle(s,animal,barn,previous_day)
			var weather_pressure := maxi(0, 6 - int(barn.protection) * 2 - int(barn.comfort)) if extreme else 0
			var social_isolation := 4 if str(animal.trait) == "social" and residents.size() < 2 else 0
			var pressure := (12 if float(animal.hunger) < 25 else 0) + (9 if float(barn.clean) < 35 or float(animal.clean) < 35 else 0) + crowd * 6 + weather_pressure + social_isolation
			animal.warning = minf(99.0, float(animal.warning) + 1.0) if pressure >= 9 else maxf(0.0, float(animal.warning) - 1.0)
			if float(animal.warning) >= 2:
				animal.illness = clampf(float(animal.illness) + maxf(1.0, float(pressure) / 3.0 - float(breed.resist) * 0.25 - (2 if str(animal.trait) == "strong" else 0)), 0.0, 100.0)
			if float(barn.clean) < 40:
				for other in residents:
					if str(other.id) != str(animal.id) and float(prior_illness.get(str(other.id), 0)) > 60: animal.illness = clampf(float(animal.illness) + 3.0, 0.0, 100.0); break
			if bool(animal.rest) and float(animal.hunger) > 35 and float(barn.clean) > 50:
				animal.illness = clampf(float(animal.illness) - 8.0, 0.0, 100.0)
				animal.health = clampf(float(animal.health) + 8.0, 0.0, 100.0)
			animal.health = clampf(float(animal.health) + (4.0 if pressure < 9 and float(animal.illness) < 30 else -minf(8.0, float(pressure) * 0.25 + float(animal.illness) * 0.05)), 15.0, 100.0)
			animal.mood = clampf(float(animal.mood) + (2 if pressure < 9 else -5) + int(barn.comfort) - (4 if float(animal.illness) > 45 else 0), 0.0, 100.0)
			animal.stress = clampf(float(animal.stress) + (7 if pressure >= 9 else -6) + (5 if str(animal.trait) == "shy" and extreme and int(barn.protection) == 0 else 0), 0.0, 100.0)
			if social_isolation > 0: animal.mood = clampf(float(animal.mood) - 4.0, 0.0, 100.0)
			var slot: int = s.animals.find(animal)
			if ranging and int(barn.protection) == 0 and not dog_help and float(animal.warning) >= 1 and previous_day % 19 == slot % 19:
				animal.lost = true
				animal.stress = clampf(float(animal.stress) + 15.0, 0.0, 100.0)
				s._ranch_notice(str(animal.name) + "走到了南坡边，地图与名册会标记位置，可带回。")
			if ranging and str(s.ranch.policy) == "day" and int(barn.protection) == 0 and not dog_help and previous_day % 17 == slot % 17:
				animal.mood = clampf(float(animal.mood) - 8.0, 0.0, 100.0)
				animal.stress = clampf(float(animal.stress) + 8.0, 0.0, 100.0)
				s._ranch_notice(str(animal.name) + "听见野外动静有些受惊，可安抚或增建围护。")
			var can_produce := mature and not bool(animal.retired) and not bool(animal.lost) and float(animal.health) >= 30 and float(animal.hunger) >= 25 and (not bool(spec.get("femaleOnly",true)) or str(animal.sex) == "female")
			if can_produce and int(animal.ready) < 28:
				var rate := float(breed.rate) * (1.08 if str(animal.trait) == "busy" else 1.0) * (0.55 if float(animal.health) < 60 else 1.0) * (0.65 if int(animal.age) >= int(spec.elder) else 1.0) * (0.6 if float(animal.illness) > 30 else 1.0)
				animal.progress = float(animal.progress) + rate
				var stock: Array = animal.qualityStock
				while float(animal.progress) >= float(spec.cycle) and int(stock.reduce(func(a, b): return int(a) + int(b), 0)) < 28:
					animal.progress = float(animal.progress) - float(spec.cycle)
					var grade: int = s._animal_quality(animal, barn)
					PRODUCTS.produce(s,animal,str(animal.product),1,grade,previous_day)
					stock[grade] = int(stock[grade]) + 1
					if str(animal.type) in ["hen", "duck"] and previous_day % 5 == 0: PRODUCTS.produce(s,animal,"feather",1,grade,previous_day)
					
			if not can_produce and not mature: animal.progress = 0
			animal.feedQuality = maxf(0.0, float(animal.feedQuality) - 1.0)
			animal.ready = int(animal.qualityStock.reduce(func(a, b): return int(a) + int(b), 0))
			animal.fed = float(animal.hunger) >= 60
		if bool(barn.autoCollect) and float(barn.durability) > 0: PRODUCTS.auto_collect(s,str(barn_id))
		elif bool(barn.autoCollect): barn.collectStatus = "停机 · 请修缮"
		barn.cleanStatus = "运行 · 料仓垫草" if bool(barn.autoClean) and int(stores.bedding)>0 else "停机 · 料仓缺垫草" if bool(barn.autoClean) else "手动换草"

	for zone in range(2): grass[zone] = clampf(float(grass[zone]) + (10 if int(s.ranch.zone) != zone else 4) + (5 if wet else 0), 0.0, 100.0)
	for birth in s.ranch.births.duplicate():
		var home := str(species_catalog[str(birth.type)].home)
		var barn: Dictionary = barns[home]
		var mother: Dictionary = {}
		for animal in s.animals:
			if birth.mother != null and str(animal.id) == str(birth.mother): mother = animal; break
		if float(barn.clean) < 40 or not mother.is_empty() and (float(mother.health) < 50 or float(mother.hunger) < 30) or extreme and int(barn.comfort) < 1: continue
		birth.remaining = maxi(0, int(birth.remaining) - 1)
		if int(birth.remaining) == 0:
			var parent_ids: Array = []
			if birth.mother != null and str(birth.mother) != "": parent_ids.append(str(birth.mother))
			if birth.father != null and str(birth.father) != "": parent_ids.append(str(birth.father))
			var baby: Dictionary = s._ranch_new_animal(str(birth.type), "female" if int(s.ranch.nextId) % 2 == 1 else "male", str(birth.breed), 0, parent_ids)
			if not mother.is_empty():
				if int(s.ranch.nextId) % 2 == 0: baby.trait = mother.trait; baby.personality = catalog.traits[str(baby.trait)]
				mother.care.breed = s.day
				mother.rest = true
				mother.postpartumUntil = s.day+2
			s.ranch.births.erase(birth)
			s._ranch_notice("新伙伴 " + str(baby.name) + " 出生了！已安置在" + str(catalog.barns[home].name) + "。")
	pet.hunger = clampf(float(pet.hunger) - 12.0, 0.0, 100.0)
	pet.energy = clampf(float(pet.energy) + (30 if str(pet.mode) == "home" else 10), 0.0, 100.0)
	if previous_day % 13 == 0 and not cat_help and int(stores.grainFeed) > 0:
		stores.grainFeed = int(stores.grainFeed) - 1
		s._ranch_notice("粮仓有一点鼠耗：谷物精料 −1。盖好料箱或训练猫咪巡看。")
	var remaining_jobs: Array = []
	for job in s.ranch.get("jobs", []):
		if int(job.get("readyDay", s.day + 1)) > s.day:
			remaining_jobs.append(job)
		else:
			s._grant_quality(str(job.get("out", "")), int(job.get("qty", 0)), int(job.get("grade", 0)))
			s._ranch_notice("牧场加工完成：%s ×%d。" % [str(s.item_catalog.get(str(job.get("out", "")), {}).get("name", job.get("out", "成品"))), int(job.get("qty", 0))])
	if s.ranch.has("jobs") or not remaining_jobs.is_empty(): s.ranch.jobs = remaining_jobs
	if s.animals.any(func(animal: Dictionary) -> bool: return float(animal.warning) >= 2 or float(animal.illness) >= 20):
		s._ranch_notice("有伙伴需要留意，打开牧场名册可查看原因与护理方式。")
	s.ranch.grass = grass
	s.ranch.barns = barns
	s.ranch.stores = stores
	s.ranch.pet = pet

	PRODUCTS.sync(s)
