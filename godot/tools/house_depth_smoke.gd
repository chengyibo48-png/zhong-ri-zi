extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;print("CHECK_FAIL ",label)
func finish(s:Node)->void:
	for step:int in 30:s._process_action(.1)
func run()->void:
	var temp:String=OS.get_environment("TEMP").replace("\\","/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp):quit(1);return
	create_timer(130).timeout.connect(func():quit(1))
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true
	var g:Script=load("res://scripts/house_geometry.gd");var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(s)
	check(g.all().size()==48,"48 configured houses")
	var inventory:Dictionary=s.inventory.duplicate(true);var money:int=s.money;var stamina:float=s.stamina;var stories:Dictionary=s.npc_stories.duplicate(true)
	for room:String in g.all():
		s.current_interior=room;s.interior_position=g.spawn(room)
		check(not nav.blocked(s,room,s.interior_position.x,s.interior_position.y),"entry clear "+room)
		var layout:Dictionary=s.system_catalog.interiors.layouts.get(room,{})
		for point:Dictionary in layout.get("points",[])+g.points(room):
			var goal:Dictionary=nav.safe(s,room,{"x":float(point.x),"y":float(point.y)})
			check(Vector2(goal.x,goal.y).distance_to(Vector2(float(point.x),float(point.y)))<=60,"stand near actual point "+room+"/"+str(point.get("id","")))
			check(not nav.route(s,room,{"x":480.0,"y":567.0},goal).is_empty(),"reachable "+room+"/"+str(point.get("id",""))+" "+str(goal))
		var config:Dictionary=g.profile(room);var owner:String=str(config.owner)
		if owner=="":continue
		var work:Dictionary=load("res://scripts/resident_life.gd").station(s,owner,room,{"key":"morning"},-float(load("res://scripts/resident_life.gd").profile(owner).phase))
		var point:Dictionary=g.points(room)[0]
		check(not work.is_empty() and Vector2(work.x,work.y).distance_to(Vector2(point.x,point.y))<45,"real resident work station shares activity contact "+owner)
		s.interior_position=Vector2(float(point.x),float(point.y));s.interior_npc_positions={owner:Vector2(float(point.x)-28,float(point.y))};s.minutes=660
		var before:int=int(s.relations[owner].points)
		var session:Dictionary=s.house_activity.start(s,point)
		check(session.has("token"),"begin "+owner)
		if not session.has("token"):continue
		var token:int=int(session.token)
		check(s.house_activity.input(s,token,0),"material "+owner)
		check(not s.house_activity.input(s,token,.02),"misaligned does not progress "+owner)
		check(s.house_activity.input(s,token,float(config.steps[1].target)),"align "+owner)
		check(s.house_activity.input(s,token,1),"place "+owner)
		check(s.house_activity.finish(s,token),"animation starts "+owner)
		check(s.minutes==660 and int(s.relations[owner].points)==before,"no early settlement "+owner)
		finish(s)
		check(s.minutes==670 and int(s.relations[owner].points)==mini(100,before+1),"single settlement "+owner)
		check(not s.house_activity.finish(s,token),"repeat completion rejected "+owner)
		check(s.interior_state.household.receipts.has(room+":theme"),"persistent keepsake "+owner)
	check(s.money==money and s.inventory==inventory and s.stamina==stamina and s.npc_stories==stories,"activities preserve economy, stamina and 104-node stories")
	check(s.save_game(OS.get_environment("ZRZ_ART_OUTPUT")+"/house-completed-fixture.json",true),"completed activity render fixture")
	var snapshot:Dictionary=s._make_save_data();check(snapshot.version==37,"v37 snapshot")
	check(load("res://scripts/house_save.gd").error(snapshot)=="","receipt schema")
	check(s.load_game_data(snapshot),"v37 reload")
	var older:Dictionary=snapshot.duplicate(true);older.version=36;older.interior_state.erase("household")
	check(s.load_game_data(older) and s.interior_state.household.receipts.is_empty(),"v36 pure migration")
	check(s._make_save_data().version==37,"migrated snapshot version")
	var invalid:Dictionary=s._make_save_data().duplicate(true);invalid.interior_state.household.receipts={"bad":{"choices":"bad"}};var before_time:float=s.minutes
	check(not s.load_game_data(invalid) and s.minutes==before_time,"invalid migration never partially applies")
	s.current_interior="home-chen";var point:Dictionary=g.points(s.current_interior)[0];s.interior_position=Vector2(point.x,point.y);s.minutes=660;s.interior_npc_positions.clear()
	check(not s.house_activity.start(s,point).has("token"),"absent owner explained")
	s.interior_npc_positions.chen=Vector2(point.x-28,point.y)
	var a:Dictionary=s.house_activity.start(s,point);s.house_activity.cancel(int(a.token))
	check(s.minutes==660 and s.house_activity.active.is_empty(),"cancel before action is free")
	a=s.house_activity.start(s,point);s.house_activity.input(s,a.token,0);s.day+=1
	check(not s.house_activity.input(s,a.token,.65),"day change invalidates activity");s.house_activity.reset();s.day-=1
	a=s.house_activity.start(s,point)
	for value:Variant in [0,.35,1]:s.house_activity.input(s,a.token,value)
	# Use this room's configured alignment rather than assuming source ordering.
	if int(s.house_activity.active.step)<3:
		s.house_activity.input(s,a.token,float(g.profile(s.current_interior).steps[1].target));s.house_activity.input(s,a.token,1)
	check(s.house_activity.finish(s,a.token),"cancel animation setup");s.cancel_action();finish(s)
	check(s.minutes==660 and s.house_activity.active.is_empty(),"animation cancel no charge")
	var transaction:RefCounted=load("res://scripts/house_activity.gd").new(func(_state:Node)->bool:return false)
	s.current_interior="building-town-1";point=g.points(s.current_interior)[0];s.interior_position=Vector2(point.x,point.y);s.minutes=660;s.interior_npc_positions.clear()
	var old_house:Dictionary=s.interior_state.duplicate(true)
	a=transaction.start(s,point)
	check(a.has("token"),"failure-injection session starts")
	transaction.input(s,a.token,0);transaction.input(s,a.token,float(g.profile(s.current_interior).steps[1].target));transaction.input(s,a.token,1)
	check(not transaction.input(s,a.token,1),"fourth input rejected")
	check(transaction.finish(s,a.token),"failed-writer animation starts");finish(s)
	check(s.minutes==660 and s.interior_state==old_house and s.money==money and s.inventory==inventory,"write failure rolls back time, claims, choices and materials")
	var path:String=s.SAVE_PATH+".house-v36-test"
	var disk:Dictionary=s._make_save_data();disk.version=36;disk.interior_state.erase("household")
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(disk));f.close()
	check(s.load_game(path) and FileAccess.file_exists(path+".v36-original"),"v36 file backup before migration")
	s.current_interior="home-chen";s.interior_position=g.spawn(s.current_interior)
	change_scene_to_file("res://scenes/interior.tscn")
	for frame:int in 8:await process_frame
	check(is_instance_valid(current_scene.hud.house_activity_panel),"native activity panel registered")
	check(current_scene._room_points().any(func(p:Dictionary):return p.kind=="house-activity"),"new activities discoverable through actual room candidates")
	print("HOUSE_DEPTH_SMOKE: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
