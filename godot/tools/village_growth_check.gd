extends SceneTree
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_warning(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	var s:Node=root.get_node("GameState")
	s.quest_runtime.set_process(false);s.autosave_coordinator.pending=false;s.set_process(false)
	check(s.quests.version==3,"new game task v3")
	var snapshot:Dictionary=s._make_save_data().duplicate(true)
	check(snapshot.version==38,"save v38")
	check(preload("res://scripts/native_save_rules.gd").error(snapshot,s.initial_state,s.world_village.get("offsets",{}))=="","snapshot schema roundtrip")
	var farm:Dictionary=s.farm.duplicate(true);var museum:Dictionary=s.collection.duplicate(true)
	for i:int in 10:s._make_save_data()
	check(farm==s.farm and museum==s.collection,"snapshot read-only")
	var old:Dictionary=snapshot.duplicate(true);old.version=37
	check(not s.load_game_data(old),"reject previous save without mutation")
	check(s.money==snapshot.money,"rejected save preserves state")
	for chapter:Dictionary in preload("res://scripts/quest_model.gd").CHAPTERS:check(chapter.goals.size()==5,"five life choices")
	var orders:Array=s.economy_weekly_orders();s.inventory["wood"]=31
	check(orders==s.economy_weekly_orders(),"board immutable on inventory change")
	check(orders.size()==3,"three daily demands")
	var before:Dictionary=s._make_save_data().duplicate(true)
	s.transactions.submit("test-failure",func():s.money-=10;return false)
	check(s.money==before.money,"rejected preparation restores money")
	var money:int=s.money
	check(s.transactions.submit("test-success",func():s.money+=1;return true),"accept durable commit")
	check(s.money==money and s.transactions.busy(),"not visible until durable")
	check(s.transactions.submit("test-success",func():s.money+=999;return true),"duplicate pending shares transaction")
	await s.wait_for_saves()
	check(s.money==money+1 and not s.transactions.busy(),"apply durable result once")
	var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(s.SAVE_PATH))
	check(disk.money==s.money,"durable money matches memory")
	var version:int=int(disk.quests.version)
	check(version==3,"durable quest version")
	# Time partition invariance includes 200 ms frames; old simulation discarded half.
	var plan:Dictionary={"mode":"standard","wait":2.0,"seed":17,"depth":1,"difficulty":30,"movement":"mixed","speed":1.0}
	var reference:Dictionary={}
	for hz:int in [5,15,30,60,120]:
		var session:=preload("res://scripts/fishing_session.gd").new();session.start(plan,{})
		session.transition("fight");session.game.holding=true
		for i:int in hz*2:session.tick(1.0/hz)
		if reference.is_empty():reference=session.snapshot()
		check(absf(float(session.game.time)-2.0)<.00001,"fish admits all time %d"%hz)
		for field:String in ["tension","stamina","distance","safe","total"]:check(absf(float(reference[field])-float(session.game[field]))<.00001,"partition "+field+str(hz))
	var original:Dictionary=s.quests.duplicate(true)
	s.quests.metrics={};s.quests.seen=[]
	for i:int in [0,1,0]:load("res://scripts/quest_service.gd").event(s,"fieldCare:"+str(i),"field-care:"+str(i))
	check(load("res://scripts/quest_service.gd").metric(s,"fertilizePlots")==2,"field care counts distinct plots, never repeated watering")
	load("res://scripts/quest_service.gd").event(s,"fieldCare:2","field-care:2")
	check(load("res://scripts/quest_service.gd").metric(s,"fertilizePlots")==3,"three actual tended plots satisfy chapter goal")
	s.quests=original
	var products:Script=load("res://scripts/ranch_products.gd")
	if not s.ranch.products.is_empty():
		var id:String=str(s.ranch.products[0].id);var previous:int=load("res://scripts/quest_service.gd").metric(s,"animalProduce")
		var count:int=products.take(s,"product",id)
		check(count>0 and load("res://scripts/quest_service.gd").metric(s,"animalProduce")==previous+count,"nest pickup advances animal output goal")
		check(products.take(s,"product",id)==0 and load("res://scripts/quest_service.gd").metric(s,"animalProduce")==previous+count,"repeated product pickup cannot duplicate goal")
	var result:Dictionary={"checks":checks,"failures":failures}
	var output:String=OS.get_environment("ZRZ_ART_OUTPUT")
	if output!="":var file:=FileAccess.open(output+"/village-growth-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
