extends SceneTree
var passed: int=0
var failed: int=0
var s: Node
var RULES: Script
var SERVICE: Script
var KNOWLEDGE: Script
var SESSION: Script
var results: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(label)
func reset_fishing() -> void:
	s.cancel_action();s._cancel_fishing_session();s.fishing=s.initial_state.fishing.duplicate(true);s.stamina=100;s.minutes=480;s.day=0;s.current_interior="";s.ui_open=false
func autopilot(model: RefCounted, dt: float=0.02) -> void:
	var g: Dictionary=model.game
	if g.stage=="bite":model.command("press")
	elif g.stage=="fight":
		var desired:=clampf((float(g.fishPos)-float(g.barPos))*5.0,-0.6,0.6)
		g.holding=desired>float(g.velocity)
	model.tick(dt)
func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func():push_error("Fishing smoke timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false)
	RULES=load("res://scripts/fishing_rules.gd");SERVICE=load("res://scripts/fishing_service.gd");KNOWLEDGE=load("res://scripts/knowledge_catalog.gd");SESSION=load("res://scripts/fishing_session.gd")
	for path: String in ["fishing_panel","fishing_meter","museum_panel","fish_spot","fish_trap","farm_world"]:
		var script: Script=load("res://scripts/"+path+".gd");check(script!=null and script.can_instantiate(),"compile "+path)
	check(s.system_catalog.fishing.species.size()==16,"16 species")
	check(s.system_catalog.fishing.trapSlots.size()==12,"12 trap sites")
	check(s.plots.size()==97 and s.system_catalog.ranch.species.size()==7,"field and ranch preserved")
	var reachable_species: Dictionary={}
	for season: int in range(4):
		for weather: String in ["晴","雨","雪"]:
			for time: int in [390,480,600,900,1020,1200]:
				for water: String in s.system_catalog.fishing.waters:
					for method: String in ["rod","trap"]:
						var pool: Array=RULES.pool(s.system_catalog.fishing.waters[water],s.system_catalog.fishing.species,season,weather,time,"grain",method,water)
						for id: String in pool:
							reachable_species[id]=true
							check(RULES.available(s.system_catalog.fishing.species[id],water,season,weather,time,method),"only legal fish "+id)
	check(reachable_species.size()==16,"every species has a legal catch window")
	for id: String in s.system_catalog.fishing.species:
		var fish: Dictionary=s.system_catalog.fishing.species[id]
		check(preload("res://scripts/item_art.gd").texture_for(id,"items")!=null,"independent fish image "+id)
		check(s.museum_entries.has("item:"+id),"fish encyclopedia "+id)
		if "rod" not in fish.methods:continue
		for mode: String in ["relaxed","standard"]:
			var model: RefCounted=SESSION.new()
			var p: Dictionary={"fish":id,"mode":mode,"inputStyle":"hold","difficulty":fish.difficulty,"movement":fish.movement,"wait":1.5,"seed":773,"rod":2,"skill":4,"tackles":[],"tutorial":false,"depth":2,"branch":"care"}
			model.start(p,s.system_catalog.fishing.spots[0])
			for frame: int in range(2300):
				autopilot(model)
				if bool(model.game.caught) or bool(model.game.missed):break
			check(bool(model.game.caught),"playable catch "+id+" "+mode)
			check(float(model.game.time)<45,"bounded session "+id+mode)
			var grade: int=RULES.grade(p,float(model.game.safe),float(model.game.total))
			check(grade<=2 if mode=="relaxed" else grade<=3,"quality cap "+mode)
			results.append({"fish":id,"mode":mode,"seconds":model.game.time,"caught":model.game.caught,"coverage":float(model.game.safe)/maxf(.01,float(model.game.total)),"grade":grade})
			var snapshot: Dictionary=model.snapshot();model.tick(.1,true);check(model.game.time==snapshot.time and not model.game.holding,"pause clears held input")
	reset_fishing()
	var point: Dictionary=s.system_catalog.fishing.spots[0];s.player_position=Vector2(float(point.x),float(point.y))
	s.inventory.grainBait=3;s.fishing.bait="grain"
	check(s.begin_fishing(str(point.id)),"begin actual action")
	s.cancel_player_action();check(int(s.inventory.grainBait)==3 and s.stamina==100 and int(s.fishing.nextId)==1,"cancel before landing no charge")
	check(s.begin_fishing(str(point.id)),"second actual action "+s.message)
	if not s.fishing_active():quit(1);return
	for frame: int in range(19):s._process_action(.1)
	check(bool(s.fishing_session.game.get("paid",false)) and int(s.inventory.grainBait)==2,"landed cast charged once")
	var minutes_before: float=s.minutes;var stamina_before: float=s.stamina
	SERVICE.commit_cast(s,s.fishing_session.game)
	check(s.minutes==minutes_before and s.stamina==stamina_before and int(s.inventory.grainBait)==2,"repeated commit harmless")
	var game: Dictionary=s.fishing_session.game;game.caught=true;game.safe=10;game.total=10;game.stage="caught"
	s._process_action(.02)
	check(not s.fishing.pending.is_empty() and not s.action_busy(),"session outcome drives completion")
	var pending: Dictionary=s.fishing.pending.duplicate(true)
	SERVICE.finish(s,game);check(s.fishing.pending==pending,"duplicate settlement harmless")
	var item:=str(pending.fish);var count_before:=int(s.inventory.get(item,0))
	s.inventory[item]=999999
	check(not s.fishing_resolve(false) and s.fishing.pending==pending,"full bag retains pending catch without loss")
	s.inventory[item]=count_before
	check(s.fishing_resolve(false),"keep pending catch")
	check(not s.fishing_resolve(false) and int(s.inventory[item])==count_before+1,"keep exactly once")
	check(int(s.fishing.records[item].count)==1,"one authentic catch recorded")
	s._consume_item(item,int(s.inventory[item]));s._museum_sync()
	check(not KNOWLEDGE.state(s,item).is_empty(),"discovery survives no stock and normalized item key")
	var native: Dictionary=s._make_save_data().duplicate(true)
	check(s.load_game_data(native),"current native save round trip "+s.message)
	# A purchased fish is acquired, never counted as personally caught.
	s.inventory.blackCarp=1;s._museum_sync()
	check(not s.fishing.records.has("blackCarp") and KNOWLEDGE.state(s,"blackCarp").get("acquired",false),"purchase does not fabricate fishing record")
	reset_fishing();s.inventory.fishTrap=10;s.inventory.grainBait=20;s.inventory.herbBait=20
	var slots: Array=s.system_catalog.fishing.trapSlots
	for i: int in range(8):
		var at: Dictionary=slots[i];s.player_position=Vector2(float(at.x),float(at.y));check(SERVICE.trap_action(s,str(at.id),"place"),"place trap "+str(i))
	var ninth: Dictionary=slots[8];s.player_position=Vector2(float(ninth.x),float(ninth.y));check(not SERVICE.trap_action(s,str(ninth.id),"place"),"8 trap capacity enforced")
	var slot: Dictionary=slots[0];s.player_position=Vector2(float(slot.x),float(slot.y));check(SERVICE.trap_action(s,str(slot.id),"bait","herb"),"bait physical trap")
	var bait_before:=int(s.inventory.herbBait);SERVICE.advance(s,0);check(s.fishing.traps[str(slot.id)].product.is_empty(),"not produce same day")
	s.day=1;SERVICE.advance(s,1);var product: Dictionary=s.fishing.traps[str(slot.id)].product.duplicate(true)
	check(not product.is_empty(),"next day trap harvest")
	SERVICE.advance(s,1);s.day=4;SERVICE.advance(s,4)
	check(s.fishing.traps[str(slot.id)].product==product and int(s.inventory.herbBait)==bait_before,"unclaimed product conserved across days")
	var output:=str(product.get("fish",""));var stock_before:=int(s.inventory.get(output,0))
	s.inventory[output]=999999
	check(not SERVICE.trap_action(s,str(slot.id),"take") and s.fishing.traps[str(slot.id)].product==product,"full bag retains trap product without loss")
	s.inventory[output]=stock_before
	check(SERVICE.trap_action(s,str(slot.id),"take"),"take physical trap product")
	check(not SERVICE.trap_action(s,str(slot.id),"take") and int(s.inventory[output])==stock_before+1,"trap cannot duplicate")
	check(float(s.food_freshness(output).age)>=3.0,"trap preserves original production age")
	native=s._make_save_data().duplicate(true);check(s.load_game_data(native),"trap native round trip "+s.message)
	for entry: Dictionary in s.system_catalog.museum.entries:
		var key:=str(entry.key);var description: Dictionary=KNOWLEDGE.describe(s,key)
		check(not str(description.get("source","")).is_empty(),"source clue "+key)
		check(KNOWLEDGE.picture(s,key)!=null,"real illustration "+key)
		for linked: String in description.get("links",[]):check(s.museum_entries.has(linked),"valid linked entry "+linked)
	reset_fishing();s.player_position=Vector2(749,2790);s.inventory.grainBait=3;s.fishing.bait="grain"
	check(s.begin_fishing("fishing"),"paid cancellation begins")
	for frame: int in range(20):s._process_action(.1)
	var cancelled_plan: Dictionary=s.fishing_session.game.plan.duplicate(true)
	var used_seed: int=s.fishing.rng;s.cancel_player_action()
	check(int(s.inventory.grainBait)==2 and int(s.fishing.rng)==used_seed,"cancel after landing retains consumed bait and random advance")
	check(not s.finish_fishing(cancelled_plan,true,10,10),"cancelled stale callback cannot produce catch")
	var valid: Dictionary=s._make_save_data().duplicate(true)
	var old_format: Dictionary=valid.duplicate(true);old_format.fishing.version=1
	check(not s.load_game_data(old_format),"old fishing format rejected without migration")
	var invalid: Dictionary=valid.duplicate(true);invalid.fishing.rng=-1
	check(not s.load_game_data(invalid) and int(s.inventory.grainBait)==2,"malformed random state rejected without mutation")
	invalid=valid.duplicate(true);invalid.fishing.pending={"id":1,"fish":"fish","water":"river","grade":8,"length":20,"producedDay":0,"method":"rod"}
	check(not s.load_game_data(invalid),"malformed pending grade rejected")
	invalid=valid.duplicate(true);invalid.fishing.traps={"trap-1":{"bait":"grain","baitedDay":-1,"lastDay":0,"product":{"fish":"carp","water":"river","grade":1,"length":30,"producedDay":0,"method":"trap"}}}
	check(not s.load_game_data(invalid),"rod-only species cannot be forged as trap product")
	var toggle: RefCounted=SESSION.new();toggle.start({"mode":"relaxed","inputStyle":"toggle","wait":2},s.system_catalog.fishing.spots[0]);toggle.command("press");toggle.tick(.1);toggle.command("release")
	check(str(toggle.game.stage)=="charge" and bool(toggle.game.holding),"toggle input continues charging after release")
	toggle.command("press");check(str(toggle.game.stage)=="cast","second toggle launches cast")
	var file:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/rules-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"sessions":results},"  "));file.close()
	print("Fishing overhaul: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
