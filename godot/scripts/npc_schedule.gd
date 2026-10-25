extends RefCounted
class_name NpcSchedule

static func activity(person: Dictionary, index: int, day: int, minutes: float, shelter: bool, home: Variant, work: Variant, school: Variant, market: Variant, friend_home: Variant, friend_name: String, bridge_ready: bool, festival_name: String, has_housework: bool = false, museum_level: int = 0, museum_door: Variant = Vector2.ZERO) -> Dictionary:
	var npc_id := str(person.get("id", ""))
	var tier := str(person.get("tier", ""))
	var late_start := 390 if npc_id == "mei" else 420 + index % 4 * 12
	var night_start := 1140 + index % 4 * 12
	if minutes < late_start or minutes >= night_start:
		return _plan("night", "在家歇息", home, "sleep", "夜间回屋，明早再忙", true, "home-" + npc_id)
	if shelter:
		return _plan("shelter", "在家" + _work_label(npc_id), home, _gesture(npc_id), "风雨或寒冷天气，转为室内活动", true, "home-" + npc_id)
	if posmod(day, 28) + 1 == 14 and minutes >= 660 and minutes < 1080:
		var offset := Vector2(float(index % 6 - 2) * 30.0, 80.0 + float(int(index / 6)) * 32.0)
		return _plan("festival", "准备" + festival_name, _offset(market, offset.x, offset.y), "fan", festival_name + "当天，去老街会合", false, "")
	if has_housework and npc_id in ["granny", "zhouSenior", "liang", "song"] and minutes >= 570 and minutes < 960:
		return _plan("housework", _request(npc_id), home, _gesture(npc_id), "家中有件小事，可带材料或一起搭把手", true, "home-" + npc_id)
	if minutes < 510 + index % 3 * 20:
		return _plan("morning", "准备出门 · " + _work_label(npc_id), home, _gesture(npc_id), "早起先整理手边东西", true, "home-" + npc_id)
	if museum_visitor_id(day, minutes, museum_level) == npc_id and _point(museum_door) != {"x": 0.0, "y": 0.0}:
		return _plan("museum", "参观村史馆", museum_door, "read", "今日来看看乡亲新登记的馆藏", true, str(GameState.system_catalog.get("museum", {}).get("house", {}).get("id", "building-river-10")))
	var lunch_start := 720 + index % 3 * 20
	if minutes >= lunch_start and minutes < lunch_start + 65:
		return _plan("lunch", "回家吃饭歇脚", home, "tea", "午饭和休息有自己的时间", true, "home-" + npc_id)
	if tier == "child" and posmod(day, 7) < 5 and minutes < 900 and _point(school) != {"x": 0.0, "y": 0.0}:
		return _plan("school", "上课与自然观察", _offset(school, float(index % 4 - 1.5) * 28.0, 30.0), "read", "平日先上学，放学后做自己的事")
	if minutes < 960:
		if posmod(day, 7) == 5 and npc_id in ["xu", "mei", "tao", "song", "luSenior", "luo"]:
			var stall := _offset(market, float(index % 5 - 2) * 37.0, 90.0 + float(int(index / 5)) * 20.0)
			return _plan("market", "赶集 · " + _work_label(npc_id), stall, _gesture(npc_id), "每周赶集日到老街照看摊位")
		return _plan("work", _work_label(npc_id), work, _gesture(npc_id), "按平日作息")
	if minutes < 1080:
		if friend_name != "":
			return _plan("visit", "在" + friend_name + "门前聊家常", _offset(friend_home, float(index % 3 - 1) * 27.0, 36.0), "tea", "忙完工作，沿路看看亲友")
		if bridge_ready:
			return _plan("visit", "去修好的河埠歇脚", Vector2(1165, 2800) + Vector2(float(index % 3 - 1) * 27.0, 36.0), "tea", "傍晚留一点散步时间")
		return _plan("visit", "在自家门前散步", _offset(home, float(index % 3 - 1) * 27.0, 36.0), "tea", "傍晚留一点散步时间")
	return _plan("evening", "收好工具，准备晚饭", home, "tea", "晚间回到自己的小屋", true, "home-" + npc_id)

static func museum_visitor_id(day: int, minutes: float, museum_level: int) -> String:
	if museum_level < 2 or minutes < 930 or minutes > 1080:
		return ""
	return ["he", "yan", "yu", "granny"][posmod(day, 4)]

static func _plan(key: String, label: String, target: Variant, gesture: String, reason: String, indoors: bool = false, room: Variant = null) -> Dictionary:
	var point := _point(target)
	return {"key": key, "label": label, "target": Vector2(point.x, point.y), "target_point": point, "gesture": gesture, "reason": reason, "room": room, "indoors": indoors}

static func _point(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result := {"x": float(value.get("x", 0.0)), "y": float(value.get("y", 0.0))}
		if value.has("direction"): result.direction = str(value.direction)
		return result
	if value is Vector2:
		return {"x": float(value.x), "y": float(value.y)}
	return {"x": 0.0, "y": 0.0}

static func _offset(value: Variant, x: float, y: float) -> Dictionary:
	var point := _point(value)
	return {"x": float(point.x) + x, "y": float(point.y) + y}

static func from_state(state: Node, person: Dictionary) -> Dictionary:
	var npc_id := str(person.get("id", ""))
	var index: int = state.npc_catalog.find(person)
	var homes: Dictionary = {}
	var school: Dictionary = {}
	var market: Dictionary = {}
	for house in state.world_village.get("houses", []):
		var owner := str(house.get("owner")) if house.get("owner") != null else ""
		if owner != "": homes[owner] = house
		if str(house.get("name", "")) == "禾溪小学": school = house
		if str(house.get("name", "")) == "许婶杂货": market = house
	var home_house: Dictionary = homes.get(npc_id, {})
	var home: Dictionary = home_house.get("door", {})
	var work: Dictionary = state.system_catalog.get("npc", {}).get("workpoints", {}).get(npc_id, home)
	var friend_home: Dictionary = home
	var friend_name := ""
	for link in state.content.get("links", []):
		if link is Array and link.size() >= 2 and str(link[0]) == npc_id:
			var friend_id := str(link[1])
			if homes.has(friend_id):
				friend_home = homes[friend_id].get("door", home)
				friend_name = state.npc_name(friend_id)
			break
	var event: Dictionary = state.neighbors.get("people", {}).get(npc_id, {}).get("event", {})
	var festivals: Array = state.content.get("festivals", [])
	var festival_index := posmod(int(state.day), 112) / 28
	var festival_name := str(festivals[int(festival_index)]) if int(festival_index) < festivals.size() else "四季饭桌"
	var museum: Dictionary = state.system_catalog.get("museum", {}).get("house", {})
	var plan := activity(person, index, state.day, state.minutes, bool(state.weather_profile().get("shelter", false)), home, work, school.get("door", Vector2.ZERO), market.get("door", work), friend_home, friend_name, bool(state.community_projects.get("bridge", false)), festival_name, not event.is_empty() and str(event.get("status", "")) != "done", int(state.collection.get("level", 0)), museum.get("door", Vector2.ZERO))
	if bool(plan.indoors) and str(plan.key) != "museum":
		plan.room = str(home_house.get("id", "home-" + npc_id))
	return plan

static func _request(npc_id: String) -> String:
	return str(GameState.system_catalog.get("npc", {}).get("profiles", {}).get(npc_id, {}).get("request", "邻里小事"))

static func _work_label(npc_id: String) -> String:
	return str(GameState.system_catalog.get("npc", {}).get("profiles", {}).get(npc_id, {}).get("work", "整理手边的事"))

static func _gesture(npc_id: String) -> String:
	return str(GameState.system_catalog.get("npc", {}).get("profiles", {}).get(npc_id, {}).get("gesture", "read"))
