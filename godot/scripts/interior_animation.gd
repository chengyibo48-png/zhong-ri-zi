extends RefCounted
## Authored poses sampled on the existing action clock; no gameplay writes.
const WORK_FRAMES := [0.0, 0.35, 1.0, 0.45, -0.3, 0.0]
static func pose(kind: String, clock: float, working: bool, action: Dictionary, point: Dictionary, enabled: bool) -> Dictionary:
	var result := {"offset":Vector2.ZERO,"rotation":0.0,"glow":0.0,"frame":0}
	if not enabled: return result
	var active: bool = not action.is_empty() and not point.is_empty() and Vector2(float(action.get("x",0)),float(action.get("y",0))).distance_to(Vector2(float(point.get("x",0)),float(point.get("y",0)))) < 28.0
	if not working and not active: return result
	var progress: float = float(action.get("progress",0)) if active else fposmod(clock*0.8,1.0)
	var frame: int = mini(5, floori(progress*6.0))
	var pulse: float = float(WORK_FRAMES[frame])
	result.frame = frame
	if "mill" in kind or "loom" in kind or "press" in kind:
		result.rotation = pulse*0.014
		result.offset = Vector2(pulse*1.1,0)
	elif "stove" in kind or "kettle" in kind or "oven" in kind or "pot" in kind:
		result.offset = Vector2(0,-absf(pulse)*0.8)
		result.glow = 0.06+absf(pulse)*0.04
	else:
		result.offset = Vector2(0,-maxf(0,pulse)*1.2)
	return result
