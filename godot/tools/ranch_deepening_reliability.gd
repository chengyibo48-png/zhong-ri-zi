extends SceneTree
var passed:=0
var failed:=0
var s:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func setup()->void:
	s.animals.clear();s.ranch.births=[];s.ranch.birthHistory=[];s.ranch.families={};s.day=30;s.minutes=600;s.stamina=100;s.money=10000;s.inventory.grainFeed=100
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;s.ranch.barns[id].clean=100;s.ranch.barns[id].comfort=2
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	var nurture:Script=load("res://scripts/ranch_nurture.gd");var intents:Script=load("res://scripts/ranch_intents.gd")
	for type_id:String in s.system_catalog.ranch.species:
		setup();var m:Dictionary=s._ranch_new_animal(type_id,"female","local",40);var f:Dictionary=s._ranch_new_animal(type_id,"male","local",40)
		var task:Dictionary={"action":"breed","arg":[m.id,f.id],"receipt":"breed-"+type_id}
		var quote:Dictionary=intents.quote(s,task)
		check(bool(quote.ok),"ready pairing quote "+type_id+str(quote.reasons))
		var money:int=s.money;var grain:int=s.inventory.grainFeed
		check(s.perform_ranch_task(task),"actual pairing "+type_id+" "+s.message)
		check(s.money==money-20 and s.inventory.grainFeed==grain-2,"one material and cash charge "+type_id)
		check(not s.perform_ranch_task(task) and s.money==money-20,"repeated receipt cannot settle again "+type_id)
		if type_id in ["hen","duck"]:
			check(s.ranch.births.is_empty(),"birds never enter mammal pregnancy "+type_id)
			var item:String="fertileHenEgg" if type_id=="hen" else "fertileDuckEgg"
			check(s.inventory[item]==1,"pairing gives actual fertile egg "+type_id)
			check(s.ranch_incubate(type_id),"actual incubation "+type_id)
			check(s.inventory[item]==0,"incubation consumes one fertile egg")
		else:check(s.ranch.births.size()==1,"one gestation reserved "+type_id)
		var birth:Dictionary=s.ranch.births[0]
		check(str(birth.mother)==str(m.id) and str(birth.father)==str(f.id),"known parents preserved through egg or gestation "+type_id)
		var gestation:int=int(s.system_catalog.ranch.species[type_id].gestation)
		check(int(birth.remaining)==gestation,"authored gestation days retained "+type_id)
		for day:int in gestation:
			s.day+=1;nurture.advance_births(s,s.day-1,false)
		check(s.animals.size()==3 and s.ranch.births.is_empty(),"full birth cycle "+type_id)
		var count:int=s.animals.size();nurture.advance_births(s,s.day-1,false)
		check(s.animals.size()==count,"cross-day duplicate callback safe "+type_id)
		var saved:Dictionary=s._make_save_data().duplicate(true)
		check(s.load_game_data(saved),"family save round trip "+type_id+" "+s.message)
	setup();var old:Dictionary=s._make_save_data().duplicate(true);old.version=34
	check(s.save_game("user://migration-v34.json",true),"save test fixture")
	check(load("res://scripts/save_repository.gd").write("user://migration-v34.json",old),"write v34 fixture")
	check(s.load_game("user://migration-v34.json") and FileAccess.file_exists("user://migration-v34.json.v34-original"),"disk migration preserves original v34 file")
	var fallback:=FileAccess.open("user://fallback-v34.json",FileAccess.WRITE);fallback.store_string("null");fallback.close()
	check(load("res://scripts/save_repository.gd").write("user://fallback-v34.json.bak",old),"write isolated v34 fallback")
	check(s.load_game("user://fallback-v34.json") and FileAccess.file_exists("user://fallback-v34.json.bak.v34-original"),"backup-only v34 recovery preserves original valid backup")
	var baseline:Dictionary=s._make_save_data().duplicate(true);var invalid:Dictionary=baseline.duplicate(true);invalid.ranch.petRecords=[]
	check(not s.load_game_data(invalid) and s._make_save_data()==baseline,"invalid new fields rejected before any mutation")
	var motion:RefCounted=load("res://scripts/animal_behavior.gd").new();var at:=Vector2(100,100);var clock:float=0
	for i:int in 120:
		clock+=1.0/60;at.x+=.5;motion.sample("walk","cow",at,"","right",true,"",false,clock,1.0/60)
	var phase:float=motion.samples.walk.phase
	for i:int in 20:clock+=1.0/60;motion.sample("walk","cow",at,"","right",false,"",false,clock,1.0/60)
	check(is_equal_approx(float(motion.samples.walk.phase),phase) and float(motion.samples.walk.weight)==0,"blocked movement stops phase and settles stance")
	motion.sample("walk","cow",Vector2(900,100),"new-room","up",false,"",false,clock,.01)
	check(is_equal_approx(float(motion.samples.walk.phase),phase),"teleport and room change add no stride")
	setup();var poor:Dictionary={"action":"purchase","arg":["cow","female","local",true]};s.money=0
	var before:Dictionary=s._make_save_data().duplicate(true);var quote:Dictionary=intents.quote(s,poor)
	check(not bool(quote.ok) and s._make_save_data()==before,"quote is read-only and reports money blocker")
	setup();s.ranch.settledDay=-1;var mother:Dictionary=s._ranch_new_animal("cow","female","local",40)
	mother.postpartumUntil=s.day+2;mother.rest=true;mother.progress=0;mother.hunger=100
	var lifecycle:Script=load("res://scripts/ranch_lifecycle.gd")
	for d:int in 2:
		var previous:int=s.day;s.day+=1;mother.hunger=100;mother.clean=100;s.ranch.barns.cattle.clean=100;lifecycle.advance(s,previous,"晴")
		check(float(mother.progress)==0 and bool(mother.rest),"two complete postpartum days pause production "+str(d))
	var previous:int=s.day;s.day+=1;mother.hunger=100;lifecycle.advance(s,previous,"晴")
	check(not bool(mother.rest) and float(mother.progress)>0,"postpartum care automatically resumes production")
	setup();s.inventory.erase("fertileHenEgg");s.storage.erase("fertileHenEgg");s.ranch.eggLineage={};s.ranch.eggStorageLineage={};s.upgrades.storage=true
	var a:Dictionary=s._ranch_new_animal("hen","female","local",40);var b:Dictionary=s._ranch_new_animal("hen","male","local",40)
	check(s.perform_ranch_task({"action":"breed","arg":[a.id,b.id]}),"prepare known fertile egg for storage")
	check(s.economy_transfer("fertileHenEgg",1,true),"deposit fertile egg")
	check(s.load_game_data(s._make_save_data().duplicate(true)),"storage genealogy save roundtrip")
	check(s.economy_transfer("fertileHenEgg",1,false),"withdraw fertile egg")
	check(s.ranch_incubate("hen") and str(s.ranch.births.back().mother)==str(a.id) and str(s.ranch.births.back().father)==str(b.id),"fertile egg keeps known parents after storage and load")
	setup();s.inventory.erase("fertileHenEgg");s.ranch.eggLineage={};s._add_inventory_count("egg",2)
	var snapshot:Dictionary=s._make_save_data().duplicate(true)
	check(not s.ranch_incubate("hen") and s._make_save_data()==snapshot,"food egg cannot incubate or charge")
	setup()
	for i:int in 32:s._ranch_new_animal("cow" if i<10 else "rabbit" if i<18 else "pig" if i<26 else "hen","female","local",40)
	var cash:int=s.money;var total:int=s.animals.size()
	check(not s.perform_ranch_task({"action":"purchase","arg":["hen","female","local",true]}) and s.money==cash and s.animals.size()==total,"full total capacity prevents partial purchase")
	print("RANCH_RELIABILITY: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
