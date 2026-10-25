extends SceneTree
const PRODUCTS = preload("res://scripts/ranch_products.gd")
var passed := 0
var failed := 0
var s: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func():push_error("economy simulation timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false)
	var reports: Array=[]
	for type: String in s.system_catalog.ranch.species:
		for route: String in (["fresh","processed","pasture"] if type=="pig" else ["fresh","processed"]):
			s.day=0;s.minutes=400;s.stamina=100;s.money=100000;s._reset_animals();s.animals.clear();s.ranch.products=[];s.ranch.settledDay=-1
			s.inventory={"bedding":500};s.quality={};s.storage={};s.kitchen=s.initial_state.kitchen.duplicate(true);s.kitchen.lots={"bag":{},"storage":{}};s.legacy_processing.clear()
			s.ranch.stores={"feed":9999,"hay":0,"grainFeed":0,"healthFeed":0,"bedding":9999};s.ranch.policy="inside";s.ranch.feed="feed"
			s.economy=s.initial_state.economy.duplicate(true);s.upgrades.kitchen=true
			var spec: Dictionary=s.system_catalog.ranch.species[type];var home:=str(spec.home)
			for key: String in s.ranch.barns:
				var b:Dictionary=s.ranch.barns[key];b.built=key==home;b.clean=100;b.durability=100;b.space=0;b.comfort=2;b.protection=3;b.autoFeed=true;b.autoClean=true;b.autoCollect=true;b.trough={}
			var a:Dictionary=s._ranch_new_animal(type,"female","local",int(spec.adult));a.trait="strong"
			var receipts := 0;var products := 0;var box_visits := 0;var process_visits := 0;var pet_visits := 0;var observed:Dictionary={}
			var movement=load("res://scripts/ranch_movement.gd").new()
			var recipe: String={"cow":"cream","sheep":"yarn","goat":"goatCheese","rabbit":"fineYarn","pig":"compost"}.get(type,"")
			var processed: String={"cow":"cream","sheep":"yarn","goat":"goatCheese","rabbit":"fineYarn","pig":"compost"}.get(type,"")
			for d: int in range(112):
				if route=="pasture":
					s.day=d;s.minutes=800;s.ranch.policy="safe";s.ranch.zone=int(d/7)%2
					if movement.safe_out(s,a):
						var pen:Dictionary=s.system_catalog.forage.pens[int(s.ranch.zone)]
						a.position.room=null;a.position.x=float(pen.x)+100;a.position.y=float(pen.y)+100;a.position.walking=false
						for pulse:int in range(3):preload("res://scripts/ranch_care.gd").graze(s,a,2.1)
						movement.advance(s,0.01)
				s.day=d+1;s.minutes=400;s.stamina=100;s._advance_kitchen(d);s._advance_ranch(d,s.weather_for(d));s._advance_legacy_processing(d)
				# Kitchen dairy jobs use their own clock and collection transaction.
				for job:Dictionary in s.kitchen.get("jobs",[]).duplicate():
					if float(job.get("ready",0))<=s._kitchen_now():check(s.collect_kitchen_job(int(job.key)),"dairy job actually collected")
				for row:Dictionary in s.ranch.products:
					if not observed.has(row.id):
						observed[row.id]=true
						if str(row.item)==str(spec.product):products+=int(row.qty)
				if route in ["fresh","pasture"] or (d+1)%7==0 or PRODUCTS.box_count(s,home)>40:
					if PRODUCTS.take(s,"box",home)>0:box_visits+=1
				if (d+1)%7==0:s.ranch_tend(0,"pet");pet_visits+=1
				if route=="processed" and recipe!="":
					var batches:=mini(5,int(s.inventory.get(str(spec.product),0))/2)
					if batches>0:
						if type=="cow" and float(s.kitchen.get("equipment",{}).get("dairy",{}).get("clean",100))<70:s.clean_kitchen_station("dairy")
						check(s.ranch_craft(recipe,batches),type+" actual processing day "+str(d));process_visits+=1
				var sale_items: Array=[str(spec.product)] if route=="fresh" or recipe=="" else [processed]
				if route=="pasture":sale_items=[str(spec.product),"truffle"]
				for item:String in sale_items:
					var quantity:int=int(s.inventory.get(item,0))
					if quantity<=0:continue
					var before:int=s.money
					check(s.sell_item(item,quantity),type+" actual sale day "+str(d))
					receipts+=int(s.money)-before
				check(float(a.health)>=80,type+" four season health "+str(d))
			var feed_cost: int=(9999-int(s.ranch.stores.feed))*int(s.item_catalog.feed.cost)
			var bedding_cost: int=(9999-int(s.ranch.stores.bedding)+500-int(s.inventory.get("bedding",0)))*int(s.item_catalog.bedding.cost)
			var def:Dictionary=s.system_catalog.ranch.barns[home]
			var facilities_per_bed:float=float(int(def.cost)+300+170+330)/int(def.base)
			reports.append({"animal":type,"route":route,"days":112,"products":products,"actualSales":receipts,"feedCost":feed_cost,"beddingCost":bedding_cost,"netBeforeCapital":receipts-feed_cost-bedding_cost,"animalCost":int(spec.cost),"facilitiesPerBed":snappedf(facilities_per_bed,0.01),"boxVisits":box_visits,"processingActions":process_visits,"petActions":pet_visits,"manualCareBaseline":112+products+ceili((9999-int(s.ranch.stores.bedding))*1.0),"unsoldStock":s.inventory.duplicate(true),"pendingJobs":s.legacy_processing.size()+s.kitchen.get("jobs",[]).size()})
	FileAccess.open("res://artifacts/ranch-overhaul-20261016/economy-112-days.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed,"runs":reports},"  "))
	print("Ranch four season economy: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
