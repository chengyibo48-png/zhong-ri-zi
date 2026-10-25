extends RefCounted
## Hand-painted character sheets keep the existing game action clock and feet.
static var _data: Dictionary = {}
static var _textures: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json"))
		if parsed is Dictionary: _data = parsed
	return _data

static func texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	if path == "": return null
	var result: Texture2D
	if ResourceLoader.exists(path):
		result = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty(): return null
		result = ImageTexture.create_from_image(image)
	if result != null: _textures[path] = result
	return result

static func has_clip(actor: String, clip: String) -> bool:
	var entry: Dictionary = data().get("actors", {}).get(actor, {})
	var spec: Dictionary = entry.get("clips", {}).get(clip, {})
	return not spec.is_empty() and (bool(entry.get("ready", false)) or bool(spec.get("ready", false)))

static func draw_actor(target: CanvasItem, actor: String, clip: String, direction: String, time: float, progress: float = -1.0, player_appearance: Dictionary = {}) -> bool:
	var entry: Dictionary = data().get("actors", {}).get(actor, {})
	if not has_clip(actor, clip): return false
	# Full customization continues to use its original renderer until matching
	# painted layers exist. A single painted body must not erase saved appearance.
	if actor == "player":
		for key in data().get("playerProfile", {}):
			if player_appearance.get(key) != data().playerProfile[key]: return false
	var spec: Dictionary = entry.get("clips", {}).get(clip, {})
	if spec.is_empty(): return false
	var sheet := texture(str(spec.get("path", "")))
	if sheet == null: return false
	var directions: Array = spec.get("directions", [])
	var row := directions.find(direction)
	if row < 0: return false
	var dimensions: Array = spec.get("frameSize", [128, 128])
	var cell := Vector2(float(dimensions[0]), float(dimensions[1]))
	var count := maxi(1, int(spec.get("frames", 1)))
	if sheet.get_width() != int(cell.x) * count or sheet.get_height() != int(cell.y) * directions.size(): return false
	var frame := mini(count - 1, floori(clampf(progress, 0.0, 1.0) * count)) if progress >= 0.0 else posmod(floori(time * float(spec.get("fps", 8))), count)
	var source := Rect2(Vector2(frame * cell.x, row * cell.y), cell)
	var anchor_values: Array = spec.get("anchor", [64, 116])
	var anchor := Vector2(float(anchor_values[0]), float(anchor_values[1]))
	var ratio := float(spec.get("worldHeight", 42)) / 108.0
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preload("res://scripts/ground_style.gd").shadow(target, Vector2(0, 0.6), 52.0 * ratio, 14.0 * ratio)
	target.draw_texture_rect_region(sheet, Rect2(-anchor * ratio, cell * ratio), source)
	return true

static func portrait(actor: String, emotion: String) -> Texture2D:
	var entry: Dictionary = data().get("actors", {}).get(actor, {})
	return texture(str(entry.get("portraits", {}).get(emotion, "")))
