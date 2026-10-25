extends Control
class_name CharacterPortrait

var character_key := ""
var painted_active := false
var character_data: Dictionary = {}
var appearance: Dictionary = {}
var emotion := "calm"
var rain := false
var cold := false
var festival := false

func configure(key: String, person: Dictionary = {}, next_emotion: String = "calm") -> void:
	character_key = key
	character_data = person.duplicate(true)
	var styles: Dictionary = GameState.system_catalog.get("art", {}).get("characters", {})
	appearance = styles.get(character_key, {}).duplicate(true)
	if appearance.is_empty():
		appearance = {"shirt": str(person.get("color", "#427660")), "accent": "#dfc18d", "skin": "#e3b991", "hair": "short", "hairColor": "#394337"}
	emotion = next_emotion if next_emotion in ["calm", "happy", "focus", "thought", "worried", "surprised", "tired"] else "calm"
	var weather: Dictionary = GameState.weather_profile()
	rain = int(weather.get("rain", 0)) > 0
	cold = int(weather.get("season", 0)) == 3
	festival = posmod(GameState.day, 28) == 13
	queue_redraw()

func _pixel(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), maxi(1, roundi(width)), maxi(1, roundi(height))), color, true)

func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _ellipse(cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
	draw_colored_polygon(points, color)

func _draw_hair(hair_color: Color, x: int, y: int, width: int, height: int) -> void:
	_pixel(x - 1, y, width + 2, 4, hair_color)
	_pixel(x, y - 2, width, 4, hair_color)
	_pixel(x - 2, y + 3, 3, height * 0.65, hair_color)
	_pixel(x + width - 1, y + 3, 3, height * 0.62, hair_color)
	var hair_kind := str(appearance.get("hair", "short"))
	if hair_kind in ["bob", "braid", "pony"]:
		_pixel(x - 3, y + 4, 4, height + 3, hair_color)
		_pixel(x + width - 1, y + 3, 4, height + 3, hair_color)
	if hair_kind == "bun":
		_pixel(x + width - 4, y - 6, 7, 6, hair_color)
	elif hair_kind == "pony":
		_pixel(x + width, y, 5, height + 7, hair_color)
	elif hair_kind == "pigtail":
		_pixel(x - 6, y + 4, 5, 10, hair_color)
		_pixel(x + width + 1, y + 4, 5, 10, hair_color)
		_pixel(x - 6, y + 4, 5, 2, Color("#c97165"))
		_pixel(x + width + 1, y + 4, 5, 2, Color("#c97165"))
	elif hair_kind == "wave":
		_pixel(x - 2, y - 2, 5, 6, hair_color)
		_pixel(x + 4, y - 3, 5, 6, hair_color)
		_pixel(x + width - 6, y - 1, 7, 6, hair_color)
	_pixel(x + 2, y + 1, maxi(3, width - 6), 1, Color(1.0, 1.0, 1.0, 0.12))

func _draw_prop(kind: String) -> void:
	if kind == "":
		return
	draw_set_transform(Vector2(48, 69), 0.0, Vector2.ONE * 0.85)
	match kind:
		"book", "mail", "seedbag", "medical":
			var prop_color := Color("#e0c486") if kind == "book" else Color("#dde1bd") if kind == "mail" else Color("#f1ecda") if kind == "medical" else Color("#b89859")
			_pixel(-5, -8, 10, 14, prop_color)
			_pixel(-4, -6, 2, 10, Color("#847249") if kind == "book" else Color("#79917b"))
			_pixel(-1, -4, 4, 2, Color("#fff1c4"))
			if kind == "medical":
				_pixel(-1, -3, 2, 7, Color("#7caaa0"))
				_pixel(-3, -1, 6, 2, Color("#7caaa0"))
		"camera":
			_pixel(-7, -6, 14, 9, Color("#374950"))
			_pixel(-3, -8, 6, 3, Color("#596971"))
			_pixel(-3, -5, 7, 7, Color("#b1bdb1"))
			_pixel(-1, -3, 3, 3, Color("#34484c"))
		"hammer", "wrench":
			_pixel(-1, -9, 2, 21, Color("#ab8150"))
			_pixel(-5, -10, 10, 5, Color("#586e70") if kind == "hammer" else Color("#849b9b"))
			if kind == "wrench": _pixel(-2, -12, 4, 3, Color("#cfba8b"))
		"basket", "tea":
			_pixel(-7, -6, 14, 12, Color("#b69559"))
			for index in range(3):
				_pixel(-6, -4 + index * 3, 12, 1, Color("#ddc584"))
			_pixel(-5, -10, 10, 2, Color("#a98c52"))
			if kind == "tea": _pixel(-4, -9, 7, 4, Color("#64975e"))
		"net":
			_pixel(0, -12, 2, 27, Color("#a08958"))
			draw_rect(Rect2(-6, -13, 14, 12), Color("#b9ccb2"), false, 1.0)
			for index in range(3): _pixel(-4 + index * 4, -12, 1, 10, Color("#d1d9b6"))
		"tray", "bowl":
			_pixel(-8, -2, 17, 4, Color("#ddd8b8"))
			for index in range(3): _pixel(-6 + index * 5, -6, 4, 4, Color("#96a16a") if kind == "bowl" else Color("#f1dfaf"))
		"fan":
			_poly([Vector2(-9, -6), Vector2(0, -12), Vector2(10, -5), Vector2(1, 4)], Color("#d9c695"))
			_pixel(0, 1, 2, 9, Color("#a28756"))
		"pinwheel":
			_pixel(0, -6, 1, 20, Color("#a38452"))
			_poly([Vector2(0, -5), Vector2(-7, -12), Vector2(-7, -3)], Color("#d09559"))
			_poly([Vector2(0, -5), Vector2(7, -12), Vector2(6, -3)], Color("#d09559"))
			_poly([Vector2(0, -5), Vector2(7, 3), Vector2(-1, 2)], Color("#d09559"))
			_poly([Vector2(0, -5), Vector2(-7, 3), Vector2(-7, -3)], Color("#d09559"))
			_pixel(0, -5, 2, 2, Color("#f3d499"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	painted_active = false
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var painted: Texture2D = preload("res://scripts/character_art.gd").portrait(character_key, emotion)
	if painted != null and not (rain or cold or festival):
		painted_active = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var ratio := minf(size.x / painted.get_width(), size.y / painted.get_height())
		var displayed := Vector2(painted.get_size()) * ratio
		draw_texture_rect(painted, Rect2((size - displayed) * 0.5, displayed), false)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 64.0, size.y / 80.0))
	var shirt := Color("#677f70") if rain else Color.from_string(str(appearance.get("shirt", "#427660")), Color("#427660"))
	var accent := Color.from_string(str(appearance.get("accent", "#dfc18d")), Color("#dfc18d"))
	var skin := Color.from_string(str(appearance.get("skin", "#e3b991")), Color("#e3b991"))
	var hair_color := Color.from_string(str(appearance.get("hairColor", "#394337")), Color("#394337"))

	_pixel(0, 0, 64, 80, Color("#e7ddbd"))
	_pixel(2, 2, 60, 76, Color("#bbcbd0") if rain else Color("#c4d2cf") if cold else Color("#d3ddbf"))
	_poly([Vector2(2, 64), Vector2(14, 48), Vector2(31, 57), Vector2(50, 37), Vector2(62, 48), Vector2(62, 78), Vector2(2, 78)], Color("#a6bba0"))
	for index in range(4):
		_pixel(7 + index * 2, 8 + index * 5, 1, 13, Color("#94ab8c"))
		_pixel(4 + index * 2, 10 + index * 5, 7, 1, Color("#94ab8c"))

	_ellipse(32, 77, 22, 4.5, Color(0.10, 0.16, 0.13, 0.22))
	_poly([Vector2(13, 79), Vector2(14, 59), Vector2(25, 51), Vector2(40, 51), Vector2(51, 60), Vector2(53, 79)], Color("#344a42"))
	_poly([Vector2(16, 79), Vector2(17, 60), Vector2(27, 53), Vector2(38, 53), Vector2(48, 61), Vector2(50, 79)], shirt)
	_pixel(28, 43, 11, 11, skin)
	_poly([Vector2(20, 56), Vector2(23, 52), Vector2(32, 60), Vector2(41, 52), Vector2(46, 57), Vector2(39, 65), Vector2(31, 60), Vector2(25, 65)], accent)

	_pixel(22, 20, 24, 29, Color("#514333"))
	_pixel(23, 22, 22, 27, skin)
	_pixel(20, 31, 3, 9, skin)
	_pixel(45, 31, 3, 9, skin)
	_pixel(24, 25, 3, 16, Color(1.0, 0.90, 0.72, 0.17))
	_pixel(42, 30, 2, 17, Color(0.64, 0.43, 0.32, 0.16))
	_pixel(27, 33, 4, 3, Color("#394032"))
	_pixel(38, 33, 4, 3, Color("#394032"))
	_pixel(28, 33, 1, 1, Color("#f2e4c8"))
	_pixel(39, 33, 1, 1, Color("#f2e4c8"))
	_pixel(33, 37, 2, 4, Color("#bc8564"))
	_pixel(31, 44, 7, 1, Color("#ab6c54"))
	_pixel(25, 39, 4, 2, Color(0.82, 0.55, 0.44, 0.20))
	_pixel(40, 39, 4, 2, Color(0.82, 0.55, 0.44, 0.20))
	var closed_eyes := emotion == "tired"
	for eye_x in [26, 37]:
		_pixel(eye_x, 30, 5, 1, hair_color)
		_pixel(eye_x, 33, 4, 1 if closed_eyes else 3, Color("#394237"))
		if not closed_eyes: _pixel(eye_x + 1, 33, 1, 1, Color("#faf1d9"))
	_pixel(32, 36, 2, 4, Color("#bc8564"))
	if emotion == "happy":
		_pixel(32, 44, 3, 1, Color("#98654e"))
	elif emotion == "surprised":
		_pixel(32, 42, 3, 3, Color("#98654e"))
	if emotion in ["thought", "worried", "focus"]:
		_pixel(27, 29, 4 if emotion == "focus" else 2, 1, hair_color)
	_draw_hair(hair_color, 20, 20, 26, 19)
	_pixel(23, 23, 5, 3, hair_color)
	_pixel(28, 23, 4, 2, hair_color)

	if bool(appearance.get("glasses", false)):
		draw_rect(Rect2(24, 32, 8, 5), Color("#53554a"), false, 1.0)
		draw_rect(Rect2(35, 32, 8, 5), Color("#53554a"), false, 1.0)
		_pixel(32, 33, 3, 1, Color("#53554a"))
	if bool(appearance.get("hat", false)) or rain:
		var hat_color := Color("#aa9d65") if rain else Color("#c5a361")
		_poly([Vector2(13, 21), Vector2(22, 10), Vector2(43, 10), Vector2(53, 21)], hat_color)
		_pixel(10, 21, 46, 4, Color("#d9c087"))
		_pixel(18, 19, 29, 2, Color("#876f3e"))
		_pixel(23, 11, 17, 2, Color("#e8d297"))
	elif bool(appearance.get("cap", false)):
		_pixel(20, 15, 29, 7, accent)
		_pixel(29, 21, 24, 3, accent.darkened(0.15))
	if festival:
		_pixel(45, 27, 4, 5, Color("#b85848"))
		_pixel(46, 32, 2, 6, Color("#e8c77c"))
	if bool(appearance.get("apron", false)):
		_pixel(24, 64, 19, 16, accent)
	if bool(appearance.get("vest", false)):
		_pixel(18, 61, 9, 19, accent)
		_pixel(39, 61, 9, 19, accent)
	_draw_prop(str(appearance.get("prop", "")))
	if cold:
		_pixel(24, 51, 18, 5, accent)
		_pixel(38, 55, 5, 16, accent)
		_pixel(38, 68, 5, 2, Color("#ebe2c6"))
	if rain:
		_pixel(7, 30, 1, 8, Color("#e7f0db"))
		_pixel(54, 9, 1, 7, Color("#e7f0db"))
	_pixel(0, 0, 64, 2, Color("#9dab8c"))
	_pixel(0, 78, 64, 2, Color("#9dab8c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
