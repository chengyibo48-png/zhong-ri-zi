extends Node2D

var node_id := ""
var item_id := ""
var node_name := ""
var event := ""

func _draw() -> void:
	var color := Color.from_string(str(GameState.system_catalog.get("forage", {}).get("defs", {}).get(item_id, {}).get("color", "#8ca56b")), Color("8ca56b"))
	var state := GameState.forage_status(node_id, item_id, event)
	state["season"] = GameState.season_index()
	state["harvested_today"] = GameState.gathered_today(node_id)
	state["motion"] = preload("res://scripts/life_presentation.gd").animate()
	state["clock"] = GameState.ranch_actor_clock if bool(state["motion"]) else 0.0
	state["wind"] = float(GameState.weather_profile().get("wind", 4.0))
	state["weather"] = str(GameState.weather_profile().get("kind", "晴"))
	var stage := float(state.get("stage", 1.0))
	if not preload("res://scripts/forage_art.gd").draw(self, item_id, state):
		draw_circle(Vector2.ZERO, 8.0 * stage, color.darkened(0.3) if not bool(state.ready) else color)
		draw_circle(Vector2(-4, -5) * stage, 4.0 * stage, color.lightened(0.14))
	if FarmWorld.hovered_resource == node_id:
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color("e8d7a1") if bool(state.ready) else Color("aaa991"), 1.0)
		var hint := OS.get_keycode_string(GameState.bound_key("interact",KEY_E)) + " 采集" if bool(state.ready) else "休养季" if not bool(state.get("in_season",true)) else "等待适宜天气" if not bool(state.get("event_ready",true)) else "再生中 · %d 天" % int(state.get("wait",0))
		if int(state.get("wait",0)) > 1: hint += " · Delete 覆土"
		draw_string(ThemeDB.fallback_font, Vector2(-25,-19), hint, HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0ce"))
