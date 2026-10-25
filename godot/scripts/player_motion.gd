extends RefCounted
# Original app.move numerical core. Scene coordinates are display projections only.
static func step(navigation: RefCounted, state: Node, room: String, p: Dictionary, path: Array, input_x: float, input_y: float, rate: float, delta: float) -> Dictionary:
	var dx:=input_x
	var dy:=input_y
	var speed:=rate*delta
	if not path.is_empty() and dx==0.0 and dy==0.0:
		var n: Dictionary=path[0]
		var distance: float=navigation.distance(p,n)
		if distance<=speed:
			p.x=n.x
			p.y=n.y
			path.pop_front()
			return {"walking":true,"waypoint":true}
		dx=(float(n.x)-float(p.x))/distance
		dy=(float(n.y)-float(p.y))/distance
	var norm: float=navigation.distance({"x":0.0,"y":0.0},{"x":dx,"y":dy})
	if norm==0.0:return {"walking":false,"waypoint":false}
	dx=dx/norm*speed
	dy=dy/norm*speed
	p.direction=("right" if dx>0 else "left") if absf(dx)>absf(dy) else ("down" if dy>0 else "up")
	if not navigation.blocked(state,room,float(p.x)+dx,float(p.y)):p.x=float(p.x)+dx
	if not navigation.blocked(state,room,float(p.x),float(p.y)+dy):p.y=float(p.y)+dy
	return {"walking":true,"waypoint":false}
