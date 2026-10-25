extends RefCounted
## Transactions for rod catches and physical traps. UI never awards inventory.
const RULES = preload("res://scripts/fishing_rules.gd")

static func plan(s: Node, water: String) -> Dictionary:
	var result := RULES.predict(water,s.system_catalog.fishing,s.fishing,s.day,s.season_index(),s.weather_for(s.day),s.minutes)
	if result.is_empty():return {}
	var rod: Dictionary=s.tool_data("rod")
	result.rod=int(rod.get("level",0));result.branch=str(rod.get("branch","broad"))
	result.skill=mini(4,int(s.fishing.get("xp",0))/10)
	result.tackles=s.fishing.get("tackles",[]).filter(func(id: Variant):return int(s.inventory.get(str(id),0))>0).slice(0,int(result.rod))
	if result.tackles.has("fishBell"):result.wait=float(result.wait)*0.7
	if str(result.bait)!="plain":result.wait=float(result.wait)*0.8
	return result

static func has_bait(s: Node, bait_id: String) -> bool:
	var bait: Dictionary=s.system_catalog.fishing.baits.get(bait_id,{})
	return not bait.is_empty() and (bait_id=="plain" or int(s.inventory.get(str(bait.get("item","")),0))>0)

static func commit_cast(s: Node, game: Dictionary) -> bool:
	if bool(game.get("paid",false)):return true
	var p: Dictionary=game.plan
	if int(p.id)!=int(s.fishing.get("nextId",1)) or not has_bait(s,str(p.bait)):return false
	if not s.spend_energy(maxi(2,6-int(p.rod)),15 if int(p.rod)==2 and str(p.branch)=="broad" else 25):return false
	if str(p.bait)!="plain":s._consume_item(str(s.system_catalog.fishing.baits[str(p.bait)].item),1)
	s.fishing.rng=int(p.seed);s.fishing.nextId=int(p.id)+1
	game.paid=true
	var at: Dictionary=game.p
	var depth:=clampi(int(p.get("depth",1)),0,2)
	var landing: Dictionary=at.get("landings",[{"x":at.waterX,"y":at.waterY},{"x":at.waterX,"y":at.waterY},{"x":at.waterX,"y":at.waterY}])[depth]
	game.landing=landing
	if s.action_busy():s.action_sequence.active.spec.waterX=float(landing.x);s.action_sequence.active.spec.waterY=float(landing.y)
	var water: Dictionary=s.fishing.waters.get(str(p.water),{})
	water={"day":s.day,"casts":(int(water.get("casts",0)) if int(water.get("day",-1))==s.day else 0)+1}
	s.fishing.waters[str(p.water)]=water
	s.changed.emit()
	return true

static func finish(s: Node, game: Dictionary) -> void:
	if game.is_empty() or not bool(game.get("paid",false)):return
	var p: Dictionary=game.plan
	if int(p.id)<=int(s.fishing.get("settled",0)):return
	s.fishing.settled=int(p.id)
	if not bool(game.get("caught",false)):
		s.fishing.last={"fish":null,"water":str(p.water),"day":s.day,"reason":str(game.get("reason","鱼游走了"))}
		s.message="鱼游回水里了："+str(game.get("reason","鱼影离开控制范围太久"))+"。这一竿已用的饵料与体力保留消耗。"
	else:
		var sp: Dictionary=s.system_catalog.fishing.species[str(p.fish)]
		var old: Dictionary=s.fishing.records.get(str(p.fish),{})
		s.fishing.pending={"id":int(p.id),"fish":str(p.fish),"water":str(p.water),"length":float(p.length),"grade":RULES.grade(p,float(game.safe),float(game.total)),"producedDay":s.day,"method":"rod","mode":str(p.mode),"ratio":float(game.safe)/maxf(0.01,float(game.total)),"new":int(old.get("count",0))==0,"best":float(p.length)>float(old.get("best",0)),"name":str(sp.name)}
		s.message="抄起"+str(sp.name)+"，选择留下或轻轻放流。"
	s.changed.emit()

static func record(s: Node, result: Dictionary, released: bool) -> void:
	var id:=str(result.fish)
	var row: Dictionary=s.fishing.records.get(id,{"count":0,"best":0.0,"grade":0,"waters":[],"rod":0,"trap":0,"released":0,"first":s.day,"manualBest":0.0})
	row.count=int(row.get("count",0))+1
	row.best=maxf(float(row.get("best",0)),float(result.get("length",0)))
	row.grade=maxi(int(row.get("grade",0)),int(result.get("grade",0)))
	var method:=str(result.get("method","rod"))
	row[method]=int(row.get(method,0))+1
	if released:row.released=int(row.get("released",0))+1
	if str(result.get("mode",""))=="standard":row.manualBest=maxf(float(row.get("manualBest",0)),float(result.get("ratio",0)))
	if not row.waters.has(str(result.water)):row.waters.append(str(result.water))
	s.fishing.records[id]=row
	s.fishing.last=result.duplicate(true);s.fishing.last.day=s.day;s.fishing.last.released=released
	s.fish_caught+=1;s.player_stats.fish=int(s.player_stats.get("fish",0))+1
	s.fishing.xp=int(s.fishing.get("xp",0))+1
	if method=="rod":s.fishing.tutorialDone=true
	s._award_tool("rod")
	s._museum_record("item:"+id,true,int(row.count)>=3,false,int(row.grade))

static func put_inventory(s: Node, result: Dictionary) -> void:
	var id:=str(result.fish)
	var grade:=int(result.grade)
	s._reconcile_kitchen_lots()
	s._add_inventory_count(id,1)
	if grade>0:
		var grades: Array=s.quality.get(id,[0,0,0]);grades[grade-1]=int(grades[grade-1])+1;s.quality[id]=grades
	if s._is_food(id):
		var lots: Dictionary=s.kitchen.lots.bag
		var rows: Array=lots.get(id,[])
		rows.append({"qty":1,"age":stored_age(s,int(result.producedDay)),"producedDay":int(result.producedDay),"grade":grade})
		lots[id]=rows

static func resolve(s: Node, released: bool) -> bool:
	var pending: Dictionary=s.fishing.get("pending",{})
	if pending.is_empty():return false
	s.fishing.pending={}
	if not released and int(s.inventory.get(str(pending.fish),0))>=999999:s.fishing.pending=pending;s.message="这一类物品已满，鱼获保留在待处理面板。";s.changed.emit();return false
	if not released:put_inventory(s,pending)
	record(s,pending,released)
	s.message=("轻轻放回" if released else "收下")+str(pending.name)+" · %.1f 厘米 · %s" % [float(pending.length),["普通","优质","上品","珍品"][int(pending.grade)]]
	s._museum_sync();s.changed.emit()
	return true

static func craft(s: Node, id: String) -> bool:
	var recipe: Dictionary=s.system_catalog.fishing.crafts.get(id,{})
	if recipe.is_empty() or not s._kitchen_has(recipe.needs,1) or recipe.needs.keys().any(func(key: Variant):return s.economy.get("locked",[]).has(key)):s.message="制作材料不足。";s.changed.emit();return false
	if not s.spend_energy(1,5):return false
	s._kitchen_consume(recipe.needs,1)
	s._add_inventory_count(id,int(recipe.qty))
	s._museum_record("item:"+id,true,true)
	s.message="制成%s ×%d。" % [str(recipe.name),int(recipe.qty)]
	s.changed.emit();return true

static func equip(s: Node, id: String) -> bool:
	var equipped: Array=s.fishing.get("tackles",[])
	if equipped.has(id):equipped.erase(id)
	elif int(s.inventory.get(id,0))>0 and s.system_catalog.fishing.tackles.has(id) and equipped.size()<int(s.tool_data("rod").get("level",0)):equipped.append(id)
	else:s.message="钓具未制作，或鱼竿没有空余钓具槽。";s.changed.emit();return false
	s.fishing.tackles=equipped;s.changed.emit();return true

static func slot(s: Node, id: String) -> Dictionary:
	for at: Dictionary in s.system_catalog.fishing.trapSlots:
		if str(at.id)==id:return at
	return {}

static func trap_status(s: Node, id: String) -> String:
	var row: Dictionary=s.fishing.traps.get(id,{})
	if row.is_empty():return "空笼位 · 可放置"
	if not str(row.get("reason","")).is_empty():return str(row.reason)
	if not row.get("product",{}).is_empty():return "待收获 · 停止继续生产"
	return "已投饵 · 明早查看" if int(row.get("baitedDay",-1))>=0 else "空笼 · 需要投饵"

static func trap_action(s: Node, id: String, op: String, bait: String="") -> bool:
	var at:=slot(s,id)
	if at.is_empty() or s.current_interior!="" or s.player_position.distance_to(Vector2(float(at.x),float(at.y)))>75:return false
	var traps: Dictionary=s.fishing.traps
	var row: Dictionary=traps.get(id,{})
	match op:
		"place":
			if not row.is_empty() or traps.size()>=int(s.system_catalog.fishing.trapLimit) or int(s.inventory.get("fishTrap",0))<1:s.message="没有空余捕笼，或已达到同时部署 8 个的上限。";return false
			if not s.spend_energy(2,8):return false
			s._consume_item("fishTrap",1);traps[id]={"bait":"","baitedDay":-1,"lastDay":s.day,"product":{}}
		"bait":
			if row.is_empty() or int(row.get("baitedDay",-1))>=0 or not row.get("product",{}).is_empty() or bait=="plain" or not has_bait(s,bait):s.message="先收好产物，再放一份制成的鱼饵。";return false
			var choices: Array=RULES.pool(s.system_catalog.fishing.waters[str(at.water)],s.system_catalog.fishing.species,s.season_index(),s.weather_for(s.day),480,bait,"trap",str(at.water))
			if choices.is_empty():s.message="这个季节没有适合捕笼的水产，换一处水域吧。";return false
			if not s.spend_energy(1,2):return false
			row.reason=""
			s._consume_item(str(s.system_catalog.fishing.baits[bait].item),1);row.bait=bait;row.baitedDay=s.day
		"take","release":
			var product: Dictionary=row.get("product",{})
			if product.is_empty():return false
			if op=="take" and int(s.inventory.get(str(product.fish),0))>=999999:s.message="这一类物品已满，产物继续留在笼内。";return false
			if not s.spend_energy(1,4):return false
			row.product={}
			if op=="take":put_inventory(s,product)
			record(s,product,op=="release")
		"remove":
			if row.is_empty() or not row.get("product",{}).is_empty() or int(row.get("baitedDay",-1))>=0:s.message="先收取产物，已投饵的笼子暂不拆除。";return false
			if not s.spend_energy(1,3):return false
			traps.erase(id);s._add_inventory_count("fishTrap",1)
		_:return false
	s.message="捕笼已处理 · "+trap_status(s,id);s._museum_sync();s.changed.emit();return true

static func advance(s: Node, target_day: int) -> void:
	for id: String in s.fishing.get("traps",{}):
		var row: Dictionary=s.fishing.traps[id]
		if int(row.get("lastDay",-1))>=target_day:continue
		row.lastDay=target_day
		if not row.get("product",{}).is_empty() or int(row.get("baitedDay",-1))<0 or int(row.baitedDay)>=target_day:continue
		var at:=slot(s,id)
		var production_day:=int(row.baitedDay)+1
		var context: Dictionary=s.fishing.duplicate(true);context.bait=str(row.bait)
		var p:=RULES.predict(str(at.water),s.system_catalog.fishing,context,production_day,int(production_day/28)%4,s.weather_for(production_day),480,"trap")
		row.baitedDay=-1
		if p.is_empty():row.reason="本季暂无笼捕对象 · 暂停";continue
		s.fishing.rng=int(p.seed)
		row.product={"fish":str(p.fish),"name":str(s.item_catalog[str(p.fish)].name),"water":str(at.water),"length":float(p.length),"grade":mini(2,int(s.tool_data("rod").get("level",0))),"producedDay":production_day,"method":"trap"}

static func queue(s: Node, tasks: Array) -> bool:
	if s.action_busy() or s.fishing_active() or s.current_interior!="":return false
	var accepted: Array=[]
	for task: Dictionary in tasks:
		if not slot(s,str(task.get("id",""))).is_empty():accepted.append(task.duplicate(true))
	if accepted.is_empty():return false
	s._interrupt_navigation_for_ui()
	s.fishing.queue=accepted;s.ui_open=false;s.changed.emit();return true

static func advance_queue(s: Node, actor: Node) -> void:
	if s.fishing.get("queue",[]).is_empty():return
	var task: Dictionary=s.fishing.queue[0]
	var at:=slot(s,str(task.id))
	var target: Dictionary=at.duplicate(true)
	target.kind="fishtrap-task";target.fishing_task=true;target.op=task.op;target.bait=task.get("bait",s.fishing.bait)
	if not actor.walk_to(target):s.fishing.queue=[];s.message="这处笼位暂时无法到达。";s.changed.emit()

static func finish_task(s: Node, target: Dictionary) -> void:
	var tasks: Array=s.fishing.get("queue",[])
	if tasks.is_empty() or str(tasks[0].id)!=str(target.id):return
	var at:=slot(s,str(target.id))
	if at.is_empty() or s.player_position.distance_to(Vector2(float(at.x),float(at.y)))>75:s.fishing.queue=[];return
	s.begin_action({"kind":"pack","label":"岸边捕笼 · "+str(target.op),"duration":1.0},target,_commit_task.bind(s,target.duplicate(true)))

static func _commit_task(s: Node, target: Dictionary) -> void:
	var tasks: Array=s.fishing.get("queue",[])
	if tasks.is_empty() or str(tasks[0].id)!=str(target.id):return
	if not trap_action(s,str(target.id),str(target.op),str(target.get("bait","grain"))):s.fishing.queue=[]
	else:tasks.pop_front()
	s.changed.emit()

static func initialize_current(s: Node) -> void:
	# JSON numbers are decoded as floats; normalize current-format identity/count fields.
	if int(s.fishing.get("version",0))!=2:return
	for key: String in ["version","rng","nextId","settled","depth","xp"]:
		if s.fishing.has(key):s.fishing[key]=int(s.fishing[key])
	s.fishing.queue=[]
	s.fishing.settled=maxi(int(s.fishing.get("settled",0)),int(s.fishing.get("nextId",1))-1)
	var pending: Dictionary=s.fishing.get("pending",{})
	for key: String in ["id","grade","producedDay"]:
		if pending.has(key):pending[key]=int(pending[key])
	for row: Dictionary in s.fishing.get("traps",{}).values():
		for key: String in ["baitedDay","lastDay"]:row[key]=int(row[key])
		for key: String in ["grade","producedDay"]:
			if row.product.has(key):row.product[key]=int(row.product[key])
	for row: Dictionary in s.fishing.get("records",{}).values():
		for key: String in ["count","grade","rod","trap","released","first"]:
			if row.has(key):row[key]=int(row[key])

static func stored_age(s: Node, produced_day: int) -> float:
	var age: float=0.0
	for day: int in range(produced_day,s.day):
		var profile: Dictionary=s.weather_profile(day)
		var temperature: float=float(profile.get("mean_temperature",20))
		age+=1.25 if temperature>=33 else 0.75 if temperature<=5 else 1.0
	return minf(3650.0,age)
