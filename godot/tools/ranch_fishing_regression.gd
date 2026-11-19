extends SceneTree
var s:Node
var passed:=0
var failed:=0
var sounds:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func prepare()->void:
	s.cancel_player_action();s.ui_open=false;s.current_interior="";s.fishing_focus_paused=false;s.stamina=100;s.minutes=600;s.fishing.pending={}
	var point:Dictionary=s.system_catalog.fishing.spots[0];s.player_position=Vector2(float(point.x),float(point.y))
func step(seconds:float)->void:
	for i:int in ceili(seconds*60):s._process_action(1.0/60.0)
func landed()->void:
	s.fishing_input("press");step(.1);s.fishing_input("release");step(.6)
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	check(OS.get_user_data_dir().replace("\\","/").begins_with(OS.get_environment("TEMP").replace("\\","/")+"/"),"isolated storage")
	s.sound_requested.connect(func(kind:String):sounds.append(kind))
	prepare();s.fishing.bait="plain";s.fishing.mode="standard";s.fishing.tutorialDone=true
	var point:Dictionary=s.system_catalog.fishing.spots[0]
	var initial:int=int(s.fishing.nextId)
	check(s.begin_fishing(str(point.id)),"cast starts on real bank")
	s.fishing_input("press","mouse");step(.2);s.cancel_player_action()
	check(s.stamina==100 and s.minutes==600 and int(s.fishing.nextId)==initial,"cancel before landing pays nothing")
	prepare();check(s.begin_fishing(str(point.id)),"restart cast")
	var serial:int=int(s.fishing.nextId);var cost:int=s.fishing_energy_cost();sounds.clear();landed()
	check(int(s.stamina)==100-cost and s.minutes==625 and int(s.fishing.nextId)==serial+1,"landing pays original costs once")
	var stamina:float=s.stamina;var minutes:float=s.minutes
	load("res://scripts/fishing_service.gd").commit_cast(s,s.fishing_session.game)
	check(s.stamina==stamina and s.minutes==minutes,"duplicate landing callback cannot pay again")
	check(sounds.count("soft")==1 and sounds.count("water")==1,"one cast and one water feedback event")
	s.cancel_player_action();check(int(s.fishing.settled)>=serial and s.stamina==stamina,"paid cancellation keeps original costs and consumes session identity")
	prepare();s.begin_fishing(str(point.id));s.fishing_input("press","mouse");step(.1)
	s.fishing_input("press","pad");check(s.fishing_session.game.inputOwner=="pad" and bool(s.fishing_session.game.holding),"device switch establishes new owner")
	s.fishing_input("release","mouse");check(bool(s.fishing_session.game.holding),"old mouse release cannot interrupt pad input")
	s.fishing_input("clear");check(not bool(s.fishing_session.game.holding),"pause clear drops held state")
	s.fishing_input("release","pad");check(s.fishing_session.game.stage=="charge","release after clear cannot launch")
	s.cancel_player_action()
	prepare();s.begin_fishing(str(point.id));landed()
	var completed_game:Dictionary=s.fishing_session.game
	var balance_time:float=0;var fought:=false;var ratio:float=0
	for frame:int in 4000:
		if not s.fishing_active():break
		var g:Dictionary=s.fishing_session.game
		if g.stage=="bite":s.fishing_input("press")
		if g.stage=="fight":
			fought=true;balance_time=float(g.total);ratio=float(g.safe)/maxf(.001,float(g.total))
			var surge:bool=str(g.fishPhase) in ["charge","surge"]
			if bool(g.holding) and (float(g.tension)>=68 or surge and float(g.tension)>=50):s.fishing_input("release")
			elif not bool(g.holding) and (float(g.tension)<=24 or float(g.tension)<=35 and not surge):s.fishing_input("press")
		s._process_action(1.0/60)
	check(fought and not s.fishing.pending.is_empty(),"actual action clock produces pending catch")
	check(balance_time>5 and ratio>.9,"quality uses only real fight safe time")
	check(sounds.count("fish")==1,"bite feedback happens once per session")
	var pending:Dictionary=s.fishing.pending.duplicate(true);var id:String=str(pending.fish)
	load("res://scripts/fishing_service.gd").finish(s,completed_game)
	check(s.fishing.pending==pending,"duplicate finish callback cannot replace pending result")
	var prior:int=int(s.inventory.get(id,0));s.inventory[id]=999999
	check(not s.fishing_resolve(false) and s.fishing.pending==pending,"full inventory retains pending fish")
	s.inventory[id]=prior
	var saved:Dictionary=s._make_save_data().duplicate(true)
	check(int(saved.version)==35 and s.load_game_data(saved) and not s.fishing.pending.is_empty(),"v35 pending fish round trip without live session")
	var count:int=int(s.fishing.records.get(id,{}).get("count",0))
	check(s.fishing_resolve(false) and int(s.inventory[id])==prior+1,"keep awards exactly one fish")
	check(not s.fishing_resolve(false) and int(s.fishing.records[id].count)==count+1,"duplicate resolution cannot grant or record twice")
	# Standard pause must freeze the model and clear ownership, not merely hide the meter.
	prepare();s.begin_fishing(str(point.id));landed();var g:Dictionary=s.fishing_session.game
	var elapsed:float=g.time;s.fishing_focus_paused=true;s._process_action(.1)
	check(float(g.time)==elapsed and not bool(g.holding),"focus pause freezes all session clocks")
	s.fishing_focus_paused=false;s.cancel_player_action()
	prepare();s.fishing.bait="herb";s.inventory.herbBait=1
	check(s.begin_fishing(str(point.id)),"prepared baited cast can start")
	s.fishing_input("press");step(.1);s.fishing_input("release");s.inventory.herbBait=0
	var next_id:int=int(s.fishing.nextId);step(.7)
	check(not s.fishing_active() and s.stamina==100 and s.minutes==600 and int(s.fishing.nextId)==next_id,"bait removed before landing aborts without partial payment")
	prepare();s.fishing.bait="plain";s.begin_fishing(str(point.id));landed()
	var toolkit:Dictionary=s.toolkit.duplicate(true);var paid_stamina:float=s.stamina
	for frame:int in 2000:
		if not s.fishing_active():break
		var failure_game:Dictionary=s.fishing_session.game
		if failure_game.stage=="bite":s.fishing_input("press")
		s._process_action(.04)
	check(s.fishing.last.reason=="鱼线张力过高" and s.toolkit==toolkit and s.stamina==paid_stamina,"line break never charges equipment or extra stamina")
	prepare();s.begin_fishing(str(point.id));landed();s.current_interior="home-an";s._process_action(.1)
	check(not s.fishing_active() and s.fishing.pending.is_empty(),"room transition cancels paid session without a catch")
	print("FISHING_TRANSACTIONS: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
