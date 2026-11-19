extends RefCounted
## Read-only guidance. Resolving a hint never starts an action or changes progress.
static func service()->Script:return load("res://scripts/quest_service.gd")
static func actor_distance(s:Node,id:String)->float:
	var resident:Dictionary=s.npc_residents.get(id,{})
	var room:String="" if resident.get("room")==null else str(resident.room)
	if room==s.current_interior:
		var positions:Dictionary=s.npc_positions if room=="" else s.interior_npc_positions
		var origin:Vector2=s.player_position if room=="" else s.interior_position
		if positions.get(id) is Vector2:return origin.distance_to(positions[id])
	var destination:Dictionary=s.npc_destination(id)
	if not destination.has("x") or not destination.has("y"):return INF
	return s.player_position.distance_to(Vector2(float(destination.x),float(destination.y)))+200.0
static func person(s:Node,metric:String)->String:
	var candidates:Array=[]
	for npc:Dictionary in s.npc_catalog:
		var id:String=str(npc.id);var step:int=int(s.npc_stories.get(id,{}).get("step",0))
		var arc:Array=s.content.arcs.get(id,[]);var rank:int=0;var remaining:int=arc.size()-step
		if metric=="talk":
			if int(s.relations[id].get("talked",-1))>=0:continue
		elif metric=="storyFinal":
			if remaining<=0:continue
			rank=2 if step==0 else 0 if bool(s.npc_story_readiness(id).get("ok",false)) else 1
		else:
			var activity:Dictionary=load("res://scripts/quest_model.gd").story_activity(s,id)
			var event:Dictionary=s.neighbors.get("people",{}).get(id,{}).get("event",{})
			if not activity.is_empty() and not bool(activity.done):
				rank=0 if int(s.relations[id].get("points",0))>=int(arc[step].get("points",0)) else 2
			elif str(event.get("status","")) in ["accepted","offered","postponed"]:rank=1
			elif remaining>0:rank=3
			else:continue
		candidates.append({"id":id,"rank":rank,"remaining":remaining if metric=="storyFinal" else 0,"distance":actor_distance(s,id)})
	candidates.sort_custom(func(a:Dictionary,z:Dictionary)->bool:
		if a.rank!=z.rank:return int(a.rank)<int(z.rank)
		if a.remaining!=z.remaining:return int(a.remaining)<int(z.remaining)
		if a.distance!=z.distance:return float(a.distance)<float(z.distance)
		return str(a.id)<str(z.id))
	return str(candidates[0].id) if not candidates.is_empty() else ""
static func plot(s:Node,metric:String)->Dictionary:
	var best:Dictionary={};var best_rank:=INF;var best_distance:=INF
	for index:int in s.plots.size():
		var row:Dictionary=s.plots[index]
		if bool(row.get("removed",false)):continue
		var rank:float=0.0
		if metric=="harvest":
			if str(row.get("crop",""))=="":continue
			rank=maxf(0.0,float(s.crop_days(str(row.crop)))-float(row.get("growth",0)))
		else:
			if not bool(row.get("tilled",false)) or int(row.get("fertilized",-1))==s.day:continue
		var at:Vector2=s.farm_plot_position(index);var distance:float=s.player_position.distance_to(at)
		if rank<best_rank or is_equal_approx(rank,best_rank) and distance<best_distance:
			best_rank=rank;best_distance=distance
			best={"x":at.x,"y":at.y,"name":"第 %d 块田"%(index+1),"goal_plot":index,"goal_ready":rank==0.0}
	return best
static func materials(s:Node,r:Dictionary)->void:
	r.progress=[];r.blockers=[]
	for item:String in r.get("needs",{}):
		var required:int=int(r.needs[item]);var grade:int=clampi(int(r.get("grade",0)),0,3)
		var owned:int=int(s.inventory.get(item,0));var counts:Array=s._quality_counts(item)
		var fresh:Array=[0,0,0,0]
		if s._is_food(item):
			for segment:Dictionary in service().food_segments(s,item):
				if float(segment.get("age",0))<float(s._food_shelf_days(item)):fresh[int(segment.grade)]+=int(segment.qty)
		else:fresh=counts.duplicate()
		var eligible:int=0;var fresh_total:int=0;var low:int=0
		for level:int in 4:
			fresh_total+=int(fresh[level])
			if level>=grade:eligible+=int(fresh[level])
			else:low+=int(fresh[level])
		var locked:bool=s.economy.get("locked",[]).has(item)
		if locked:eligible=0
		var stale:int=maxi(0,owned-fresh_total);var label:String=str(s.item_catalog.get(item,{}).get("name",item))
		r.progress.append({"item":item,"label":label,"current":mini(eligible,required),"required":required,"owned":owned,"eligible":eligible,"stale":stale,"low_quality":low})
		if eligible>=required:continue
		if locked:r.blockers.append({"kind":"protected","item":item,"text":label+"：已保护，解除后才可交付。"})
		if owned<required:r.blockers.append({"kind":"quantity","item":item,"text":"%s：背包还缺 %d 份，需交付合格物品 %d 份。"%[label,required-owned,required]})
		if stale>0:r.blockers.append({"kind":"freshness","item":item,"text":"%s：%d 份已变质，不计入交付。"%[label,stale]})
		if low>0:r.blockers.append({"kind":"quality","item":item,"text":"%s：%d 份新鲜物品低于要求品质，不计入交付。"%[label,low]})
		if not locked and owned>=required and stale==0 and low==0:r.blockers.append({"kind":"quantity","item":item,"text":"%s：还需 %d 份合格物品。"%[label,required-eligible]})
	if not r.blockers.is_empty():r.reason=str(r.blockers[0].text)
static func progress_text(row:Dictionary)->String:
	if str(row.kind)=="journey" and int(row.get("stage",0))==1:
		var prefix:String="生活目标 %d / %d（任选两项）"%[mini(int(row.current),int(row.required)),int(row.required)]
		for progress:Dictionary in row.get("progress",[]):
			if int(progress.current)<int(progress.required):return prefix+"\n下一步："+str(progress.label)
		return prefix
	if str(row.status)=="ready":return "可以继续这段故事" if str(row.kind)=="story" else "材料已齐 · 到现场交付"
	if str(row.status)=="reward":
		if str(row.kind)=="journey":return "翻开这一章" if int(row.get("stage",0))==0 else "回老屋记下这一章" if int(row.get("stage",0))==3 else "章节目标已达成"
		return "目标已达成 · 等待自动记入"
	for progress:Dictionary in row.get("progress",[]):
		if int(progress.current)<int(progress.required):return "%s %d / %d"%[str(progress.label),int(progress.current),int(progress.required)]
	return "进度 %d / %d"%[mini(int(row.current),int(row.required)),int(row.required)]
