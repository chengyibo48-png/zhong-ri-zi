extends RefCounted
const ID="ranch-meadow"
const SIZE=Vector2(3776,2048)
const ENTRY=Vector2(2670,2556)
const EXIT=Vector2(1536,1900)
const HOUSE={"id":ID,"name":"东坡大牧野","x":2646,"y":2516,"w":48,"h":40,"door":{"x":2670,"y":2556},"kind":"pasture","region":"pasture"}
const NAMES=["牛群西草甸","牛群东草甸","绵羊轮牧地","山羊缓坡地","鸡群觅食园","鸭群塘畔地","猪群拱土园","兔群苜蓿地","马匹舒展地","羊驼草甸"]
const BY_SPECIES={"cow":[0,1],"sheep":[2,3],"goat":[2,3],"hen":[4],"duck":[5],"pig":[6],"rabbit":[7],"horse":[8],"alpaca":[9],"goose":[5]}
const SLOT_ORDER=[0,19,7,12,4,15,2,17,9,10,1,18,6,13,3,16,5,14,8,11]
static var obstacles:Array[Rect2]=[]
static func pen(index:int)->Rect2:return Rect2(Vector2(2912,96+(index-8)*816) if index>=8 else Vector2(96+(index%4)*704,96+(index/4)*816),Vector2(600,600))
static func gate(index:int)->Vector2:
	var r:=pen(index);return Vector2(r.get_center().x,r.end.y)
static func feeder(index:int)->Vector2:return pen(index).position+Vector2(150,200)
static func water(index:int)->Vector2:return pen(index).position+Vector2(450,200)
static func pond()->Rect2:return Rect2(pen(5).position+Vector2(355,335),Vector2(180,125))
static func obstacle_rects()->Array[Rect2]:
	if not obstacles.is_empty():return obstacles
	for i:int in 10:
		var r:=pen(i);var g:=gate(i)
		obstacles.append(Rect2(r.position-Vector2(7,7),Vector2(614,14)))
		obstacles.append(Rect2(r.position-Vector2(7,7),Vector2(14,614)))
		obstacles.append(Rect2(Vector2(r.end.x-7,r.position.y-7),Vector2(14,614)))
		obstacles.append(Rect2(Vector2(r.position.x-7,r.end.y-7),Vector2(g.x-56-r.position.x+7,14)))
		obstacles.append(Rect2(Vector2(g.x+56,r.end.y-7),Vector2(r.end.x-g.x-49,14)))
		obstacles.append(Rect2(feeder(i)-Vector2(27,13),Vector2(54,26)))
		obstacles.append(Rect2(water(i)-Vector2(23,13),Vector2(46,26)))
	return obstacles
static func blocked(x:float,y:float,profile:String="ground")->bool:
	if not is_finite(x) or not is_finite(y) or x<24 or y<38 or x>SIZE.x-24 or y>SIZE.y-24:return true
	var p:=Vector2(x,y)
	if profile!="waterfowl" and pond().grow(8).has_point(p):return true
	for r:Rect2 in obstacle_rects():
		if r.has_point(p):return true
	return false
static func ensure(s:Node)->void:
	if not s.ranch.has("meadowEnabled"):s.ranch.meadowEnabled=true
	if not s.ranch.has("meadowAssignments"):s.ranch.meadowAssignments={}
static func assignment(s:Node,animal:Dictionary)->Dictionary:
	ensure(s);var id:String=str(animal.id);var records:Dictionary=s.ranch.meadowAssignments
	if records.has(id):return records[id]
	var choices:Array=BY_SPECIES.get(str(animal.type),[0]);var selected:int=int(choices[0]);var lowest:int=100000
	var living:Dictionary={}
	for other:Dictionary in s.animals:living[str(other.id)]=true
	for candidate:int in choices:
		var count:int=0
		for key:Variant in records:
			if living.has(str(key)) and int(records[key].pen)==candidate:count+=1
		if count<lowest:lowest=count;selected=candidate
	for parent:Variant in animal.get("parents",[]):
		if records.has(str(parent)) and choices.has(int(records[str(parent)].pen)):selected=int(records[str(parent)].pen);break
	var occupied:Array=[]
	for key:Variant in records:
		if living.has(str(key)) and int(records[key].pen)==selected:occupied.append(int(records[key].slot))
	var slot:int=0
	for candidate:int in SLOT_ORDER:
		if not occupied.has(candidate):slot=candidate;break
	records[id]={"pen":selected,"slot":slot};return records[id]
static func stand(row:Dictionary)->Vector2:
	var r:=pen(int(row.pen));var slot:int=int(row.slot)
	return r.position+Vector2(90+(slot%5)*105,95+(slot/5)*130)
static func activate(s:Node)->bool:
	if str(s.current_interior)!="" or s.player_position.distance_to(ENTRY)>75:return false
	ensure(s);s.current_interior=ID;s.interior_return_source={"x":ENTRY.x,"y":ENTRY.y+15,"direction":"down"};s.interior_position=EXIT;s.player_direction="up";s.riding=false;s.walking_target.clear();s.interior_npc_positions.clear();s.changed.emit();return true
static func visit(s:Node)->void:
	if s.current_interior==ID:return
	if s.current_interior!="":s.leave_interior();s.meadow_visit_pending=true;return
	var players:Array=s.get_tree().get_nodes_in_group("player")
	if not players.is_empty():players[0].walk_to({"id":ID,"house":ID,"kind":"enter","name":"东坡大牧野","x":ENTRY.x,"y":ENTRY.y,"world_click":true,"click_room":"","auto_interact":true})
static func advance_animal(s:Node,animal:Dictionary,delta:float,runtime:Dictionary,movement:RefCounted)->void:
	var p:Dictionary=animal.position;var inside:Dictionary=p.inside;var clock:float=s.ranch_actor_clock
	var row:=assignment(s,animal);var index:int=int(row.pen)
	var native_home:bool=preload("res://scripts/animal_species.gd").sheltered(s,str(animal.type))
	if runtime.has("arrival_target"):
		movement.walk(s,inside,runtime.arrival_target,ID,delta,18,runtime)
		if movement.navigation.distance(inside,runtime.arrival_target)<5:runtime.erase("arrival_target");runtime.target=null
		return
	if native_home and (not movement.safe_out(s,animal) or not bool(s.ranch.meadowEnabled)):
		var bed:Vector2=preload("res://scripts/animal_species.gd").home(s,str(animal.type)).bed
		movement.walk(s,inside,{"x":bed.x,"y":bed.y},ID,delta,24,runtime)
		if movement.navigation.distance(inside,{"x":bed.x,"y":bed.y})<5:s.ranch_actor_poses[str(animal.id)]={"action":"sleep","until":clock+.3};inside.walking=false
		return
	if not movement.safe_out(s,animal) or not bool(s.ranch.meadowEnabled):
		movement.walk(s,inside,{"x":EXIT.x,"y":EXIT.y},ID,delta,52,runtime)
		if Vector2(float(inside.x),float(inside.y)).distance_to(EXIT)<10 and movement._gate(ID,str(animal.id),clock):
			p.room=null;p.x=ENTRY.x;p.y=ENTRY.y;runtime.target=null;runtime.erase("wander")
		return
	if s.ranch_actor_held(str(animal.id)):
		inside.walking=false;return
	preload("res://scripts/ranch_care.gd").graze(s,animal,delta)
	if str(animal.type)=="pig" and not bool(inside.get("walking",false)) and int(animal.get("foundDay",-1))!=s.day and s.day%4==0:
		animal.foundDay=s.day;var home:String=str(s.system_catalog.ranch.species.pig.home)
		preload("res://scripts/ranch_products.gd").produce(s,animal,"truffle",1,s._animal_quality(animal,s.ranch.barns[home]),s.day,true)
	var spec:Dictionary=s.system_catalog.ranch.species[str(animal.type)]
	if int(animal.age)<int(spec.adult):
		for parent_id:Variant in animal.get("parents",[]):
			var parent_index:int=s.ranch_animal_index(str(parent_id))
			if parent_index<0:continue
			var parent:Dictionary=s.animals[parent_index]
			if str(parent.sex)!="female" or parent.position.get("room")!=ID:continue
			var mother_at:=Vector2(float(parent.position.inside.x),float(parent.position.inside.y))
			if Vector2(float(inside.x),float(inside.y)).distance_to(mother_at)>52:
				var next:Vector2=mother_at+Vector2(-22,20)
				if not blocked(next.x,next.y):movement.walk(s,inside,{"x":next.x,"y":next.y},ID,delta,36,runtime)
				return
			break
	var barn:Dictionary=s.ranch.barns[str(spec.home)]
	var portions:int=0
	for food:String in barn.trough:
		if load("res://scripts/ranch_care.gd").accepts(s,animal,food):portions+=int(barn.trough[food])
	if portions>0 and float(animal.hunger)<80 and load("res://scripts/ranch_care.gd").needed(s,animal,s.day)>0:
		var target:Vector2=feeder(index)+Vector2(0,30)
		movement.walk(s,inside,{"x":target.x,"y":target.y},ID,delta,31,runtime)
		if Vector2(float(inside.x),float(inside.y)).distance_to(target)<7:
			load("res://scripts/ranch_care.gd").from_trough(s,animal,barn,s.day);s.ranch_actor_poses[str(animal.id)]={"action":"feed","until":clock+2}
		return
	if clock>float(runtime.get("next_drink",clock+1)):
		var target:Vector2=water(index)+Vector2(0,29)
		movement.walk(s,inside,{"x":target.x,"y":target.y},ID,delta,28,runtime)
		if Vector2(float(inside.x),float(inside.y)).distance_to(target)<7:
			s.ranch_actor_poses[str(animal.id)]={"action":"drink","until":clock+2};runtime.next_drink=clock+90+posmod(str(animal.id).hash(),60)
		return
	if not runtime.has("next_drink"):runtime.next_drink=clock+45+posmod(str(animal.id).hash(),90)
	if runtime.get("wander")==null or clock>float(runtime.get("next",0)):
		var center:=stand(row);var seed:int=posmod(str(animal.id).hash(),1009);var angle:float=clock*.09+seed
		var target:Vector2=center+Vector2(sin(angle)*80,cos(angle*1.3)*65)
		if blocked(target.x,target.y):target=center
		runtime.wander={"x":target.x,"y":target.y};runtime.next=clock+5.0+(seed%70)/10.0;runtime.target=null
	movement.walk(s,inside,runtime.wander,ID,delta,30 if str(animal.type)=="cow" else 38,runtime)
static func route_to_meadow(s:Node,animal:Dictionary,delta:float,runtime:Dictionary,movement:RefCounted)->void:
	var p:Dictionary=animal.position
	movement.walk(s,p,{"x":ENTRY.x,"y":ENTRY.y},"",delta,45,runtime)
	if Vector2(float(p.x),float(p.y)).distance_to(ENTRY)<10 and movement._gate(ID,str(animal.id),s.ranch_actor_clock):
		assignment(s,animal);p.room=ID;p.inside={"x":EXIT.x+float(posmod(str(animal.id).hash(),5)-2)*12,"y":EXIT.y-12,"direction":"up"};runtime.target=null;runtime.erase("wander")
