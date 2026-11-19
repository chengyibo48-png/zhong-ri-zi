extends RefCounted
static func data_error(value:Dictionary)->String:
	var ranch:Variant=value.get("ranch",{})
	if not ranch is Dictionary:return "牧场数据无效。"
	for key:String in ["families","petRecords","eggLineage","eggStorageLineage"]:
		if ranch.has(key) and not ranch[key] is Dictionary:return "牧场家系或伙伴记录无效。"
	if ranch.has("meadowEnabled") and not ranch.meadowEnabled is bool:return "牧野设置无效。"
	if ranch.has("meadowAssignments"):
		if not ranch.meadowAssignments is Dictionary:return "牧野分区无效。"
		for row:Variant in ranch.meadowAssignments.values():
			if not row is Dictionary or not preload("res://scripts/source_save_validation.gd").integer(row.get("pen"),0,9) or not preload("res://scripts/source_save_validation.gd").integer(row.get("slot"),0,19):return "牧野分区无效。"
	if ranch.has("petActive") and ranch.petActive not in ["companion-cat","companion-dog"]:return "当前伙伴身份无效。"
	for animal:Variant in value.get("animals",[]):
		if not animal is Dictionary:return "动物档案无效。"
		var visual_error:String=preload("res://scripts/animal_species.gd").appearance_error(animal)
		if visual_error!="":return visual_error
		for key:String in ["postpartumUntil","nurseryUntil","arrivalDay"]:
			if animal.has(key) and not preload("res://scripts/source_save_validation.gd").integer(animal[key],-1,100002):return "养育阶段日数无效。"
	for key:String in ["birthHistory","receipts"]:
		if ranch.has(key) and not ranch[key] is Array:return "牧场养育记录无效。"
	for row:Variant in ranch.get("families",{}).values():
		if not row is Dictionary or not row.get("parents",[]) is Array:return "家系关系无效。"
		for id:Variant in row.get("parents",[]):
			if not id is String:return "家系身份无效。"
	for row:Variant in ranch.get("births",[]):
		if not row is Dictionary:return "孕育记录无效。"
		for key:String in ["pausedDays","lastDay"]:
			if row.has(key) and not preload("res://scripts/source_save_validation.gd").integer(row[key],-1,100001):return "孕育日数无效。"
		if row.has("protected") and not row.protected is bool:return "保育状态无效。"
		if row.has("pauseReason") and not row.pauseReason is String:return "保育原因无效。"
		if row.has("kind") and row.kind not in ["gestation","incubation"]:return "孕育方式无效。"
	for row:Variant in ranch.get("birthHistory",[]):
		if not row is Dictionary or not row.get("id") is String or not row.get("animalId") is String or not row.get("parents",[]) is Array:return "出生凭据无效。"
	for row:Variant in ranch.get("petRecords",{}).values():
		if not row is Dictionary or not row.get("identity") is Dictionary or not row.get("care") is Dictionary:return "伙伴档案无效。"
		if row.identity.get("type") not in ["cat","dog"] or not row.identity.get("name") is String:return "伙伴身份无效。"
		if not preload("res://scripts/source_save_validation.gd").integer(row.identity.get("bond",0),0,100):return "伙伴亲近数据无效。"
		for key:String in ["hunger","energy","training"]:
			if not preload("res://scripts/source_save_validation.gd").number(row.care.get(key,0),0,100):return "伙伴照料数据无效。"
	for rows:Variant in (ranch.get("eggLineage",{}).values()+ranch.get("eggStorageLineage",{}).values()):
		if not rows is Array:return "受精蛋来源记录无效。"
		for row:Variant in rows:
			if not row is Dictionary or not row.get("parents",[]) is Array or not preload("res://scripts/source_save_validation.gd").integer(row.get("qty"),1,999999):return "受精蛋数量或来源无效。"
			for id:Variant in row.get("parents",[]):
				if not id is String:return "受精蛋亲缘记录无效。"
	return ""
## Authoritative family records and daily nursery commits; never called by drawing.
static func ensure(s:Node)->void:
	if not s.ranch.has("families"):s.ranch.families={}
	if not s.ranch.has("birthHistory"):s.ranch.birthHistory=[]
	if not s.ranch.has("petRecords"):s.ranch.petRecords={}
	if not s.ranch.has("petActive"):s.ranch.petActive="companion-"+str(s.pet_state.get("type","cat"))
	if not s.ranch.has("eggLineage"):s.ranch.eggLineage={}
	if not s.ranch.has("eggStorageLineage"):s.ranch.eggStorageLineage={}
	for a:Dictionary in s.animals:
		preload("res://scripts/animal_species.gd").ensure_animal(a)
		s.ranch.families[str(a.id)]={"parents":a.get("parents",[]).duplicate(),"generation":int(a.get("generation",0))}
	for entry:Dictionary in s.ranch.get("rehomed",[]):
		var a:Dictionary=entry.get("animal",{})
		if not a.is_empty():s.ranch.families[str(a.id)]={"parents":a.get("parents",[]).duplicate(),"generation":int(a.get("generation",0))}
	for birth:Dictionary in s.ranch.births:
		if not birth.has("kind"):birth.kind="incubation" if preload("res://scripts/animal_species.gd").bird(s,str(birth.type)) else "gestation"
		if not birth.has("pausedDays"):birth.pausedDays=0
		if not birth.has("protected"):birth.protected=false
		if not birth.has("pauseReason"):birth.pauseReason=""
static func ancestors(s:Node,id:String)->Dictionary:
	var found:Dictionary={};var queue:Array=[id];var visited:Dictionary={}
	while not queue.is_empty():
		var at:String=str(queue.pop_back())
		if visited.has(at):continue
		visited[at]=true
		var parents:Array=s.ranch.get("families",{}).get(at,{}).get("parents",[])
		for animal:Dictionary in s.animals:
			if str(animal.id)==at:parents=animal.get("parents",[]);break
		for entry:Dictionary in s.ranch.get("rehomed",[]):
			if str(entry.get("animal",{}).get("id",""))==at:parents=entry.animal.get("parents",[]);break
		for parent:Variant in parents:
			var key:=str(parent)
			if key!="":found[key]=true;queue.append(key)
	return found
static func egg_sync(s:Node,id:String)->void:
	if not preload("res://scripts/animal_species.gd").fertile(id):return
	if not s.ranch.has("eggLineage"):s.ranch.eggLineage={}
	var rows:Array=s.ranch.eggLineage.get(id,[]);var total:int=0
	for row:Dictionary in rows:total+=int(row.qty)
	var actual:int=int(s.inventory.get(id,0))
	# Unknown acquisitions remain explicitly unparented; never invent ancestry.
	if total!=actual:
		rows=[]
		if actual>0:rows.append({"qty":actual,"parents":[],"breed":"local"})
	s.ranch.eggLineage[id]=rows
static func egg_added(s:Node,id:String,qty:int)->void:
	if not preload("res://scripts/animal_species.gd").fertile(id) or qty<=0:return
	egg_sync(s,id)
	var rows:Array=s.ranch.eggLineage[id]
	if not rows.is_empty() and rows.back().get("parents",[]).is_empty():rows.back().qty+=qty
	else:rows.append({"qty":qty,"parents":[],"breed":"local"})
static func egg_consumed(s:Node,id:String,qty:int)->void:
	if not preload("res://scripts/animal_species.gd").fertile(id):return
	egg_sync(s,id);var rows:Array=s.ranch.eggLineage[id];var remaining:int=qty
	while remaining>0 and not rows.is_empty():
		var amount:int=mini(remaining,int(rows[0].qty));rows[0].qty-=amount;remaining-=amount
		if int(rows[0].qty)==0:rows.pop_front()
static func mark_paired_egg(s:Node,id:String,a:Dictionary,b:Dictionary)->void:
	egg_sync(s,id);var rows:Array=s.ranch.eggLineage[id]
	if rows.is_empty():return
	rows.back().qty-=1
	if int(rows.back().qty)==0:rows.pop_back()
	rows.append({"qty":1,"parents":[str(a.id),str(b.id)],"breed":str(a.breed)})
static func egg_preview(s:Node,id:String)->Dictionary:
	var rows:Array=s.ranch.get("eggLineage",{}).get(id,[]);var total:int=0
	for row:Dictionary in rows:total+=int(row.qty)
	return rows[0].duplicate(true) if total==int(s.inventory.get(id,0)) and not rows.is_empty() else {"parents":[],"breed":"local"}
static func related(s:Node,a:String,b:String)->bool:
	var first:=ancestors(s,a);var second:=ancestors(s,b)
	return a==b or first.has(b) or second.has(a) or first.keys().any(func(id:Variant):return second.has(id))
static func advance_births(s:Node,previous_day:int,extreme:bool)->void:
	ensure(s)
	for birth:Dictionary in s.ranch.births.duplicate():
		if int(birth.get("lastDay",-1))>=previous_day:continue
		birth.lastDay=previous_day
		var spec:Dictionary=s.system_catalog.ranch.species[str(birth.type)]
		var barn:Dictionary=s.ranch.barns[str(spec.home)];var mother:Dictionary={}
		for animal:Dictionary in s.animals:
			if birth.get("mother")!=null and str(animal.id)==str(birth.mother):mother=animal;break
		var reasons:Array[String]=[]
		if float(barn.clean)<40:reasons.append("畜舍清洁不足40，清扫或铺垫草")
		if str(birth.kind)!="incubation" and not mother.is_empty() and (float(mother.health)<50 or float(mother.hunger)<30):reasons.append("母畜需要喂食与护理")
		if extreme and int(barn.comfort)<1:reasons.append("极端天气，添置舒适巢床")
		birth.pauseReason="；".join(reasons)
		if not reasons.is_empty() and not bool(birth.protected):
			birth.pausedDays=int(birth.pausedDays)+1
			if int(birth.pausedDays)<3:continue
			birth.protected=true;s._ranch_notice("已为幼崽安排保护性保育，不另收费，床位继续保留。")
		else:birth.pausedDays=0
		birth.remaining=maxi(0,int(birth.remaining)-1)
		if int(birth.remaining)>0:continue
		if s.ranch.birthHistory.any(func(row:Dictionary):return str(row.id)==str(birth.id)):
			s.ranch.births.erase(birth);continue
		var parents:Array=[]
		for key:String in ["mother","father"]:
			if birth.get(key)!=null and str(birth[key])!="":parents.append(str(birth[key]))
		var baby:Dictionary=s._ranch_new_animal(str(birth.type),"female" if int(s.ranch.nextId)%2 else "male",str(birth.breed),0,parents)
		if baby.is_empty():continue
		baby.nurseryUntil=s.day+2;baby.arrivalDay=s.day
		if not mother.is_empty() and str(birth.kind)!="incubation":
			mother.care.breed=s.day;mother.rest=true;mother.postpartumUntil=s.day+2
			if int(s.ranch.nextId)%2==0:baby.trait=mother.trait;baby.personality=s.system_catalog.ranch.traits[str(baby.trait)]
		s.ranch.birthHistory.append({"id":str(birth.id),"animalId":str(baby.id),"day":s.day,"kind":str(birth.kind),"parents":parents.duplicate(),"seen":false})
		s.ranch.families[str(baby.id)]={"parents":parents.duplicate(),"generation":int(baby.generation)}
		s.ranch.births.erase(birth);s._ranch_notice("新伙伴 "+str(baby.name)+(" 破壳啦！" if str(birth.kind)=="incubation" else " 出生啦！")+"已安置在安全育幼区，可在养育记录中命名。")
static func pet_exchange(s:Node,type_id:String)->bool:
	if type_id not in ["cat","dog"]:return false
	ensure(s);var next_id:String="companion-"+type_id
	if str(s.ranch.petActive)==next_id:s.message="这位伙伴已经在家。";return false
	s.ranch.petRecords[str(s.ranch.petActive)]={"identity":s.pet_state.duplicate(true),"care":s.ranch.pet.duplicate(true)}
	var record:Dictionary=s.ranch.petRecords.get(next_id,{})
	s.pet_state=record.get("identity",{"type":type_id,"name":"阿福" if type_id=="dog" else "小团","bond":0,"patted":-1}).duplicate(true)
	s.ranch.pet=record.get("care",{"hunger":65,"energy":100,"training":0,"fed":-1,"trained":-1}).duplicate(true)
	if s.ranch_movement==null:s.ranch_movement=load("res://scripts/ranch_movement.gd").new()
	s.ranch.pet.position=s.ranch_movement.navigation.safe(s,"",{"x":2831,"y":1652},true)
	s.ranch_movement.actors.pet={"arrival_until":s.ranch_actor_clock+2,"actor_id":"pet"}
	s.ranch.pet.mode="home";s.ranch.petActive=next_id;s.ranch.pet.arrivalDay=s.day
	s.pet_visual_action.clear();s.message="已正式接回「"+str(s.pet_state.name)+"」。原伙伴的名字、亲近和训练记录已保留。";s.changed.emit();return true

static func egg_transfer(s:Node,id:String,qty:int,to_storage:bool)->Dictionary:
	if not preload("res://scripts/animal_species.gd").fertile(id):return {}
	ensure(s);egg_sync(s,id)
	var bag:Array=s.ranch.eggLineage[id].duplicate(true)
	var stored:Array=s.ranch.eggStorageLineage.get(id,[]).duplicate(true)
	var total:int=0
	for row:Dictionary in stored:total+=int(row.qty)
	if total!=int(s.storage.get(id,0)):
		stored=[]
		if int(s.storage.get(id,0))>0:stored.append({"qty":int(s.storage[id]),"parents":[],"breed":"local"})
	var source:Array=bag if to_storage else stored;var destination:Array=stored if to_storage else bag
	var remaining:int=qty
	while remaining>0 and not source.is_empty():
		var row:Dictionary=source[0];var amount:int=mini(remaining,int(row.qty));var moved:Dictionary=row.duplicate(true);moved.qty=amount;destination.append(moved)
		row.qty-=amount;remaining-=amount
		if int(row.qty)==0:source.pop_front()
	return {"bag":bag,"storage":stored}
