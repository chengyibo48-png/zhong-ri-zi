extends RefCounted
## One dated meal account is shared by grass, hand feeding and automatic troughs.
static func needed(s: Node, a: Dictionary, meal_day: int) -> int:
	var spec: Dictionary = s.system_catalog.ranch.species[str(a.type)]
	var breed: Dictionary = s.system_catalog.ranch.breeds[str(a.breed)]
	var portions := ceili(float(spec.feed)*float(breed.feed))
	return maxi(0,portions-(int(a.get("mealUnits",0)) if int(a.get("mealDay",-1)) == meal_day else 0))

static func accepts(s: Node, a: Dictionary, food: String) -> bool:
	return food in s.system_catalog.ranch.species[str(a.type)].get("diet",[])

static func eat(s: Node, a: Dictionary, food: String, portions: int, meal_day: int, source: String) -> int:
	var consumed := mini(portions,needed(s,a,meal_day))
	if consumed <= 0: return 0
	if int(a.get("mealDay",-1)) != meal_day: a.mealUnits = 0; a.mealDay = meal_day
	var total: int = ceili(float(s.system_catalog.ranch.species[str(a.type)].feed)*float(s.system_catalog.ranch.breeds[str(a.breed)].feed))
	var info: Dictionary = s.system_catalog.ranch.feedKinds.get(food,{"gain":55,"quality":3})
	a.mealUnits += consumed; a.mealSource = source
	a.hunger = clampf(float(a.hunger)+float(info.gain)*consumed/total,0,100)
	a.feedQuality = maxf(float(a.feedQuality),float(info.quality))
	a.mood = minf(100,float(a.mood)+4.0*consumed/total)
	if food == "healthFeed": a.health = minf(100,float(a.health)+12); a.illness = maxf(0,float(a.illness)-12)
	if needed(s,a,meal_day) == 0: a.care.feed = meal_day
	a.fed = float(a.hunger) >= 60
	return consumed

static func from_trough(s: Node, a: Dictionary, barn: Dictionary, meal_day: int) -> void:
	var trough: Dictionary = barn.get("trough",{})
	for food: String in trough:
		if not accepts(s,a,food): continue
		var consumed := eat(s,a,food,int(trough[food]),meal_day,"料槽")
		trough[food] = int(trough[food])-consumed
	barn.trough = trough

static func settle(s: Node, a: Dictionary, barn: Dictionary, meal_day: int) -> void:
	from_trough(s,a,barn,meal_day)
	if not bool(barn.autoFeed) or needed(s,a,meal_day) == 0: return
	if float(barn.durability) <= 0: barn.feedStatus = "停机 · 请修缮"; return
	for food: String in [str(s.ranch.feed),"feed","hay","grainFeed","healthFeed"]:
		if not accepts(s,a,food): continue
		var amount := mini(needed(s,a,meal_day),int(s.ranch.stores.get(food,0)))
		if amount <= 0: continue
		s.ranch.stores[food] = int(s.ranch.stores[food])-amount
		barn.trough[food] = int(barn.trough.get(food,0))+amount
		from_trough(s,a,barn,meal_day)
	barn.feedStatus = "运行 · 牧场料仓 → 本舍料槽" if needed(s,a,meal_day) == 0 else "停机 · 料仓缺少适用饲料"

static func graze(s: Node, a: Dictionary, delta: float) -> void:
	if a.position.get("room") != null or bool(a.position.get("walking",false)): return
	var spec: Dictionary = s.system_catalog.ranch.species[str(a.type)]
	if int(a.age) < int(spec.adult) or needed(s,a,s.day) == 0: return
	var zone := int(spec.get("grazingZone",s.ranch.zone))
	var pen: Dictionary = s.system_catalog.forage.pens[zone]
	if not Rect2(float(pen.x),float(pen.y),float(pen.w),float(pen.h)).has_point(Vector2(a.position.x,a.position.y)): return
	a.grazeElapsed = float(a.get("grazeElapsed",0))+delta
	if float(a.grazeElapsed) < 2.0 or float(s.ranch.grass[zone]) < 2: return
	a.grazeElapsed = 0
	var consumed := eat(s,a,"grass",1,s.day,"草圈")
	if consumed>0:s.quest_event("graze","graze:%s:%d" % [str(a.id),s.day])
	s.ranch.grass[zone] = maxf(0,float(s.ranch.grass[zone])-consumed*2.0)
	s.ranch_actor_poses[str(a.id)] = {"action":"feed","until":s.ranch_actor_clock+2}

static func status(s: Node, a: Dictionary) -> String:
	var states: Array[String] = []
	if bool(a.lost): states.append("需要带回")
	elif float(a.illness) >= 20 or float(a.health) < 50: states.append("需要帮助 · 留舍护理")
	elif int(a.warning) >= 1: states.append("需要留意饮食与垫草")
	else: states.append("吃饱" if float(a.hunger)>=55 else "需要添料")
	if int(a.care.get("pet",-1)) == s.day: states.append("已亲近")
	if int(a.ready)>0: states.append("可收 %d" % int(a.ready))
	if int(a.age)<int(s.system_catalog.ranch.species[str(a.type)].adult): states.append("幼崽成长中")
	return " · ".join(states)

static func clean_barn(s: Node, home: String, automatic: bool, produced_day: int) -> int:
	var barn: Dictionary = s.ranch.barns[home]
	var residents: Array = s.animals.filter(func(a):return str(s.system_catalog.ranch.species[str(a.type)].home)==home)
	var manure := mini(8,int(barn.get("waste",0)))
	barn.waste = maxi(0,int(barn.get("waste",0))-manure)
	barn.clean = 95 if automatic else 100
	barn.lastClean = produced_day
	for a: Dictionary in residents:a.clean=minf(100,float(a.clean)+(25 if automatic else 15))
	if manure>0:
		var owner: Dictionary = residents[0] if not residents.is_empty() else {}
		if owner.is_empty():
			for type: String in s.system_catalog.ranch.species:
				if str(s.system_catalog.ranch.species[type].home)==home:
					owner={"id":"barn:"+home,"type":type,"position":{"room":s.system_catalog.ranch.barns[home].house}}
					break
		preload("res://scripts/ranch_products.gd").produce(s,owner,"manure",manure,0,produced_day)
		if not automatic:preload("res://scripts/ranch_products.gd").take(s,"product",str(s.ranch.products[-1].id))
	preload("res://scripts/ranch_products.gd").sync(s)
	return manure
