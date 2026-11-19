extends SceneTree
## Accelerated native path simulation. No inventory, rewards, task metrics, NPC positions
## or phase values are injected. Scene portals use the normal near-door state entry.
class Walker extends Node2D:
	var state:Node
	var navigation:RefCounted
	var target:Dictionary={}
	var runtime:Dictionary={}
	var distance:float=0
	func pause_player_frame()->void:pass
	func advance_player_frame(delta:float)->void:
		if target.is_empty():return
		var p:Dictionary=state.player_navigation_position();var before:=Vector2(float(p.x),float(p.y))
		navigation.refresh(state);load("res://scripts/player_motion.gd").step(navigation,state,state.current_interior,p,runtime.get("path",[]),0.0,0.0,state.player_movement_rate(false),delta)
		state.set_player_navigation_position(p);position=Vector2(float(p.x),float(p.y));distance+=before.distance_to(position)
class DriverRoot extends Node2D:
	var hud:Variant=null
var s:Node
var actor:Walker
var Q:Script
var G:Script
var frames:int=0
var trace:Array=[]
var issue:String=""
var nodes:Array=[]
var route_kind:String="plant"
var money_spent:int=0
var money_received:int=0
var energy_spent:float=0
var last_energy:float=100
var last_money:int=180
var rooms_entered:int=0
var rooms_left:int=0
var action_costs:Array=[]
func tally()->void:
	energy_spent+=maxf(0,last_energy-float(s.stamina))
	var cash:int=int(s.money)-last_money
	money_spent+=maxi(0,-cash);money_received+=maxi(0,cash)
	last_energy=float(s.stamina);last_money=int(s.money)

func _initialize()->void:call_deferred("run")
func note(label:String)->void:
	print("ROUTE ",route_kind," ",label," day ",s.day," money ",s.money)
	trace.append({"event":label,"day":s.day,"minutes":s.minutes,"energy":s.stamina,"money":s.money,"distance":actor.distance,"chapter":s.quests.journey.duplicate(),"room":s.current_interior})
func tick()->void:
	if s.transactions.busy():await s.wait_for_saves()
	s.advance_simulation_frame(.05,actor);tally();frames+=1
	if frames%12==0:await process_frame
func walk_local(target:Dictionary,tolerance:float=5)->bool:
	actor.navigation.refresh(s)
	var plan:Dictionary=s.interaction_route(target,s.player_navigation_position(),s.current_interior,target.has("kind"))
	if not bool(plan.reachable):issue="no route to actual interaction stand "+str(target);return false
	var safe:Dictionary=plan.stand
	if Vector2(float(safe.x),float(safe.y)).distance_to(Vector2(float(target.x),float(target.y)))>56:issue="no nearby stand "+str(target);return false
	actor.target=safe;actor.runtime={"path":plan.path}
	for i:int in 12000:
		var p:Dictionary=s.player_navigation_position()
		if Vector2(float(p.x),float(p.y)).distance_to(Vector2(float(safe.x),float(safe.y)))<=tolerance:actor.target={};return true
		await tick()
	actor.target={};issue="walking route unavailable "+str(target)+" FROM "+str(s.player_navigation_position())+" PATH "+str(actor.runtime.get("path",[]).slice(0,4));return false
func outside()->bool:
	if s.current_interior=="":return true
	if not await walk_local({"x":480,"y":590}):return false
	if not s.leave_room_state():return false
	rooms_left+=1
	await tick();return true
func go(target:Dictionary,room:String="")->bool:
	if s.current_interior!=room:
		if not await outside():return false
		if room!="":
			var house:Dictionary=s.house_data(room)
			if house.is_empty() or not await walk_local(house.door):return false
			if not s.enter_room_state(room):issue="door rejected "+room;return false
			rooms_entered+=1
			await tick()
	return await walk_local(target)
func perform(label:String,operation:Callable)->bool:
	var inventory_before:Dictionary=s.inventory.duplicate(true)
	var done:Array=[false]
	var spec:Dictionary=s.ACTION_RULES.spec("read",label);spec.duration=.8
	var point:Dictionary=s.player_navigation_position();point.kind="route-command"
	if not s.begin_action(spec,point,func()->bool:
		var value:Variant=operation.call();done[0]=value if value is bool else true;return bool(done[0])):issue="start rejected "+label;return false
	for i:int in 2000:
		await tick()
		if not s.action_busy():break
	if not done[0]:issue=label+": "+s.message;return false
	if s.transactions.busy():await s.wait_for_saves()
	var consumed:Dictionary={};var received:Dictionary={}
	for item:String in inventory_before.keys()+s.inventory.keys():
		var change:int=int(s.inventory.get(item,0))-int(inventory_before.get(item,0))
		if change<0:consumed[item]=-change
		elif change>0:received[item]=change
	action_costs.append({"operation":label,"day":s.day,"consumed":consumed,"received":received})
	tally();return true
func sleep_night()->bool:
	if s.day>=60:issue="route exceeded 60 normal days";return false
	var home:Dictionary=Q.KNOWLEDGE._house(s,"home")
	if not await go({"x":238,"y":315},str(home.id)):return false
	if not await perform("在自己的床边睡到明天",s.advance_day):return false
	note("sleep at real home bed")
	return await outside()
func farm(index:int,tool:String,arg:Dictionary={})->bool:
	if s.stamina<8 or s.minutes>1220:
		if not await sleep_night():return false
	var point:Vector2=s.farm_plot_position(index)
	if not await go({"x":point.x,"y":point.y}):return false
	return await perform("farm:"+tool,s._farm_plot_action_single.bind(index,tool,arg))
func find_person(id:String)->bool:
	for attempt:int in 16:
		var resident:Dictionary=s.npc_residents[id];var room:String="" if resident.get("room")==null else str(resident.room)
		if s.current_interior!=room:
			if room=="":
				if not await outside():return false
			else:
				if not await go({"x":480,"y":540},room):return false
		await tick();s.npc_movement.publish(s)
		var position:Variant=(s.npc_positions if room=="" else s.interior_npc_positions).get(id)
		if not position is Vector2:continue
		if not await walk_local({"x":position.x,"y":position.y}):return false
		if s.npc_is_near(id):return true
	issue="could not meet moving resident "+id;return false
func talk(id:String)->bool:
	if not await find_person(id):return false
	return await perform("talk:"+id,func()->bool:return s.talk_to_npc(id) if s.npc_is_near(id) else false)
func gather(item:String,quantity:int)->bool:
	for day_loop:int in 20:
		if Q.qualified(s,item)>=quantity:return true
		var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_gather_points.json"));nodes=catalog[str(s.season_index())].duplicate(true)
		nodes.sort_custom(func(a:Dictionary,b:Dictionary):return s.player_position.distance_squared_to(Vector2(a.x,a.y))<s.player_position.distance_squared_to(Vector2(b.x,b.y)))
		for point:Dictionary in nodes:
			if str(point.item)!=item:continue
			s.register_forage_point(point)
			if not bool(s.forage_status(str(point.id),item,str(point.get("event",""))).ready):continue
			if s.stamina<12 or s.minutes>1210:
				if not await sleep_night():return false
			if not await go(point):return false
			if not await perform("gather:"+item,s.gather_node.bind(str(point.id),item,str(point.get("event","")))):return false
			if Q.qualified(s,item)>=quantity:return true
		if not await sleep_night():return false
	issue="normal source not obtainable "+item;return false
func home_note()->bool:
	var home:Dictionary=Q.KNOWLEDGE._house(s,"home")
	if not await go({"x":480,"y":540},str(home.id)):return false
	var d:Dictionary=load("res://scripts/quest_model.gd").chapter_definition(s)
	if not s.quest_claim(str(d.id)):issue="home chapter note "+s.message;return false
	await s.wait_for_saves();note("home chapter close");return true
func wait_stage(stage:int)->bool:
	for i:int in 150:
		if int(s.quests.journey.stage)==stage:return true
		await tick();await process_frame
	issue="stage not ready: "+str(s.quests.journey)+" / "+s.message;return false
func build(id:String)->bool:
	for item:String in s.content.projects[id].needs:
		if not await gather(item,int(s.content.projects[id].needs[item])):return false
	var site:Vector2=G.SITES[id]
	if not await go({"x":site.x,"y":site.y}):return false
	if not await perform("survey "+id,s.growth_action.bind(id,"survey")):return false
	if not await perform("deliver material "+id,s.growth_action.bind(id,"contribute")):return false
	for i:int in 12000:
		if bool(G.quote(s,id,"collaborate").ready):break
		await tick()
		if i==11999:issue="collaborator did not arrive "+id+" / "+s.message;return false
	if not await perform("real collaboration "+id,s.growth_action.bind(id,"collaborate")):return false
	if not await perform("first use "+id,s.growth_action.bind(id,"use")):return false
	note("project complete "+id);return await wait_stage(3)
func kitchen(id:String,processing:bool=false)->bool:
	var house:Dictionary=Q.KNOWLEDGE._house(s,"kitchen")
	if not await go({"x":480,"y":500},str(house.id)):return false
	if not await perform("process:"+id if processing else "cook:"+id,s.process_recipe.bind(id) if processing else s.cook_recipe.bind(id)):return false
	for job:Dictionary in s.kitchen.jobs.duplicate(true):
		for i:int in 120000:
			if float(job.ready)<=s._kitchen_now():break
			if float(job.ready)-s._kitchen_now()>180 or s.minutes>1230:
				if not await sleep_night():return false
				if not await go({"x":480,"y":500},str(house.id)):return false
			else:await tick()
		if not await perform("collect actual batch "+id,s.collect_kitchen_job.bind(int(job.key))):return false
	return true
func prepare_cabbage()->bool:
	for i:int in range(2,8):
		if str(s.plots[i].crop)=="":
			if not bool(s.plots[i].tilled) and not await farm(i,"hoe"):return false
			if not await farm(i,"seed",{"crop":"cabbage"}):return false
	for days:int in 8:
		for i:int in range(2,8):
			if str(s.plots[i].crop)!="" and float(s.plots[i].growth)>=s.crop_days(str(s.plots[i].crop)):
				if not await farm(i,"hand"):return false
		if Q.qualified(s,"cabbage")>=6:return true
		for i:int in range(2,8):
			if str(s.plots[i].crop)!="" and int(s.plots[i].moisture)<65:
				if not await farm(i,"water"):return false
		if not await sleep_night():return false
	issue="cabbage did not mature with normal care";return false
func catch_kinds(required:int)->bool:
	for attempt:int in 40:
		if Q.metric(s,"rodSpecies")>=required:return true
		if s.stamina<10 or s.minutes>1200:
			if not await sleep_night():return false
		var spots:Array=s.system_catalog.fishing.spots
		var spot:Dictionary=spots[attempt%spots.size()]
		if not await go(spot):return false
		if not s.begin_fishing(str(spot.id)):issue="cast: "+s.message;return false
		s.fishing_input("press","route");await tick();s.fishing_input("release","route")
		for frame:int in 1800:
			if not s.fishing_active():break
			var g:Dictionary=s.fishing_snapshot()
			if str(g.stage)=="bite":s.fishing_input("release","route");s.fishing_input("press","route")
			if str(g.stage)=="fight":
				var surge:bool=str(g.fishPhase) in ["charge","surge"]
				if bool(g.holding) and (float(g.tension)>=68 or surge and float(g.tension)>=50):s.fishing_input("release","route")
				elif not bool(g.holding) and (float(g.tension)<=24 or float(g.tension)<=35 and not surge):s.fishing_input("press","route")
			await tick()
		if s.transactions.busy():await s.wait_for_saves()
		if not s.fishing.pending.is_empty():
			if not s.fishing_resolve(false):issue="keep catch: "+s.message;return false
			await s.wait_for_saves();note("actual fish catch")
		if s.fishing_active():s.cancel_player_action()
	issue="forty legal casts did not provide required common species";return false
func tend_existing(action:String,index:int=0)->bool:
	var id:String=str(s.animals[index].id)
	if action=="collect":
		for product:Dictionary in s.ranch.products.duplicate(true):
			if str(product.animalId)!=id:continue
			var room:String="" if product.get("room")==null else str(product.room)
			if not await go({"x":product.x,"y":product.y},room):return false
			return await perform("collect actual nest product",s.ranch_fixture_action.bind("ranch-product",str(product.id)))
		issue="no real product available";return false
	for attempt:int in 10:
		var animal:Dictionary=s.animals[s.ranch_animal_index(id)]
		var room:String="" if animal.position.get("room")==null else str(animal.position.room)
		var point:Dictionary=animal.position if room=="" else animal.position.inside
		if not await go(point,room):return false
		if s.transactions.busy():await s.wait_for_saves()
		if s.ranch_tend(s.ranch_animal_index(id),action):await s.wait_for_saves();note("actual animal "+action);return true
		await tick()
	issue="animal care: "+s.message;return false
func neighbor_activity()->bool:
	if not await find_person("granny"):return false
	if not s.start_npc_story_activity("granny"):return await perform("neighbor sharing",s.village_activity.bind("share","granny"))
	for i:int in 100:
		await tick()
		if not s.action_busy():return true
	issue="neighbor activity did not finish";return false
func main_route()->bool:
	if not s.quest_claim(str(load("res://scripts/quest_model.gd").chapter_definition(s).id)):return false
	await s.wait_for_saves()
	if not await farm(0,"hand") or not await farm(1,"hand"):return false
	if route_kind=="fish":
		if not await catch_kinds(3):return false
	elif route_kind=="animal":
		if not await tend_existing("pet"):return false
	elif route_kind=="neighbor":
		for id:String in ["granny","qiao","lin"]:
			if not await talk(id):return false
	else:
		if not await kitchen("greens"):return false
	if not await wait_stage(2) or not await build("bridge") or not await home_note():return false
	if not s.quest_claim(str(load("res://scripts/quest_model.gd").chapter_definition(s).id)):return false
	await s.wait_for_saves()
	if not await prepare_cabbage():return false
	for i:int in [2,3,4]:
		if int(s.plots[i].moisture)<95 and not await farm(i,"water"):return false
	if not await kitchen("compost",true):return false
	if route_kind=="animal":
		if not await tend_existing("collect"):return false
	elif route_kind=="neighbor":
		if not await neighbor_activity():return false
	if not await wait_stage(2) or not await build("canal") or not await home_note():return false
	if not s.quest_claim(str(load("res://scripts/quest_model.gd").chapter_definition(s).id)):return false
	await s.wait_for_saves()
	if not await kitchen("greens"):return false
	if not await find_person("granny"):return false
	if not await perform("share actual dish",s.village_activity.bind("meal","granny")):return false
	var spot:Dictionary=s.system_catalog.fishing.spots[0]
	if not await go(spot) or not await perform("observe real river",s.village_activity.bind("observe")):return false
	if not await wait_stage(2) or not await build("market") or not await home_note():return false
	if not s.quest_claim(str(load("res://scripts/quest_model.gd").chapter_definition(s).id)):return false
	await s.wait_for_saves()
	if not await find_person("chen") or not await perform("village sharing",s.village_activity.bind("share","chen")):return false
	var museum:Dictionary=Q.KNOWLEDGE._house(s,"村史馆")
	if not await go({"x":480,"y":510},str(museum.id)):return false
	for item:String in ["rice","egg"]:
		if not await perform("donate real produce "+item,s.museum_donate.bind("item:"+item,"sample",0)):return false
	if not await wait_stage(2) or not await build("stage") or not await home_note():return false
	return int(s.quests.journey.chapter)==4
func run()->void:
	await process_frame;route_kind=OS.get_environment("ZRZ_ROUTE");if route_kind=="":route_kind="plant"
	seed(12345);s=root.get_node("GameState");s.set_process(false);Q=load("res://scripts/quest_service.gd");G=load("res://scripts/village_growth.gd")
	var parent:=DriverRoot.new();root.add_child(parent);actor=Walker.new();actor.state=s;actor.navigation=load("res://scripts/npc_navigation.gd").new();parent.add_child(actor)
	last_energy=float(s.stamina);last_money=int(s.money)
	var ok:bool=await main_route();tally();note("end: "+issue)
	var output:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/normal-"+route_kind+"-route.json",FileAccess.WRITE);output.store_string(JSON.stringify({"ok":ok,"seed":12345,"kind":"accelerated native paths, normal commands and real material deductions; no progress/material injection","issue":issue,"frames":frames,"money_spent":money_spent,"money_received":money_received,"energy_spent":energy_spent,"rooms_entered":rooms_entered,"rooms_left":rooms_left,"walking_distance":actor.distance,"action_costs":action_costs,"trace":trace},"\t"))
	print("NORMAL_ROUTE ",ok," ",issue," chapter ",s.quests.journey," day ",s.day)
	await root.get_node("AudioService").prepare_exit();quit(0 if ok else 1)
