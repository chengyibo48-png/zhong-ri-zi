extends SceneTree
var s: Node
var Q: GDScript
var passed:=0
var failed:=0
var deliveries:=0
var expiries:=0
var seasons: Array=[0,0,0,0]
func _initialize() -> void:call_deferred("run")
func check(value: bool,text: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(text)
func finish_action() -> void:
	for frame: int in range(150):
		if not s.action_busy():break
		s._process_action(.1)
	check(not s.action_busy(),"action sequence reaches a real completion")
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("task seasons timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);Q=load("res://scripts/quest_service.gd");s.quests=Q.defaults();s.day=0;s.minutes=480;s.flags.introDone=true;s.current_interior="";s.money=10000;s.ui_open=false;s.economy.claimed=[];s.economy.locked=[]
	Q.sync(s);check(Q.accept(s,"wish:firstDish"),"long-term wish accepted at start")
	var week_defs: Array=[]
	for day: int in range(112):
		check(s.day==day,"real consecutive day "+str(day));s.minutes=480;s.stamina=100
		var candidates: Array=s.economy_weekly_orders();check(candidates.size()==3,"three weekly candidates "+str(day));seasons[s.season_index()]+=candidates.size()
		for order: Dictionary in candidates:check(s.item_catalog.has(str(order.id)) and int(order.qty)>0,"valid actual weekly item "+str(order.key))
		if day%7==0:
			week_defs=[]
			for order: Dictionary in candidates:
				var d: Dictionary=Q.weekly_definition(s,order);check(Q.accept(s,str(d.id)),"explicit accept "+str(d.id));week_defs.append(d.duplicate(true))
			var first: Dictionary=week_defs[0];var item: String=first.order.id
			s.inventory[item]=0;s.quality[item]=[0,0,0];s._reconcile_kitchen_lots();s._grant_legacy_item(item,int(first.order.qty));s._reconcile_kitchen_lots()
			if int(first.order.grade)>0:
				var ledger: Array=[0,0,0];ledger[int(first.order.grade)-1]=int(first.order.qty);s.quality[item]=ledger
			var at: Dictionary=Q.target(s,first);check(not at.is_empty(),"actual cooperative counter reachable")
			s.player_position=Vector2(float(at.x),float(at.y));var before: int=s.money
			check(s.quest_submit(str(first.id)),"on-site annual order action");finish_action()
			check(s.money>before and s.economy.claimed.has(str(first.ref)),"annual order paid once");deliveries+=int(s.money>before)
			var paid: int=s.money;check(not s.fulfill_economy_order(str(first.ref)) and s.money==paid,"annual order repeated callback rejected")
		for d: Dictionary in week_defs:
			check(Q.definition(s,str(d.id)).order==d.order,"accepted annual conditions unchanged "+str(d.id))
		check(str(Q.snapshot(s,Q.definition(s,"wish:firstDish")).status) in ["active","ready"],"long-term task never expires "+str(day))
		if day%7==6:
			var snapshot: Dictionary=s._make_save_data().duplicate(true)
			check(s.load_game_data(snapshot),"weekly current-format save "+str(day))
		s.advance_day()
		if day%7==6:
			for d: Dictionary in week_defs.slice(1):
				check(str(Q.snapshot(s,Q.definition(s,str(d.id))).status)=="expired","unfulfilled order expires precisely "+str(d.id));expiries+=1
		if day%14==0:await process_frame
	check(deliveries==16 and expiries==32,"sixteen weeks of fulfilled and expired contracts")
	check(seasons.all(func(value: int):return value==84),"all four seasons retain available objectives")
	check(s.quests.entries.has("wish:firstDish") and str(Q.snapshot(s,Q.definition(s,"wish:firstDish")).status)!="expired","year-end does not invalidate long-term wish")
	var f:=FileAccess.open("res://artifacts/ui-quests-20261017/seasons-report.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"failed":failed,"days":112,"acceptedOrders":48,"deliveredOrders":deliveries,"expiredOrders":expiries,"seasonCandidateDays":seasons,"method":"Actual advance_day and action settlement; deterministic supplied order materials."},"  "))
	print("UI quest 112 days: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
