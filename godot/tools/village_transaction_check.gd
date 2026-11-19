extends SceneTree
const G=preload("res://scripts/village_growth.gd")
var Q:Script
var passed:int=0
var failed:Array[String]=[]
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed.append(label);print("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	Q=load("res://scripts/quest_service.gd")
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.autosave_coordinator.pending=false
	# Real filesystem failure: a directory occupies the temporary file name.
	var denied:String=ProjectSettings.globalize_path("user://denied.json")
	DirAccess.make_dir_recursive_absolute(denied+".tmp")
	var money:int=s.money;var receipts:Dictionary=s.commit_log.duplicate(true)
	s.transactions.submit("io-denied",func():s.money-=10;return true)
	s.autosave_coordinator.commits[0].path=denied
	await s.wait_for_saves()
	check(s.money==money and s.commit_log==receipts,"failed write restores money and receipt")
	check(int(s.transactions.metrics.failed)==1,"real failed write reported")
	s.autosave_coordinator.inline_for_tests=true
	# The following are domain fixtures, not balance playthroughs.
	s.minutes=660;s.day=0;s.current_interior="";s.money=10000;s.stamina=100
	for i:int in 4:
		var id:String=G.ORDER[i];s.quests.journey={"chapter":i,"stage":2};s.player_position=G.SITES[id]
		var m:int=s.money;var time:float=s.minutes
		check(s.growth_action(id,"survey"),"survey "+id)
		check(s.minutes==time+5 and s.money==m,"survey exact cost "+id)
		check(not s.growth_action(id,"survey"),"survey no duplicate "+id)
		check(G.phase(s,id)=="materials","survey advances material phase "+id)
		s.inventory.wood=3;s.inventory.bamboo=0;s.quality.wood=[0,0,0]
		check(s.growth_action(id,"contribute",{"wood":1}),"partial material "+id)
		check(s.inventory.wood==2 and G.project(s,id).supplied.wood==1,"partial exact deduction "+id)
		s.economy.locked.append("wood")
		check(not s.growth_action(id,"contribute",{"wood":1}),"protected material "+id)
		s.economy.locked.erase("wood")
		var q:Dictionary=G.quote(s,id,"procure");var bag:Dictionary=s.inventory.duplicate(true);m=s.money;time=s.minutes
		check(int(q.money)>0 and s.growth_action(id,"procure"),"procure missing materials "+id)
		check(s.money==m-int(q.money) and s.inventory==bag and s.minutes==time,"procurement pays once, never grants bag "+id)
		check(not s.growth_action(id,"procure"),"no duplicate procurement "+id)
		check(not s.growth_action(id,"collaborate"),"actual collaborator required "+id)
		var npc:String=str(s.content.projects[id].npc);s.npc_positions[npc]=s.player_position+Vector2(20,0)
		var energy:float=s.stamina;time=s.minutes
		check(s.growth_action(id,"collaborate"),"on-site collaboration "+id)
		check(s.stamina==energy-4 and s.minutes==time+10,"collaboration exact cost "+id)
		check(not s.growth_action(id,"collaborate"),"no duplicate completion "+id)
		check(G.phase(s,id)=="firstUse","visible first use pending "+id)
		check(s.growth_action(id,"use") and G.phase(s,id)=="complete","first facility use "+id)
		check(not s.growth_action(id,"use"),"first use once "+id)
		var snapshot:Dictionary=s._make_save_data().duplicate(true)
		check(G.save_valid(snapshot) and Q.validate(snapshot.quests,s.day),"project checkpoint validates "+id)
		s.npc_positions.clear()
	# Orders are voluntary and capped at two simultaneous, with frozen definitions.
	s.quests=Q.defaults()
	var board:Array=s.economy_weekly_orders()
	check(s.quest_accept("weekly:"+str(board[0].key)),"accept first demand")
	check(s.quest_accept("weekly:"+str(board[1].key)),"accept second demand")
	check(not s.quest_accept("weekly:"+str(board[2].key)),"cannot accept third concurrent demand")
	check(Q.validate(s.quests,s.day),"daily deadline validates")
	var before_money:int=s.money;var before_bag:Dictionary=s.inventory.duplicate(true)
	s.day+=2
	check(str(Q.snapshot(s,Q.definition(s,"weekly:"+str(board[0].key))).status)=="expired","cross-day expiry")
	check(s.money==before_money and s.inventory==before_bag,"expiry does not confiscate anything")
	# Dish and meeting contact are authoritative; no proximity means no meal.
	s.minutes=660;s.inventory.greens=1;s.quality.greens=[0,0,0];s.economy.locked=[]
	check(not s.village_activity("meal","granny"),"cannot share with absent resident")
	s.npc_positions.granny=s.player_position+Vector2(10,0)
	check(s.village_activity("meal","granny"),"share real fresh dish")
	check(int(s.inventory.greens)==0 and Q.metric(s,"sharedMeal")==1,"dish consumed once, goal recorded")
	check(not s.village_activity("meal","granny"),"no empty meal loop")
	var final:Dictionary=s._make_save_data().duplicate(true)
	check(preload("res://scripts/native_save_rules.gd").error(final,s.initial_state,s.world_village.get("offsets",{}))=="","full transaction save validates")
	var output:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/village-transaction-check.json",FileAccess.WRITE);output.store_string(JSON.stringify({"passed":passed,"failed":failed,"note":"Domain fixtures; not normal progression/balance evidence"},"\t"))
	print("TRANSACTIONS ",passed," passed / ",failed)
	await root.get_node("AudioService").prepare_exit();quit(0 if failed.is_empty() else 1)
