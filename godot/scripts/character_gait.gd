extends RefCounted
## Presentation-only heel contact, support, toe-off and swing for a distance-owned cycle.
static func _ease(value:float)->float:
	var p:=clampf(value,0,1)
	return p*p*p*(p*(p*6.0-15.0)+10.0)
static func leg(phase:float)->Dictionary:
	var p:=fposmod(phase,1.0)
	var support:=p<.58
	var t:=p/.58 if support else (p-.58)/.42
	var travel:=1.0-2.0*_ease(t) if support else -1.0+2.0*_ease(t)
	var lift:=0.0 if support else pow(maxf(0,sin(t*PI)),1.3)*2.3
	var toe:=lerpf(-.10,.11,_ease(t)) if support else -.16*sin(t*PI)
	return {"travel":travel,"lift":lift,"toe":toe,"support":support}
static func sample(phase:float,weight:float=1.0)->Dictionary:
	var p:=fposmod(phase,1.0);var amount:=clampf(weight,0,1)
	var near:=leg(p);var far:=leg(p+.5)
	var transfer:=sin(TAU*(p-.035))*amount
	return {"near":near,"far":far,"weight":amount,"pelvis":transfer*.52,"drop":(.28+.28*cos(TAU*p*2.0))*amount,"roll":sin(TAU*(p+.025))*.022*amount,"arm":-cos(TAU*(p-.055))*amount,"head":sin(TAU*(p-.11))*.012*amount}
