extends SceneTree
var passed: int=0
var failed: int=0
var s: Node
var world: Node
var SERVICE: Script
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(6):await process_frame
func place_actor(position: Vector2) -> void:
	s.stop_walking();world.player.walk_path.clear();world.player.walk_source_path.clear();world.player.global_position=position;s.player_position=position;s.ui_open=false
func wait_task() -> void:
	for frame: int in range(1400):
		if s.fishing.get("queue",[]).is_empty() and s.walking_target.is_empty() and not s.action_busy():return
		await physics_frame
	check(false,"physical task deadline")
func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func():push_error("Fishing walk timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.current_interior="";s.minutes=480;s.day=0;s.player_position=Vector2(2690,2000)
	SERVICE=load("res://scripts/fishing_service.gd")
	change_scene_to_file("res://scenes/main.tscn");await settle();world=current_scene
	if world==null:quit(1);return
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	world.set_process(false);s.set_process(true);Engine.time_scale=8.0
	var home:=Vector2(2690,2000)
	for at: Dictionary in s.system_catalog.fishing.spots:
		for landing: Dictionary in at.landings:
			var cell:=Vector2i(floori(float(landing.x)/32),floori(float(landing.y)/32))
			check(preload("res://scripts/world_layout.gd").ground_column(cell,world.ground_layer.get_cell_atlas_coords(cell).x)==8,"cast lands on actual water "+str(at.id))
		place_actor(home)
		var target: Dictionary=at.duplicate(true);target.kind="fish"
		var route: Dictionary=world.player.preview_walk(target)
		check(bool(route.get("reachable",false)),"connected bank "+str(at.id))
		var points: Array=route.get("points",[])
		if points.is_empty():continue
		var start: Vector2=points[maxi(0,points.size()-3)]
		place_actor(start)
		check(world.player.walk_to(target),"actual bank walk "+str(at.id))
		for frame: int in range(800):
			if s.walking_target.is_empty():break
			await physics_frame
		check(s.player_position.distance_to(Vector2(float(at.x),float(at.y)))<=75,"arrived usable bank "+str(at.id))
		s.minutes=480;s.stamina=100
		check(s.begin_fishing(str(at.id)),"fish from reached bank "+str(at.id))
		s.cancel_player_action()
	for at: Dictionary in s.system_catalog.fishing.trapSlots:
		var cell:=Vector2i(floori(float(at.waterX)/32),floori(float(at.waterY)/32))
		check(preload("res://scripts/world_layout.gd").ground_column(cell,world.ground_layer.get_cell_atlas_coords(cell).x)==8,"trap is on actual water "+str(at.id))
		place_actor(home)
		var target: Dictionary=at.duplicate(true);target.kind="fishtrap-task";target.fishing_task=true
		var preview: Dictionary=world.player.preview_walk(target)
		check(bool(preview.get("reachable",false)),"connected trap slot "+str(at.id))
		var points: Array=preview.get("points",[])
		if points.is_empty():continue
		place_actor(points[maxi(0,points.size()-3)])
		s.inventory.fishTrap=2
		check(s.queue_fishing_tasks([{"id":str(at.id),"op":"place"}]),"queue placement "+str(at.id));await wait_task()
		check(s.fishing.traps.has(str(at.id)),"physical placement completes "+str(at.id))
		check(s.queue_fishing_tasks([{"id":str(at.id),"op":"remove"}]),"queue separate removal "+str(at.id));await wait_task()
		check(not s.fishing.traps.has(str(at.id)),"physical removal completes "+str(at.id))
	# Cancellation during unfinished work keeps all supplies.
	var at: Dictionary=s.system_catalog.fishing.trapSlots[0];place_actor(Vector2(float(at.x),float(at.y)))
	s.inventory.fishTrap=1
	check(s.queue_fishing_tasks([{"id":str(at.id),"op":"place"}]),"cancel placement queued")
	for frame: int in range(200):
		if s.action_busy():break
		await physics_frame
	s.cancel_player_action();s.stop_walking()
	check(int(s.inventory.fishTrap)==1 and not s.fishing.traps.has(str(at.id)),"cancel before completion retains trap")
	# Short stock completes first step, stops remaining steps without negative quantities.
	var next_at: Dictionary=s.system_catalog.fishing.trapSlots[1]
	check(s.queue_fishing_tasks([{"id":str(at.id),"op":"place"},{"id":str(next_at.id),"op":"place"}]),"short-stock batch queued");await wait_task()
	check(s.fishing.traps.has(str(at.id)) and not s.fishing.traps.has(str(next_at.id)) and int(s.inventory.fishTrap)==0,"completed result retained and stock shortage stops")
	# Keyboard release, pad press/release, and touch button signals share the same state.
	s.minutes=480;s.stamina=100;s.fishing.bait="plain"
	check(s.begin_fishing("fishing"),"begin input parity test")
	if s.fishing_active():
		var press:=InputEventKey.new();press.keycode=KEY_SPACE;press.pressed=true;world.hud.handle_source_key(press)
		check(bool(s.fishing_session.game.holding),"keyboard pressed")
		press.pressed=false;world.hud.handle_source_key(press);check(not bool(s.fishing_session.game.holding),"keyboard released")
		var buttons: Array=[];buttons.resize(17);buttons.fill(false);buttons[0]=true
		s.poll_source_gamepad(1.0,world.player,{"connected":true,"buttons":buttons,"axes":[0,0]});check(bool(s.fishing_session.game.holding),"pad pressed")
		buttons[0]=false;s.poll_source_gamepad(1.1,world.player,{"connected":true,"buttons":buttons,"axes":[0,0]});check(not bool(s.fishing_session.game.holding),"pad released")
		world.hud.fishing_panel.reel_button.button_down.emit();check(bool(s.fishing_session.game.holding),"touch pressed")
		world.hud.fishing_panel.reel_button.button_up.emit();check(not bool(s.fishing_session.game.holding),"touch released")
		world.hud.show_settings();var paused_at: float=s.fishing_session.game.time;s._process_action(.1)
		check(world.hud.settings_open() and s.fishing_session.game.time==paused_at and not s.fishing_session.game.holding,"settings freezes live session and clears input")
		world.hud.close_settings()
		s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);var before: float=s.fishing_session.game.time;s._process_action(.1);check(float(s.fishing_session.game.time)==before,"focus out freezes fishing")
		s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);s.cancel_player_action()
	Engine.time_scale=1;s.set_process(false)
	var file:=FileAccess.open("res://artifacts/fishing-overhaul-20261017/walk-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed},"  "));file.close()
	print("Fishing physical walking: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
