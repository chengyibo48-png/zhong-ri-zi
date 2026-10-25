extends RefCounted

var key := ""
var manual := ""
var room := ""
var options: Array[Dictionary] = []

func _number_key(value: Variant) -> String:
	var number := float(value)
	return str(int(number)) if number == float(int(number)) else String.num(number)

func target_key(point: Dictionary) -> String:
	if point.is_empty(): return ""
	var raw_identity: Variant = point.get("id", point.get("index", ""))
	var identity := _number_key(raw_identity) if raw_identity is int or raw_identity is float else str(raw_identity)
	if not point.has("id") and not point.has("index"):
		identity = _number_key(point.get("x",0)) + "," + _number_key(point.get("y",0))
	return str(point.get("kind","")) + "/" + identity

func clear() -> void:
	key = ""
	manual = ""

func choose(at: Vector2, facing: Vector2, points: Array, hover: Dictionary = {}, tool: String = "hand", room_id: String = "", readiness: Callable = Callable()) -> Dictionary:
	if room != room_id:
		clear()
		room = room_id
	var unique: Dictionary = {}
	for candidate in points:
		if not candidate is Dictionary: continue
		var point: Dictionary = candidate.duplicate(true)
		var offset := Vector2(float(point.get("x",0)),float(point.get("y",0))) - at
		var distance := offset.length()
		if distance >= 53.0: continue
		var fit := 8.0 if str(point.get("kind","")) == "plot" and tool in ["hoe","seed","water","sickle"] else 0.0
		var is_ready := bool(readiness.call(point,tool)) if readiness.is_valid() else bool(point.get("ready",true))
		point.ready = is_ready
		var available := 3.0 if is_ready else 0.0
		point.score = distance - (offset.dot(facing) / distance if distance > 0 else 1.0) * 15.0 - fit - available
		unique[target_key(point)] = point
	options.clear()
	for value in unique.values(): options.append(value)
	options.sort_custom(func(a: Dictionary,b: Dictionary):
		return float(a.score) < float(b.score) if float(a.score) != float(b.score) else target_key(a) < target_key(b))
	var best: Dictionary = options[0] if not options.is_empty() else {}
	var chosen: Dictionary = unique.get(manual,{})
	if chosen.is_empty(): manual = ""
	if chosen.is_empty(): chosen = unique.get(target_key(hover),{})
	if chosen.is_empty():
		var last: Dictionary = unique.get(key,{})
		chosen = last if not last.is_empty() and not best.is_empty() and float(last.score) <= float(best.score) + 9.0 else best
	key = target_key(chosen)
	return chosen

func cycle(direction: int = 1) -> Dictionary:
	if options.size() < 2: return options[0] if not options.is_empty() else {}
	var index := -1
	for i in range(options.size()):
		if target_key(options[i]) == key: index = i; break
	var chosen: Dictionary = options[posmod(index + direction,options.size())]
	key = target_key(chosen)
	manual = key
	return chosen

func hit(at: Vector2, points: Array) -> Dictionary:
	# Village.hit checks plots before sprite hit boxes.
	for point in points:
		if str(point.get("kind","")) != "plot": continue
		var offset := at - Vector2(float(point.get("x",0)),float(point.get("y",0)))
		if absf(offset.x) < 19 and offset.y > -20 and offset.y < 14: return point
	var best: Dictionary = {}
	var distance := INF
	for point in points:
		if str(point.get("kind","")) == "plot": continue
		var offset := at - Vector2(float(point.get("x",0)),float(point.get("y",0)))
		if absf(offset.x) >= 29 or offset.y <= -44 or offset.y >= 20: continue
		if offset.length_squared() < distance:
			distance = offset.length_squared()
			best = point
	return best
