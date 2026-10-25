extends RefCounted
## Seasonal painted stages follow the existing ecological rules and harvest dates.
static func descriptor(item: String, status: Dictionary) -> Dictionary:
	var row: Dictionary = preload("res://scripts/world_art.gd").entries().get("forage/" + item, {})
	if not bool(row.get("baseReady", false)): return {}
	var bounds: Array = row.get("worldRect", [])
	if bounds.size() != 4: return {}
	var seasonal: Texture2D = preload("res://scripts/character_art.gd").texture(str(row.get("seasonalAtlas", "")))
	var stage := clampf(float(status.get("stage", 1.0)), 0.0, 1.0)
	var season := clampi(int(status.get("season", 0)), 0, 3)
	if seasonal != null and seasonal.get_size() == Vector2(1024, 576):
		var phase := 0 if bool(status.get("harvested_today",false)) or stage < 0.35 else 1 if stage < 0.85 else 2
		var ratio := float(bounds[3]) / 176.0
		return {"texture":seasonal, "source":Rect2(season * 256, phase * 192, 256, 192), "destination":Rect2(Vector2(-128, -184) * ratio, Vector2(256, 192) * ratio), "stage":phase, "paintedSeason":true}
	var texture: Texture2D = preload("res://scripts/character_art.gd").texture(str(row.get("path", "")))
	if texture == null: return {}
	var factor := lerpf(0.22, 1.0, stage)
	return {"texture":texture, "source":Rect2(Vector2.ZERO, texture.get_size()), "destination":Rect2(float(bounds[0]) * factor, float(bounds[1]) * factor, float(bounds[2]) * factor, float(bounds[3]) * factor), "stage":0 if stage < 0.35 else 1 if stage < 0.85 else 2, "paintedSeason":false}

static func draw(target: CanvasItem, item: String, status: Dictionary) -> bool:
	var art := descriptor(item, status)
	if art.is_empty(): return false
	var rect: Rect2 = art.destination
	var tint := Color.WHITE
	if not bool(status.get("in_season", true)): tint = Color(0.87, 0.89, 0.87)
	if str(status.get("weather", "")) in ["雨", "台风", "雾"]: tint = tint.lerp(Color("#c3d2d4"), 0.12)
	var biological := item != "wood"
	var phase := float(status.get("clock", 0.0))
	var strength := clampf(float(status.get("wind", 4.0)) / 8.0, 0.2, 2.0)
	var sway := sin(phase * 1.8 + float(item.length())) * 0.018 * strength if biological and bool(status.get("motion", false)) else 0.0
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preload("res://scripts/ground_style.gd").shadow(target, Vector2(0.5, 0.5), rect.size.x * 0.62, 2.5)
	target.draw_set_transform(Vector2.ZERO, sway)
	target.draw_texture_rect_region(art.texture, rect, art.source, tint)
	target.draw_set_transform(Vector2.ZERO)
	return true
