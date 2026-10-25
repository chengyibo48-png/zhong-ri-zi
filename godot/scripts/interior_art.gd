extends RefCounted
## Independent room shells and furniture retain authored interaction coordinates.
const WORLD_ART := preload("res://scripts/world_art.gd")
const TEXTURES := preload("res://scripts/character_art.gd")
static var _furniture_regions: Dictionary = {}
const ROOM_NIGHT_WEIGHT := 0.68

static func lighting(minutes: float) -> Color:
	var evening: float = WORLD_ART.night_factor(minutes)
	return Color.WHITE.lerp(Color(0.97, 0.95, 0.89), evening)

static func draw_room(target: CanvasItem, house_id: String, minutes: float) -> bool:
	var resolved_id: String = "player_home" if house_id == "building-farm-12" else house_id
	var row: Dictionary = WORLD_ART.entries().get("interiors/" + resolved_id, {})
	if not bool(row.get("baseReady", false)): return false
	var image: Texture2D = TEXTURES.texture(str(row.get("path", "")))
	if image == null: return false
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rectangle := Rect2(102, 104, 756, 500)
	var states: Dictionary = row.get("states", {})
	var night: Texture2D = TEXTURES.texture(str(states.get("night", "")))
	if row.has("roomBase"):
		var base: Texture2D = TEXTURES.texture(str(row.roomBase))
		var base_night: Texture2D = TEXTURES.texture(str(row.get("roomBaseNight", "")))
		if base == null: return false
		var colors: Array = row.get("roomTint", [1.0, 1.0, 1.0])
		var tint := Color(float(colors[0]), float(colors[1]), float(colors[2]))
		var amount: float = WORLD_ART.night_factor(minutes)*ROOM_NIGHT_WEIGHT
		target.draw_texture_rect(base, rectangle, false, tint)
		if base_night != null and amount > 0.0: target.draw_texture_rect(base_night, rectangle, false, Color(tint.r, tint.g, tint.b, amount))
		target.draw_texture_rect(image, rectangle, false, Color(1.0, 1.0, 1.0, 1.0 - amount) if night != null else Color.WHITE)
		if night != null and amount > 0.0: target.draw_texture_rect(night, rectangle, false, Color(1.0, 1.0, 1.0, amount))
		return true
	if night == null:
		target.draw_texture_rect(image, rectangle, false, lighting(minutes))
	else:
		target.draw_texture_rect(image, rectangle, false)
		var amount: float = WORLD_ART.night_factor(minutes)*ROOM_NIGHT_WEIGHT
		if amount > 0.0: target.draw_texture_rect(night, rectangle, false, Color(1.0, 1.0, 1.0, amount))
	return true

static func draw_furniture(target: CanvasItem, row: Dictionary, minutes: float, selected: Dictionary) -> bool:
	var kind: String = str(row.get("kind", ""))
	var art: Dictionary = WORLD_ART.entries().get("interior_props/" + kind, {})
	if not bool(art.get("baseReady", false)): return false
	if kind == "搪瓷缸":
		# Small keepsakes sit on a table rather than becoming floor-sized props.
		draw_furniture(target,{"kind":"table","x":row.get("x",480),"y":row.get("y",350),"w":row.get("w",104),"h":35},minutes,{})
	var point: Dictionary = row.get("point", {})
	var focused: bool = not point.is_empty() and not selected.is_empty() and str(point.get("id", "")) == str(selected.get("id", ""))
	var running: bool = false
	if str(point.get("kind", "")) == "kitchen-station":
		for job: Dictionary in GameState.kitchen.get("jobs", []):
			if str(job.get("station", "")) == str(point.get("station", "")) and float(job.get("ready", 0)) > GameState._kitchen_now():
				running = true
				break
	var state: String = "working" if running else "focused" if focused else "night" if WORLD_ART.night_factor(minutes) >= 0.5 else "normal"
	var states: Dictionary = art.get("states", {})
	var image: Texture2D = TEXTURES.texture(str(states.get(state, art.get("path", ""))))
	if image == null: return false
	var width: float = float(row.get("w", 104)) * 1.02
	# The floor footprint is not the sprite's upright height. Tall shelves and
	# beds were being squeezed into the same 55 px limit as small tabletop props.
	var upright: float = {"bed": 94.0, "shelf": 96.0, "table": 72.0, "chair": 60.0}.get(kind, 74.0)
	var height: float = maxf(float(row.get("h", 35)) + 20.0, upright)
	if kind == "搪瓷缸": height = 16.0
	elif kind in ["小铜镜", "稻草帽"]: height = 30.0
	height = float(row.get("visualHeight", height))
	var path: String = str(states.get(state,art.get("path","")))
	if not _furniture_regions.has(path):
		var pixels := image.get_image()
		_furniture_regions[path] = Rect2(pixels.get_used_rect()) if pixels != null else Rect2(Vector2.ZERO,image.get_size())
	var region: Rect2 = _furniture_regions[path]
	if not region.has_area(): return false
	var dimensions: Vector2 = region.size
	var factor: float = minf(width / dimensions.x, height / dimensions.y)
	var size: Vector2 = dimensions * factor
	var bottom: Vector2 = Vector2(float(row.get("x", 480)), float(row.get("y", 350)) + 9.0)
	if kind == "搪瓷缸": bottom += Vector2(width * 0.23, -26.0)
	var rectangle := Rect2(bottom - Vector2(size.x * 0.5, size.y), size)
	preload("res://scripts/ground_style.gd").shadow(target, bottom, size.x * 0.82, minf(5.0, size.x * 0.055))
	var tint: Color = Color.WHITE if state == "night" and states.has("night") else lighting(minutes)
	if focused and not states.has("focused"): tint = tint.lerp(Color(1.0, 0.96, 0.83), 0.3)
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var pose: Dictionary = preload("res://scripts/interior_animation.gd").pose(kind,float(target.get_meta("furniture_clock",0.0)),running,GameState.action_snapshot(),point,preload("res://scripts/life_presentation.gd").animate())
	var pivot: Vector2 = bottom+Vector2(pose.offset)
	target.draw_set_transform(pivot,float(pose.rotation),Vector2.ONE)
	target.draw_texture_rect_region(image,Rect2(rectangle.position-bottom,rectangle.size),region,tint)
	if float(pose.glow) > 0.0:
		target.draw_circle(Vector2(0,-size.y*0.3),size.x*0.2,Color(1.0,0.68,0.26,float(pose.glow)))
	target.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	return true

