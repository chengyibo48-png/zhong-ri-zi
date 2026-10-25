extends SceneTree
const CARE = preload("res://scripts/ranch_care.gd")
const PRODUCTS = preload("res://scripts/ranch_products.gd")
var passed := 0
var failed := 0
var s: Node
var economy: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func fresh() -> void:
	s.day=0; s.minutes=400; s.stamina=100; s.money=100000
	s._reset_animals(); s.animals.clear(); s.ranch.products=[]; s.ranch.births=[]
	s.ranch.settledDay=-1; s.ranch.productNext=1
	s.ranch.policy="inside"
	for home: String in s.ranch.barns:
		var b: Dictionary = s.ranch.barns[home]
		b.built=true;b.space=3;b.comfort=2;b.protection=3;b.clean=100;b.durability=100
		b.autoFeed=true;b.autoClean=true;b.autoCollect=false;b.trough={}
	s.ranch.stores={"feed":9999,"hay":9999,"grainFeed":9999,"healthFeed":9999,"bedding":9999}
func next_day(weather: String = "晴") -> void:
	var previous: int = s.day
	s.day += 1;s.minutes=400;s.stamina=100
	s._advance_ranch(previous,weather)
func output_count(item: String = "") -> int:
	var qty := 0
	for row: Dictionary in s.ranch.products:
		if item=="" or str(row.item)==item: qty+=int(row.qty)
	return qty
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func():push_error("ranch overhaul timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.ui_open=false
	check(s.plots.size()==97 and preload("res://scripts/farm_layout.gd").MAIN_COUNT==49,"7x7 field preserved")
	check(s.system_catalog.ranch.species.size()==7,"seven species available")
	for type: String in s.system_catalog.ranch.species:
		fresh()
		var spec: Dictionary = s.system_catalog.ranch.species[type]
		check(s.ranch_buy_animal(type,"female","local",true),type+" purchase allowed without date lock")
		var a: Dictionary = s.animals[0]
		check(a.position.room==s.system_catalog.ranch.barns[str(spec.home)].house,type+" housed")
		a.trait="strong"
		for d: int in range(int(spec.adult)):
			next_day()
		check(int(a.age)==int(spec.adult),type+" reaches adulthood")
		a.progress=0;a.clean=100;s.ranch.barns[str(spec.home)].clean=100;s.ranch.barns[str(spec.home)].autoClean=false;s.ranch.products=[];PRODUCTS.sync(s)
		for d: int in range(int(spec.cycle)-1): next_day()
		check(output_count(str(spec.product))==0,type+" not early")
		next_day()
		check(output_count(str(spec.product))==1,type+" completes production cycle")
		var row: Dictionary = s.ranch.products.filter(func(x):return x.item==str(spec.product))[0]
		if str(row.location) in ["nest","ground"]:
			s.current_interior=str(row.room);s.interior_position=Vector2(float(row.x),float(row.y))
		var old_inventory: int = int(s.inventory.get(str(spec.product),0))
		check(s.ranch_tend(0,"collect"),type+" harvest action")
		check(int(s.inventory.get(str(spec.product),0))==old_inventory+1,type+" quantity transferred")
		check(int(a.ready)==0 and output_count(str(spec.product))==0,type+" ledger consumed once")
		check(not s.ranch_tend(0,"collect"),type+" cannot collect twice")
		s.stamina=100;s.minutes=400;s.ranch.barns[str(spec.home)].autoClean=true
		var father: Dictionary = s._ranch_new_animal(type,"male","local",int(spec.adult))
		father.trait="strong";a.hunger=100;father.hunger=100;a.mood=100;a.health=100
		s.inventory.grainFeed=99
		check(s.ranch_breed(str(a.id),str(father.id)),type+" breeding scheduled")
		check(s.ranch.births.size()==1,type+" reserves birth")
		for d: int in range(int(spec.gestation)): next_day()
		check(s.animals.size()==3 and s.ranch.births.is_empty(),type+" baby born")
		var baby: Dictionary = s.animals[2]
		check(baby.parents==[a.id,father.id] and int(baby.generation)==1,type+" lineage retained")
		check(bool(a.rest) and int(a.postpartumUntil)==s.day+2,type+" postpartum recovery")
		var snapshot: Array = s.ranch.products.duplicate(true)
		check(s.save_game("user://ranch-overhaul-test.json",true),type+" current save succeeds")
		check(s.load_game("user://ranch-overhaul-test.json"),type+" current load succeeds")
		check(s.ranch.products==snapshot and s.animals.size()==3,type+" load preserves outputs and companions")
		check(not s._museum_entry("animal:"+type).is_empty(),type+" encyclopedia")
	# Shared sheepfold and reserved birth slots.
	fresh();s.ranch.barns.sheepfold.space=0
	var goat: Dictionary = s._ranch_new_animal("goat","female","local",12)
	s._ranch_new_animal("sheep","female","local",10)
	s.ranch.births.append({"type":"sheep","mother":null,"father":null,"remaining":4,"total":6})
	check(not s._ranch_space_for("goat") and not s._ranch_space_for("sheep"),"shared sheepfold counts both species and reservations")
	check(not s.ranch_buy_animal("goat","female","local",false),"full shared barn prevents purchase")
	# Species sex rules, diet and relaxed relationship care.
	for type: String in s.system_catalog.ranch.species:
		fresh();var spec: Dictionary=s.system_catalog.ranch.species[type]
		var a: Dictionary=s._ranch_new_animal(type,"male","local",int(spec.adult));a.trait="strong";a.bond=45
		for d: int in range(int(spec.cycle)):next_day()
		check((output_count(str(spec.product))==0)==bool(spec.femaleOnly),type+" correct male production restriction")
		check(float(a.bond)==45,type+" skipped petting keeps bond")
		check(CARE.accepts(s,a,"hay")==bool(type not in ["hen","duck"]),type+" data configured diet")
	# Actual grass consumption and feed share a single meal account.
	fresh();goat=s._ranch_new_animal("goat","female","local",12);goat.hunger=30
	goat.position.room=null;goat.position.x=2720;goat.position.y=2750;goat.position.walking=false
	s.ranch.zone=0;var grass_before: float=s.ranch.grass[0]
	CARE.graze(s,goat,2.1)
	check(CARE.needed(s,goat,0)==1 and float(s.ranch.grass[0])==grass_before-2,"one portion eaten at real grass position")
	s.inventory.feed=10;s.stamina=100
	check(s.ranch_tend(0,"feed","feed"),"manual feeding completes partial grazing")
	check(int(s.inventory.feed)==9 and CARE.needed(s,goat,0)==0,"only missing feed portion consumed")
	CARE.graze(s,goat,20)
	check(float(s.ranch.grass[0])==grass_before-2,"sated animal never consumes grass twice")
	var stores_before: int=s.ranch.stores.feed
	next_day();var settled: Dictionary=s.ranch.duplicate(true)
	check(int(s.ranch.stores.feed)==stores_before,"overnight does not deduct a second meal")
	s._advance_ranch(0,"晴")
	check(s.ranch==settled,"duplicate overnight call is idempotent")
	# Box capacity, conservation, ages, qualities and retrieval idempotence.
	fresh();goat=s._ranch_new_animal("goat","female","local",12)
	s.day=7;PRODUCTS.produce(s,goat,"goatMilk",2,3,2);PRODUCTS.sync(s)
	var bag_before: int=int(s.inventory.get("goatMilk",0))
	PRODUCTS.auto_collect(s,"sheepfold")
	check(PRODUCTS.box_count(s,"sheepfold")==2 and int(s.inventory.get("goatMilk",0))==bag_before,"auto collection goes to barn box")
	check(int(goat.ready)==0 and int(s.ranch.products[0].producedDay)==2,"box preserves production date and removes animal counter")
	check(PRODUCTS.take(s,"box","sheepfold")==2,"box transferred once")
	check(PRODUCTS.take(s,"box","sheepfold")==0,"box cannot be collected twice")
	check(int(s.inventory.goatMilk)==bag_before+2 and int(s.quality.goatMilk[2])>=2,"quality and quantity conserved")
	var lots: Array=s.kitchen.lots.bag.goatMilk
	check(float(lots[-1].age)==5.0 and int(lots[-1].producedDay)==2,"delayed collection does not refresh food")
	PRODUCTS.produce(s,goat,"goatMilk",48,1,7);PRODUCTS.auto_collect(s,"sheepfold")
	PRODUCTS.produce(s,goat,"goatMilk",1,2,7);PRODUCTS.auto_collect(s,"sheepfold")
	check(PRODUCTS.box_count(s,"sheepfold")==48 and int(goat.ready)==1 and output_count()==49,"full box keeps source output")
	check(str(s.ranch.barns.sheepfold.collectStatus).contains("箱满"),"full box warning visible")
	PRODUCTS.take(s,"box","sheepfold");PRODUCTS.take(s,"animal",str(goat.id))
	PRODUCTS.produce(s,goat,"goatMilk",47,0,7);PRODUCTS.auto_collect(s,"sheepfold")
	PRODUCTS.produce(s,goat,"goatMilk",2,2,7);PRODUCTS.auto_collect(s,"sheepfold")
	check(PRODUCTS.box_count(s,"sheepfold")==47 and int(goat.ready)==2 and str(s.ranch.barns.sheepfold.collectStatus).contains("箱满"),"partially full box retains whole lot and warning")
	goat.health=45;goat.illness=40;s.inventory.animalMedicine=1;s.stamina=100
	check(s.ranch_default_action(0)=="treat" and s.ranch_tend(0,"treat"),"illness prioritizes real treatment")
	check(float(goat.health)>45 and float(goat.illness)<40 and bool(goat.rest),"medicine starts recoverable rest")
	var related:Dictionary=s._ranch_new_animal("goat","male","local",12,[str(goat.id)])
	goat.hunger=100;goat.mood=100;goat.health=100;goat.illness=0
	check(not s.ranch_breed(str(goat.id),str(related.id)),"direct relatives cannot breed")
	goat.position.room="ranch-sheepfold";goat.position.inside={"x":520,"y":490}
	PRODUCTS.follow_animals(s)
	var attached:Array=s.ranch.products.filter(func(row):return str(row.location)=="animal")
	check(not attached.is_empty() and float(attached[0].x)==520 and attached[0].room=="ranch-sheepfold","attached output follows live animal location")
	var manure_before:int=int(s.inventory.get("manure",0))
	s.ranch.barns.sheepfold.clean=20;s.ranch.barns.sheepfold.waste=5;s.ranch.barns.sheepfold.lastClean=-1;s.stamina=100
	check(s.ranch_barn_action("sheepfold","clean"),"manual barn cleaning uses shared settlement")
	check(int(s.inventory.get("manure",0))==manure_before+5 and int(s.ranch.barns.sheepfold.waste)==0,"cleaning conserves waste to manure transfer")
	check(s.ranch.products.filter(func(row):return str(row.item)=="manure").is_empty(),"manual cleaning output never remains claimable twice")
	# Invalid ledger rejected before state mutation.
	var bad: Dictionary=s._make_save_data().duplicate(true)
	bad.ranch.products[0].qty=-1
	check(not preload("res://scripts/native_save_rules.gd").valid(bad,s.initial_state),"invalid product quantity rejected")
	# New processing and encyclopedia, all recipes are real transactions.
	s.inventory.rabbitFur=4;s.inventory.goatMilk=4;s.stamina=100;s.minutes=400
	var yarn_before: int=int(s.inventory.get("fineYarn",0))
	check(s.ranch_craft("fineYarn",2),"rabbit fur processing")
	check(int(s.inventory.fineYarn)==yarn_before+4 and int(s.inventory.rabbitFur)==0,"fine yarn recipe conserves materials")
	check(s.ranch_craft("goatCheese",1),"goat cheese processing scheduled")
	check(s.legacy_processing.any(func(job):return str(job.id)=="goatCheese"),"goat cheese real timed processing")
	var cheese_before:int=int(s.inventory.get("goatCheese",0))
	s.day+=1;s._advance_legacy_processing(s.day-1)
	check(int(s.inventory.get("goatCheese",0))==cheese_before+1,"goat cheese processing actually completes")
	s.stamina=100;s.minutes=400
	check(s.sale_quote("goatCheese",1)>0 and s.sell_item("goatCheese",1),"goat cheese connects to real sale")
	for item: String in ["goatMilk","goatCheese","rabbitFur","fineYarn"]:
		check(not s._museum_entry("item:"+item).is_empty(),item+" encyclopedia")
		check(preload("res://scripts/item_art.gd").texture_for(item)!=null,item+" distinct real icon")
	# Independent 112 day actual lifecycle simulations per species and bed.
	for type: String in s.system_catalog.ranch.species:
		fresh();var spec: Dictionary=s.system_catalog.ranch.species[type]
		var a: Dictionary=s._ranch_new_animal(type,"female","local",int(spec.adult));a.trait="strong"
		var home:=str(spec.home);s.ranch.barns[home].autoCollect=true
		var units := 0;var gross := 0;var labor := 0
		var feed_start: int=int(s.ranch.stores.feed)
		for d: int in range(112):
			next_day(["晴","雨","晴","寒潮"][int(d/28)])
			for row: Dictionary in s.ranch.products:
				if str(row.item)==str(spec.product):
					units+=int(row.qty);gross+=roundi(float(s.item_catalog[str(row.item)].price)*[1.0,1.2,1.5,1.9][int(row.grade)])*int(row.qty)
			PRODUCTS.take(s,"box",home);labor+=1
			check(float(a.health)>=90 and float(a.hunger)>=40,type+" stable care day "+str(d))
		var feed_cost: int=(feed_start-int(s.ranch.stores.feed))*int(s.item_catalog.feed.cost)
		var capital: int=int(spec.cost)+int(s.system_catalog.ranch.barns[home].cost)+300
		economy.append({"species":type,"days":112,"perBedProducts":units,"gross":gross,"feedCost":feed_cost,"netBeforeCapital":gross-feed_cost,"animalBarnAutomation":capital,"collectVisits":labor,"manualHarvestVisits":units})
		check(units>=floori(112.0/float(spec.cycle))-1,type+" seasonal output cadence")
	var report := {"passed":passed,"failed":failed,"days":112,"economy":economy}
	FileAccess.open("res://artifacts/ranch-overhaul-20261016/rules-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Ranch overhaul: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
