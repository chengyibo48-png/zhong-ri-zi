extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	var life:Script=load("res://scripts/resident_life.gd");var contact:Script=load("res://scripts/resident_work_pose.gd");var art:Script=load("res://scripts/canonical_character.gd");var nav:RefCounted=load("res://scripts/npc_navigation.gd").new()
	check(life.all().size()==24,"all resident identities configured")
	var before:Dictionary=s._make_save_data();var messages:Dictionary={};var count:int=0
	for person:Dictionary in s.npc_catalog:
		var id:String=str(person.id);var p:Dictionary=life.profile(id);check(p.name==person.name and int(p.age)==int(person.age),"identity and age "+id)
		check(not messages.has(str(person.warm)),"unique warm response "+id);messages[str(person.warm)]=true
		var room:String="home-"+id;var station:Dictionary=life.station(s,id,room,{"key":"work"},0)
		check(not station.is_empty(),"real household workstation "+id)
		var at:=Vector2(float(station.x),float(station.y));var task:Dictionary=contact.describe(s,id,at,room,{"walking":false,"plan":{"key":"work"}})
		check(not task.is_empty() and task.station==station.station,"contact uses own authored station "+id)
		check(contact.describe(s,id,at+Vector2(200,0),room,{"plan":{"key":"work"}}).is_empty(),"no remote contact "+id)
		check(contact.describe(s,id,at,room,{"listening":true,"plan":{"key":"work"}}).is_empty(),"conversation interrupts work "+id)
		var safe:Dictionary=nav.safe(s,room,station);check(not nav.blocked(s,room,float(safe.x),float(safe.y)),"station has safe standing position "+id)
		var route:Array=nav.route(s,room,{"x":480,"y":560},safe);check(not route.is_empty() or nav.distance({"x":480,"y":560},safe)<10,"door to work area reachable "+id)
		var pure:Dictionary=life.sample(id,3.7);check(pure==life.sample(id,3.7),"deterministic idle "+id)
		check(float(life.sample(id,3.7,{"reduced":true}).gain)==0,"reduced motion "+id)
		check(float(life.sample(id,3.7,{"explicit":true}).gain)==0,"explicit action precedence "+id)
		if person.tier=="child":check(str(p.workKind) in ["read","pack"],"age appropriate activities "+id)
		var spec:Dictionary=load("res://scripts/character_art.gd").data().actors[id].clips.idle
		for direction:String in ["down","left","right","up"]:
			for clip:String in ["idle","walk",str(p.workKind)]:
				for frame:int in 12:
					var g:Dictionary=art.geometry(spec,clip,direction,float(frame)/12,-1,true,art.profile(id))
					var valid:bool=true
					for i:int in range(0,g.indices.size(),3):
						var a:Vector2=g.vertices[g.indices[i]];var z:Vector2=g.vertices[g.indices[i+1]];var q:Vector2=g.vertices[g.indices[i+2]]
						if not a.is_finite() or (z-a).cross(q-a)>=0:valid=false;break
					check(valid,"connected mesh without inversion "+id+"/"+direction+"/"+clip)
		count+=s.content.arcs[id].size()
	check(count==104,"all 104 story nodes retained")
	check(s._make_save_data()==before,"identity, presentation and navigation queries do not award or mutate save state")
	s.flags.introDone=true;s.ui_open=false;s.current_interior="";s.player_position=Vector2(2800,600);s.minutes=600
	for person:Dictionary in s.npc_catalog:
		var id:String=str(person.id);s.npc_stories[id]={"step":1,"choices":[0],"lastDay":-1};s.relations[id].points=10
		s.npc_residents[id]={"x":2800,"y":600,"room":null};s.npc_positions[id]=s.player_position
		var metric:String="storyActivity:"+id+":1";s.quests.metrics.erase(metric)
		check(s.start_npc_story_activity(id),"resident-specific activity starts "+id)
		s.cancel_action(false)
		for tick:int in 35:s._process_action(.1)
		check(int(s.quests.metrics.get(metric,0))==0,"cancel does not complete activity "+id)
		check(s.start_npc_story_activity(id),"activity can restart after cancel "+id)
		for tick:int in 35:s._process_action(.1)
		check(int(s.quests.metrics.get(metric,0))==1,"activity settles once "+id)
		check(not s.start_npc_story_activity(id) and int(s.quests.metrics.get(metric,0))==1,"repeat input cannot award again "+id)
	print("RESIDENT_DEPTH_NATIVE: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
