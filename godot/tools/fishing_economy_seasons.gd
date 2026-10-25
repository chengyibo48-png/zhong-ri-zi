extends SceneTree
var passed: int=0
var failed: int=0
var s: Node
var RULES: Script
var SERVICE: Script
var SESSION: Script
var reports: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func simulate(model: RefCounted, quality: String) -> void:
	var frames: int=0
	while not bool(model.game.caught) and not bool(model.game.missed) and frames<1100:
		var game: Dictionary=model.game
		if game.stage=="bite":model.command("press")
		if game.stage=="fight":
			var lag: float=0.0 if quality=="steady" else sin(float(game.time)*3)*0.045
			var desired:=clampf((float(game.fishPos)-float(game.barPos)+lag)*5,-0.6,0.6)
			game.holding=desired>float(game.velocity)
		model.tick(.05);frames+=1
func actual_quote(id: String, grade: int) -> float:
	s.inventory[id]=1
	s.quality[id]=[0,0,0]
	if grade>0:s.quality[id][grade-1]=1
	s.kitchen.lots.bag[id]=[{"qty":1,"age":0.0}]
	return float(s.sale_quote(id,1,grade))

func equipment_investment(tier: int, equipped: Array) -> float:
	if tier==0:return 0.0
	var cost: float=300.0
	var materials: Dictionary=s.tool_definition("rod").get("needs",{}).duplicate(true)
	materials.wood=int(materials.get("wood",0))+6;materials.bamboo=int(materials.get("bamboo",0))+5
	for id: String in equipped:
		for item: String in s.system_catalog.fishing.crafts[id].needs:materials[item]=int(materials.get(item,0))+int(s.system_catalog.fishing.crafts[id].needs[item])
	for id: String in materials:cost+=float(s.item_catalog[id].price)*int(materials[id])
	return cost

func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func():push_error("Fishing economy timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.ui_open=false
	RULES=load("res://scripts/fishing_rules.gd");SERVICE=load("res://scripts/fishing_service.gd");SESSION=load("res://scripts/fishing_session.gd")
	for mode: String in ["relaxed","standard"]:
		for bait: String in ["plain","grain","herb","shrimp"]:
			for variant: int in [0,1,2]:
				var tier: int=0 if variant==0 else 2
				s.fishing=s.initial_state.fishing.duplicate(true);s.fishing.mode=mode;s.fishing.bait=bait;s.fishing.tutorialDone=true
				s.inventory.steadyFloat=1;s.inventory.gentleSinker=1;s.inventory.fishBell=1
				s.toolkit.tools.rod.level=tier;s.toolkit.tools.rod.branch="broad" if variant==2 else "care";s.fishing.tackles=(["steadyFloat","fishBell"] if variant==2 else ["steadyFloat","gentleSinker"]) if tier==2 else []
				var earned: float=0.0;var bait_cost: float=0.0;var work: float=0.0;var game_minutes: float=0.0;var catches: int=0;var losses: int=0;var grades: Array=[0,0,0,0];var seasons: Array=[0,0,0,0]
				for day: int in range(112):
					s.day=day;s.stamina=100
					for cast: int in range(6):
						s.minutes=[420,540,780,1025,1140,1230][cast]
						var water: String=["river","pond","bamboo","pasture","spring"][(day+cast)%5]
						var plan: Dictionary=SERVICE.plan(s,water)
						check(not plan.is_empty(),"rod pool year day "+str(day)+water)
						if plan.is_empty():continue
						plan.depth=2 if tier==2 else 1
						var model: RefCounted=SESSION.new();model.start(plan,s.system_catalog.fishing.spots[0]);simulate(model,"steady")
						s.fishing.rng=int(plan.seed);s.fishing.nextId=int(s.fishing.nextId)+1
						var bait_def: Dictionary=s.system_catalog.fishing.baits[bait]
						for ingredient: String in bait_def.get("needs",{}):bait_cost+=float(s.item_catalog[ingredient].price)*int(bait_def.needs[ingredient])/maxf(1,float(bait_def.get("qty",1)))
						work+=float(model.game.time);game_minutes+=15 if variant==2 else 25
						if not bool(model.game.caught):losses+=1;continue
						var grade: int=RULES.grade(plan,float(model.game.safe),float(model.game.total))
						grades[grade]+=1;catches+=1;seasons[int(day/28)]+=1
						earned+=actual_quote(str(plan.fish),grade)
						s.fishing.xp=int(s.fishing.get("xp",0))+1
				for season: int in range(4):check(int(seasons[season])>0,"viable season "+mode+bait+str(tier)+str(season))
				check(int(grades[3])==0 if mode=="relaxed" else true,"assist no exclusive quality")
				var investment: float=equipment_investment(tier,s.fishing.tackles)
				reports.append({"route":"rod","mode":mode,"bait":bait,"rod":tier,"loadout":"quick" if variant==2 else "stable" if variant==1 else "basic","tackles":s.fishing.tackles.duplicate(),"branch":str(s.toolkit.tools.rod.branch),"days":112,"attempts":672,"caught":catches,"missed":losses,"grades":grades,"seasonCatches":seasons,"gross":snappedf(earned,.01),"baitCost":snappedf(bait_cost,.01),"investment":investment,"net":snappedf(earned-bait_cost-investment,.01),"activeSeconds":snappedf(work,.1),"gameMinutes":game_minutes,"operator":"deterministic stable tracking controller","valuation":"actual sale_quote; bait ingredients and crafted gear materials at base value"})
	for bait: String in ["grain","herb"]:
		s.fishing=s.initial_state.fishing.duplicate(true);s.fishing.bait=bait;s.toolkit.tools.rod.level=1
		var gross: float=0;var cost: float=0;var catches: int=0;var seasons: Array=[0,0,0,0]
		var slots: Array=s.system_catalog.fishing.trapSlots.slice(0,8)
		for at: Dictionary in slots:s.fishing.traps[str(at.id)]={"bait":bait,"baitedDay":0,"lastDay":0,"product":{}}
		for day: int in range(1,113):
			s.day=day;s.minutes=400;s.stamina=100;SERVICE.advance(s,day)
			for at: Dictionary in slots:
				var row: Dictionary=s.fishing.traps[str(at.id)]
				var product: Dictionary=row.product
				if not product.is_empty():
					gross+=actual_quote(str(product.fish),int(product.grade));catches+=1;seasons[int((day-1)/28)]+=1;row.product={}
				var bait_def: Dictionary=s.system_catalog.fishing.baits[bait]
				var legal: Array=RULES.pool(s.system_catalog.fishing.waters[str(at.water)],s.system_catalog.fishing.species,int(day/28)%4,s.weather_for(day),480,bait,"trap",str(at.water))
				if not legal.is_empty():
					row.baitedDay=day
					for ingredient: String in bait_def.needs:cost+=float(s.item_catalog[ingredient].price)*int(bait_def.needs[ingredient])/float(bait_def.qty)
			check(s.fishing.traps.size()==8,"trap count invariant day "+str(day))
		reports.append({"route":"trap","bait":bait,"days":112,"traps":8,"caught":catches,"seasonCatches":seasons,"gross":snappedf(gross,.01),"baitCost":snappedf(cost,.01),"investment":8*s.shop_price("fishTrap"),"net":snappedf(gross-cost-8*s.shop_price("fishTrap"),.01),"gameMinutes":catches*6,"note":"annual availability and capacity, one claim per cage per day"})
	var file:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/economy-112-days.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"runs":reports},"  "));file.close()
	print("Fishing four seasons: %d passed, %d failed; %d independent 112-day routes" % [passed,failed,reports.size()]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
