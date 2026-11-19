extends SceneTree
var passed:=0
var failed:=0
var s:Node
var Q:Script
var M:Script
var G:Script=preload("res://scripts/quest_guidance.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	Q=load("res://scripts/quest_service.gd");M=load("res://scripts/quest_model.gd")
	s.current_interior="";s.player_position=Vector2(1000,1000)
	for id:String in s.npc_residents:s.npc_residents[id].room=null
	for id:String in s.relations:s.relations[id].talked=0;s.relations[id].points=0
	s.relations.granny.talked=-1;s.relations.qiao.talked=-1
	s.npc_positions.granny=Vector2(2000,2000);s.npc_positions.qiao=Vector2(1100,1000)
	check(G.person(s,"talk")=="qiao","new-neighbor hint chooses proximity instead of catalog order")
	s.relations.qiao.talked=0
	check(G.person(s,"talk")=="granny","already greeted resident excluded")
	s.npc_stories.qiao={"step":4,"choices":[1,1,1,1],"lastDay":0};s.relations.qiao.points=40
	check(G.person(s,"storyFinal")=="qiao","story completion hint favors advanced ready chain")
	s.relations.qiao.points=35
	check(G.person(s,"storyFinal")=="qiao","advanced chain is not replaced by a new multi-step story when short of relationship points")
	s.npc_stories.granny={"step":1,"choices":[0],"lastDay":0};s.relations.granny.points=10
	check(G.person(s,"neighborWork")=="granny","cooperation hint finds an actual available activity")
	for i:int in s.plots.size():s.plots[i].crop="";s.plots[i].tilled=true;s.plots[i].fertilized=-1
	s.plots[0].crop="cabbage";s.plots[0].growth=s.crop_days("cabbage")
	s.plots[1].crop="cabbage";s.plots[1].growth=s.crop_days("cabbage")
	s.player_position=s.farm_plot_position(1)
	check(int(G.plot(s,"harvest").goal_plot)==1,"harvest hint selects nearest ripe bed")
	s.plots[1].growth=0
	check(int(G.plot(s,"harvest").goal_plot)==0,"ripe crop preferred over nearer immature crop")
	s.plots[0].growth=1;s.plots[1].growth=2
	check(int(G.plot(s,"harvest").goal_plot)==1 and not bool(G.plot(s,"harvest").goal_ready),"no-ripe hint points to actual growing crop without inventing readiness")
	s.plots[1].fertilized=s.day
	check(int(G.plot(s,"fertilize").goal_plot)!=1,"same-day already fertilized bed excluded")
	var target:Dictionary=Q.target(s,M.goal_definition(s,"harvest"))
	check(not target.is_empty() and int(target.goal_plot)==1 and not bool(target.auto_interact),"precise bed survives reachable-standpoint resolution and cannot auto harvest")
	s.quests=Q.defaults();s.quests.journey.stage=1;s.player_stats.harvested=0
	var journey:Dictionary=M.chapter_definition(s);target=Q.target(s,journey)
	check(str(target.questId)==str(journey.id),"map marker retains actual chapter identity")
	# Read-only mixed lots: one fresh premium, two fresh ordinary, three stale.
	s.inventory.milk=6;s.quality.milk=[3,0,0];s.economy.locked=[]
	s.kitchen.lots.bag.milk=[{"qty":2,"grade":0,"age":0.0},{"qty":1,"grade":0,"age":999.0},{"qty":1,"grade":1,"age":0.0},{"qty":2,"grade":1,"age":999.0}]
	var original:Array=[s.inventory.duplicate(true),s.quality.duplicate(true),s.kitchen.duplicate(true),s.quests.duplicate(true)]
	var row:Dictionary={"needs":{"milk":4},"grade":1,"reason":""};G.materials(s,row)
	check(int(row.progress[0].current)==1 and int(row.progress[0].owned)==6,"qualified amount differs correctly from owned amount")
	check(int(row.progress[0].stale)==3 and int(row.progress[0].low_quality)==2,"stale and low-quality portions reported independently")
	var kinds:Array=[]
	for block:Dictionary in row.blockers:kinds.append(block.kind)
	check(kinds.has("freshness") and kinds.has("quality") and not kinds.has("quantity"),"mixed causes shown without falsely claiming missing owned stock")
	for grade:int in 4:
		row.grade=grade;G.materials(s,row)
		check(int(row.progress[0].eligible)==Q.qualified(s,"milk",grade),"display and settlement agree on quality threshold %d"%grade)
	row.needs.milk=8;G.materials(s,row);kinds.clear()
	for block:Dictionary in row.blockers:kinds.append(block.kind)
	check(kinds.has("quantity") and kinds.has("freshness") and kinds.has("quality"),"quantity and lot eligibility causes coexist")
	s.economy.locked=["milk"];G.materials(s,row)
	check(row.blockers[0].kind=="protected" and int(row.progress[0].current)==0,"protection remains authoritative")
	s.economy.locked=[]
	check(original==[s.inventory,s.quality,s.kitchen,s.quests],"guidance never reconciles, consumes or changes live state")
	var progress:Dictionary={"kind":"journey","stage":1,"status":"active","current":1,"required":2,"progress":[{"label":"已经收获","current":1,"required":1},{"label":"制作家常菜","current":0,"required":1}]}
	var text:String=G.progress_text(progress)
	check(text.contains("1 / 2") and text.contains("制作家常菜") and not text.contains("已经收获"),"HUD shows overall choice count and next unfinished goal")
	progress={"kind":"story","status":"ready"}
	check(G.progress_text(progress).contains("故事"),"story readiness does not masquerade as material delivery")
	# Season changes must invalidate a cached season-seed guide without an inventory mutation.
	var chosen:String="";var next_season:int=0
	for crop:String in s.crop_catalog:
		var seasons:Array=[]
		for value:Variant in s.crop_catalog[crop].seasons:seasons.append(int(value))
		if not seasons.has(0):continue
		for season:int in [1,2,3]:
			if not seasons.has(season):chosen=crop;next_season=season;break
		if chosen!="":break
	check(chosen!="","real crop exists for seasonal-cache regression")
	if chosen!="":
		for item:String in s.inventory:s.inventory[item]=0
		s.inventory[str(s.crop_catalog[chosen].seed)]=1;s.day=0
		s.quests=Q.defaults();s.quests.entries["fixture:season"]={"status":"active","acceptedDay":0,"deadline":-1};s.quest_runtime.reset()
		var guide:Dictionary={"id":"fixture:season","kind":"guide","metric":"seasonSeed","target":1,"source":"farm","previous":"","chain":"farm"}
		check(int(s.quest_runtime.view(guide).current)==1,"cached seasonal seed initially valid")
		s.quest_runtime.dirty.clear();s.day=next_season*28;s.domain_changed.emit("world")
		check(int(s.quest_runtime.view(guide).current)==0,"same inventory correctly changes eligibility across seasons")
	var recommendations:Array=M.recommendations(s,[{"id":"a-far","kind":"wish","npc":"granny","status":"ready","pinned":false},{"id":"z-near","kind":"wish","npc":"qiao","status":"ready","pinned":false}])
	s.player_position=Vector2(1000,1000)
	recommendations=M.recommendations(s,[{"id":"a-far","kind":"wish","npc":"granny","status":"ready","pinned":false},{"id":"z-near","kind":"wish","npc":"qiao","status":"ready","pinned":false}])
	check(str(recommendations[0].id)=="z-near","equal priority tasks use distance rather than lexical ID")
	s.atlas.tracking=target.duplicate(true)
	var saved:Dictionary=s._make_save_data().duplicate(true)
	check(int(saved.version)==34 and s.load_game_data(saved),"precise goal metadata round trips in existing v34 save format")
	var cached_guide:Dictionary={"id":"fixture:cache","kind":"guide","metric":"sow","target":1,"source":"farm","previous":"","chain":"farm"}
	s.quest_runtime.view(cached_guide);s.quest_runtime.dirty.clear()
	var recomputed:int=int(s.quest_runtime.metrics.recomputed)
	s.quest_runtime.mark("settings");s.quest_runtime.view(cached_guide)
	check(int(s.quest_runtime.metrics.recomputed)==recomputed,"unrelated settings changes keep task view cached")
	s.quest_runtime.mark("metric:sow");s.quest_runtime.view(cached_guide)
	check(int(s.quest_runtime.metrics.recomputed)==recomputed+1,"relevant behavior metric invalidates only its dependent view")
	var navigation:Script=load("res://scripts/npc_navigation.gd")
	var before_routes:int=int(navigation.metrics.route_calls);var before_grids:int=int(navigation.metrics.grid_builds)
	var started:int=Time.get_ticks_usec()
	for iteration:int in 120:G.person(s,"storyFinal")
	var guidance_ms:float=(Time.get_ticks_usec()-started)/1000.0
	check(int(navigation.metrics.route_calls)==before_routes and int(navigation.metrics.grid_builds)==before_grids,"ranking hints does not build navigation grids or run path searches")
	print("QUEST_GUIDANCE: %d passed, %d failed; 120 rank evaluations_ms=%.3f"%[passed,failed,guidance_ms])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
