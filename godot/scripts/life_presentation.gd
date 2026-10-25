extends RefCounted
## Shared presentation policy. No save, economy, collision or navigation data.
static func animate() -> bool:
	return str(GameState.visual_fx.get("motion", "full")) == "full" and str(GameState.visual_fx.get("density", "standard")) != "off" and not GameState.ui_open and not GameState.simulation_hidden()

static func visible_rect(target: CanvasItem, margin: float = 64.0) -> Rect2:
	# Scene replacement can leave signal callbacks alive until queued deletion.
	if not is_instance_valid(target) or not target.is_inside_tree(): return Rect2()
	var viewport := target.get_viewport()
	if viewport == null: return Rect2()
	var inverse := viewport.get_canvas_transform().affine_inverse()
	var screen := target.get_viewport_rect()
	var a := inverse * screen.position
	var b := inverse * screen.end
	return Rect2(a, b - a).abs().grow(margin)

static func wildlife_available(identity: String, season: int, minutes: float, weather: Dictionary) -> bool:
	return minutes >= 420.0 and minutes < 1080.0 and int(weather.get("rain", 0)) == 0 and not bool(weather.get("extreme", false)) and not (identity == "butterfly" and season >= 2)
