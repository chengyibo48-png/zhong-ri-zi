extends SceneTree
var s: Node
var w: Node
var Q: GDScript
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,text: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(text)
func settle() -> void:
	for i: int in range(6):await process_frame
func place(at: Vector2) -> void:
	w.hud.ui_stack.leave();s.stop_walking();w.player.walk_path.clear();w.player.walk_source_path.clear();w.player.global_position=at;s.player_position=at;s.current_interior=""
func finish_action() -> void:
	for frame: int in range(150):
		if not s.action_busy():break
		s._process_action(.1)
	check(not s.action_busy(),"real bounded action completes")
func approach(target: Dictionary) -> void:
	var preview: Dictionary=w.player.preview_walk(target);check(bool(preview.get("reachable",false)),"connected path "+str(target.name))
	var points: Array=preview.get("points",[])
	if points.is_empty():return
	place(points[maxi(0,points.size()-3)])
	check(w.player.walk_to(target),"actual walk begins "+str(target.name))
	for frame: int in range(900):
		if s.walking_target.is_empty():break
		await physics_frame
	check(s.walking_target.is_empty(),"actual walk finishes "+str(target.name))
func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func():push_error("UI task walking timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.current_interior="";s.flags.introDone=true;s.ui_open=false;s.day=84;s.minutes=600;s.stamina=100;s.flags.firstDish=true;s.inventory.wood=100;s.inventory.bamboo=100;Q=load("res://scripts/quest_service.gd")
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.set_process(false);Engine.time_scale=8
	check(w.quest_site_points.size()==4,"four physical on-site construction signs")
	for id: String in Q.PROJECT_SITES:
		place(Vector2(2690,2000));var d: Dictionary=Q.definition(s,"project:"+id);var target: Dictionary=Q.target(s,d)
		await approach(target)
		check(Q.near(s,d),"arrived actual construction stand "+id)
		var point: Dictionary={}
		for candidate: Dictionary in w._world_target_candidates():
			if str(candidate.get("kind",""))=="quest-project" and str(candidate.id)==id:point=candidate
		check(not point.is_empty() and s.player_position.distance_to(Vector2(float(point.x),float(point.y)))<53,"sign can be reached and used "+id)
		w._interact_target(point,true);await settle()
		check(w.hud.life_plan_panel.visible and w.hud.life_plan_panel.selected_id=="project:"+id,"physical sign opens corresponding task "+id)
		w.hud.life_plan_panel._submit();finish_action();check(bool(s.community_projects.get(id,false)),"actual on-site construction action "+id)
		place(s.player_position)
	# Map references stay canonical as the NPC's actual resident position changes.
	var person: Dictionary=s.npc_catalog.filter(func(row: Dictionary):return str(row.id)=="lin")[0]
	s.npc_residents.lin={"x":2690.0,"y":1912.0,"room":null};s.npc_positions.lin=Vector2(2690,1912);place(Vector2(2650,1912))
	var d: Dictionary=Q.definition(s,"wish:schoolLunch");var at: Dictionary=Q.target(s,d)
	check(str(at.id)=="neighbor-lin" and not s.atlas_resolve(at).is_empty(),"NPC map marker is a real catalogue identity")
	s.npc_residents.lin.x=2760;s.npc_positions.lin=Vector2(2760,1912)
	check(float(s.atlas_resolve(at).x)==2760,"map resolves moving NPC position afresh")
	var walk: Dictionary=Q.walk_target(s,d);check(walk.has("npc") and str(walk.id)=="lin","physical NPC walk uses the live-follow navigation interface")
	# Movement during handoff invalidates the action without consuming items.
	s.inventory.eggRice=2;s._reconcile_kitchen_lots();s.quest_accept("wish:schoolLunch");place(s.npc_positions.lin)
	check(s.quest_submit("wish:schoolLunch"),"face-to-face handoff starts")
	s.npc_positions.lin+=Vector2(240,0);finish_action()
	check(s.inventory.eggRice==2 and not bool(s.flags.get("schoolLunch",false)),"moving recipient prevents stale handoff")
	# Closed counter windows are exact, and a ready contract survives to opening.
	s.day=84;s.minutes=479;var order: Dictionary=s.economy_weekly_orders()[0];var weekly: Dictionary=Q.weekly_definition(s,order);s.quest_accept(str(weekly.id));s.inventory[str(order.id)]=100;s._reconcile_kitchen_lots()
	check(not Q.counter_open(s) and str(Q.snapshot(s,weekly).status)=="active","before opening remains actionable later")
	s.minutes=480;check(Q.counter_open(s),"08:00 opening inclusive");s.minutes=1199;check(Q.counter_open(s),"19:59 open");s.minutes=1200;check(not Q.counter_open(s),"20:00 closure exclusive")
	# Keyboard and controller enter the same task journal; shoulder navigation switches tabs.
	place(Vector2(2690,2000));var event:=InputEventKey.new();event.keycode=KEY_J;event.unicode=106;event.pressed=true
	check(w.hud.handle_source_key(event),"keyboard task hotkey consumed");await settle();check(w.hud.life_plan_panel.visible,"J opens unified tasks")
	w.hud.apply_source_gamepad({"kind":"tab","value":1});check(w.hud.life_plan_panel.active_tab=="available","controller shoulder changes journal section")
	w.hud.show_museum("catalog","item:cabbage");await settle();w.hud.apply_source_gamepad({"kind":"close"});await settle();check(w.hud.life_plan_panel.visible and s.ui_open,"controller back returns to task source")
	w.hud.ui_stack.leave()
	var pad: RefCounted=load("res://scripts/source_gamepad.gd").new();var buttons: Array=[];buttons.resize(17);buttons.fill(false);buttons[8]=true
	var commands: Array=pad.poll({"connected":true,"buttons":buttons,"axes":[0,0]},true,false,false,false,1000)
	check(commands.any(func(command: Dictionary):return str(command.kind)=="journal"),"controller View opens task journal")
	Engine.time_scale=1;s.set_process(false)
	var f:=FileAccess.open("res://artifacts/ui-quests-20261017/walk-report.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"failed":failed,"projectStations":w.quest_site_points},"  "))
	print("UI quest walking: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
