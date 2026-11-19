extends RefCounted
const GUIDANCE=preload("res://scripts/quest_guidance.gd")
const CHAPTERS=[{"title": "安顿小院", "project": "bridge", "goals": [["harvest", 1, "首次亲自收获"], ["rodCatch", 1, "钓获一条鱼"], ["cook", 1, "做一道家常菜"], ["animalCare", 1, "照料一次动物"], ["talk", 3, "认识三位居民"]]}, {"title": "学会分工", "project": "canal", "goals": [["fertilizePlots", 3, "养护三块田"], ["rodSpecies", 2, "钓获两种常见水产"], ["animalProduce", 1, "收集一次畜产"], ["process", 1, "完成一次加工"], ["neighborWork", 1, "参与一次邻里协作"]]}, {"title": "分享收成", "project": "market", "goals": [["weeklyComplete", 1, "完成一张供货单"], ["preserve", 1, "保存一份食材"], ["sharedMeal", 1, "参加公共聚餐"], ["houseCooperation", 1, "完成住宅协作"], ["sourceObservation", 1, "完成来源观察记录"]]}, {"title": "留下故事", "project": "stage", "goals": [["storyFinal", 1, "完成居民故事"], ["gathering", 1, "参加村庄分享活动"], ["donate", 2, "捐赠两种常见物产"], ["rodSpecies", 3, "记录三种常见鱼"], ["nurseryRecord", 1, "完成育幼成长记录"]]}]
static func service()->Script:return load("res://scripts/quest_service.gd")
static func goal_definition(s:Node,metric:String)->Dictionary:
	var source:String=str({"harvest":"farm","fertilize":"farm","fertilizePlots":"farm","rodCatch":"water","rodSpecies":"water","animalCare":"ranch","animalProduce":"ranch","nurseryRecord":"ranch","houseCooperation":"home","sourceObservation":"farm","cook":"kitchen","process":"kitchen","preserve":"kitchen","weeklyComplete":"coop","donate":"museum","sharedMeal":"home","gathering":"gathering"}.get(metric,"home"))
	var result:Dictionary={"id":"goal:"+metric,"kind":"goal","source":source}
	if metric in ["talk","storyFinal","neighborWork"]:
		var id:String=GUIDANCE.person(s,metric)
		if id!="":result.source="npc:"+id
	elif metric in ["harvest","fertilize"]:
		var plot:Dictionary=GUIDANCE.plot(s,metric)
		if not plot.is_empty():result.target_override=plot
	return result

static func chapter_definition(s:Node)->Dictionary:
	var chapter:int=int(s.quests.journey.chapter);var stage:int=int(s.quests.journey.stage)
	if chapter>=4:return {"id":"journey:complete","kind":"journey","category":"主线","title":"村庄仍有新的日子","text":"四章故事已记下。继续照顾小院，与邻里来往。","chapter":4,"stage":0,"source":"home"}
	var row:Dictionary=CHAPTERS[chapter]
	return {"id":"journey:%d:%d"%[chapter,stage],"kind":"journey","category":"主线","title":"第%d章 · %s · %s"%[chapter+1,row.title,["新的一页","今天想做什么","一起动工","回家记下"][stage]],"text":["从眼前的生活开始，不必等到指定季节。核心生活功能随时可用。","任选下面两项，各有一种与村庄相处的方式；已经做过的普通行为也算。","带上自己这一份材料，到实际施工点和乡亲们共同完成。","回到老屋，记下这次合作和你想继续的生活。"][stage],"chapter":chapter,"stage":stage,"ref":str(row.project),"goals":row.goals,"source":"project:"+str(row.project) if stage==2 else "home","page":"plans"}
static func chapter_snapshot(s:Node,r:Dictionary)->Dictionary:
	r.accepted=true;r.status="active";r.current=0;r.required=1;r.progress=[]
	if int(r.chapter)>=4:r.status="completed";r.current=1;return r
	if int(r.chapter)!=int(s.quests.journey.chapter) or int(r.stage)!=int(s.quests.journey.stage):
		r.status="completed" if s.quests.receipts.has(str(r.id)) else "locked";return r
	match int(r.stage):
		0:r.status="reward";r.current=1
		1:
			r.required=2
			for goal:Array in r.goals:
				var current:int=service().metric(s,str(goal[0]));var done:bool=current>=int(goal[1])
				r.current+=int(done);r.progress.append({"label":str(goal[2]),"current":mini(current,int(goal[1])),"required":int(goal[1]),"metric":str(goal[0])})
			if int(r.current)>=2:r.status="reward"
		2:
			if bool(load("res://scripts/village_growth.gd").project(s,str(r.ref)).firstUse):r.status="reward";r.current=1
			else:
				r.reason=str(s.community_project_status(str(r.ref)).reason)
				r.needs=s.content.projects[str(r.ref)].needs.duplicate(true);material_progress(s,r)
		3:
			r.status="reward";r.current=1
			r.reason="回到老屋当面翻开这一页。"
	return r
static func advance_chapter(s:Node,d:Dictionary)->bool:
	if s.quests.receipts.has(str(d.id)) or str(service().snapshot(s,d).status)!="reward":return false
	if int(d.get("chapter",4))>=4:return false
	var home:Dictionary=service().KNOWLEDGE._house(s,"home")
	if int(d.stage)==3 and not (not home.is_empty() and s.current_interior==str(home.id) or s.current_interior=="" and service().near(s,d)):
		s.message="回到老屋后，记下这一章。";return false
	if int(d.stage)==3:
		if s.minutes+5>1320:s.message="明早回家再记下这一章。";return false
		s.minutes+=5
	s.quests.receipts[str(d.id)]=true
	s.quests.entries[str(d.id)]={"status":"completed","acceptedDay":s.day,"deadline":-1,"completedDay":s.day,"definition":d.duplicate(true)}
	if int(d.stage)==3:s.quests.journey.chapter+=1;s.quests.journey.stage=0
	else:s.quests.journey.stage+=1
	s.quests.pins.erase(str(d.id));s.changed.emit();return true
static func project_gate(s:Node,id:String)->String:
	var index:int=["bridge","canal","market","stage"].find(id)
	if index<0:return "没有这项公共建设。"
	if int(s.quests.journey.chapter)!=index or int(s.quests.journey.stage)<2:return "先在任务手记推进对应章节的生活目标；无需等待季节。"
	return ""
static func guide_revealed(s:Node,d:Dictionary)->bool:
	if s.quests.entries.has(str(d.id)):return true
	var trigger:String=str(d.get("revealMetric",""))
	return trigger=="" or service().metric(s,trigger)>0
static func material_progress(s:Node,r:Dictionary)->void:
	GUIDANCE.materials(s,r)

static func commission_payout(s:Node,d:Dictionary)->int:
	var base:float=0.0
	for item:String in d.get("needs",{}):base+=float(s.item_catalog.get(item,{}).get("price",0))*int(d.needs[item])
	var complexity:String=str(d.get("complexity","simple"))
	return floori(base*1.15)+int({"simple":25,"processed":30,"cross":40}.get(complexity,25))
static func story_compensation(s:Node,event:Dictionary)->int:
	var total:int=0
	for item:String in event.get("needs",{}):total+=int(s.item_catalog.get(item,{}).get("price",0))*int(event.needs[item])
	return total
static func story_activity(s:Node,id:String)->Dictionary:
	var arc:Array=s.content.arcs.get(id,[]);var step:int=int(s.npc_stories.get(id,{}).get("step",0))
	if step>=arc.size():return {}
	var activity:Dictionary=arc[step].get("activity",{}).duplicate(true)
	if not activity.is_empty():activity.done=int(s.quests.metrics.get("storyActivity:"+id+":"+str(step),0))>0
	return activity
static func dependencies(d:Dictionary)->Array[String]:
	var result:Array[String]=["progress"]
	match str(d.kind):
		"guide":
			var key:String=str(d.get("metric",""));result.append("metric:"+key)
			if key.begins_with("inventory:") or key=="seasonSeed":
				result.append("inventory")
				if key=="seasonSeed":result.append("world")
			elif key in ["sow","water","harvest","fertilize"]:result.append("farm")
			elif key in ["cook","process","share","freshCheck"]:result.append("economy")
			elif key in ["talk","gift","story"]:result.append("relations")
			elif key in ["rest","yearReview"]:result.append("world")
			elif str(d.get("chain",""))=="fish":result.append("fishing")
			elif str(d.get("chain",""))=="ranch":result.append("ranch")
			result.append("metric:"+str(d.get("revealMetric","")))
		"journey":
			result.append_array(["farm","relations","economy","inventory","world","ranch","fishing","household","village"])
			for goal:Array in d.get("goals",[]):result.append("metric:"+str(goal[0]))
		"story":
			result.append_array(["relations","inventory","economy"])
			result.append("metric:storyActivity:"+str(d.npc)+":"+str(d.step))
		_:result.append_array(["inventory","economy","world"])
	if str(d.kind)=="weekly":result.append("clock")
	return result
static func recommendations(s:Node,rows:Array)->Array:
	var result:Array=[]
	for row:Dictionary in rows:
		if str(row.status) not in ["active","ready","reward"]:continue
		if str(row.kind)=="weekly" and not service().counter_open(s):continue
		if not row.get("blockers",[]).is_empty() or str(row.status)=="active" and str(row.get("reason",""))!="":continue
		var candidate:Dictionary=row.duplicate(true)
		candidate.distance=GUIDANCE.actor_distance(s,str(row.npc)) if row.has("npc") else INF
		candidate.score=1000 if str(row.status) in ["ready","reward"] else 100 if row.pinned else 0
		if row.has("npc") and s.npc_is_near(str(row.npc)):candidate.score+=50
		if str(row.kind)=="journey":candidate.score+=10
		result.append(candidate)
	result.sort_custom(func(a:Dictionary,z:Dictionary)->bool:
		if a.score!=z.score:return int(a.score)>int(z.score)
		if a.distance!=z.distance:return float(a.distance)<float(z.distance)
		return str(a.id)<str(z.id))
	return result.slice(0,3)
