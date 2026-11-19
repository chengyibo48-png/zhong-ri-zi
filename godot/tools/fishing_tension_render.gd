extends SceneTree
var s:Node
var w:Node
var out:String
var passed:=0
var failed:=0
var movies:=false
var captures:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle(frames:int=10)->void:
	for i:int in frames:await process_frame
func capture(name:String)->void:
	await settle();RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"GPU "+name)
	captures.append(name)
func seed_for(point:Dictionary)->void:
	var rules:Script=load("res://scripts/fishing_rules.gd")
	for seed_value:int in range(1,2000):
		var f:Dictionary=s.fishing.duplicate(true);f.rng=seed_value
		var prediction:Dictionary=rules.predict(str(point.water),s.system_catalog.fishing,f,s.day,s.season_index(),s.weather_for(s.day),s.minutes)
		if str(prediction.get("fish",""))=="fish":s.fishing.rng=seed_value;return
func prepare(point:Dictionary,depth:int=1)->void:
	s.cancel_player_action();s.fishing.pending={};s.ui_open=false;s.fishing_focus_paused=false;s.current_interior="";s.minutes=600;s.stamina=100
	s.player_position=Vector2(float(point.x),float(point.y));w.player.global_position=s.player_position;w.player.camera.reset_smoothing()
	s.fishing.mode="standard";s.fishing.inputStyle="hold";s.fishing.bait="plain";s.fishing.depth=depth;s.fishing.tutorialDone=true;seed_for(point)
	check(s.begin_fishing(str(point.id)),"real spot "+str(point.id)+" depth "+str(depth))
func control(policy:String="correct")->void:
	if not s.fishing_active():return
	var g:Dictionary=s.fishing_session.game
	if g.stage=="bite":s.fishing_input("press","mouse")
	if g.stage=="fight":
		if policy=="hold":
			if not bool(g.holding):s.fishing_input("press","mouse")
		else:
			var surge:bool=str(g.fishPhase) in ["charge","surge"]
			if bool(g.holding) and (float(g.tension)>=68 or surge and float(g.tension)>=50):s.fishing_input("release","mouse")
			elif not bool(g.holding) and (float(g.tension)<=24 or float(g.tension)<=35 and not surge):s.fishing_input("press","mouse")
func run()->void:
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/fishing";DirAccess.make_dir_recursive_absolute(out);movies=OS.get_environment("ZRZ_FISH_MOVIES")=="1"
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.current_interior="";s.ui_open=false;s.minutes=600;s.player_position=Vector2(749,2790)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle(18);w=current_scene
	var point:Dictionary=s.system_catalog.fishing.spots[0];prepare(point)
	s.fishing_input("press","mouse")
	for i:int in 10:s._process_action(1.0/24);await process_frame
	await capture("charge-preview")
	var button_at:Vector2=w.hud.fishing_panel.reel_button.global_position
	check(s.fishing_session.game.stage=="charge","charge is distinct from airborne cast")
	s.fishing_input("release","mouse")
	for i:int in 8:s._process_action(1.0/24);await process_frame
	await capture("airborne-line")
	for i:int in 500:
		control();s._process_action(1.0/24);await process_frame
		if s.fishing_active() and s.fishing_session.game.stage=="fight":break
	await capture("fight-instruments")
	check(w.hud.fishing_panel.live_panel.is_visible_in_tree(),"live instrument remains in world")
	check(w.hud.fishing_panel.reel_button.size.y>=48,"fixed primary touch target")
	check(w.hud.fishing_panel.reel_button.global_position.distance_to(button_at)<1,"primary button does not jump between charge and fight")
	s.fishing_input("clear");s.fishing_session.game.plan.inputStyle="toggle"
	var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;Input.parse_input_event(key);await settle()
	print("KEY_EDGE ",JSON.stringify({"held":s.fishing_session.game.holding,"owner":s.fishing_session.game.get("inputOwner",""),"down":s.fishing_session.game.inputDown,"focus_pause":s.fishing_focus_paused,"ui":s.ui_open}))
	if OS.get_environment("ZRZ_INPUT_PROBE")=="1":await root.get_node("AudioService").prepare_exit();quit();return
	check(bool(s.fishing_session.game.holding) and s.fishing_session.game.inputOwner=="keyboard","native Space press reaches fishing controller")
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;key.echo=true;Input.parse_input_event(key);await settle()
	check(bool(s.fishing_session.game.holding),"native keyboard repeat cannot toggle reeling")
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key);await settle()
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;Input.parse_input_event(key);await settle()
	check(not bool(s.fishing_session.game.holding),"second physical Space press unloads toggle input")
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key);await settle()
	s.fishing_input("clear");s.fishing_session.game.plan.inputStyle="hold"
	var buttons:Array=[];buttons.resize(17);buttons.fill(false);buttons[0]=true
	s.poll_source_gamepad(10000,w.player,{"connected":true,"buttons":buttons,"axes":[0,0]})
	check(bool(s.fishing_session.game.holding) and s.fishing_session.game.inputOwner=="pad","native pad adapter starts reeling")
	s.ui_open=true;s._process_action(.1);s.ui_open=false
	s.poll_source_gamepad(10010,w.player,{"connected":true,"buttons":buttons,"axes":[0,0]})
	check(not bool(s.fishing_session.game.holding),"pad held across settings cannot auto resume reeling")
	buttons[0]=false;s.poll_source_gamepad(10020,w.player,{"connected":true,"buttons":buttons,"axes":[0,0]})
	# The touch button's production signals are exercised separately from world clicks.
	w.hud.fishing_panel.reel_button.button_down.emit();check(bool(s.fishing_session.game.holding),"fixed touch button starts reeling")
	w.hud.fishing_panel.reel_button.button_up.emit();check(not bool(s.fishing_session.game.holding),"fixed touch button releases tension")
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=Vector2(180,450);mouse.pressed=true;Input.parse_input_event(mouse);await settle()
	check(bool(s.fishing_session.game.holding) and s.fishing_session.game.inputOwner=="mouse","native world mouse press starts reeling")
	mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=Vector2(180,450);mouse.pressed=false;Input.parse_input_event(mouse);await settle()
	check(not bool(s.fishing_session.game.holding),"native mouse release unloads")
	var spot:Node=w.fish_nodes.get(str(point.id)) if w.get("fish_nodes") is Dictionary else null
	for child:Node in w.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("fish_spot.gd") and str(child.spot_id)==str(point.id):spot=child;break
	check(spot!=null and not spot.columns.is_empty(),"water effects use real terrain topology")
	if spot!=null:
		var attachments:Dictionary=w.player.character_visual.contact_attachments()
		check(not attachments.is_empty() and Vector2(attachments.tip).distance_to(spot.last_tip)<1.5,"rendered line follows deformed rod tip")
	var visual:Node=w.player.character_visual;var garment:Node=visual.wardrobe
	for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		w.player.facing=direction;visual.set_pose(direction,false);await settle()
		check(absf(float(garment.rig_frame.get("rod_bend",0)))<=3.5,"four-direction rod remains bounded")
	await capture("fight-back-view")
	s.visual_fx.motion="reduced";s.changed.emit();await settle()
	check(w.player.camera.offset.distance_to(w.player.fishing_camera.saved_offset)<.01,"reduced motion removes presentation camera offset")
	await capture("reduced-motion")
	s.visual_fx.motion="full";s.player_settings.textScale=1.25;s.source_input_mode="touch";s.changed.emit();root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);await settle()
	await capture("large-touch-instruments")
	check(w.hud.fishing_panel.live_panel.get_global_rect().end.y<=root.get_visible_rect().end.y,"large-touch dock stays inside viewport")
	s.player_settings.textScale=1.0;root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	# All authored ranges remain literal water positions, not screen-space indicators.
	var water:Script=load("res://scripts/water_geometry.gd")
	for at:Dictionary in s.system_catalog.fishing.spots:
		for landing:Dictionary in at.landings:check(water.is_water(spot.columns,Vector2(float(landing.x),float(landing.y))),"authored landing remains water "+str(at.id))
	for at:Dictionary in s.system_catalog.fishing.spots:
		for depth:int in 3:
			prepare(at,depth);s.fishing_input("press","mouse");s._process_action(.1);s.fishing_input("release","mouse")
			for i:int in 8:s._process_action(.1);await process_frame
			await settle()
			check(int(s.fishing_session.game.plan.depth)==depth,"tap honors all eighteen preset landings")
			var active_spot:Node=null
			for child:Node in w.fish_nodes:
				if str(child.spot_id)==str(at.id):active_spot=child;break
			check(active_spot!=null and water.is_water(active_spot.columns,active_spot.last_bobber),"rendered float stays on water at each bank")
			if depth==1:await capture("bank-"+str(at.id))
	prepare(point);s.minutes=1260;s.changed.emit();s.fishing_input("press","mouse");s._process_action(.1);s.fishing_input("release","mouse")
	for i:int in 8:s._process_action(.1);await process_frame
	await capture("night-water")
	for day:int in 28:
		if int(s.weather_profile(day).get("rain",0))<=0:continue
		s.day=day;s.minutes=720;s.clock_changed.emit();s.changed.emit();await capture("rain-water");break
	s.cancel_player_action();s.day=0;s.minutes=600;s.changed.emit()
	for scenario:String in ["release","failure"]:
		prepare(point);s.fishing_input("press","mouse");var captured:int=0;var ended:=false;var tail:int=0
		var folder:String=out+"/"+scenario;var traces:Array=[]
		if movies:DirAccess.make_dir_recursive_absolute(folder)
		for i:int in 1300:
			if i==8:s.fishing_input("release","mouse")
			root.mode=Window.MODE_WINDOWED;s.fishing_focus_paused=false;control("hold" if scenario=="failure" else "correct");s._process_action(1.0/24);await process_frame
			if s.fishing_active():
				var g:Dictionary=s.fishing_session.game;traces.append({"frame":i,"stage":g.stage,"tension":g.tension,"distance":g.distance,"stamina":g.stamina,"holding":g.holding})
			elif not ended:
				ended=true
				if scenario=="release":
					check(not s.fishing.pending.is_empty(),"complete visible reel cycle catches fish")
					await capture("catch-result")
					if movies:
						for hold:int in 48:
							await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg"%captured,0.94);captured+=1
					w.hud.fishing_panel._resolve(true)
				else:
					check(str(s.fishing.last.get("reason",""))=="鱼线张力过高","visible failure is caused by over-tension")
					await capture("failure-feedback")
			if movies:
				RenderingServer.force_draw();root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg"%captured,0.94);captured+=1
			if ended:
				tail+=1
				if tail>40:break
		var f:=FileAccess.open(out+"/"+scenario+"-trace.json",FileAccess.WRITE);f.store_string(JSON.stringify(traces));f.close()
		check(ended,"visible sequence terminates "+scenario)
	await create_timer(2.3).timeout;await settle()
	check(not w.player.fishing_camera.engaged and w.player.camera.offset.distance_to(Vector2.ZERO)<.01,"camera restores after fishing")
	await capture("restored-camera")
	print("FISHING_TENSION_GPU: %d passed, %d failed; movies="%[passed,failed],movies)
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
