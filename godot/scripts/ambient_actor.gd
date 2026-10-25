extends Node2D
## Independent draw lists allow animals to move without invalidating map furniture.
const PRESENTATION := preload("res://scripts/life_presentation.gd")
const WILDLIFE := preload("res://scripts/wildlife_art.gd")
const RANCH := preload("res://scripts/ranch_visual.gd")
var definition: Dictionary = {}
var companion := false
var _clock := 0.0
var _draw_elapsed := 0.0
var _scan_elapsed := 1.0
var _on_screen := false

func _ready() -> void:
	GameState.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_scan_elapsed = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if companion:
		var saved: Dictionary = GameState.ranch.get("pet", {}).get("position", {})
		position = Vector2(float(saved.get("x", 2822)), float(saved.get("y", 1603)))
	_scan_elapsed += delta
	if _scan_elapsed >= 0.2:
		_scan_elapsed = fmod(_scan_elapsed, 0.2)
		_on_screen = PRESENTATION.visible_rect(self).has_point(global_position)
		visible = _on_screen and (companion or PRESENTATION.wildlife_available(str(definition.get("id", "")), GameState.season_index(), GameState.minutes, GameState.weather_profile()))
	if not visible:
		return
	if PRESENTATION.animate():
		_clock += minf(delta, 0.1)
	_draw_elapsed += delta
	var interval := 1.0 / 24.0 if PRESENTATION.animate() else 1.0 / 6.0
	if _draw_elapsed >= interval and (companion or PRESENTATION.animate()):
		_draw_elapsed = fmod(_draw_elapsed, interval)
		queue_redraw()

func _draw() -> void:
	var now := _clock if PRESENTATION.animate() else 0.0
	if companion:
		RANCH.pet(self, GameState.ranch.get("pet", {}), GameState.pet_state, Vector2.ZERO, GameState.ranch_actor_clock, GameState.minutes)
		if FarmWorld.hovered_pet:
			draw_arc(Vector2.ZERO, 21, 0, TAU, 24, Color("#f4e7ad"), 1.5)
	else:
		var local := definition.duplicate()
		local["x"] = 0.0
		local["y"] = 0.0
		var focused := FarmWorld.hovered_wildlife == str(definition.get("id", ""))
		WILDLIFE.draw(self, local, now, focused)
		if focused:
			draw_string(ThemeDB.fallback_font, Vector2(10, 5), str(definition.get("name", "野生伙伴")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f7edcf"))
