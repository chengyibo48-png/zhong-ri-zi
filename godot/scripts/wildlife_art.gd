extends RefCounted
## Small, continuous outdoor motions for the village wildlife. All animation is visual.

static func _fallback(target: CanvasItem, wildlife: Dictionary, clock: float, hovered: bool = false) -> void:
	var id := str(wildlife.get("id", ""))
	var seed := float(abs(hash(id)) % 997) * 0.013
	var phase := clock + seed
	var at := Vector2(float(wildlife.get("x", 0.0)), float(wildlife.get("y", 0.0)))
	var bob := sin(phase * 2.1) * 1.3
	var flutter := absf(sin(phase * 13.0))
	if id == "butterfly":
		at += Vector2(sin(phase * 0.75) * 5.0, sin(phase * 1.7) * 3.0)
		var wing_color := Color("#eaa5bd") if int(floor(phase * 0.8)) % 2 == 0 else Color("#efc87b")
		var wing_h := lerpf(1.8, 5.3, flutter)
		target.draw_set_transform(at, sin(phase * 1.2) * 0.08, Vector2.ONE)
		_draw_oval(target, Vector2(-4, -1), Vector2(4.5, wing_h), wing_color)
		_draw_oval(target, Vector2(4, -1), Vector2(4.5, wing_h), wing_color)
		target.draw_line(Vector2(0, -3), Vector2(0, 3), Color("#725547"), 1.2)
		target.draw_line(Vector2(-1, -2), Vector2(-3, -5), Color("#725547"), 0.7)
		target.draw_line(Vector2(1, -2), Vector2(3, -5), Color("#725547"), 0.7)
		if int(floor(phase * 1.5)) % 4 == 0:
			target.draw_circle(Vector2(8, -8), 1.2, Color(1.0, 0.91, 0.62, 0.8))
		target.draw_set_transform(Vector2.ZERO)
	elif id == "egret":
		at += Vector2(sin(phase * 0.7) * 1.1, bob * 0.35)
		var peck := maxf(0.0, sin(phase * 0.55 - 1.4))
		target.draw_ellipse(at + Vector2(0, 5), 8.0, 2.0, Color(0.17, 0.22, 0.18, 0.22))
		target.draw_set_transform(at + Vector2(0, -peck * 3.0), 0.0, Vector2.ONE)
		_draw_oval(target, Vector2(-1, -1), Vector2(11, 6), Color("#f1eee0"))
		_draw_oval(target, Vector2(5, -7), Vector2(6, 6), Color("#fff7e5"))
		target.draw_circle(Vector2(7, -8), 0.8, Color("#354039"))
		target.draw_colored_polygon(PackedVector2Array([Vector2(8, -6), Vector2(15, -5), Vector2(8, -4)]), Color("#d99654"))
		if flutter > 0.91:
			target.draw_line(Vector2(-4, -4), Vector2(1, -1), Color("#d5d0be"), 1.4)
		target.draw_line(Vector2(-2, 3), Vector2(-3, 8), Color("#6e7865"), 1.2)
		target.draw_line(Vector2(3, 3), Vector2(4, 8), Color("#6e7865"), 1.2)
		target.draw_set_transform(Vector2.ZERO)
	else:
		var hop := maxf(0.0, sin(phase * 2.8))
		at += Vector2(sin(phase * 1.4) * 2.0, -hop * 2.0)
		target.draw_ellipse(at + Vector2(0, 4), 6.0, 1.5, Color(0.17, 0.22, 0.18, 0.22))
		target.draw_set_transform(at, sin(phase * 0.3) * 0.03, Vector2.ONE)
		_draw_oval(target, Vector2(0, 0), Vector2(10, 7), Color("#a9835d"))
		_draw_oval(target, Vector2(5, -4), Vector2(6, 6), Color("#c59c6d"))
		_draw_oval(target, Vector2(-1, 0), Vector2(5, 4), Color("#d2b17a"))
		target.draw_circle(Vector2(7, -5), 0.75, Color("#312c27"))
		target.draw_colored_polygon(PackedVector2Array([Vector2(8, -3), Vector2(13, -2), Vector2(8, -1)]), Color("#d49c56"))
		var peck := maxf(0.0, sin(phase * 0.65 - 1.0))
		target.draw_line(Vector2(2, 4), Vector2(2 + peck * 2.0, 8), Color("#81705a"), 1.0)
		target.draw_line(Vector2(6, 4), Vector2(7, 8), Color("#81705a"), 1.0)
		if int(floor(phase * 0.7)) % 5 == 0:
			target.draw_arc(Vector2(11, -13), 3.0, 3.8, 5.7, 10, Color(1.0, 0.93, 0.74, 0.65), 0.8)
		target.draw_set_transform(Vector2.ZERO)
	if hovered:
		target.draw_arc(Vector2(float(wildlife.get("x", 0.0)), float(wildlife.get("y", 0.0))), 13.0, 0.0, TAU, 20, Color("#f4e7ad"), 1.5)

static func _draw_oval(target: CanvasItem, center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	target.draw_colored_polygon(points, color)

static func activity(identity: String, clock: float) -> Dictionary:
	var t := fposmod(clock, 24.0)
	var offset := Vector2.ZERO
	var frame := 0
	var action := "idle"
	if identity == "butterfly":
		if t < 4.0:
			frame = 3
			action = "perched"
		else:
			frame = 4 + posmod(floori(clock * 8.0), 2) if t < 8.0 or t > 22.0 else [0, 1, 2, 1][posmod(floori(clock * 10.0), 4)]
			action = "flight"
			offset = Vector2(sin((t - 4.0) * PI / 10.0) * 10, -sin((t - 4.0) * PI / 20.0) * 9)
	elif t < 4.0:
		frame = 0
	elif t < 8.0:
		action = "walking" if identity == "egret" else "hopping"
		frame = 1 + posmod(floori(clock * 5.0), 2)
		offset.x = sin((t - 4) * PI / 4.0) * 7.0
		if identity == "sparrow": offset.y = -absf(sin((t - 4) * PI * 2.0)) * 2.0
	elif t < 14.0:
		action = "foraging"
		frame = 3 if posmod(floori(clock * 2), 3) > 0 else 0
	else:
		action = "flight"
		var flight := sin((t - 14.0) * PI / 10.0)
		offset = Vector2(sin((t - 14) * TAU / 10.0) * 11, -flight * (18 if identity == "egret" else 12))
		frame = 4 + posmod(floori(clock * (4 if identity == "egret" else 8)), 2)
	return {"frame":frame, "offset":offset, "action":action}

static func draw(target: CanvasItem, wildlife: Dictionary, clock: float, hovered: bool = false) -> void:
	var identity := str(wildlife.get("id", ""))
	var row: Dictionary = preload("res://scripts/world_art.gd").entries().get("wildlife/" + identity, {})
	var atlas: Texture2D = preload("res://scripts/character_art.gd").texture(str(row.get("path", ""))) if bool(row.get("baseReady", false)) else null
	if atlas == null or atlas.get_size() != Vector2(768, 384):
		_fallback(target, wildlife, clock, hovered)
		return
	var pose := activity(identity, clock)
	var index := int(pose.frame)
	var at := Vector2(float(wildlife.get("x", 0)), float(wildlife.get("y", 0)))
	var ratio := float(row.get("worldHeight", 18.0)) / 176.0
	var source := Rect2((index % 3) * 256, int(index / 3) * 192, 256, 192)
	var rectangle := Rect2(Vector2(-128, -184) * ratio, Vector2(256, 192) * ratio)
	if identity != "butterfly":
		preload("res://scripts/ground_style.gd").shadow(target, at + Vector2(pose.offset.x, 1), 7 if identity == "egret" else 4, 2)
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	target.draw_set_transform(at + Vector2(pose.offset))
	target.draw_texture_rect_region(atlas, rectangle, source)
	target.draw_set_transform(Vector2.ZERO)
	if hovered:
		target.draw_arc(at, 13, 0, TAU, 20, Color("#f4e7ad"), 1.5)
