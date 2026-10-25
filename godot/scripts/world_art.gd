extends RefCounted
## Visual replacement only; collision, navigation and interaction remain in world data.
static var _entries: Dictionary = {}
static var _building_positions: Dictionary = {}
const NIGHT_SHADER := preload("res://art/shaders/seasonal_night.gdshader")
const NIGHT_TINTS := [Color(0.76,0.82,0.90),Color(0.70,0.80,0.87),Color(0.83,0.77,0.83),Color(0.76,0.84,0.96)]
static func entries() -> Dictionary:
	if _entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
		if parsed is Dictionary:
			_entries = parsed.get("entries", {})
			for key in _entries:
				if str(key).begins_with("buildings/"):
					var row: Dictionary = _entries[key]
					if row.has("sourcePosition"):
						_building_positions[Vector2(float(row.sourcePosition[0]), float(row.sourcePosition[1]))] = key
	return _entries
static func key_for(data: Dictionary) -> String:
	entries()
	var kind := str(data.get("kind", data.get("type", "")))
	if kind == "house":
		var id := str(data.get("id", ""))
		if id != "": return "buildings/" + id
		return str(_building_positions.get(Vector2(float(data.get("x", 0)), float(data.get("y", 0))), ""))
	return "props/" + kind
static func night_factor(minutes: float) -> float:
	if minutes < 420.0:
		return 1.0 - smoothstep(360.0, 420.0, minutes)
	return smoothstep(1140.0, 1260.0, minutes)

static func draw_prop(target: CanvasItem, data: Dictionary, season: int, minutes: float = 720.0) -> bool:
	var row: Dictionary = entries().get(key_for(data), {})
	if str(row.get("status", "missing")) != "ready" and not bool(row.get("baseReady", false)): return false
	var variants: Array = row.get("seasons", [])
	var path := str(variants[season]) if variants.size() == 4 else str(row.get("path", ""))
	var locked: bool = bool(row.get("geometryLockedSeasons", false))
	if locked: path = str(row.get("path", ""))
	var texture := preload("res://scripts/character_art.gd").texture(path)
	if texture == null: return false
	var rectangle: Array = preload("res://scripts/world_layout.gd").house_rect(key_for(data), row.get("worldRect", []))
	if data.has("_layout_rect"): rectangle = data._layout_rect
	if data.has("_visual_rect"): rectangle = data._visual_rect
	if rectangle.size() != 4: return false
	if bool(row.get("fitSourceSize",false)) and not data.has("_layout_rect") and not data.has("_visual_rect"):
		var desired_width:=float(data.get("w",rectangle[2]))
		var desired_height:=float(data.get("h",rectangle[3]))
		if desired_width<=0.0:desired_width=float(rectangle[2])
		if desired_height<=0.0:desired_height=float(rectangle[3])
		rectangle=[-desired_width*0.5,-desired_height,desired_width,desired_height]
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if key_for(data) == "props/fence" and not data.has("_layout_rect"):
		var scale_factor := clampf(float(data.get("w", 48)), 28.0, 88.0) / float(rectangle[2])
		rectangle = [float(rectangle[0])*scale_factor,float(rectangle[1])*scale_factor,float(rectangle[2])*scale_factor,float(rectangle[3])*scale_factor]
	if bool(row.get("fitLayout", false)):
		var texture_size := Vector2(texture.get_size())
		var factor := minf(float(rectangle[2]) / texture_size.x, float(rectangle[3]) / texture_size.y)
		var fitted := texture_size * factor
		rectangle = [float(rectangle[0]) + (float(rectangle[2]) - fitted.x) * 0.5, float(rectangle[1]) + float(rectangle[3]) - fitted.y, fitted.x, fitted.y]
	var width := float(rectangle[2])
	preload("res://scripts/ground_style.gd").shadow(target, Vector2(0.7, 0.5), width * 0.78, clampf(width * 0.08, 3.0, 10.0))
	if bool(row.get("rapidSeasonMaterial", false)) and target.has_node("RapidSeasonArt"):
		return true
	var draw_rect := Rect2(float(rectangle[0]), float(rectangle[1]), float(rectangle[2]), float(rectangle[3]))
	var tint: Color = preload("res://scripts/building_season_details.gd").tint(season) if locked else Color.WHITE
	target.draw_texture_rect(texture, draw_rect, false, tint)
	var states: Dictionary = row.get("states", {})
	# Each night painting belongs to its source season; preserve seasonal geometry.
	var night_path := str(states.get("night_" + str(season), ""))
	if night_path.is_empty() and season == int(row.get("nightSeason", 0)):
		night_path = str(states.get("night", ""))
	var night_alpha := night_factor(minutes)
	if key_for(data).begins_with("buildings/"):
		var night_material := target.material as ShaderMaterial
		if night_material == null or night_material.shader != NIGHT_SHADER:
			night_material = ShaderMaterial.new()
			night_material.shader = NIGHT_SHADER
			target.material = night_material
		night_material.set_shader_parameter("night_tint",NIGHT_TINTS[clampi(season,0,3)])
		night_material.set_shader_parameter("night_amount",night_alpha if night_path.is_empty() else 0.0)
	if not night_path.is_empty() and night_alpha > 0.0:
		var night_texture := preload("res://scripts/character_art.gd").texture(night_path)
		if night_texture != null:
			target.draw_texture_rect(night_texture, draw_rect, false, Color(1.0, 1.0, 1.0, night_alpha))
	if locked: preload("res://scripts/building_season_details.gd").draw(target, draw_rect, season)
	return true
