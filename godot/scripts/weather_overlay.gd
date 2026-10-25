extends Control

var phase := 0.0
var redraw_clock := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	phase += delta
	redraw_clock += delta
	if redraw_clock >= 0.06:
		redraw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	var profile: Dictionary = GameState.weather_profile()
	var conditions: Dictionary = GameState.ground_conditions()
	var fx: Dictionary = GameState.visual_fx
	var gentle_weather := str(fx.get("weather", "standard")) == "gentle" or str(fx.get("motion", "full")) == "reduced" or str(fx.get("density", "standard")) == "off"
	var events: Array = GameState.system_catalog.get("environment", {}).get("events", [])
	var light: Dictionary = EnvironmentRules.daylight(GameState.day, GameState.minutes, events)
	var viewport_size := get_viewport_rect().size
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	if GameState.current_interior != "":
		# Night paintings already contain their room lighting.
		if float(light.night) > 0.01:
			draw_rect(bounds,Color(0.10,0.12,0.18,minf(0.06,float(light.night)*0.12)),true)
		return
	if float(conditions.wet) > 0.0:
		draw_rect(bounds, Color(0.16, 0.25, 0.34, 0.05 * float(conditions.wet)), true)
	if float(conditions.snow) > 0.0:
		draw_rect(bounds, Color(0.85, 0.91, 0.93, 0.08 * float(conditions.snow)), true)
	if str(profile.kind) == "雾":
		draw_rect(bounds, Color(0.78, 0.84, 0.78, 0.16), true)
		for band in range(3):
			var x := fposmod(phase * 7.0 + band * 241.0, viewport_size.x + 320.0) - 320.0
			preload("res://scripts/detail_art.gd").draw(self, "effects/fog", Rect2(x, viewport_size.y * (0.2 + 0.22 * band), 420, 140), Color(1, 1, 1, 0.16))
	if str(profile.kind) == "台风":
		draw_rect(bounds, Color(0.16, 0.23, 0.28, 0.17), true)
	if float(light.warm) > 0.01:
		draw_rect(bounds, Color(0.83, 0.50, 0.29, float(light.warm) * 0.18), true)
	if float(light.night) > 0.01:
		draw_rect(bounds, Color(0.05, 0.10, 0.19, minf(0.28,float(light.night))), true)
	if int(profile.rain) > 0:
		var rain_count := 48 if gentle_weather and str(profile.kind) == "台风" else 30 if gentle_weather else 90 if str(profile.kind) == "台风" else 55
		for i in range(rain_count):
			var x := fposmod(float(i * 173) + phase * (150.0 if gentle_weather and str(profile.kind) == "台风" else 80.0 if gentle_weather else 240.0 if str(profile.kind) == "台风" else 110.0), viewport_size.x + 40.0) - 20.0
			var y := fposmod(float(i * 83) + phase * (210.0 if gentle_weather else 340.0), viewport_size.y + 40.0) - 20.0
			preload("res://scripts/detail_art.gd").draw(self, "effects/rain", Rect2(x - 3, y, 6, 11), Color(1, 1, 1, 0.32 if gentle_weather else 0.43))
	if bool(profile.snow):
		for i in range(18 if gentle_weather else 38):
			var x := fposmod(float(i * 151) + sin(phase + float(i)) * (9.0 if gentle_weather else 18.0), viewport_size.x + 20.0) - 10.0
			var y := fposmod(float(i * 109) + phase * (14.0 if gentle_weather else 25.0), viewport_size.y + 20.0) - 10.0
			preload("res://scripts/detail_art.gd").draw(self, "effects/snow", Rect2(x - 2, y - 2, 4, 4), Color(1, 1, 1, 0.48 if gentle_weather else 0.64))
	if float(profile.wind) >= 8.0 and not gentle_weather:
		for i in range(3):
			var at := Vector2(fposmod(phase * 36.0 + i * 281.0, viewport_size.x + 60) - 60, viewport_size.y * (0.22 + i * 0.24))
			preload("res://scripts/detail_art.gd").draw(self, "effects/wind", Rect2(at, Vector2(40, 15)), Color(1, 1, 1, 0.14))
