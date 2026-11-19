extends RefCounted
## Display scale is independent of collision footprints and saved world coordinates.
const FLORA := ["tree", "willow", "orchard", "blossom", "bamboo"]
static var doors: Array[Vector2] = []
static func configure(houses: Array) -> void:
	doors.clear()
	for house: Dictionary in houses:
		var door: Dictionary=house.get("door",{})
		if not door.is_empty():doors.append(Vector2(float(door.x),float(door.y)))
static func rectangle(data: Dictionary, base: Array) -> Array:
	if base.size() != 4: return base
	var kind := str(data.get("kind", data.get("type", "")))
	if kind not in FLORA: return base
	var height := float(base[3])
	if height <= 0.0: return base
	var seed_value := posmod(int(float(data.get("x", 0))) * 17 + int(float(data.get("y", 0))) * 31, 101)
	var scale_factor: float = float({"tree":2.05,"willow":2.1,"orchard":1.65,"blossom":1.75,"bamboo":2.15}.get(kind, 1.0)) * lerpf(0.9, 1.12, float(seed_value)/100.0)
	# Small intentionally planned courtyard plants retain their decorative role.
	if height < 32.0: scale_factor = minf(scale_factor, 1.3)
	var foot := Vector2(float(data.get("x", 0)), float(data.get("y", 0)))
	for door: Vector2 in doors:
		var distance := foot.distance_to(door)
		if distance < 105.0: scale_factor = minf(scale_factor, 1.35)
	return [float(base[0])*scale_factor, float(base[1])*scale_factor, float(base[2])*scale_factor, height*scale_factor]
