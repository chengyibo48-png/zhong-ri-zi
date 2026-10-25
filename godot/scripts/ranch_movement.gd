extends RefCounted
# Original ranch-view runtime: double precision data, one waypoint per frame.
const NAVIGATION := preload("res://scripts/npc_navigation.gd")
var navigation = NAVIGATION.new()
var actors: Dictionary = {}

func clear(state: Node, room: String, p: Vector2) -> bool:
	return not navigation.blocked(state,room,p.x,p.y,true)

func safe_position(state: Node, room: String, p: Vector2) -> Vector2:
	var q: Dictionary = navigation.safe(state,room,{"x":p.x,"y":p.y},true)
	return Vector2(q.x,q.y)

func walk(state: Node, p: Dictionary, target: Dictionary, room: String, delta: float, speed: float, runtime: Dictionary) -> void:
	if runtime.get("target")==null or navigation.distance(runtime.target,target)>18 or runtime.get("room")!=(null if room=="" else room):
		runtime.target=target
		runtime.room=null if room=="" else room
		runtime.path=navigation.route(state,room,p,target,true)
	p.walking=false
	if runtime.get("path",[]).is_empty():return
	var q: Dictionary=runtime.path[0]
	var d: float=navigation.distance(p,q)
	var amount:=minf(d,speed*delta)
	if d>0.01:
		var dx: float=(float(q.x)-float(p.x))/d*amount
		var dy: float=(float(q.y)-float(p.y))/d*amount
		p.direction=("right" if dx>0 else "left") if absf(dx)>absf(dy) else ("down" if dy>0 else "up")
		if navigation.blocked(state,room,float(p.x)+dx,float(p.y)+dy,true):
			runtime.target=null
			runtime.path=[]
			return
		p.x=float(p.x)+dx
		p.y=float(p.y)+dy
		p.walking=true
	if d<=amount+0.1:runtime.path.pop_front()

func safe_out(state: Node, animal: Dictionary) -> bool:
	var spec: Dictionary = state.system_catalog.get("ranch",{}).get("species",{}).get(str(animal.get("type","")),{})
	var weather: String = state.weather_for(state.day)
	return not bool(animal.get("lost",false)) and int(animal.get("age",0))>=int(spec.get("adult",999999)) and not bool(animal.get("rest",false)) and not bool(animal.get("retired",false)) and float(animal.get("health",0))>=45 and float(animal.get("illness",0))<45 and str(state.ranch.get("policy","inside"))!="inside" and weather not in ["台风","寒潮","小雪","高温"] and not (str(state.ranch.get("policy","inside"))=="safe" and weather=="雨") and state.minutes>=480 and state.minutes<1050

func advance(state: Node, delta: float) -> void:
	navigation.refresh(state)
	var clock: float=state.ranch_actor_clock
	var village_clock: float=state.npc_movement.clock+delta
	var catalog: Dictionary=state.system_catalog.ranch
	var focus: Variant=null if state.ranch_actor_focus.is_empty() else state.ranch_actor_focus
	# Source distinguishes absent focus (null) from expired focus (false).
	var gathering: Variant=null if focus==null else village_clock<float(focus.until)
	var sequence: Dictionary=state.action_sequence.snapshot() if state.action_sequence.active.has("spec") else state.action_sequence.active
	for index in range(state.animals.size()):
		var a: Dictionary=state.animals[index]
		var id:=str(a.id)
		var runtime: Dictionary=actors.get(id,{})
		actors[id]=runtime
		var p: Dictionary=a.position
		var room: String="" if p.get("room")==null else str(p.room)
		var spec: Dictionary=catalog.species[str(a.type)]
		var barn: Dictionary=catalog.barns[str(spec.home)]
		var house: Dictionary=state.house_data(str(barn.house))
		if house.is_empty():continue
		var door: Dictionary=house.door
		var out:=safe_out(state,a)
		if out and not state.ranch_actor_held(id) and str(sequence.get("animalId",""))!=id:
			preload("res://scripts/ranch_care.gd").graze(state,a,delta)
		if room != "" and preload("res://scripts/ranch_care.gd").needed(state,a,state.day)>0 and float(a.hunger)<80:
			var home_barn: Dictionary = state.ranch.barns[str(spec.home)]
			var portions := 0
			for food: String in home_barn.trough:
				if preload("res://scripts/ranch_care.gd").accepts(state,a,food): portions += int(home_barn.trough[food])
			if portions>0:
				walk(state,p.inside,{"x":250,"y":492},room,delta,30,runtime)
				if navigation.distance(p.inside,{"x":250,"y":492})<6:
					preload("res://scripts/ranch_care.gd").from_trough(state,a,home_barn,state.day)
					state.ranch_actor_poses[id] = {"action":"feed","until":clock+2}
				continue
		if str(a.type)=="pig" and out and room=="" and not bool(p.get("walking",false)) and int(a.get("foundDay",-1))!=state.day and state.day%4==0:
			a.foundDay=state.day
			preload("res://scripts/ranch_products.gd").produce(state,a,"truffle",1,state._animal_quality(a,state.ranch.barns[str(spec.home)]),state.day,true)

		if state.ranch_actor_held(id) or str(sequence.get("animalId",state.action_sequence.active.get("animalId","")))==id:
			var held: Dictionary=p if room=="" else p.inside
			held.walking=false
			continue
		if room!="":
			var inside: Dictionary=p.inside
			if navigation.blocked(state,room,float(inside.x),float(inside.y),true):
				inside.merge(navigation.safe(state,room,inside,true),true)
				runtime.target=null
			if out or bool(a.get("lost",false)):
				walk(state,inside,{"x":480,"y":567},room,delta,38,runtime)
				if navigation.distance(inside,{"x":480,"y":567})<5:
					p.merge(navigation.safe(state,"",{"x":door.x,"y":float(door.y)+8},true),true)
					p.room=null
					runtime.target=null
			else:
				if runtime.get("wander")==null or clock>float(runtime.get("next",0)):
					runtime.wander=navigation.safe(state,room,{"x":335+(index%6)*55+sin(clock+index)*24,"y":485+(index%2)*38},true)
					runtime.next=clock+8
					runtime.target=null
				walk(state,inside,runtime.wander,room,delta,12 if bool(a.get("rest",false)) else 23,runtime)
		elif not out and not bool(a.get("lost",false)):
			walk(state,p,door,"",delta,55,runtime)
			if navigation.distance(p,door)<7:
				p.room=str(house.id)
				p.inside={"x":480,"y":560,"direction":"up"}
				runtime.target=null
				runtime.wander=null
		else:
			var zone_index:=int(spec.get("grazingZone",state.ranch.zone))
			var center: Dictionary={"x":3680,"y":3402} if bool(a.get("lost",false)) else focus if gathering else ({"x":3258,"y":3018} if str(a.type)=="duck" else catalog.zones[zone_index])
			if runtime.get("wander")==null or clock>float(runtime.get("next",0)) or not runtime.has("gathering") or runtime.gathering!=gathering:
				var target: Dictionary=navigation.safe(state,"",{"x":float(center.x)+sin(index*2.4+clock*0.05)*100,"y":float(center.y)+cos(index*1.8+clock*0.07)*65},true)
				var pens: Array=state.system_catalog.get("forage",{}).get("pens",[])
				if not bool(a.get("lost",false)) and not pens.is_empty():
					var pen: Dictionary=pens[zone_index]
					target={"x":maxf(float(pen.x)+36,minf(float(pen.x)+float(pen.w)-36,float(target.x))),"y":maxf(float(pen.y)+36,minf(float(pen.y)+float(pen.h)-36,float(target.y)))}
				runtime.wander=target
				runtime.next=clock+9
				runtime.gathering=gathering
				runtime.target=null
			walk(state,p,runtime.wander,"",delta,70 if gathering else 30 if str(a.type)=="cow" else 38,runtime)
	preload("res://scripts/ranch_products.gd").follow_animals(state)
	var pet: Dictionary=state.ranch.pet
	var pr: Dictionary=actors.get("pet",{})
	actors.pet=pr
	var target: Dictionary={"x":2775,"y":1690}
	if float(pet.energy)>=15 and float(pet.hunger)>=15 and state.minutes<1140:
		if str(pet.mode)=="follow" and state.current_interior=="":
			target={"x":float(state.player_source_position.x)-35,"y":float(state.player_source_position.y)+22}
		elif str(pet.mode)=="patrol":
			target={"x":3040+sin(clock*0.025)*170,"y":2750+cos(clock*0.025)*110}
	if not state.ranch_actor_held("pet"):
		walk(state,pet.position,navigation.safe(state,"",target,true),"",delta,185 if str(pet.mode)=="follow" else 82,pr)
