extends RefCounted
const NAVIGATION = preload("res://scripts/npc_navigation.gd")
var navigation = NAVIGATION.new()
var actors: Dictionary = {}
var clock := 0.0

func face(p: Dictionary, player: Dictionary) -> void:
	var dx := float(player.x)-float(p.x); var dy := float(player.y)-float(p.y)
	p.direction = ("right" if dx>0 else "left") if absf(dx)>absf(dy) else ("down" if dy>0 else "up")

func advance(state: Node, delta: float) -> void:
	clock += delta
	navigation.refresh(state)
	state.ensure_neighbor_events()
	var index := 0
	for person in state.npc_catalog:
		update_actor(state,person,index,delta)
		index += 1

func update_actor(state: Node, person: Dictionary, index: int, delta: float) -> void:
	var npc_id := str(person.id)
	var p: Dictionary = state.npc_residents[npc_id]
	var a: Dictionary = actors.get(npc_id,{"wait":2.0+index*0.31,"path":[],"phase":"","walking":false})
	actors[npc_id] = a
	var plan: Dictionary = state.npc_dialogue_activity(person)
	var room: String = str(p.room) if p.get("room") != null else ""
	var house: Dictionary = state.house_data(room if room != "" else str(plan.room) if plan.room != null else "")
	if house.is_empty():
		for h in state.world_village.get("houses",[]):
			if str(h.get("owner","")) == npc_id: house = h; break
	var player: Dictionary=state.player_navigation_position()
	var sequence: Dictionary = state.action_sequence.snapshot() if state.action_sequence.active.has("spec") else state.action_sequence.active
	if sequence.get("npcId", "") == npc_id:
		a.walking = false
		var here: Dictionary = a.get("inside",{}) if room != "" else p
		if not here.is_empty(): face(here,player)
		a.emotion = "focus"; a.emotionUntil = clock+2.0
		return
	var key := "%d/%s/%s/%s/%s" % [state.day,str(plan.key),str(plan.room),str(plan.target_point.x),str(plan.target_point.y)]
	if str(a.get("scheduleKey","")) != key:
		a.merge({"scheduleKey":key,"plan":plan,"phase":plan.key,"target":null,"path":[],"wait":0.0,"insideRt":{"path":[],"wait":0.0},"goal":navigation.safe(state,"",plan.target_point,true),"failures":0},true)
	a.activity = plan.label; a.gesture = plan.gesture
	if room != "":
		if not a.get("inside") is Dictionary: a.inside = navigation.safe(state,room,{"x":480.0,"y":560.0,"direction":"up"})
		var q: Dictionary = a.insideRt
		if room != str(plan.room):
			var door := {"x":480.0,"y":590.0}
			for object in state.system_catalog.get("interiors",{}).get("layouts",{}).get(room,{}).get("points",[]):
				if str(object.get("kind","")) == "exit": door = object; break
			a.walking = navigation.step(state,a.inside,door,delta,48.0,q,room)
			if navigation.distance(a.inside,door) < 8.0:
				p.room = null; p.merge(house.get("door",{}),true); a.path = []; a.target = null; a.inside = null
			return
		if state.current_interior == room and navigation.distance(a.inside,player) < 60.0:
			a.walking = false; face(a.inside,player); return
		if float(q.wait)>0:
			q.wait = float(q.wait)-delta; a.walking = false; return
		if not q.get("target") is Dictionary:
			var choices: Array = []
			for object in state.system_catalog.get("interiors",{}).get("layouts",{}).get(room,{}).get("points",[]):
				if str(object.get("kind","")) in ["egg","tea","bed-visit"]: choices.append(object)
			var target: Dictionary = choices[posmod(floori(clock/18.0)+index,choices.size())] if not choices.is_empty() else {"x":480.0,"y":450.0}
			q.target = navigation.safe(state,room,{"x":float(target.x),"y":float(target.y)+25.0})
		a.walking = navigation.step(state,a.inside,q.target,delta,34.0,q,room)
		if q.path.is_empty(): q.target = null; q.wait = 5.0+index%5
		return
	if state.current_interior == "" and navigation.distance(p,player) < 60.0:
		a.walking = false; face(p,player); return
	if bool(plan.indoors):
		a.walking = navigation.step(state,p,house.door,delta,64.0 if int(person.get("age",0))>60 else 96.0,a)
		if navigation.distance(p,house.door)<8.0:
			p.room = str(house.id); a.inside = navigation.safe(state,str(house.id),{"x":480.0,"y":560.0,"direction":"up"}); a.path = []; a.walking = false
		return
	if float(a.wait)>0:
		a.wait = float(a.wait)-delta; a.walking = false; return
	if not a.get("target") is Dictionary:
		var arrived := navigation.distance(p,a.goal)<90.0
		a.target = navigation.safe(state,"",{"x":float(a.goal.x)+sin(clock*0.12+index)*38.0,"y":float(a.goal.y)+cos(clock*0.1+index)*22.0},true) if arrived else a.goal
	a.walking = navigation.step(state,p,a.target,delta,103.0 if str(person.get("tier",""))=="child" else 64.0 if int(person.get("age",0))>60 else 92.0,a)
	if a.path.is_empty():
		if navigation.distance(p,a.target)>15.0:
			a.failures = int(a.failures)+1
			a.goal = navigation.safe(state,"",house.door if int(a.failures)>2 else {"x":float(a.goal.x)+24.0,"y":float(a.goal.y)+24.0},true)
			a.activity = "绕到附近可通行处"
		a.target = null; a.wait = 4.0+index%5; a.walking = false

func publish(state: Node) -> void:
	state.npc_positions.clear()
	state.interior_npc_positions.clear()
	for person in state.npc_catalog:
		var id := str(person.id); var p: Dictionary = state.npc_residents.get(id,{})
		if p.is_empty(): continue
		if p.get("room") == null:
			state.npc_positions[id] = Vector2(float(p.x),float(p.y))
		elif str(p.room) == state.current_interior:
			var inside: Dictionary = actors.get(id,{}).get("inside",{})
			if inside.is_empty(): inside = {"x":565.0,"y":430.0,"direction":"left"}
			state.interior_npc_positions[id] = Vector2(float(inside.x),float(inside.y))
