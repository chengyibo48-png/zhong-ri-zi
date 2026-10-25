extends RefCounted
## Pure profile normalization shared by creation, loading and settings.
const JS_TEXT = preload("res://scripts/js_string.gd")
const VISUAL_FX_DEFAULT := {"density": "standard", "weather": "standard", "ambient": true, "motion": "full"}
const UI_ART_DEFAULT := {"theme": "paper", "seasonal": true}
const APPEARANCE_DEFAULT := {"shirt": 0, "hair": 0, "skin": 0, "hat": true, "outfit": "field", "hairColor": 0, "bag": false, "weatherDress": true}
const FEEDBACK_PREFS_DEFAULT := {"pace": "normal", "motion": "full", "floating": "normal", "seconds": 5, "quiet": false}
const FEEDBACK_TYPES := ["收支", "照料", "社交", "提醒", "未完成"]
const FEEDBACK_LINKS := ["feedback", "bag", "farmcare", "ranch", "processing", "build", "weather", "neighbors", "economy", "fishing", "tools"]

static func visual_fx(source: Variant, legacy_feedback: Variant = {}, legacy_settings: Variant = {}) -> Dictionary:
	var values: Dictionary = source if source is Dictionary else {}
	var feedback_data: Dictionary = legacy_feedback if legacy_feedback is Dictionary else {}
	var prefs: Dictionary = feedback_data.get("prefs", {}) if feedback_data.get("prefs", {}) is Dictionary else {}
	var settings_data: Dictionary = legacy_settings if legacy_settings is Dictionary else {}
	var density := str(values.get("density", "off" if settings_data.get("particles", true) == false else VISUAL_FX_DEFAULT.density))
	if density not in ["standard", "quiet", "off"]:
		density = str(VISUAL_FX_DEFAULT.density)
	var weather := str(values.get("weather", VISUAL_FX_DEFAULT.weather))
	if weather not in ["standard", "gentle"]:
		weather = str(VISUAL_FX_DEFAULT.weather)
	var motion := str(values.get("motion", prefs.get("motion", VISUAL_FX_DEFAULT.motion)))
	if motion not in ["full", "reduced"]:
		motion = str(VISUAL_FX_DEFAULT.motion)
	return {"density": density, "weather": weather, "ambient": bool(values.get("ambient", VISUAL_FX_DEFAULT.ambient)), "motion": motion}


static func ui_art(source: Variant) -> Dictionary:
	var values: Dictionary = source if source is Dictionary else {}
	var theme_key := str(values.get("theme", UI_ART_DEFAULT.theme))
	if theme_key not in ["paper", "porcelain", "timber"]: theme_key = str(UI_ART_DEFAULT.theme)
	return {"theme": theme_key, "seasonal": bool(values.get("seasonal", UI_ART_DEFAULT.seasonal))}


static func appearance(source: Variant) -> Dictionary:
	var values: Dictionary = source if source is Dictionary else {}
	var result := APPEARANCE_DEFAULT.duplicate(true)
	result.shirt = clampi(int(values.get("shirt", result.shirt)), 0, 3)
	result.hair = clampi(int(values.get("hair", result.hair)), 0, 3)
	result.skin = clampi(int(values.get("skin", result.skin)), 0, 2)
	result.hairColor = clampi(int(values.get("hairColor", result.hairColor)), 0, 3)
	result.hat = bool(values.get("hat", result.hat))
	result.bag = bool(values.get("bag", result.bag))
	result.weatherDress = bool(values.get("weatherDress", result.weatherDress))
	var outfit := str(values.get("outfit", result.outfit))
	result.outfit = outfit if outfit in ["field", "apron", "traveler", "festival"] else "field"
	return result


static func feedback_default() -> Dictionary:
	return {"version": 1, "next": 1, "rows": [], "days": [], "seen": [], "prefs": FEEDBACK_PREFS_DEFAULT.duplicate(true)}


static func feedback(source: Variant, current_day: int, item_catalog: Dictionary) -> Dictionary:
	var result := feedback_default()
	if not source is Dictionary:
		return result
	var prefs: Dictionary = source.get("prefs", {}) if source.get("prefs", {}) is Dictionary else {}
	result.prefs = {
		"pace": str(prefs.get("pace", "normal")) if str(prefs.get("pace", "normal")) in ["normal", "brisk"] else "normal",
		"motion": str(prefs.get("motion", "full")) if str(prefs.get("motion", "full")) in ["full", "reduced"] else "full",
		"floating": str(prefs.get("floating", "normal")) if str(prefs.get("floating", "normal")) in ["normal", "compact", "off"] else "normal",
		"seconds": int(prefs.get("seconds", 5)) if int(prefs.get("seconds", 5)) in [5, 8, 12] else 5,
		"quiet": bool(prefs.get("quiet", false))
	}
	var rows: Array = []
	var used_ids: Dictionary = {}
	var highest_id := 0
	var raw_rows: Variant = source.get("rows", [])
	if raw_rows is Array:
		for raw in raw_rows:
			if not raw is Dictionary or rows.size() >= 80:
				continue
			var row_id := int(raw.get("id", 0))
			var row_type := str(raw.get("type", "提醒"))
			var row_link := str(raw.get("link", "feedback"))
			var row_day := int(raw.get("day", current_day))
			if row_id < 1 or used_ids.has(row_id) or row_day < 0 or row_day > current_day or not FEEDBACK_TYPES.has(row_type) or not FEEDBACK_LINKS.has(row_link):
				continue
			var row := {
				"id": row_id,
				"key": JS_TEXT.prefix(JS_TEXT.coerce(raw.get("key", "legacy/%d" % row_id)), 140),
				"title": JS_TEXT.prefix(JS_TEXT.coerce(raw.get("title", "手边的事有了结果")), 120),
				"text": JS_TEXT.prefix(JS_TEXT.coerce(raw.get("text", "")), 1800),
				"type": row_type,
				"priority": clampi(int(raw.get("priority", 0)), 0, 2),
				"link": row_link,
				"day": row_day,
				"minute": clampf(float(raw.get("minute", 0)), 0.0, 1320.0),
				"count": clampi(int(raw.get("count", 1)), 1, 999999),
				"read": bool(raw.get("read", true))
			}
			rows.append(row)
			used_ids[row_id] = true
			highest_id = maxi(highest_id, row_id)
	result.rows = rows
	result.next = maxi(highest_id + 1, clampi(int(source.get("next", 1)), 1, 2147483647))
	var days: Array = []
	var seen_days: Dictionary = {}
	var raw_days: Variant = source.get("days", [])
	if raw_days is Array:
		for raw_day in raw_days:
			if not raw_day is Dictionary or days.size() >= 7:
				continue
			var day_id := int(raw_day.get("day", -1))
			var item_rows: Dictionary = raw_day.get("items", {}) if raw_day.get("items", {}) is Dictionary else {}
			if day_id < 0 or day_id > current_day or seen_days.has(day_id):
				continue
			var clean_items: Dictionary = {}
			for key in item_rows:
				var parts := str(key).split(":")
				if parts.size() == 2 and item_catalog.has(parts[0]) and parts[1].is_valid_int() and int(parts[1]) in [0, 1, 2, 3]:
					clean_items[str(key).left(100)] = clampi(int(item_rows[key]), 0, 1000000000000)
			days.append({"day": day_id, "actions": clampi(int(raw_day.get("actions", 0)), 0, 1000000), "income": clampi(int(raw_day.get("income", 0)), 0, 1000000000000), "spent": clampi(int(raw_day.get("spent", 0)), 0, 1000000000000), "items": clean_items})
			seen_days[day_id] = true
	result.days = days
	var seen: Array = []
	var raw_seen: Variant = source.get("seen", [])
	if raw_seen is Array:
		for key in raw_seen:
			var token: Variant = JS_TEXT.coerce(key)
			if JS_TEXT.length(token) <= 140 and not JS_TEXT.includes(seen, token):
				seen.append(token)
			if seen.size() >= 80:
				break
	result.seen = seen
	return result

static func settings(source: Variant, defaults: Dictionary) -> Dictionary:
	var player_settings: Dictionary = source if source is Dictionary else {}
	if player_settings.get("performance", "auto") not in ["auto", "light"]: player_settings.performance = "auto"
	for key in defaults:
		if not player_settings.has(key): player_settings[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
	if str(player_settings.get("speed", "relaxed")) not in ["relaxed", "normal"]: player_settings.speed = "relaxed"
	player_settings.zoom = float(player_settings.get("zoom", 1.0)) if float(player_settings.get("zoom", 1.0)) in [1.0, 1.2, 1.4] else 1.0
	player_settings.volume = clampf(float(player_settings.get("volume", 0.2)), 0.0, 1.0)
	var audio_defaults := {"music": 0.35, "ambient": 0.3, "effects": 0.6}
	for audio_key in audio_defaults:
		player_settings[audio_key] = clampf(float(player_settings.get(audio_key, audio_defaults[audio_key])), 0.0, 1.0)
	player_settings.textScale = float(player_settings.get("textScale", 1.0)) if float(player_settings.get("textScale", 1.0)) in [1.0, 1.15, 1.3] else 1.0
	if str(player_settings.get("textSpeed", "instant")) not in ["instant", "normal", "slow"]:
		player_settings.textSpeed = "instant"
	for key in ["sound", "hints", "gamepad", "vibration", "contrast", "fishAssist"]:
		player_settings[key] = bool(player_settings.get(key, true))
	var bindings: Dictionary = player_settings.get("bindings", {}) if player_settings.get("bindings", {}) is Dictionary else {}
	var used: Dictionary = {}
	var defaults_bindings: Dictionary = defaults.get("bindings", {})
	var normalized: Dictionary = {}
	var valid := true
	for action in ["up", "left", "down", "right", "interact", "bag", "map", "journal"]:
		var value := str(bindings.get(action, defaults_bindings.get(action, "e"))).to_lower()
		var code := value.to_upper().unicode_at(0) if value.length() == 1 else 0
		if code < KEY_A or code > KEY_Z or code in [KEY_C, KEY_F, KEY_H, KEY_Q] or used.has(value):
			valid = false
		normalized[action] = value
		used[value] = true
	# Like the browser loader, reject the whole invalid mapping to avoid duplicates.
	player_settings.bindings = normalized if valid else defaults_bindings.duplicate(true)
	return player_settings
