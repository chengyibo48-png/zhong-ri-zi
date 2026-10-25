extends RefCounted
## Owns task progress and commands; gameplay domains remain authoritative.
const KNOWLEDGE=preload("res://scripts/knowledge_catalog.gd")
const PROJECT_SITES={"bridge":{"x":1014,"y":2820,"name":"村口河埠施工点"},"canal":{"x":3040,"y":1950,"name":"小院旧水渠施工点"},"market":{"x":2816,"y":790,"name":"老街遮雨集市施工点"},"stage":{"x":3520,"y":930,"name":"老街戏台施工点"}}
static var _guides: Array=[]
static var _syncing: bool=false
static var _hours: Dictionary={}
static func guides() -> Array:
	if _guides.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"));_guides=data.guides;_hours=data.serviceHours
	return _guides
static func defaults() -> Dictionary:
	return {"version":1,"entries":{},"metrics":{},"pins":[],"collapsed":false,"sequence":0,"seen":[],"notices":{}}
static func initialize(s: Node) -> void:
	if s.quests.is_empty():s.quests=defaults()
static func event(s: Node, key: String, token: String="", amount: int=1) -> bool:
	initialize(s)
	if token!="" and s.quests.seen.has(token):return false
	if token!="":
		s.quests.seen.append(token)
		while s.quests.seen.size()>1024:s.quests.seen.pop_front()
	s.quests.sequence=int(s.quests.sequence)+1
	s.quests.metrics[key]=int(s.quests.metrics.get(key,0))+maxi(0,amount)
	return true
static func metric(s: Node, key: String) -> int:
	var n: int=int(s.quests.metrics.get(key,0))
	match key:
		"rest":return maxi(n,s.day)
		"harvest":return maxi(n,int(s.player_stats.get("harvested",0)))
		"cook":return maxi(n,int(s.player_stats.get("cooked",0)))
		"gift":return maxi(n,int(s.player_stats.get("gifts",0)))
		"animals":return s.animals.size()
		"seasonSeed":
			for id: String in s.crop_catalog:
				if s.crop_in_season(id) and int(s.inventory.get(str(s.crop_catalog[id].seed),0))>0:return 1
		"sow":return n
		"fertilize":
			for row: Dictionary in s.farm.get("beds",[]):
				if int(row.get("fertilized",-1))>=0:return maxi(1,n)
		"animalCare":
			for a: Dictionary in s.animals:
				if int(a.get("care",{}).get("pet",-1))>=0 or int(a.get("care",{}).get("feed",-1))>=0:return maxi(1,n)
		"graze":
			for a: Dictionary in s.animals:
				if bool(a.get("outside",false)) or str(a.get("activity",""))=="graze":return maxi(1,n)
		"rodCatch","trapCatch":
			var total:=0
			for row: Dictionary in s.fishing.records.values():total+=int(row.get("rod" if key=="rodCatch" else "trap",0))
			return total
		"fishRecord","freshCheck":return n
		"baitedTrap":
			for row: Dictionary in s.fishing.get("traps",{}).values():
				if int(row.get("baitedDay",-1))>=0 or not row.get("product",{}).is_empty():return maxi(n,1)
		"talk":
			var total:=0
			for row: Dictionary in s.relations.values():
				if int(row.get("talked",-1))>=0:total+=1
			return total
		"story":
			var total:=0
			for row: Dictionary in s.npc_stories.values():total+=int(row.get("step",0))
			return total
		"share":return metric(s,"gift")+int(bool(s.flags.get("firstDish",false)))
		"research":return n
		"donate":return s.collection.get("donated",{}).size()
		"yearReview":return int(s.day>=112 and int(s.quests.metrics.get("visit:year",0))>0)
	if key.begins_with("inventory:"):
		var bits:=key.split(":");return int(int(s.inventory.get(bits[1],0))>=int(bits[2]))
	if key.begins_with("flag:"):return int(bool(s.flags.get(key.trim_prefix("flag:"),false)))
	if key.begins_with("project:"):return int(bool(s.community_projects.get(key.trim_prefix("project:"),false)))
	return n
static func definitions(s: Node) -> Array:
	var rows: Array=guides().duplicate(true)
	for row: Dictionary in rows:row.kind="guide"
	for order: Dictionary in s.content.get("orders",[]):
		rows.append({"id":"wish:"+str(order.id),"kind":"wish","category":"人物","title":order.title,"text":order.text,"needs":order.needs,"reward":order.get("reward",{}),"money":order.get("money",0),"npc":order.npc,"source":"npc:"+str(order.npc),"ref":str(order.id),"page":"orders"})
	for favor: Dictionary in s.content.get("favors",[]):
		rows.append({"id":"favor:"+str(favor.id),"kind":"favor","category":"委托","title":favor.title,"text":favor.text,"needs":favor.needs,"reward":favor.get("reward",{}),"money":favor.get("money",0),"npc":favor.npc,"source":"npc:"+str(favor.npc),"ref":str(favor.id),"page":"orders"})
	for id: String in s.content.get("projects",{}):
		var project: Dictionary=s.content.projects[id]
		rows.append({"id":"project:"+id,"kind":"project","category":"主线","title":project.name,"text":str(project.people)+"\n"+str(project.change),"needs":project.needs,"source":"project:"+id,"ref":id,"seasonDay":int(project.season)*28,"page":"projects","unlock":str(project.get("recipe",""))})
	for order: Dictionary in s.economy_weekly_orders():
		rows.append(weekly_definition(s,order))
	for entry: Dictionary in s.quests.entries.values():
		if entry.get("definition",{}).get("kind","") in ["weekly","story","chapter"]:
			for i: int in range(rows.size()-1,-1,-1):
				if str(rows[i].id)==str(entry.definition.id):rows.remove_at(i)
			rows.append(entry.definition.duplicate(true))
	for npc: Dictionary in s.npc_catalog:
		var id:=str(npc.id);var arc: Array=s.content.get("arcs",{}).get(id,[]);var step:=int(s.npc_stories.get(id,{}).get("step",0))
		if step>=arc.size():continue
		if step==0 and int(s.relations.get(id,{}).get("talked",-1))<0 and not bool(s.neighbors.get("people",{}).get(id,{}).get("introduced",false)):continue
		var story: Dictionary=arc[step]
		rows.append({"id":"story:"+id+":"+str(step),"kind":"story","category":"人物","title":str(npc.name)+" · "+str(story.title),"text":"在关系与前置满足后，面对面倾听这一段故事。后续内容会逐步展开。","npc":id,"ref":id,"step":step,"points":int(story.get("points",0)),"needs":story.get("needs",{}) if story.get("needs") is Dictionary else {},"source":"npc:"+id,"page":"stories"})
	for season: int in range(4):
		var chapter: Dictionary=s.content.seasonChapters[season]
		rows.append({"id":"chapter:%d:%d" % [int(s.day/112)+1,season],"year":int(s.day/112)+1,"kind":"chapter","category":"主线","title":chapter.title,"text":chapter.goal,"ref":str(season),"seasonDay":season*28,"source":"home","page":"stories"})
	return rows
static func weekly_definition(s: Node, order: Dictionary) -> Dictionary:
	return {"id":"weekly:"+str(order.key),"kind":"weekly","category":"委托","title":order.title,"text":"合作社本周供货单。接取后条件固定；到实际柜台交付。","ref":str(order.key),"order":order.duplicate(true),"needs":{str(order.id):int(order.qty)},"grade":int(order.grade),"source":"coop","deadline":(int(s.day/7)+1)*7,"page":"economy"}
static func definition(s: Node, id: String) -> Dictionary:
	for row: Dictionary in definitions(s):
		if str(row.id)==id:return row
	return s.quests.entries.get(id,{}).get("definition",{}).duplicate(true)
static func done(s: Node, d: Dictionary) -> bool:
	var ref:=str(d.get("ref",""))
	match str(d.kind):
		"wish":return bool(s.flags.get(ref,false))
		"favor":return bool(s.season_events.get("favor-"+ref,false))
		"project":return bool(s.community_projects.get(ref,false))
		"weekly":return s.economy.get("claimed",[]).has(ref)
		"story":return int(s.npc_stories.get(ref,{}).get("step",0))>int(d.step)
		"chapter":return s.legacy_chapters.has(str(int(d.get("year",int(s.day/112)+1)))+"-"+ref)
	return str(s.quests.entries.get(str(d.id),{}).get("status",""))=="completed"
static func food_segments(s: Node, item: String) -> Array:
	var counts: Array=s._quality_counts(item).duplicate()
	var result: Array=[]
	for row: Dictionary in s.kitchen.get("lots",{}).get("bag",{}).get(item,[]):
		var left:=int(row.get("qty",0));var specified:=int(row.get("grade",-1))
		var order: Array=[specified] if specified>=0 and specified<=3 else [0,1,2,3]
		if order.size()==1:order.append_array([0,1,2,3])
		for grade: int in order:
			var qty:=mini(left,int(counts[grade]))
			if qty<=0:continue
			var segment:=row.duplicate(true);segment.qty=qty;segment.grade=grade;result.append(segment);counts[grade]-=qty;left-=qty
			if left<=0:break
	return result
static func eligible_counts(s: Node, item: String) -> Array:
	if s._is_food(item):s._reconcile_kitchen_lots()
	if s.economy.get("locked",[]).has(item):return [0,0,0,0]
	var counts: Array=s._quality_counts(item)
	if not s._is_food(item):return counts
	var fresh: Array=[0,0,0,0]
	for segment: Dictionary in food_segments(s,item):
		if float(segment.get("age",0))<float(s._food_shelf_days(item)):fresh[int(segment.grade)]+=int(segment.qty)
	return fresh
static func qualified(s: Node, item: String, grade: int=0) -> int:
	var counts:=eligible_counts(s,item);var result:=0
	for i: int in range(clampi(grade,0,3),4):result+=int(counts[i])
	return result
static func consume(s: Node, item: String, quantity: int, minimum: int=0, exact: bool=false) -> Array:
	var counts: Array=s._quality_counts(item);var eligible:=eligible_counts(s,item);var taken: Array=[0,0,0,0];var left:=quantity
	for grade: int in range(clampi(minimum,0,3),4):
		if exact and grade!=minimum:continue
		taken[grade]=mini(left,int(eligible[grade]));left-=int(taken[grade])
	if left>0:return []
	if s._is_food(item):
		var segments:=food_segments(s,item);segments.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.get("age",0))>float(b.get("age",0)))
		var pending:=taken.duplicate();var remaining: Array=[]
		for segment: Dictionary in segments:
			var grade:=int(segment.grade)
			if float(segment.get("age",0))<float(s._food_shelf_days(item)):
				var qty:=mini(int(segment.qty),int(pending[grade]));segment.qty-=qty;pending[grade]-=qty
			if int(segment.qty)>0:remaining.append(segment)
		s.kitchen.lots.bag[item]=remaining
	s.inventory[item]=int(s.inventory.get(item,0))-quantity
	s.quality[item]=[int(counts[1])-int(taken[1]),int(counts[2])-int(taken[2]),int(counts[3])-int(taken[3])]
	return taken
static func snapshot(s: Node, d: Dictionary) -> Dictionary:
	var r:=d.duplicate(true);var id:=str(d.id);var e: Dictionary=s.quests.entries.get(id,{})
	r.status="available";r.reason="";r.current=0;r.required=int(d.get("target",1));r.deadline=int(e.get("deadline",d.get("deadline",-1)));r.accepted=not e.is_empty();r.pinned=s.quests.pins.has(id)
	if done(s,d):r.status="completed";r.current=r.required;return r
	if str(e.get("status","")) in ["expired","abandoned"]:r.status=e.status;return r
	if r.accepted and int(r.deadline)>=0 and s.day>=int(r.deadline):r.status="expired";r.reason="已过截止日，物品保留，不扣钱或关系。";return r
	if d.has("previous") and str(d.previous)!="" and str(s.quests.entries.get(str(d.previous),{}).get("status",""))!="completed":r.status="locked";r.reason="先完成这条引导链的当前步骤。";return r
	if s.day<int(d.get("seasonDay",0)):r.status="locked";r.reason="等待对应季节到来，之后可以慢慢补做。";return r
	if str(d.kind)=="guide":
		if str(d.get("source","")).begins_with("project:"):
			var site_status: Dictionary=s.community_project_status(str(d.source).trim_prefix("project:"));r.reason=str(site_status.get("reason","")) if not bool(site_status.get("done",false)) else ""
		r.current=maxi(0,metric(s,str(d.metric))-(int(e.get("baseline",0)) if bool(d.get("afterAccept",false)) else 0))
		if r.accepted:r.status="reward" if int(r.current)>=int(r.required) else "active"
		return r
	var ready:=true;var lines: Array[String]=[]
	for item: String in d.get("needs",{}):
		var have:=qualified(s,item,int(d.get("grade",0)));var need:=int(d.needs[item]);ready=ready and have>=need
		lines.append(str(s.item_catalog.get(item,{}).get("name",item))+" %d / %d" % [mini(have,need),need]+(" · 已保护" if s.economy.get("locked",[]).has(item) else ""))
	r.materials=lines;r.current=int(ready)
	if str(d.kind)=="project":
		var status: Dictionary=s.community_project_status(str(d.ref));ready=bool(status.get("ready",false));r.reason=str(status.get("reason",""))
	if str(d.kind)=="story":
		var story_status: Dictionary=s.npc_story_readiness(str(d.npc))
		ready=bool(story_status.get("ok",false)) and ready
		if not ready:r.reason=str(story_status.get("message","关系或故事前置尚未满足。"))
	if str(d.kind)=="weekly" and not counter_open(s):ready=false;r.reason="今日柜台已休息，订单今晚结束；未交物资保留，没有额外处罚。" if int(r.deadline)==s.day+1 and s.minutes>=1200 else "合作社柜台办理时间为 08:00—20:00，先准备材料，营业后交接。"
	if r.accepted:r.status="ready" if ready else "active"
	if not ready and str(r.reason)=="":r.reason="材料尚未备齐，或物品品质、鲜度与保护状态不符合。"
	return r
static func rows(s: Node, filters: Dictionary={}) -> Array:
	initialize(s);var result: Array=[]
	for d: Dictionary in definitions(s):
		var r:=snapshot(s,d)
		if str(r.status)=="locked" and str(r.kind)!="project":continue
		if str(filters.get("category","全部"))!="全部" and str(r.category)!=str(filters.category):continue
		var search:=str(filters.get("search","")).strip_edges()
		if search!="" and not (str(r.title)+str(r.text)).contains(search):continue
		result.append(r)
	return result
static func sync(s: Node) -> void:
	if _syncing:return
	_syncing=true;initialize(s)
	for d: Dictionary in guides():
		var key:=str(d.metric);s.quests.metrics[key]=maxi(int(s.quests.metrics.get(key,0)),metric(s,key)) if not key.begins_with("inventory:") and key!="seasonSeed" else int(s.quests.metrics.get(key,0))
		if not s.quests.entries.has(str(d.id)) and (bool(d.auto) or str(d.previous)!="" and str(s.quests.entries.get(str(d.previous),{}).get("status",""))=="completed"):
			s.quests.entries[str(d.id)]={"status":"active","acceptedDay":s.day,"deadline":-1,"baseline":metric(s,str(d.metric)) if bool(d.get("afterAccept",false)) else 0}
	for id: String in s.quests.entries:
		var e: Dictionary=s.quests.entries[id]
		if str(e.status) in ["completed","expired","abandoned"]:continue
		if int(e.get("deadline",-1))>=0 and s.day>=int(e.deadline):e.status="expired"

	var notes: Array[String]=[]
	var notify_new: bool=s.quests.notices.has("initialized")
	for d: Dictionary in definitions(s):
		var state: String=str(snapshot(s,d).status)
		if state not in ["available","active","ready","reward"]:continue
		var notice_key: String="known:"+str(d.id)
		if not s.quests.notices.has(notice_key):
			if notify_new:notes.append(("下一步 · " if str(d.kind)=="guide" and state=="active" else "新心愿 · ")+str(d.title))
			s.quests.notices[notice_key]="shown"
	s.quests.notices.initialized="yes"
	for d: Dictionary in definitions(s):
		if not s.quests.entries.has(str(d.id)):continue
		var r:=snapshot(s,d);var state:=str(r.status);var previous:=str(s.quests.notices.get(str(d.id),"active"))
		if state!=previous and state in ["ready","reward"]:notes.append(str(d.title)+(" · 可以交付" if state=="ready" else " · 已达成"))
		s.quests.notices[str(d.id)]=state
		if r.accepted and int(r.deadline)-s.day==1 and state in ["active","ready"]:
			var key: String="deadline:"+str(d.id)
			if not s.quests.notices.has(key):notes.append(str(d.title)+" · 今天截止");s.quests.notices[key]="shown"
	_syncing=false
	s.quest_changed.emit()
	if not notes.is_empty():s.message_requested.emit("手记更新："+"；".join(notes.slice(0,2))+(" 等 %d 项" % notes.size() if notes.size()>2 else ""))
static func accept(s: Node, id: String) -> bool:
	initialize(s);var d:=definition(s,id)
	if d.is_empty() or str(snapshot(s,d).status)!="available":return false
	s.quests.entries[id]={"status":"active","acceptedDay":s.day,"deadline":int(d.get("deadline",-1)),"baseline":metric(s,str(d.get("metric",""))) if bool(d.get("afterAccept",false)) else 0,"definition":d.duplicate(true)}
	s.changed.emit();return true
static func claim(s: Node, id: String) -> bool:
	var d:=definition(s,id)
	if d.is_empty() or str(d.kind)!="guide" or str(snapshot(s,d).status)!="reward":return false
	for item: String in d.get("reward",{}):
		if int(s.inventory.get(item,0))+int(d.reward[item])>999999:s.message="背包暂时放不下，回礼会留在手记里。";s.changed.emit();return false
	s.quests.entries[id].status="completed";s.quests.entries[id].claimed=true;s.quests.entries[id].completedDay=s.day
	for item: String in d.get("reward",{}):s._grant_legacy_item(item,int(d.reward[item]))
	s.message="记下了："+str(d.title)+(" · 回礼已收好。" if not d.get("reward",{}).is_empty() else "。")
	s.quests.pins.erase(id)
	s.changed.emit();return true
static func pin(s: Node, id: String) -> bool:
	var d:=definition(s,id)
	if d.is_empty():return false
	if s.quests.pins.has(id):s.quests.pins.erase(id)
	else:
		if s.quests.pins.size()>=2:s.quests.pins.pop_front()
		s.quests.pins.append(id);event(s,"pin")
	s.changed.emit();return true
static func abandon(s: Node, id: String) -> bool:
	var d:=definition(s,id)
	if d.is_empty() or str(d.kind)!="weekly" or not s.quests.entries.has(id) or str(snapshot(s,d).status) not in ["active","ready"]:return false
	s.quests.entries[id].status="abandoned";s.quests.pins.erase(id);s.changed.emit();return true
static func near(s: Node, d: Dictionary) -> bool:
	if str(d.get("source","")).begins_with("npc:"):return s.npc_is_near(str(d.source).trim_prefix("npc:"))
	if str(d.get("source",""))=="coop":
		var at: Dictionary=KNOWLEDGE._house(s,"禾溪合作社")
		if s.current_interior!="":return s.current_interior==str(at.get("id","")) and s.interior_position.distance_to(Vector2(480,510))<=110.0
		return not at.is_empty() and s.player_position.distance_to(Vector2(float(at.x),float(at.y)))<=85.0
	var at:=target(s,d)
	return s.current_interior=="" and not at.is_empty() and s.player_position.distance_to(Vector2(float(at.x),float(at.y)))<=95.0
static func submit(s: Node, id: String) -> bool:
	var d:=definition(s,id)
	if d.is_empty() or str(snapshot(s,d).status)!="ready":return false
	if not near(s,d):s.message="先到实际人物或办理地点，再交接。";s.changed.emit();return false
	if not reward_room(s,d):s.message="回礼暂时放不下，整理背包后再交付。";s.changed.emit();return false
	var ok:=false
	match str(d.kind):
		"wish":ok=s.fulfill_legacy_order(str(d.ref))
		"favor":ok=s.complete_neighbor_favor(int(d.ref))
		"project":ok=s.complete_community_project(str(d.ref))
		"weekly":ok=s.fulfill_economy_order(str(d.ref))
	if ok:
		s.quests.entries[id].status="completed";s.quests.entries[id].completedDay=s.day;s.quests.pins.erase(id);s.changed.emit()
	return ok
static func reward_room(s: Node, d: Dictionary) -> bool:
	if s.money+int(d.get("money",0))>1000000000:return false
	for item: String in d.get("reward",{}):
		if int(s.inventory.get(item,0))-int(d.get("needs",{}).get(item,0))+int(d.reward[item])>999999:return false
	return true
static func target(s: Node, d: Dictionary) -> Dictionary:
	var source:=str(d.get("source","home"));var at: Dictionary={}
	if source.begins_with("npc:"):
		for person: Dictionary in s.npc_catalog:
			if str(person.id)==source.trim_prefix("npc:"):return s.atlas_npc_target(person)
		return {}
	if source.begins_with("item:"):return KNOWLEDGE.source_target(s,source)
	if source.begins_with("project:"):
		var id:=source.trim_prefix("project:")
		at=PROJECT_SITES.get(id,{}).duplicate(true)
	elif source=="water":
		var best:=INF;var choices: Array=s.system_catalog.fishing.spots
		if str(d.get("metric","")) in ["baitedTrap","trapCatch"]:
			choices=s.system_catalog.fishing.trapSlots
			var deployed: Array=[]
			for slot: Dictionary in choices:
				if s.fishing.traps.has(str(slot.id)):deployed.append(slot)
			if not deployed.is_empty():choices=deployed
		for spot: Dictionary in choices:
			var dist: float=s.player_position.distance_to(Vector2(float(spot.x),float(spot.y)))
			if dist<best:best=dist;at=spot.duplicate(true)
	elif source=="farm":at=s.world_village.regionDestinations.farm.duplicate(true)
	elif source=="ranch":at=s.world_village.regionDestinations.pasture.duplicate(true)
	elif source=="gathering":at=s.world_village.regionDestinations.mountain.duplicate(true)
	else:at=KNOWLEDGE._house(s,{"home":"home","seed":"seed","kitchen":"kitchen","museum":"村史馆","coop":"禾溪合作社"}.get(source,source))
	if at.is_empty():return {}
	at.kind="walk";at.id=null;at.questId=str(d.id);at.auto_interact=false
	var nav: RefCounted=s.npc_movement.navigation;nav.refresh(s)
	var origin:=Vector2(float(at.x),float(at.y))
	for radius: float in [0.0,24.0,48.0,72.0]:
		for direction: int in range(8):
			var p:=origin+Vector2.from_angle(direction*TAU/8)*radius
			if nav.blocked(s,"",p.x,p.y):continue
			var candidate:=at.duplicate(true);candidate.x=p.x;candidate.y=p.y
			if bool(s.atlas_preview(candidate).get("reachable",false)):return candidate
	return {}
static func track(s: Node, id: String) -> Dictionary:
	var d:=definition(s,id)
	if d.is_empty():return {}
	var at:=target(s,d)
	if not at.is_empty():
		s.atlas.tracking=at.duplicate(true)
		if not s.quests.pins.has(id):pin(s,id)
		else:s.changed.emit()
	return at
static func validate(value: Variant, day: int) -> bool:
	return preload("res://scripts/quest_save_rules.gd").validate(value,day)

static func can_commit(s: Node, kind: String, ref: String) -> bool:
	initialize(s)
	var prefix: String={"wish":"wish:","favor":"favor:","project":"project:","weekly":"weekly:"}.get(kind,"")
	var d:=definition(s,prefix+ref)
	if d.is_empty():return false
	if not near(s,d):s.message="请先到"+(s.npc_name(str(d.npc)) if d.has("npc") else "实际办理地点")+"身边交接，任务手记可追踪路线。";return false
	if kind=="weekly" and not counter_open(s):s.message="合作社柜台已休息，办理时间为 08:00—20:00。";return false
	if kind=="weekly":
		var e: Dictionary=s.quests.entries.get(prefix+ref,{})
		if e.is_empty() or str(snapshot(s,d).status) not in ["active","ready"]:s.message="请先接取仍在期限内的供货单。";return false
	for item: String in d.get("needs",{}):
		if qualified(s,item,int(d.get("grade",0)))<int(d.needs[item]):s.message="材料的数量、品质、鲜度或保护状态不符合交付要求。";return false
	if not reward_room(s,d):s.message="回礼暂时放不下，请先整理背包或零钱。";return false
	return true
static func accepted_order(s: Node, key: String) -> Dictionary:
	var e: Dictionary=s.quests.entries.get("weekly:"+key,{})
	if e.is_empty() or int(e.get("deadline",-1))<=s.day or str(e.get("status","")) in ["completed","expired","abandoned"]:return {}
	return e.get("definition",{}).get("order",{}).duplicate(true)

static func complete_record(s: Node, d: Dictionary) -> void:
	if d.is_empty():return
	var id:=str(d.id)
	var e: Dictionary=s.quests.entries.get(id,{"acceptedDay":s.day,"deadline":-1,"baseline":0})
	e.status="completed";e.completedDay=s.day;e.definition=d.duplicate(true);e.domainSettled=true
	s.quests.entries[id]=e;s.quests.pins.erase(id)

static func walk_target(s: Node, d: Dictionary) -> Dictionary:
	var source:=str(d.get("source",""))
	return s.npc_destination(source.trim_prefix("npc:")) if source.begins_with("npc:") else target(s,d)

static func counter_open(s: Node) -> bool:
	guides()
	var hours: Array=_hours.get("coop",[480,1200])
	return s.minutes>=float(hours[0]) and s.minutes<float(hours[1])
static func location_text(s: Node, d: Dictionary) -> String:
	var source:=str(d.get("source","home"))
	if source.begins_with("npc:"):
		var id:=source.trim_prefix("npc:");var place: Dictionary=s.npc_location(id)
		return s.npc_name(id)+" · "+str(place.get("place","查看人物行踪"))+" · "+str(place.get("activity",""))+"；靠近后当面交接。"
	if source.begins_with("project:"):return str(PROJECT_SITES.get(source.trim_prefix("project:"),{}).get("name","公共施工点"))+"；现场立牌可打开同一份安排。"
	if source.begins_with("item:"):
		var info: Dictionary=KNOWLEDGE.describe(s,source)
		return str(info.get("source",""))+(" · "+str(info.reason) if str(info.get("reason",""))!="" else "")
	if source=="coop":return "禾溪合作社门前交接处或室内柜台 · 08:00—20:00。"
	if source=="museum":return "禾溪村史馆 · 进门后走到登记桌前。"
	if source=="kitchen":return "禾溪小灶 · 材料备好后到实际工位制作或领取。"
	if source=="seed":return "种子互助屋 · 当季种子；背包中的合格种子同样可用。"
	if source=="water" and str(d.get("metric",""))=="trapCatch":
		var waits: Array[String]=[]
		for trap: Dictionary in s.fishing.traps.values():
			if not trap.get("product",{}).is_empty():return "已有捕笼待收；地图指向已部署的笼位。"
			if int(trap.get("baitedDay",-1))>=0:waits.append("第 %d 天起查看" % (int(trap.baitedDay)+2))
		return "捕笼所在岸边 · "+("、".join(waits) if not waits.is_empty() else "先部署捕笼并投一份制成的饵料。")
	return {"home":"爷爷的老屋；背包、地图与手记也可随时便携查看。","farm":"7×7 主田与相邻菜畦；查看田块当前状态再操作。","ranch":"东坡牧场；名册中的行动会走到实际动物、畜舍或料槽。","water":"合法水岸站位；垂钓与捕笼的出没规则以水产图鉴为准。","gathering":"青岚茶山 · 本周茶聚；到活动所在区域参加。"}.get(source,"查看来源图鉴与地图上的实际办理位置。")
