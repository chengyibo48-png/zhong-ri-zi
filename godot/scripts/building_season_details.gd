extends RefCounted
## Seasonal surface accents share the same architectural image and world rect.
static func tint(season: int) -> Color:
	return [Color.WHITE, Color(1.0, 0.99, 0.94), Color(1.0, 0.95, 0.87), Color(0.90, 0.95, 1.0)][clampi(season, 0, 3)]

static func draw(target: CanvasItem, rectangle: Rect2, season: int) -> void:
	var scale: Vector2 = rectangle.size / Vector2(512, 334)
	if season == 3:
		# Snow follows the original roof's curves; it never replaces the roof image.
		for side: float in [-1.0, 1.0]:
			for band: int in range(3):
				var points := PackedVector2Array()
				for step: int in range(17):
					var distance: float = 27.0 + step * 10.0
					var y: float = 27.0 + sin(distance / 187.0 * PI * 0.5) * 46.0 + band * 26.0
					points.append(rectangle.position + Vector2(256.0 + side * distance, y) * scale)
				target.draw_polyline(points, Color(0.93, 0.96, 1.0, 0.76 - band * 0.13), maxf(1.0, 5.5 * scale.y), true)
	elif season in [1, 2]:
		var leaf_color: Color = Color("6e965d") if season == 1 else Color("b98448")
		for side: float in [-1.0, 1.0]:
			for leaf: int in range(9):
				var center := Vector2(256.0 + side * (207.0 + sin(leaf * 0.8) * 3.0), 220.0 + leaf * 7.0)
				var polygon := PackedVector2Array()
				for step: int in range(12):
					var angle: float = step * TAU / 12.0
					polygon.append(rectangle.position + (center + Vector2(cos(angle) * 4.2, sin(angle) * 2.3)) * scale)
				target.draw_colored_polygon(polygon, leaf_color.lightened((leaf % 3) * 0.07))
