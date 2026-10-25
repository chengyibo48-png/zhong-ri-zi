extends RefCounted
# Source Actions.approach chooses the first clear, reachable ring candidate.
static func approach(navigation: RefCounted,state: Node,room: String,position: Dictionary,target: Dictionary) -> Dictionary:
 var x:=float(target.x)
 var y:=float(target.y)
 var fallback:={"x":x,"y":y+5.0}
 var kind:=str(target.get("kind",""))
 if kind in ["animal","ranch-task"]:fallback.y=y
 if kind in ["walk","enter","exit"]:return fallback
 var angle:=preload("res://scripts/js_navigation_math.gd").angle(float(position.y)-y,float(position.x)-x)
 var radius:=38.0 if kind in ["animal","ranch-task","npc"] else 30.0
 for ring in [radius,24.0,16.0]:
  for offset in [0.0,0.6,-0.6,1.2,-1.2,PI]:
   var candidate:={"x":x+cos(angle+float(offset))*float(ring),"y":y+sin(angle+float(offset))*float(ring)}
   if not navigation.blocked(state,room,candidate.x,candidate.y) and navigation.line_clear(state,room,candidate,fallback) and not navigation.route(state,room,position,candidate).is_empty():return candidate
 return fallback
