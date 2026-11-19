extends RefCounted
## Read-only quotes and one mutation surface for the village's physical projects.
const ORDER=["bridge","canal","market","stage"]
const SITES={"bridge":Vector2(1014,2820),"canal":Vector2(3040,1950),"market":Vector2(2816,790),"stage":Vector2(3520,930)}
static func defaults()->Dictionary:return {"version":1,"projects":{},"observations":{},"growth":{},"cohorts":{},"dailyBoard":{}}
static func project(s:Node,id:String)->Dictionary:return s.village_progress.get("projects",{}).get(id,{"surveyed":false,"supplied":{},"collaborated":false,"firstUse":false}).duplicate(true)
static func remaining(s:Node,id:String)->Dictionary:
	var result:Dictionary={};var p:Dictionary=project(s,id)
	for item:String in s.content.projects.get(id,{}).get("needs",{}):result[item]=maxi(0,int(s.content.projects[id].needs[item])-int(p.supplied.get(item,0)))
	return result
static func phase(s:Node,id:String)->String:
	var p:=project(s,id)
	if bool(p.collaborated):return "complete" if bool(p.firstUse) else "firstUse"
	if not bool(p.surveyed):return "survey"
	for amount:Variant in remaining(s,id).values():
		if int(amount)>0:return "materials"
	return "collaborate"
static func quote(s:Node,id:String,op:String="")->Dictionary:
	var reason:String="";var missing:Dictionary={};var contribution:Dictionary={};var spend:int=0;var minutes:int=0;var energy:int=0
	if id not in ORDER:return {"ready":false,"reason":"没有这处公共项目。","known":false,"done":false,"remaining":{},"money":0,"minutes":0,"energy":0}
	var stage:String=phase(s,id);var work:String=op if op!="" else stage
	var chapter:int=int(s.quests.journey.chapter)
	if chapter>=4 or ORDER[chapter]!=id or int(s.quests.journey.stage)!=2:
		if stage not in ["firstUse","complete"]:reason="先完成当前篇章的生活目标，再来一起筹备。"
	missing=remaining(s,id)
	for item:String in missing:contribution[item]=mini(int(missing[item]),load("res://scripts/quest_service.gd").qualified(s,item,0))
	if reason=="" and op!="" and (s.current_interior!="" or s.player_position.distance_to(SITES[id])>95):reason="先到实际施工立牌旁办理，手记可追踪。"
	if work=="survey":minutes=5
	elif work=="collaborate":minutes=10;energy=4
	if work in ["contribute","procure"] and stage!="materials":reason="当前不需要再次筹料。"
	if work=="contribute":
		var any:bool=false
		for item:String in missing:
			if int(missing[item])>0 and load("res://scripts/quest_service.gd").qualified(s,item,0)>0:any=true
		if not any:reason="背包还没有可提交的未保护建材。"
	if work=="procure":
		for item:String in missing:
			var value:int=int(s.item_catalog.get(item,{}).get("price",0));var shop:int=s.shop_price(item)
			spend+=int(missing[item])*maxi(shop,ceili(value*1.85))
		if s.money<spend:reason="筹料还需 %d 元；也可以自己分次带来建材。"%spend
	if work=="survey" and stage!="survey":reason="现场已经勘察过了。"
	if work=="collaborate":
		if stage!="collaborate":reason="先勘察并筹齐建材，再现场协作。"
		elif not s.npc_is_near(str(s.content.projects[id].npc)):reason=s.npc_name(str(s.content.projects[id].npc))+"正在按真实路线赶来；到场后再一起动手。"
	if work=="use" and stage!="firstUse":reason="这处设施已体验过，或还未完成。"
	if stage=="complete" and work not in ["complete"]:reason="已经完成并体验过，不会重复扣料或发奖。"
	if s.minutes+minutes>1320:reason="今晚先休息，筹备进度会保留。"
	if s.stamina<energy:reason="需要 %d 点体力；恢复后再来。"%energy
	return {"ready":reason=="","known":true,"done":stage in ["firstUse","complete"],"phase":stage,"reason":reason,"remaining":missing,"contribution":contribution,"money":spend,"minutes":minutes,"energy":energy,"npc":str(s.content.projects[id].npc)}
static func perform(s:Node,id:String,op:String,quantities:Dictionary={})->bool:
	var q:=quote(s,id,op)
	if not bool(q.ready):s.message=str(q.reason);return false
	var p:=project(s,id)
	for amount:Variant in quantities.values():
		if not load("res://scripts/source_save_validation.gd").integer(amount,0,999999):return false
	match op:
		"survey":p.surveyed=true
		"contribute":
			var taken:bool=false
			for item:String in q.remaining:
				var available:int=load("res://scripts/quest_service.gd").qualified(s,item,0)
				var count:int=mini(int(q.remaining[item]),mini(available,int(quantities.get(item,available))))
				if count<=0:continue
				if load("res://scripts/quest_service.gd").consume(s,item,count).is_empty():return false
				p.supplied[item]=int(p.supplied.get(item,0))+count;taken=true
			if not taken:s.message="本次没有选中可交付的建材，材料保持原样。";return false
		"procure":
			s.money-=int(q.money)
			for item:String in q.remaining:p.supplied[item]=int(s.content.projects[id].needs[item])
		"collaborate":
			p.collaborated=true;s.community_projects[id]=true
			if id=="bridge" and not s.archives.has("photo"):s.archives.append("photo")
			if id=="bridge":s.flags.bridge=true
			var npc:String=str(s.content.projects[id].npc);s.relations[npc].points=mini(100,int(s.relations[npc].points)+20)
			var recipe:String=str(s.content.projects[id].get("recipe",""))
			if recipe!="" and not s.known_recipes.has(recipe):s.known_recipes.append(recipe)
			s._award_skill_xp("craft",12)
			if str(s.skills.get("craft",{}).get("choice",""))=="cooperate":s._grant_legacy_item("bamboo",2)
			s._record_community_log(str(s.content.projects[id].name)+"：大家完成了现场协作。")
		"use":
			p.firstUse=true;s._record_community_log(str(s.content.projects[id].change));s.quest_event("projectUse:"+id,"project-use:"+id)
		_:return false
	s.minutes+=int(q.minutes);s.stamina-=int(q.energy)
	s.village_progress.projects[id]=p;s.quest_event("villageProject","project:"+id+":"+op+":"+str(s.quests.sequence))
	s.message={"survey":"勘察记下了，乡亲会沿路来帮忙。","contribute":"这批建材已经放到现场，剩余部分可以下次再带。","procure":"已委托筹齐缺口建材，不会重复发到背包。","collaborate":"共同修缮完成，再试用一下新设施吧。","use":str(s.content.projects[id].change)}.get(op,"已经记下。")
	s.changed.emit();return true
static func npc_plan(s:Node,npc:String)->Dictionary:
	if s.minutes<540 or s.minutes>=1080 or bool(s.weather_profile().get("extreme",false)):return {}
	for id:String in ORDER:
		if str(s.content.projects[id].npc)!=npc:continue
		var p:=project(s,id)
		if bool(p.surveyed) and not bool(p.collaborated):
			var target:Vector2=SITES[id]+Vector2(30,12)
			return {"key":"village-work","label":"赴约参加公共修缮","target":target,"target_point":{"x":target.x,"y":target.y},"gesture":"hammer" if npc in ["chen","wu"] else "read","reason":"按真实路线去赴约，不瞬移。","room":null,"indoors":false}
	return {}
static func _raw_available(s:Node,item:String)->bool:
	if load("res://scripts/quest_service.gd").qualified(s,item)>0:return true
	if item=="rice":return true # Normal grocery stock, purchased through the original shop.
	if item in ["egg","milk","goatMilk","wool"]:
		for animal:Dictionary in s.animals:
			var species:Dictionary=s.system_catalog.ranch.species[str(animal.type)]
			if str(species.get("product",""))==item and int(animal.age)>=int(species.adult):return true
	if s.crop_catalog.has(item):
		for plot:Dictionary in s.plots:
			if str(plot.get("crop",""))==item and float(s.crop_days(item))-float(plot.growth)<=1:return true
	return false
static func plan_orders(s:Node)->Array[Dictionary]:
	var raw:Array[String]=["rice"];var processed:Array[String]=[];var cooked:Array[String]=[]
	for item:String in s.item_catalog:
		if int(s.item_catalog[item].get("price",0))<=0 or item=="rice":continue
		if (s.crop_catalog.has(item) or item in ["egg","milk","goatMilk","wool"]) and _raw_available(s,item):raw.append(item)
	for recipe:Dictionary in s.system_catalog.kitchen.processing:
		var ok:bool=true
		for item:String in recipe.needs:
			if not _raw_available(s,item):ok=false;break
		var station:Dictionary=s.system_catalog.kitchen.stations.get(str(recipe.get("stationId","")),{})
		if ok and not station.has("upgrade"):processed.append(str(recipe.get("out",recipe.id)))
	for recipe:Dictionary in s.content.recipes:
		if not s.known_recipes.has(str(recipe.id)):continue
		var ok:bool=true
		for item:String in recipe.ingredients:
			if not _raw_available(s,item):ok=false;break
		if ok:cooked.append(str(recipe.id))
	raw.sort();processed.sort();cooked.sort()
	var pools:Array=[raw,processed if not processed.is_empty() else raw,cooked if not cooked.is_empty() else raw]
	var result:Array[Dictionary]=[]
	for i:int in 3:
		var pool:Array=pools[i];var item:String=str(pool[posmod(s.day+i,pool.size())]);var value:int=maxi(1,int(s.item_catalog[item].price))
		var complexity:int=40 if i==2 and not cooked.is_empty() else 30 if i==1 and not processed.is_empty() else 25
		result.append({"key":"day-%d-%d"%[s.day,i],"id":item,"qty":clampi(ceili(40.0/value),1,2),"grade":0,"title":["邻里时令篮","日常备料单","共餐备料单"][i],"bonus":complexity,"day":s.day})
	return result
static func prepare_day(s:Node)->void:
	if int(s.village_progress.get("dailyBoard",{}).get("day",-1))==s.day:return
	s.village_progress.dailyBoard={"day":s.day,"orders":plan_orders(s)}
static func daily_orders(s:Node)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var board:Dictionary=s.village_progress.get("dailyBoard",{})
	if int(board.get("day",-1))!=s.day:return plan_orders(s)
	for order:Dictionary in board.get("orders",[]):result.append(order.duplicate(true))
	return result
static func record_growth(s:Node)->void:
	for animal:Dictionary in s.animals:
		if int(animal.age)<int(s.system_catalog.ranch.species[str(animal.type)].adult):continue
		if not animal.get("parents",[]).is_empty() or s.village_progress.get("cohorts",{}).has(str(animal.id)):
			s.village_progress.growth[str(animal.id)]=s.day
static func save_valid(value:Dictionary)->bool:
	if int(value.get("version",0))!=38:return false
	var data:Variant=value.get("village_progress",defaults())
	if not data is Dictionary or data.get("version")!=1:return false
	for key:String in ["projects","observations","growth","cohorts"]:
		if data.has(key) and not data[key] is Dictionary:return false
	for id:Variant in data.get("projects",{}):
		if id not in ORDER:return false
		var p:Variant=data.projects[id]
		if not p is Dictionary or not p.get("supplied") is Dictionary:return false
		for key:String in ["surveyed","collaborated","firstUse"]:
			if not p.get(key) is bool:return false
		if bool(p.firstUse) and not bool(p.collaborated) or bool(p.collaborated) and not bool(p.surveyed):return false
		for item:Variant in p.supplied:
			if item not in ["wood","bamboo"] or not load("res://scripts/source_save_validation.gd").integer(p.supplied[item],0,100):return false
	for group:String in ["growth","cohorts"]:
		if data.get(group,{}).size()>1024:return false
		for id:Variant in data.get(group,{}):
			if not id is String or id.length()>160 or not load("res://scripts/source_save_validation.gd").integer(data[group][id],0,int(value.day)):return false
	if data.get("observations",{}).size()>256:return false
	for key:Variant in data.get("observations",{}):
		var entry:Variant=data.observations[key]
		if not key is String or key.length()>200 or not entry is Dictionary or entry.get("kind") not in ["observe","meal","share"] or not entry.get("npc") is String or entry.npc.length()>80 or not load("res://scripts/source_save_validation.gd").integer(entry.get("day"),0,int(value.day)):return false
	var board:Variant=data.get("dailyBoard",{})
	if not board is Dictionary:return false
	if not board.is_empty():
		if not load("res://scripts/source_save_validation.gd").integer(board.get("day"),0,int(value.day)) or not board.get("orders") is Array or board.orders.size()!=3:return false
		for i:int in 3:
			var order:Variant=board.orders[i]
			if not order is Dictionary or order.get("key")!="day-%d-%d"%[int(board.day),i] or not order.get("id") is String or order.id.length()>80 or not order.get("title") is String or order.title.length()>80:return false
			if not load("res://scripts/source_save_validation.gd").integer(order.get("qty"),1,4) or order.get("grade")!=0 or (not load("res://scripts/source_save_validation.gd").integer(order.get("bonus"),25,40) or int(order.bonus) not in [25,30,40]) or order.get("day")!=board.day:return false
	var log:Variant=value.get("commit_log",{"next":1,"rows":[]})
	if not log is Dictionary or not load("res://scripts/source_save_validation.gd").integer(log.get("next"),1,1000000000) or not log.get("rows") is Array or log.rows.size()>256:return false
	var seen:Dictionary={}
	for row:Variant in log.rows:
		if not row is Dictionary or not load("res://scripts/source_save_validation.gd").integer(row.get("id"),1,int(log.next)-1) or not row.get("op") is String or seen.has(row.id):return false
		seen[row.id]=true
	return true

static func activity_quote(s:Node,kind:String,npc:String="")->Dictionary:
	var reason:String="";var item:String="";var minutes:int=5 if kind=="observe" else 10
	if kind not in ["observe","meal","share"]:reason="没有这项生活活动。"
	elif kind!="observe" and (npc=="" or not s.npc_is_near(npc)):reason="先找到愿意一起坐坐的居民；手记指向真实位置。"
	elif kind=="observe" and s.current_interior!="":reason="到田边、河岸或牧野观察实际来源。"
	if kind=="meal":
		for id:String in s.inventory:
			if str(s.item_catalog.get(id,{}).get("kind",""))=="料理" and load("res://scripts/quest_service.gd").qualified(s,id)>0:item=id;break
		if item=="":reason="带一份新鲜、未保护的家常菜，再邀请邻居。"
	if kind=="observe" and reason=="":
		var found:bool=false
		for i:int in s.plots.size():
			if str(s.plots[i].get("crop",""))!="" and s.farm_plot_position(i).distance_to(s.player_position)<100:found=true;break
		if not found:
			for point:Dictionary in s.system_catalog.fishing.spots:
				if Vector2(float(point.x),float(point.y)).distance_to(s.player_position)<110:found=true;break
		if not found:reason="走近一块正在生长的田或真实钓点，再记录观察。"
	if s.minutes+minutes>1320:reason="今晚先歇息，明早还可以继续。"
	return {"ready":reason=="","reason":reason,"minutes":minutes,"item":item,"npc":npc,"kind":kind}
static func activity(s:Node,kind:String,npc:String="")->bool:
	var q:=activity_quote(s,kind,npc)
	if not q.ready:s.message=q.reason;return false
	if q.item!="" and load("res://scripts/quest_service.gd").consume(s,q.item,1).is_empty():return false
	s.minutes+=int(q.minutes)
	var key:String=kind+":"+str(s.day)+":"+npc
	s.village_progress.observations[key]={"day":s.day,"npc":npc,"kind":kind}
	if s.village_progress.observations.size()>256:s.village_progress.observations.erase(s.village_progress.observations.keys()[0])
	s.quest_event({"observe":"sourceObservation","meal":"sharedMeal","share":"gathering"}[kind],key)
	s.message={"observe":"记下了眼前的来源与季节变化。","meal":"一起尝过了这份家常菜，分享记在了村庄手记里。","share":"交换了近来的生活见闻，留下一则共同记录。"}[kind]
	s._record_community_log(s.message);s.changed.emit();return true
