extends SceneTree
var passed: int=0
var failed: int=0
var s: Node
var SERVICE: Script
var RULES: Script
var KNOWLEDGE: Script
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func seed_for(id: String,water: String,method: String,day: int,minute: float) -> int:
	var context: Dictionary=s.fishing.duplicate(true)
	for seed: int in range(1,20000):
		context.rng=seed
		var p: Dictionary=RULES.predict(water,s.system_catalog.fishing,context,day,int(day/28)%4,s.weather_for(day),minute,method)
		if not p.is_empty() and str(p.fish)==id:return seed
	return -1
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("Content integration timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.ui_open=false;s.current_interior=""
	SERVICE=load("res://scripts/fishing_service.gd");RULES=load("res://scripts/fishing_rules.gd");KNOWLEDGE=load("res://scripts/knowledge_catalog.gd")
	s.fishing=s.initial_state.fishing.duplicate(true);s.inventory.herbBait=100;s.inventory.fishTrap=100;s.toolkit.tools.rod.level=2;s.toolkit.tools.rod.branch="care"
	for id: String in s.system_catalog.fishing.species:
		var fish: Dictionary=s.system_catalog.fishing.species[id]
		var day: int=-1;var water:=str(fish.waters[0]);var method: String="rod" if fish.methods.has("rod") else "trap"
		var minute: float=maxf(390,float(fish.times[0][0])+10) if method=="rod" else 480
		for d: int in range(s.day,s.day+113):
			if RULES.available(fish,water,int(d/28)%4,s.weather_for(d),minute,method):day=d;break
		check(day>=0,"authored window "+id)
		if day<0:continue
		s.day=day;s.minutes=minute;s.stamina=100;s.fishing.bait="plain" if method=="rod" else "herb"
		if method=="rod":
			var point: Dictionary={}
			for at: Dictionary in s.system_catalog.fishing.spots:
				if str(at.water)==water:point=at;break
			s.player_position=Vector2(float(point.x),float(point.y));s.fishing.rng=seed_for(id,water,"rod",day,minute)
			check(int(s.fishing.rng)>0 and s.begin_fishing(str(point.id)),"actual rod lifecycle "+id)
			if not s.fishing_active():continue
			for frame: int in range(1200):
				if not s.fishing_active():break
				var game: Dictionary=s.fishing_session.game
				if str(game.stage)=="fight":game.holding=clampf((float(game.fishPos)-float(game.barPos))*5,-.6,.6)>float(game.velocity)
				s._process_action(.04)
			check(str(s.fishing.pending.get("fish",""))==id,"actual expected rod product "+id)
			check(s.fishing_resolve(false),"claim actual rod product "+id)
		else:
			var at: Dictionary={}
			for slot: Dictionary in s.system_catalog.fishing.trapSlots:
				if str(slot.water)==water:at=slot;break
			s.player_position=Vector2(float(at.x),float(at.y));s.fishing.traps={};s.fishing.rng=seed_for(id,water,"trap",day,480)
			check(int(s.fishing.rng)>0,"trap target seed "+id)
			s.day=maxi(0,day-1)
			check(SERVICE.trap_action(s,str(at.id),"place"),"actual place for "+id)
			# Day zero cannot have a previous in-game day: use first later legal window.
			if day==0:s.day=0;day=1;s.fishing.rng=seed_for(id,water,"trap",1,480)
			check(SERVICE.trap_action(s,str(at.id),"bait","herb"),"actual bait for "+id)
			s.day=day;SERVICE.advance(s,day)
			check(str(s.fishing.traps[str(at.id)].product.get("fish",""))==id,"actual expected trap product "+id)
			check(SERVICE.trap_action(s,str(at.id),"take"),"claim actual trap product "+id)
		check(int(s.fishing.records.get(id,{}).get("count",0))==1,"genuine species record "+id)
		var snapshot: Dictionary=s._make_save_data().duplicate(true)
		var schema_error: String=load("res://scripts/native_save_schema.gd").error(snapshot,s.initial_state)
		check(s.load_game_data(snapshot),"species native round trip "+id+" "+schema_error+" "+s.message)
	# Preserve a pending catch through disk save/load, then resolve only once.
	s.day=0;s.minutes=480;s.stamina=100;s.fishing=s.initial_state.fishing.duplicate(true);s.fishing.bait="plain";s.fishing.pending={};s.fishing.traps={};s.player_position=Vector2(749,2790)
	check(s.begin_fishing("fishing"),"pending persistence begin")
	for frame: int in range(1200):
		if not s.fishing_active():break
		var g: Dictionary=s.fishing_session.game
		if str(g.stage)=="fight":g.holding=clampf((float(g.fishPos)-float(g.barPos))*5,-.6,.6)>float(g.velocity)
		s._process_action(.04)
	var pending: Dictionary=s.fishing.pending.duplicate(true)
	check(not pending.is_empty() and s.save_game("user://fishing-pending-test.json",true),"pending disk save")
	var loaded: bool=s.load_game("user://fishing-pending-test.json")
	if not loaded:print("PENDING LOAD FAILURE ",s.message)
	check(loaded and s.fishing.pending==pending,"pending disk reload")
	check(s.fishing_resolve(true) and not s.fishing_resolve(true),"reload release once")
	check(int(s.fishing.records[str(pending.fish)].released)>=1,"release contributes actual record")
	# No tooltip/source catalogue may invent a destination that cannot be reached.
	s.player_position=Vector2(2690,2000)
	var target_count: int=0
	for entry: Dictionary in s.system_catalog.museum.entries:
		var info: Dictionary=KNOWLEDGE.describe(s,str(entry.key))
		if info.get("target",{}).is_empty():continue
		var target: Dictionary=KNOWLEDGE.source_target(s,str(entry.key))
		check(not target.is_empty(),"reachable real source "+str(entry.key))
		if not target.is_empty():target_count+=1
	check(target_count>240,"broad source navigation coverage")
	check(KNOWLEDGE.describe(s,"item:cabbage").target.get("name","")=="种子互助屋","crop source prefers the actual seed house")
	check(KNOWLEDGE.describe(s,"item:fishSoup").target.get("name","")=="禾溪小灶","cooking source prefers the actual kitchen")
	check(str(KNOWLEDGE.describe(s,"item:yarn").target.get("name","")).contains("牧场"),"ranch processing source uses the actual service point")
	for person: Dictionary in s.npc_catalog:
		s._museum_record("npc:"+str(person.id),false,true)
		var profile: Dictionary=KNOWLEDGE.describe(s,"npc:"+str(person.id))
		check(str(profile.detail).contains(str(person.greeting)) and str(profile.detail).contains(str(person.get("family",person.get("warm","")))),"real known biography fields "+str(person.id))
	for id: String in ["egret","sparrow","butterfly"]:
		s._museum_record("wild:"+id,false,true)
		check(not str(KNOWLEDGE.describe(s,"wild:"+id).get("detail","")).is_empty(),"known wildlife details "+id)
	# New shellfish dishes have playable recipes rather than only catalogue text.
	s.known_recipes.append("leekSnails");s.known_recipes.append("musselRadishSoup")
	s.inventory.riverSnail=4;s.inventory.riverMussel=4;s.inventory.leek=3;s.inventory.radish=3;s.stamina=100;s.minutes=480
	check(s.cook_recipe("leekSnails",1),"snail dish actually cooked "+s.message)
	check(s.cook_recipe("musselRadishSoup",1),"mussel dish actually cooked "+s.message)
	check(int(s.inventory.get("leekSnails",0))>0 and int(s.inventory.get("musselRadishSoup",0))>0,"new dishes enter inventory")
	for item: String in ["carp","riverSnail","riverMussel","leekSnails","musselRadishSoup"]:check(s.sale_quote(item,1)>=0,"economic quote recognizes "+item)
	var file:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/content-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"reachableSources":target_count},"  "));file.close()
	print("Fishing content integration: %d passed, %d failed; %d source routes" % [passed,failed,target_count]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
