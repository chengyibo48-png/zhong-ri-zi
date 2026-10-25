extends RefCounted

static func season_days(content: Dictionary, day: int, season: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var terms: Array = content.get("terms", [])
	for date in range(1, 29):
		var absolute := floori(float(day) / 112.0) * 112 + season * 28 + date - 1
		var annual_day := season * 28 + date - 1
		var term_index := floori(float(annual_day * 24) / 112.0)
		var previous_index := floori(float((annual_day - 1) * 24) / 112.0)
		var birthdays: Array[Dictionary] = []
		for person in content.get("npcs", []):
			if int(person.get("birthday", -1)) == annual_day + 1:
				birthdays.append({"id": str(person.id), "name": str(person.name)})
		result.append({
			"day": absolute, "date": date, "season": season, "today": absolute == day,
			"festival": date == 14, "market": absolute % 7 == 5, "gathering": absolute % 7 == 6,
			"term": str(terms[term_index]) if term_index < terms.size() else "",
			"term_start": date == 1 or term_index != previous_index,
			"birthdays": birthdays
		})
	return result
