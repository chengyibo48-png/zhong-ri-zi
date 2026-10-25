extends RefCounted
static func safe_margins(control: CanvasItem) -> Vector2:
	if not preload("res://scripts/input_hints.gd").touch(): return Vector2(14,12)
	var size := control.get_viewport_rect().size
	var pixels := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if not safe.has_area() or pixels.x <= 0 or pixels.y <= 0: return Vector2(20,16)
	var left := maxf(0,safe.position.x)
	var right := maxf(0,float(pixels.x-safe.end.x))
	var bottom := maxf(0,float(pixels.y-safe.end.y))
	return Vector2(maxf(20,maxf(left,right)*size.x/pixels.x),maxf(16,bottom*size.y/pixels.y))
static func reserve(control: CanvasItem) -> float:
	return (108.0 if preload("res://scripts/input_hints.gd").touch() else 96.0)+safe_margins(control).y-12.0
