extends SceneTree
## Fixed-seed production route. Positions are arranged between commands to omit travel;
## inventory, crops, money, activity metrics and quest progress are never injected.
var s:Node
var Q:Script
var M:Script=preload("res://scripts/quest_model.gd")
var points:Array=[]
var trace:Array=[]
var failed:=false
func _initialize()->void:call_deferred("run")
func record(text:String)->void:
	trace.append({"day":s.day,"minute":s.minutes,"money":s.money,"stamina":s.stamina,"chapter":s.quests.journey.duplicate(),"text":text})
func rest()->void:
	s.current_interior=""
	for i:int in range(2,8):
		if str(s.plots[i].crop)!="" and s.stamina>12:s._farm_plot_action_single(i,"water")
	s.advance_day();s.minutes=600
	for i:int in range(8):
		if str(s.plots[i].crop)!="" and float(s.plots[i].growth)>=s.crop_days(str(s.plots[i].crop)):s._farm_plot_action_single(i,"hand")
	record("rest and collect mature crops")
func gather(item:String,qty:int)->bool:
	for day_loop:int in 16:
		for p:Dictionary in points:
			if int(s.inventory[item])>=qty:return true
			if str(p.item)!=item:continue
			if s.stamina<15 or s.minutes>1200:rest()
			s.current_interior="";s.player_position=Vector2(float(p.x),float(p.y))
			if bool(s.forage_status(str(p.id),item,str(p.get("event",""))).ready):s.gather_node(str(p.id),item,str(p.get("event","")))
		if int(s.inventory[item])>=qty:return true
		rest()
	return false
func claim()->bool:
	var d:Dictionary=M.chapter_definition(s)
	if int(d.get("stage",0))==3:s.current_interior=str(Q.KNOWLEDGE._house(s,"home").id)
	var ok:bool=Q.claim(s,str(d.id));record("chapter claim "+str(d.id)+" "+str(ok));return ok
func build(id:String)->bool:
	for item:String in s.content.projects[id].needs:
		if not gather(item,int(s.content.projects[id].needs[item])):return false
	s.current_interior="";var at:Dictionary=Q.PROJECT_SITES[id];s.player_position=Vector2(float(at.x),float(at.y))
	var ok:bool=s.complete_community_project(id);record("actual build "+id+" "+str(ok));return ok
func cooperate()->bool:
	s.current_interior="";s.player_position=Vector2(800,2600);s.npc_positions.granny=s.player_position
	while int(s.relations.granny.points)<10:s.talk_to_npc("granny");rest();s.npc_positions.granny=s.player_position
	if int(s.npc_stories.granny.step)==0:s.choose_npc_story("granny",0)
	if not s.start_npc_story_activity("granny"):return false
	for i:int in 80:
		if not s.action_busy():break
		s._process_action(.1)
	return int(s.quests.metrics.get("neighborWork",0))>0
func make_greens()->bool:
	s.current_interior=""
	if Q.qualified(s,"cabbage")<2:
		for index:int in [2,3]:
			if str(s.plots[index].crop)=="":s._farm_plot_action_single(index,"seed",{"crop":"cabbage"})
		for days:int in 6:
			if Q.qualified(s,"cabbage")>=2:break
			rest()
	return s.cook_recipe("greens")
func run()->void:
	seed(12345);s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);Q=load("res://scripts/quest_service.gd")
	s.start_new_game();s.quest_runtime.set_process(false);s.minutes=600
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_gather_points.json"))
	points=catalog["0"]
	for i:int in [0,1]:s._farm_plot_action_single(i,"hand")
	for id:String in ["granny","chen","xu"]:s.talk_to_npc(id)
	for i:int in range(2,8):
		s._farm_plot_action_single(i,"hoe");s._farm_plot_action_single(i,"seed",{"crop":"cabbage" if i<6 else "radish"})
	failed=not (claim() and claim() and build("bridge") and claim() and claim())
	if not failed:
		failed=not claim()
		if int(s.inventory.cabbage)<1:rest()
		var started:bool=s.process_recipe("compost")
		rest();rest()
		for job:Dictionary in s.kitchen.jobs.duplicate(true):s.collect_kitchen_job(int(job.key))
		failed=failed or not started or not cooperate() or not claim() or not build("canal") or not claim() or not claim()
	if not failed:
		failed=not claim()
		# A normal shared meal is an alternative to trading or preservation machinery.
		gather("wood",20);gather("bamboo",9)
		if s.money<220:
			s.sell_item("wood",mini(10,int(s.inventory.wood)))
		s.perform_legacy_upgrade("room")
		make_greens()
		s.current_interior=str(Q.KNOWLEDGE._house(s,"home").id);s.host_meal("granny","greens")
		gather("tea",2);s.process_recipe("dryTea");rest()
		for job:Dictionary in s.kitchen.jobs.duplicate(true):s.collect_kitchen_job(int(job.key))
		failed=failed or not claim() or not build("market") or not claim() or not claim()
	if not failed:
		failed=not claim()
		for loop:int in 16:
			if int(s.npc_stories.granny.step)>=4:break
			s.current_interior="";s.player_position=Vector2(800,2600);s.npc_positions.granny=s.player_position;s.talk_to_npc("granny")
			if int(s.npc_stories.granny.step)==2 and Q.qualified(s,"greens")<1:make_greens();s.current_interior="";s.npc_positions.granny=s.player_position
			if bool(s.npc_story_readiness("granny").ok):s.choose_npc_story("granny",0)
			else:rest()
		s.current_interior="";s.player_position=Vector2(750,699);s.attend_small_gathering("tea")
		failed=failed or not claim() or not build("stage") or not claim() or not claim()
	record("final: "+s.message)
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/production-route.json",FileAccess.WRITE);file.store_string(JSON.stringify({"ok":not failed,"seed":12345,"travel":"arranged test positions; not an elapsed travel benchmark","trace":trace},"\t"));file.close()
	print("QUEST_PRODUCTION_ROUTE: ","FAIL" if failed else "PASS"," chapter=",s.quests.journey.chapter," day=",s.day," message=",s.message)
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
