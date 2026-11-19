extends SceneTree
var passed:int=0
var failed:int=0
const L=preload("res://scripts/house_life.gd")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;print("CHECK_FAIL ",label)
func _initialize()->void:call_deferred("run")
func finish(s:Node)->void:
	for i:int in 20:s._process_action(.1)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(OS.get_environment("TEMP").replace("\\","/")):quit(1);return
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.day=30;s.minutes=660
	var initial:Dictionary={"inventory":s.inventory.duplicate(true),"relations":s.relations.duplicate(true),"money":s.money,"stamina":s.stamina,"stories":s.npc_stories.duplicate(true)}
	var g:Script=load("res://scripts/house_geometry.gd");var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(s)
	for room:String in g.all():
		s.current_interior=room;s.interior_npc_positions.clear()
		for extra:Dictionary in L.rows(s,room):
			check(not L.footprint(extra).intersects(Rect2(450,300,60,280)),"60px trunk passage "+str(extra.id))
		var count:int=0
		for point:Dictionary in L.points(s,room):
			if str(point.type)=="preset":continue
			count+=1;var safe:Dictionary=nav.safe(s,room,{"x":point.x,"y":point.y-8});s.interior_position=Vector2(safe.x,safe.y)
			check(not nav.blocked(s,room,point.x,point.y-8),"precise use stand is clear "+str(point.id))
			check(s.interior_position.distance_to(Vector2(point.x,point.y))<=50,"fixture reachable near actual furniture "+str(point.id))
			check(not nav.route(s,room,{"x":480,"y":567},safe).is_empty(),"fixture route "+str(point.id))
			var old:bool=L.state(s,room,str(point.id));var time:float=s.minutes
			check(s.house_activity.toggle_fixture(s,point),"fixture begins "+str(point.id))
			check(not s.house_activity.toggle_fixture(s,point),"duplicate input rejected "+str(point.id))
			finish(s);check(L.state(s,room,str(point.id))!=old,"fixture commits once "+str(point.id))
			check(s.minutes==time,"no time charged "+str(point.id))
			check(s.house_activity.toggle_fixture(s,point),"cancel starts "+str(point.id));s.cancel_action();finish(s)
			check(L.state(s,room,str(point.id))!=old,"cancel preserves fixture "+str(point.id))
		check(count==2 if room!="building-farm-12" else count==0,"two appropriate direct controls "+room)
	check(s.money==initial.money and s.inventory==initial.inventory and s.relations==initial.relations and s.stamina==initial.stamina and s.npc_stories==initial.stories,"no economy, reward, story or stamina effects")
	var snapshot:Dictionary=s._make_save_data();check(snapshot.version==37 and s.load_game_data(snapshot),"v37 with all furniture states reloads")
	var invalid:Dictionary=snapshot.duplicate(true);invalid.interior_state.household.fixtureStates={"home-chen:fixture:invented":true}
	check(not s.load_game_data(invalid),"invented fixture rejected before load")
	invalid=snapshot.duplicate(true);invalid.interior_state.household.fixtureStates={"home-chen:fixture:lamp":"true"}
	check(not s.load_game_data(invalid),"wrong state type rejected")
	var older:Dictionary=snapshot.duplicate(true);older.interior_state.household.erase("fixtureStates");older.interior_state.household.erase("homePreset")
	check(s.load_game_data(older),"original v37 defaults without new fields")
	s.current_interior="building-farm-12";s.interior_npc_positions.clear();s.interior_position=Vector2(420,555)
	var owned:Array=s.building.layout.duplicate(true);var before:float=s.minutes
	check(s.house_activity.set_home_preset(s,true),"home preview confirm")
	nav.refresh(s);check(not nav.blocked(s,s.current_interior,s.interior_position.x,s.interior_position.y),"home installation never covers preview standing position")
	check(L.enabled(s,s.current_interior) and s.building.layout==owned and s.minutes==before,"preview preserves ownership, placement, money and time")
	check(s.house_activity.set_home_preset(s,false) and L.rows(s,s.current_interior).is_empty(),"home additions withdrawn without removing owned furniture")
	var failed_writer:RefCounted=load("res://scripts/house_activity.gd").new(func(_s:Node)->bool:return false)
	check(not failed_writer.set_home_preset(s,true) and not L.enabled(s,s.current_interior),"failed home save rolls back")
	s.current_interior="home-chen";var point:Dictionary=L.points(s,s.current_interior)[0];s.interior_position=Vector2(point.x,point.y)
	var old:bool=L.state(s,s.current_interior,str(point.id));check(failed_writer.toggle_fixture(s,point),"failed fixture writer starts");finish(s)
	check(L.state(s,s.current_interior,str(point.id))==old,"failed fixture save rolls back")
	check(s.house_activity.toggle_fixture(s,point),"leave room animation starts");s.current_interior="home-lan";finish(s)
	check(L.state(s,"home-chen",str(point.id))==old,"leaving room cancels fixture commit")
	# Real overlap with an existing grid item hides additions; identities stay intact.
	s.current_interior="building-farm-12";s.interior_position=Vector2(420,555);s.interior_state.household.homePreset=true
	var candidate:Dictionary=g.profile(s.current_interior).furnishings[0];var zone:Dictionary=s.system_catalog.building.zones.home
	var cell:int=floori((float(candidate.y)-float(zone.y))/float(zone.size))*int(zone.cols)+floori((float(candidate.x)-float(zone.x))/float(zone.size))
	s.building.layout.append({"key":999999,"type":"teaTable","zone":"home","cell":cell,"rotation":0});s.building.revision+=1
	check(L.blocked_by_player(s,candidate) and not L.rows(s,s.current_interior).has(candidate),"owned furniture takes priority over supplement")
	s.building.layout=owned;s.building.revision+=1
	s.current_interior="home-granny";s.interior_position=g.spawn(s.current_interior);change_scene_to_file("res://scenes/interior.tscn")
	for frame:int in 8:await process_frame
	check(is_instance_valid(current_scene.life_collision_root),"actual native furniture collision root")
	check(current_scene.furniture_visuals.any(func(n:Node2D)->bool:return str(n.row.get("kind","")).begins_with("domestic-")),"new bitmap sprites in native scene")
	s.current_interior="building-farm-12";s.interior_position=Vector2(480,567);change_scene_to_file("res://scenes/interior.tscn")
	for frame:int in 8:await process_frame
	var collision_count:int=current_scene.life_collision_root.get_child_count()
	s.building.layout.append({"key":999999,"type":"teaTable","zone":"home","cell":cell,"rotation":0});s.building.revision+=1;s.domain_changed.emit("world")
	for frame:int in 8:await process_frame
	check(current_scene.life_collision_root.get_child_count()<collision_count,"owned placement removes hidden supplement collision in live scene")
	check(not current_scene.furniture_visuals.any(func(n:Node2D)->bool:return str(n.row.get("id",""))==str(candidate.id)),"owned placement removes overlapping supplemental sprite")
	s.building.layout=owned;s.building.revision+=1;s.domain_changed.emit("world")
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/household-completed-fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(s._make_save_data()));file.close()
	print("HOUSEHOLD_RICH: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
