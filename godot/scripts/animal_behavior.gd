extends RefCounted
## Shared visual sampling. All persistent care and transactions remain outside this module.
var samples:Dictionary={}
var accumulated:float=0
func clear()->void:samples.clear();accumulated=0
func advance(s:Node,delta:float)->void:
	accumulated+=delta
	if accumulated<1.0/24:return
	delta=accumulated;accumulated=0;var alive:Dictionary={}
	for animal:Dictionary in s.animals:
		var point:Dictionary=animal.position;var room:String=str(point.room) if point.get("room")!=null else ""
		if room!="":point=point.inside
		var id:String=str(animal.id);alive[id]=true
		var pose:Dictionary=s.ranch_actor_poses.get(id,{});var action:String=str(pose.get("action","")) if float(pose.get("until",0))>s.ranch_actor_clock else ""
		var context:Dictionary={"trait":str(animal.trait),"hunger":float(animal.hunger),"mood":float(animal.mood),"age":int(animal.age),"adult":int(s.system_catalog.ranch.species[str(animal.type)].adult),"serial":float(pose.get("serial",pose.get("at",0))),"contact_target":pose.get("contact_target",{}),"progress":pose.get("progress",-1.0)}
		sample(id,str(animal.type),Vector2(float(point.x),float(point.y)),room,str(point.get("direction","down")),bool(point.get("walking",false)),action,s.minutes>=1200 or bool(animal.rest),s.ranch_actor_clock,delta,int(animal.age)<int(context.adult),context)
	var pet:Dictionary=s.ranch.pet.get("position",{})
	if not pet.is_empty():
		alive.pet=true;var action:String=str(s.pet_visual_action.get("kind","")) if float(s.pet_visual_action.get("until",0))>s.ranch_actor_clock else ""
		sample("pet",str(s.pet_state.type),Vector2(float(pet.x),float(pet.y)),"",str(pet.get("direction","down")),bool(pet.get("walking",false)),action,s.minutes>=1140 or float(s.ranch.pet.energy)<15,s.ranch_actor_clock,delta,false,{"trait":"friendly","hunger":s.ranch.pet.hunger})
	for id:Variant in samples.keys():
		if not alive.has(id):samples.erase(id)
func sample(id:String,type_id:String,position:Vector2,room:String,direction:String,walking:bool,action:String,sleeping:bool,clock:float,dt:float,young:bool=false,context:Dictionary={})->Dictionary:
	var profile:Dictionary=preload("res://scripts/animal_species.gd").profile(type_id)
	if profile.is_empty():profile=preload("res://scripts/animal_species.gd").profile("cow")
	var seed:int=posmod(id.hash(),10007)
	var row:Dictionary=samples.get(id,{"position":position,"room":room,"phase":float(seed%100)/100,"weight":0.0,"direction":direction,"requested":direction,"turn":1.0,"sleep":0.0,"action":"idle","since":clock,"seed":seed,"head_pitch":0.0,"water_blend":0.0,"next_think":clock+float(seed%17)/10,"habit":"idle","habit_until":clock})
	var displacement:Vector2=position-Vector2(row.position);var distance:float=displacement.length()
	if room!=str(row.room) or distance>64:distance=0;row.weight=0.0;row.erase("feet")
	if walking and distance>.001:row.phase=fposmod(float(row.phase)+minf(distance/float(profile.stride),2.2*dt),1)
	row.weight=move_toward(float(row.weight),1 if walking and distance>.001 else 0,dt/.12)
	if direction!=str(row.requested):row.requested=direction;row.turn=0.0
	row.turn=minf(1,float(row.turn)+dt/.14)
	if float(row.turn)>=.5 and str(row.direction)!=direction:row.direction=direction;row.erase("feet")
	row.sleep=move_toward(float(row.sleep),1 if (sleeping or action=="sleep") and not walking else 0,dt/.5)
	var water:bool=room=="ranch-meadow" and bool(profile.waterfowl) and load("res://scripts/ranch_meadow.gd").pond().has_point(position)
	row.motion_mode="swim" if water else "ground";row.water_blend=move_toward(float(row.water_blend),1 if water else 0,dt/.35)
	var selected:String=action if action!="" else "walk" if row.weight>.03 else "sleep" if sleeping else "idle"
	if selected=="idle":
		if clock>=float(row.next_think):
			var temperament:String=str(context.get("trait","friendly"));var choice:int=posmod(seed+floori(clock/3),11)
			row.habit="observe" if temperament=="shy" or choice<2 else "graze" if float(context.get("hunger",100))<50 and type_id in ["horse","cow","alpaca","sheep","goat"] else str(profile.idle)
			if type_id=="dog" and choice>7:row.habit="sit"
			row.habit_until=clock+float(profile.idleDuration);row.next_think=row.habit_until+4+seed%5
		if clock<float(row.habit_until):selected=str(row.habit)
	var changed:bool=selected!=str(row.action) or float(row.get("serial",0))!=float(context.get("serial",0)) and action!=""
	if changed:row.previous_action=row.action;row.action=selected;row.since=clock;row.serial=context.get("serial",0)
	row.elapsed=clock-float(row.since);var elapsed:float=float(row.elapsed)
	row.behavior_stage="prepare" if elapsed<.18 else "recover" if selected=="idle" and elapsed<.45 else "execute"
	row.behavior_progress=clampf(elapsed/.5,0,1);row.contact_target=context.get("contact_target",{})
	var pitch:float=1 if selected in ["feed","graze","peck","root","browse","drink","sniff"] else -.25 if selected=="observe" else .4 if selected in ["wash","preen"] else 0
	row.head_pitch=move_toward(float(row.head_pitch),pitch,dt/.30)
	row.position=position;row.room=room;row.clock=clock;row.actual_displacement=displacement if distance>0 else Vector2.ZERO
	var growth:float=clampf(float(context.get("age",0))/float(context.get("adult",1)),0,1) if young else 1
	var h:float=float(profile.height)*lerpf(float(profile.youngHeight),1,growth*growth*(3-2*growth))
	var count:int=2 if str(profile.family)=="bird" else 4;var side:bool=str(row.direction) in ["left","right"];var feet:Array=row.get("feet",[]);var offsets:Array=[]
	for i:int in count:
		var ph:float=float(row.phase)*TAU+float(profile.gait[i])*TAU
		var stance:bool=sin(ph)<=0;var x:float=(i-.5)*h*.22 if count==2 else [-.24,-.20,.20,.24][i]*h if side else [-.10,.10,-.18,.18][i]*h
		var base:Vector2=position+Vector2(x,0);var desired:=Vector2(cos(ph)*h*.045,-maxf(0,sin(ph))*h*.045)*float(row.weight)
		if feet.size()<=i:feet.append({"stance":false,"anchor":base,"age":0.0,"released":true,"offset":Vector2.ZERO})
		var foot:Dictionary=feet[i]
		if stance and not bool(foot.stance):foot.anchor=base+desired;foot.age=0;foot.released=false
		foot.age+=dt
		if float(foot.age)>.16 or Vector2(foot.anchor).distance_to(base)>h*.12 or water:foot.released=true
		if stance and not bool(foot.released):foot.offset=Vector2(foot.anchor)-base
		else:foot.offset=Vector2(foot.offset).lerp(desired,minf(1,dt/.06))
		foot.stance=stance;offsets.append(foot.offset)
	row.feet=feet;row.foot_offsets=offsets;samples[id]=row;return row
