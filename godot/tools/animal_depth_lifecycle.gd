extends SceneTree
var s:Node
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func setup()->void:
	s.animals.clear();s.ranch.births=[];s.ranch.birthHistory=[];s.ranch.products=[];s.ranch.receipts=[];s.ranch.families={};s.ranch.eggLineage={};s.ranch.eggStorageLineage={};s.ranch.meadowAssignments={};s.day=30;s.minutes=600;s.money=10000;s.stamina=100;s.inventory.grainFeed=100
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;s.ranch.barns[id].clean=100;s.ranch.barns[id].comfort=2
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true
	check(int(s._make_save_data().version)==37,"new native version37")
	var species:Script=load("res://scripts/animal_species.gd");var nurture:Script=load("res://scripts/ranch_nurture.gd")
	for type_id:String in ["horse","alpaca","goose"]:
		setup();var price:int=int(s.system_catalog.ranch.species[type_id].cost)
		var task:Dictionary={"action":"purchase","arg":[type_id,"female","local",false],"name":"新伙伴","receipt":"purchase-"+type_id}
		check(s.perform_ranch_task(task),"purchase "+type_id+" "+s.message);check(s.money==10000-price and str(s.animals.back().name)=="新伙伴","one charge and submitted name "+type_id)
		var cash:int=s.money;var count:int=s.animals.size();check(not s.perform_ranch_task(task) and s.money==cash and s.animals.size()==count,"receipt prevents second purchase "+type_id)
		var mother:Dictionary=s.animals[0];mother.age=40;var father:Dictionary=s._ranch_new_animal(type_id,"male","local",40)
		check(s.perform_ranch_task({"action":"breed","arg":[mother.id,father.id],"receipt":"pair-"+type_id}),"actual pair "+type_id+" "+s.message)
		if type_id=="goose":
			check(s.ranch.births.is_empty() and int(s.inventory.get("fertileGooseEgg",0))==1,"goose pair gives egg, never gestation")
			check(s.ranch_incubate(type_id),"fertile goose egg incubation "+s.message)
		check(s.ranch.births.size()==1,"single reserved place "+type_id)
		var days:int=int(s.system_catalog.ranch.species[type_id].gestation)
		for d:int in days:s.day+=1;nurture.advance_births(s,s.day-1,false)
		check(s.animals.size()==3 and s.ranch.births.is_empty(),"complete authored birth days "+type_id)
		check(s.animals.back().parents==[mother.id,father.id] and int(s.animals.back().generation)==1,"parents and generation "+type_id)
		check(s.load_game_data(s._make_save_data().duplicate(true)),"new species family save roundtrip "+type_id+" "+s.message)
		if type_id=="horse":check(s.animals[0].product==null and not species.produces(s,type_id),"horse explicitly has no product")
	setup();check(not s.ranch_incubate("goose"),"ordinary goose egg cannot incubate")
	check(not s.perform_ranch_task({"action":"purchase","arg":["horse","female","productive",false]}),"horse production breed not sold")
	for version:int in [34,35]:
		setup();var old:Dictionary=s._make_save_data().duplicate(true);old.version=version;old.ranch.barns.erase("horseStable");old.ranch.barns.erase("alpacaShelter")
		var old_copy:Dictionary=old.duplicate(true);check(s.load_game_data(old),"old save migrates "+str(version)+" "+s.message)
		check(old==old_copy and s.ranch.barns.has("horseStable") and not bool(s.ranch.barns.horseStable.built),"migration is pure and initializes only new homes")
		var path:String="user://migration-v%d.json"%version;check(load("res://scripts/save_repository.gd").write(path,old),"write isolated migration fixture")
		check(s.load_game(path) and FileAccess.file_exists(path+".v%d-original"%version),"disk original preserved "+str(version))
	setup();var invalid:Dictionary=s._make_save_data().duplicate(true);invalid.ranch.meadowAssignments={"bad":{"pen":10,"slot":0}}
	var before:Dictionary=s._make_save_data().duplicate(true);check(not s.load_game_data(invalid) and s._make_save_data()==before,"invalid new bounds reject atomically")
	print("ANIMAL_DEPTH_LIFECYCLE: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
