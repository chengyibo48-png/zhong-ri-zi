extends SceneTree
var s: Node
var Q: GDScript
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, text: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(text)
func reset() -> void:
	s.cancel_action(false);s.quests=Q.defaults();s.flags={};s.day=0;s.minutes=480;s.money=10000;s.stamina=100;s.current_interior="";s.player_stats={};s.inventory=s._new_inventory();s.quality={};s.kitchen=s.initial_state.kitchen.duplicate(true);s.fishing=s.initial_state.fishing.duplicate(true);s.community_projects={};s.season_events={};s.legacy_chapters={};Q.sync(s)
func finish_action() -> void:
	for frame: int in range(150):
		if not s.action_busy():break
		s._process_action(.1)
	check(not s.action_busy(),"action sequence reaches a real completion")
func run() -> void:
	create_timer(140,true,false,true).timeout.connect(func():push_error("quest rules timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);Q=load("res://scripts/quest_service.gd");reset()
	check(Q.guides().size()==40,"40 actual guide definitions")
	var chain_counts: Dictionary={}
	for d: Dictionary in Q.guides():
		chain_counts[str(d.chain)]=int(chain_counts.get(str(d.chain),0))+1
		check(not str(d.text).is_empty() and not str(d.metric).is_empty(),"configured objective "+str(d.id))
		for item: String in d.reward:check(s.item_catalog.has(item),"real guide reward "+item)
	check(chain_counts=={"home":6,"farm":6,"ranch":5,"fish":5,"cook":5,"neighbor":5,"village":4,"memory":4},"eight chain node counts")
	check(str(Q.snapshot(s,Q.definition(s,"guide:home:bag")).status)=="active","tutorial starts")
	check(Q.event(s,"visit:bag","same-ui-event"),"first input event accepted")
	check(not Q.event(s,"visit:bag","same-ui-event") and int(s.quests.metrics["visit:bag"])==1,"duplicate input event not counted")
	check(Q.claim(s,"guide:home:bag"),"completed objective acknowledged")
	check(not Q.claim(s,"guide:home:bag"),"no duplicate acknowledgement")
	check(s.quests.entries.has("guide:home:tools"),"next chain step activates")
	check(not Q.accept(s,"guide:home:map"),"locked future node cannot be accepted")
	check(Q.pin(s,"guide:home:tools") and Q.pin(s,"guide:farm:seed") and Q.pin(s,"guide:ranch:home") and s.quests.pins.size()==2,"only two HUD pins")
	check(Q.metric(s,"sow")==0,"preplanted starter crops are not a personal sowing record")
	# Actual ownership is not an action record.
	s.inventory.fish=10
	check(Q.metric(s,"rodCatch")==0,"buying fish cannot create a catch")
	s.quests.entries["guide:fish:prepare"]={"status":"completed","acceptedDay":0,"deadline":-1}
	s.fishing.records.fish={"rod":3,"trap":0,"count":3}
	check(Q.accept(s,"guide:fish:catch"),"accept post-accept catch objective")
	check(int(Q.snapshot(s,Q.definition(s,"guide:fish:catch")).current)==0,"preexisting catch excluded from after-accept objective")
	s.fishing.records.fish.rod=4
	check(str(Q.snapshot(s,Q.definition(s,"guide:fish:catch")).status)=="reward","genuine new catch advances")
	# Material readiness is live, respects quality/locks and freshness.
	reset();s.inventory.greens=1;s._reconcile_kitchen_lots()
	check(Q.accept(s,"wish:firstDish"),"accept real neighbor wish")
	check(str(Q.snapshot(s,Q.definition(s,"wish:firstDish")).status)=="ready","material readiness")
	s.inventory.greens=0
	check(str(Q.snapshot(s,Q.definition(s,"wish:firstDish")).status)=="active","consumed material clears readiness")
	s.inventory.greens=1;s.economy.locked=["greens"]
	check(Q.qualified(s,"greens")==0,"protected ingredients excluded")
	s.economy.locked=[];s._reconcile_kitchen_lots()
	for lot: Dictionary in s.kitchen.lots.bag.greens:lot.age=999
	check(Q.qualified(s,"greens")==0,"spoiled food excluded")
	# Remote calls cannot consume or pay out.
	s.kitchen.lots.bag.greens=[];s._reconcile_kitchen_lots();s.player_position=Vector2.ZERO;s.npc_positions.granny=Vector2(2600,2000)
	var money: int=s.money;var food: int=s.inventory.greens
	check(not s.fulfill_legacy_order("firstDish") and s.money==money and s.inventory.greens==food,"remote legacy delivery blocked atomically")
	s.player_position=s.npc_positions.granny;s.inventory.beanSeed=999999
	check(not s.fulfill_legacy_order("firstDish") and s.inventory.greens==food,"full reward bag blocks before deduction")
	s.inventory.beanSeed=0
	check(s.fulfill_legacy_order("firstDish"),"on-site existing wish settles through original domain")
	check(not s.fulfill_legacy_order("firstDish") and s.money==money+60,"existing wish cannot pay twice")
	# Weekly acceptance saves the entire order and enforces exact midnight boundary.
	reset();s.day=6
	var d: Dictionary=Q.weekly_definition(s,s.economy_weekly_orders()[0]);var id: String=d.id
	check(Q.accept(s,id),"explicit weekly acceptance")
	var fixed: Dictionary=Q.definition(s,id).order.duplicate(true)
	s.day=7
	check(Q.definition(s,id).order==fixed,"refresh never rewrites accepted conditions")
	check(str(Q.snapshot(s,Q.definition(s,id)).status)=="expired" and Q.accepted_order(s,str(d.ref)).is_empty(),"deadline midnight expires without consuming")
	check(not Q.accept(s,id) and not Q.claim(s,id),"expired contract cannot be revived or awarded")
	reset();d=Q.weekly_definition(s,s.economy_weekly_orders()[0]);id=str(d.id);Q.accept(s,id)
	check(Q.abandon(s,id) and not Q.accept(s,id),"abandon is final for this weekly instance")
	# Current disk snapshot, invalid payload and event replay.
	reset();Q.event(s,"water","water-event-1");Q.accept(s,"wish:firstDish")
	var snapshot: Dictionary=s._make_save_data().duplicate(true)
	check(int(snapshot.version)==33 and Q.validate(snapshot.quests,s.day),"current task schema validates")
	check(s.load_game_data(snapshot),"current native round trip")
	check(not Q.event(s,"water","water-event-1"),"replayed event after load not counted")
	check(s.save_game("user://ui-quest-current.json",true) and s.load_game("user://ui-quest-current.json"),"current task disk save/load")
	var invalid: Dictionary=s._make_save_data().duplicate(true);invalid.quests.pins=["a","b","c"]
	check(not s.load_game_data(invalid),"invalid oversized pins rejected")
	invalid=s._make_save_data().duplicate(true);invalid.quests.metrics.water=-1
	check(not s.load_game_data(invalid),"negative task counters rejected")
	# Only eligible fresh quality lots are removed; production day is conserved.
	reset();s.inventory.milk=5;s.quality.milk=[0,2,0];s.kitchen.lots.bag.milk=[{"qty":3,"age":100,"grade":0,"producedDay":0},{"qty":2,"age":1,"grade":2,"producedDay":0}]
	check(Q.qualified(s,"milk",2)==2,"quality-specific fresh count")
	check(Q.consume(s,"milk",1,2,true)==[0,0,1,0],"consume exact eligible quality")
	check(s.inventory.milk==4 and s.quality.milk==[0,1,0] and int(s.kitchen.lots.bag.milk[0].qty)==3 and int(s.kitchen.lots.bag.milk[-1].producedDay)==0,"quantity quality and production-date conservation")
	# Action cancellation and shortages at commit never deduct material or pay out.
	reset();s.inventory.greens=1;s._reconcile_kitchen_lots();s.npc_positions.granny=Vector2(2600,2000);s.player_position=s.npc_positions.granny;Q.accept(s,"wish:firstDish")
	check(s.quest_submit("wish:firstDish"),"delivery enters real action sequence")
	var stale_commit: Callable=s.action_sequence.active.commit
	check(s.cancel_action() and s.inventory.greens==1 and not bool(s.flags.get("firstDish",false)),"cancel keeps all uncommitted material")
	stale_commit.call()
	check(s.inventory.greens==1 and not bool(s.flags.get("firstDish",false)) and s.quest_action.is_empty(),"captured stale callback cannot commit a cancelled delivery")
	check(s.quest_submit("wish:firstDish"),"delivery can restart")
	s.inventory.greens=0;finish_action()
	check(not bool(s.flags.get("firstDish",false)) and s.money==10000,"shortage at action completion stops settlement")
	reset();s.quests.entries["guide:home:plans"]={"status":"completed","acceptedDay":0,"deadline":-1};Q.accept(s,"guide:home:help");Q.event(s,"visit:help");s.inventory.cabbageSeed=999999
	check(not Q.claim(s,"guide:home:help") and str(Q.snapshot(s,Q.definition(s,"guide:home:help")).status)=="reward","full inventory retains earned guide reward")
	s.inventory.cabbageSeed=0
	check(Q.claim(s,"guide:home:help") and s.inventory.cabbageSeed==2 and not Q.claim(s,"guide:home:help"),"reward later claimed exactly once")
	# Every configured guide has a real route, including all four construction sites.
	reset();s.player_position=Vector2(2690,2000)
	for guide: Dictionary in Q.guides():
		var target: Dictionary=Q.target(s,guide)
		check(not target.is_empty(),"real reachable task source "+str(guide.id))
	var file:=FileAccess.open("res://artifacts/ui-quests-20261017/rules-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"guideNodes":40,"chains":8},"  "))
	print("UI quest rules: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
