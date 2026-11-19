extends SceneTree
var s:Node
var Q:Script
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func finish()->void:
	for i:int in 100:
		if not s.action_busy():break
		s._process_action(.1)
func prepare()->void:
	s.cancel_action(false);s.quests=Q.defaults();s.quest_runtime.reset();s.current_interior="";s.day=0;s.minutes=600;s.money=10000
	s.player_position=Vector2(2500,1800);s.npc_positions.granny=s.player_position;s.flags.firstDish=false
	s.inventory.greens=1;s.inventory.beanSeed=0;s.economy.locked=[];s.kitchen.lots.bag.greens=[];s._reconcile_kitchen_lots();Q.accept(s,"wish:firstDish")
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);Q=load("res://scripts/quest_service.gd")
	prepare();var cash:int=s.money
	check(s.quest_submit("wish:firstDish"),"on-site handoff action starts")
	s.cancel_action(false);finish();check(s.inventory.greens==1 and s.money==cash and not s.flags.firstDish,"cancel leaves all materials and rewards")
	prepare();check(s.quest_submit("wish:firstDish"),"start moving-target handoff")
	s.npc_positions.granny+=Vector2(400,0);finish();check(s.inventory.greens==1 and s.money==cash,"target moving away blocks final commit")
	prepare();check(s.quest_submit("wish:firstDish"),"start stale-material handoff")
	for lot:Dictionary in s.kitchen.lots.bag.greens:lot.age=999
	finish();check(s.inventory.greens==1 and s.money==cash,"food spoiling during action never partially settles")
	prepare();check(s.quest_submit("wish:firstDish"),"start protected-material handoff")
	s.economy.locked=["greens"];finish();check(s.inventory.greens==1 and s.money==cash,"new protection during action blocks deduction")
	prepare();check(s.quest_submit("wish:firstDish"),"start reward-capacity handoff")
	s.inventory.beanSeed=999999;finish();check(s.inventory.greens==1 and s.money==cash,"reward capacity revalidated before material deduction")
	prepare();check(s.quest_submit("wish:firstDish"),"start successful action")
	finish();var paid:int=s.money;check(s.flags.firstDish and s.inventory.greens==0 and paid>cash,"action settles actual commissioned goods once")
	check(not s.quest_submit("wish:firstDish") and s.money==paid,"duplicate handoff cannot settle again")
	prepare();s.day=6;s.minutes=1190
	var d:Dictionary=Q.weekly_definition(s,s.economy_weekly_orders()[0]);Q.accept(s,str(d.id))
	s.inventory[str(d.order.id)]=int(d.order.qty);s.economy.locked=[]
	if int(d.order.grade)>0:s.quality[str(d.order.id)]=[0,0,int(d.order.qty)]
	s._reconcile_kitchen_lots();s.day=7;var material:int=int(s.inventory[str(d.order.id)])
	check(not Q.submit(s,str(d.id)) and int(s.inventory[str(d.order.id)])==material and s.money==10000,"midnight expiration has no material or money penalty")
	# Blocker diagnostics are independent and getter-only.
	prepare();var wish:Dictionary=Q.definition(s,"wish:firstDish")
	s.economy.locked=["greens"];var protected_view:Dictionary=Q.snapshot(s,wish)
	check(str(protected_view.blockers[0].kind)=="protected","structured protected reason")
	s.economy.locked=[];s.inventory.greens=0
	check(str(Q.snapshot(s,wish).blockers[0].kind)=="quantity","structured missing quantity reason")
	s.inventory.greens=1;s._reconcile_kitchen_lots()
	for lot:Dictionary in s.kitchen.lots.bag.greens:lot.age=999
	check(str(Q.snapshot(s,wish).blockers[0].kind)=="freshness","structured stale food reason")
	prepare();s.npc_stories.granny={"step":1,"choices":[0],"lastDay":0};s.relations.granny.points=10
	check(s.start_npc_story_activity("granny"),"cooperation begins")
	s.cancel_action(false);check(int(s.quests.metrics.get("storyActivity:granny:1",0))==0,"cancelled cooperation is not counted")
	check(s.start_npc_story_activity("granny"),"cooperation restart")
	s.npc_positions.granny+=Vector2(400,0);finish()
	check(int(s.quests.metrics.get("storyActivity:granny:1",0))==0,"cooperator leaving does not count the action")
	prepare()
	for item:String in ["compost","pickles","driedFish"]:
		var prior:int=int(s.quests.metrics.get("preserve",0))
		s.kitchen.jobs=[{"key":900,"id":item,"qty":1,"grade":0,"ready":0,"station":"pickle" if item=="pickles" else "dry" if item=="driedFish" else "compost","cooking":item=="pickles"}]
		check(s.collect_kitchen_job(900),"collect real processing result "+item)
		check(int(s.quests.metrics.get("preserve",0))-prior==(0 if item=="compost" else 1),"preservation distinguishes food and compost "+item)
	# Reject malformed new task state and preserve old files through startup/manual paths.
	var valid:Dictionary=s._make_save_data().duplicate(true)
	for bad:Variant in [null,"bad",[],{"chapter":1.5,"stage":0},{"chapter":4,"stage":2}]:
		var broken:Dictionary=valid.duplicate(true);broken.quests.journey=bad
		check(not Q.validate(broken.quests,s.day),"malformed chapter state rejected")
	var old:Dictionary=valid.duplicate(true);old.version=33;old.quests.version=1
	var repository:Script=load("res://scripts/save_repository.gd")
	check(repository.write(s.SAVE_PATH,old),"write isolated old-version fixture")
	var original:String=FileAccess.get_file_as_string(s._save_path_absolute(s.SAVE_PATH))
	check(not s.load_game() and s.incompatible_save,"old default slot enters protected state")
	s.request_autosave();s._queue_autosave();check(not s.save_game(),"manual default save is blocked while protected")
	check(FileAccess.get_file_as_string(s._save_path_absolute(s.SAVE_PATH))==original,"old default file bytes unchanged")
	check(s.start_new_game(),"explicit new game establishes a new valid slot")
	var backup:Variant=repository.read(s._save_path_absolute("user://zhenrizhi_godot_backup.json"))
	check(backup is Dictionary and int(backup.version)==33,"explicit new game preserves original old progress in backup")
	check(not s.incompatible_save and int(s._make_save_data().version)==36,"new game exits protection with new task version")
	print("QUEST_SAFETY: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
