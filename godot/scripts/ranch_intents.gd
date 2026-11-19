extends RefCounted
## One read-only quote for confirmations and commit-time validation.
static func quote(s:Node,task:Dictionary)->Dictionary:
	var op:String=str(task.get("action",""));var arg:Variant=task.get("arg","")
	var reasons:Array[String]=[];var money:int=0;var energy:int=0;var minutes:int=0;var materials:Dictionary={};var title:String="";var details:String=""
	var species:Dictionary=s.system_catalog.ranch.species
	if op=="purchase" and arg is Array and arg.size()==4:
		var type_id:String=str(arg[0]);var spec:Dictionary=species.get(type_id,{});var breed:Dictionary=s.system_catalog.ranch.breeds.get(str(arg[2]),{})
		if spec.is_empty() or breed.is_empty() or not preload("res://scripts/animal_species.gd").breeds(s,type_id).has(str(arg[2])) or str(arg[1]) not in ["female","male"]:reasons.append("请选择有效种类、性别和品种")
		else:
			money=roundi(float(spec.cost)*float(breed.get("cost",1))*(.7 if bool(arg[3]) else 1));energy=2;minutes=5;title="迎接"+str(spec.name)
			if not s._ranch_space_for(type_id) or not bool(s.ranch.barns[str(spec.home)].built):reasons.append("先修好畜舍并留出床位，孕育预留也计入容量")
			details="%s · %s · %s\n安置：%s"%[str(breed.name),"幼崽" if bool(arg[3]) else "成年","母" if str(arg[1])=="female" else "公",str(s.system_catalog.ranch.barns[str(spec.home)].name)]
	elif op=="breed" and arg is Array and arg.size()==2:
		var a:Dictionary={};var b:Dictionary={}
		for animal:Dictionary in s.animals:
			if str(animal.id)==str(arg[0]):a=animal
			if str(animal.id)==str(arg[1]):b=animal
		if a.is_empty() or b.is_empty():reasons.append("请先选择仍在牧场的双方")
		elif str(a.type)!=str(b.type) or str(a.sex)!="female" or str(b.sex)!="male" or str(a.id)==str(b.id):reasons.append("需要同种母畜与公畜")
		else:
			var spec:Dictionary=species[str(a.type)];title="安排配对";details=str(a.name)+" 与 "+str(b.name)
			if preload("res://scripts/ranch_nurture.gd").related(s,str(a.id),str(b.id)):reasons.append("有已知直系或共同祖先，请选择不同家系")
			for animal:Dictionary in [a,b]:
				if int(animal.age)<int(spec.adult):reasons.append(str(animal.name)+"尚未成年")
				if bool(animal.retired) or bool(animal.rest) or bool(animal.lost):reasons.append(str(animal.name)+"需要先结束休养、退休或找回")
				if float(animal.health)<70 or float(animal.illness)>10:reasons.append(str(animal.name)+"需要治疗恢复健康")
				if float(animal.hunger)<55 or float(animal.mood)<50:reasons.append(str(animal.name)+"需要先喂食和安抚")
			if s.day-int(a.care.breed)<12 or s.ranch.births.any(func(row:Dictionary):return str(row.get("mother",""))==str(a.id)):reasons.append("母畜正在孕育或尚未满12天配种间隔")
			if not s._ranch_space_for(str(a.type)):reasons.append("先为幼崽预留床位")
			if float(s.ranch.barns[str(spec.home)].clean)<50:reasons.append("先将畜舍清洁提高到50")
			details+="\n配对后获得一枚受精蛋，再在巢箱孵化。" if preload("res://scripts/animal_species.gd").bird(s,str(a.type)) else "\n约%d个舒适日后出生，预留一个床位。"%int(spec.gestation)
			money=20;energy=3;minutes=5;materials={"grainFeed":2}
	elif op=="incubate" and preload("res://scripts/animal_species.gd").bird(s,str(arg)):
		title="安排孵化";details="受精蛋入巢，约%d个舒适日后破壳；预留一个床位。"%int(species[str(arg)].gestation);energy=2;minutes=5;materials={preload("res://scripts/animal_species.gd").egg(s,str(arg)):1}
		if int(s.ranch.barns.poultry.comfort)<1:reasons.append("先添置舒适巢箱")
		if not s._ranch_space_for(str(arg)):reasons.append("先为幼禽留出床位")
	elif op.begins_with("adopt:"):
		var type_id:String=op.trim_prefix("adopt:");title="正式接回"+("小猫" if type_id=="cat" else "小狗")
		details="先安置当前伙伴，再接回新伙伴。原伙伴的名字、亲近与训练将保留，可再次接回。\n单伙伴名额，不收额外领养费。"
		if type_id not in ["cat","dog"] or str(s.pet_state.type)==type_id:reasons.append("这位伙伴已经在家，或领养对象无效")
	elif op=="readopt":
		title="接回原伙伴";var found:Dictionary={}
		for entry:Dictionary in s.ranch.rehomed:
			if str(entry.get("animal",{}).get("id",""))==str(arg):found=entry;break
		if found.is_empty():reasons.append("原送养记录已不在名册")
		else:
			var animal:Dictionary=found.animal;money=int(found.fee);energy=2;minutes=5;details=str(animal.name)+" · "+str(animal.species)+"\n名字、品种、亲近和亲缘保持。"
			if not s._ranch_space_for(str(animal.type)):reasons.append("先留出对应畜舍床位")
	else:reasons.append("无效的养育操作")
	if s.money<money:reasons.append("零钱不足，需要%d元"%money)
	if s.stamina<energy:reasons.append("体力不足，需要%d点"%energy)
	if s.minutes+minutes>1320:reasons.append("今天时间不足，明天再安排")
	for id:String in materials:
		if not s._building_has({id:int(materials[id])}):reasons.append("缺少 "+str(s.item_catalog.get(id,{}).get("name",id))+" ×"+str(materials[id]))
	return {"ok":reasons.is_empty(),"reasons":reasons,"title":title,"details":details,"money":money,"energy":energy,"minutes":minutes,"materials":materials}
