extends RefCounted
## Pure task envelope validation: safe to preload before autoloads exist.
static func validate(value: Variant, day: int) -> bool:
	if not value is Dictionary or int(value.get("version",-1))!=1:return false
	if not value.get("collapsed") is bool or not value.get("notices") is Dictionary or not (value.get("sequence") is int or value.get("sequence") is float) or float(value.sequence)!=floor(float(value.sequence)) or float(value.sequence)<0:return false
	if not value.get("entries") is Dictionary or not value.get("metrics") is Dictionary or not value.get("pins") is Array or value.pins.size()>2 or not value.get("seen") is Array or value.seen.size()>1024:return false
	for id: Variant in value.entries:
		if not id is String or id.length()>160 or not value.entries[id] is Dictionary or value.entries.size()>1024:return false
		var e: Dictionary=value.entries[id]
		if str(e.get("status","")) not in ["active","completed","expired","abandoned"]:return false
		for field: String in ["acceptedDay","deadline","baseline","completedDay"]:
			if e.has(field) and (not e[field] is int and not e[field] is float or float(e[field])!=floor(float(e[field])) or float(e[field])<(-1 if field=="deadline" else 0) or float(e[field])>1000000000):return false
		if int(e.get("acceptedDay",0))>day:return false
		if str(id).begins_with("weekly:"):
			var d: Variant=e.get("definition")
			if not d is Dictionary or str(d.get("id",""))!=id or str(d.get("kind",""))!="weekly" or str(d.get("source",""))!="coop" or not d.get("order") is Dictionary:return false
			var order: Dictionary=d.order
			if str(order.get("key",""))!=str(d.get("ref","")) or not order.get("id") is String:return false
			for field: String in ["qty","grade","bonus"]:
				if not order.has(field) or not (order[field] is int or order[field] is float) or float(order[field])!=floor(float(order[field])) or float(order[field])<0:return false
			if int(order.qty)<1 or int(order.qty)>999999 or int(order.grade)>3 or int(order.bonus)>10000:return false
			if int(e.get("deadline",-1))!=(int(int(e.acceptedDay)/7)+1)*7 or int(d.get("deadline",-2))!=int(e.deadline):return false
			if d.get("needs",{})!={str(order.id):order.qty} or int(d.get("grade",-1))!=int(order.grade) or not d.get("reward",{}).is_empty() or int(d.get("money",0))!=0:return false
	for n: Variant in value.metrics.values():
		if not (n is int or n is float) or float(n)<0 or float(n)>1000000000 or float(n)!=floor(float(n)):return false
	var distinct_pins: Dictionary={}
	for id: Variant in value.pins:
		if not id is String or distinct_pins.has(id):return false
		distinct_pins[id]=true
	for notice: Variant in value.notices.values():
		if not notice is String or notice.length()>100:return false
	for token: Variant in value.seen:
		if not token is String or token.length()>200:return false
	return true

