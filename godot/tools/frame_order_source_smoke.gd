extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
var record:Dictionary={}
var frame_index:=0
var arrival:=""
var state:Node

class Actor extends Node:
	var owner_test:SceneTree
	func advance_player_frame(_delta:float)->void:owner_test.probe_move()
	func pause_player_frame()->void:pass

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=20:push_error(label)
func begin_probe()->void:
	check(state.begin_action({"kind":"read","label":"probe","duration":0.12},{"kind":"test"},func():record.commits+=1),"begin probe")
func probe_move()->void:
	record.moves+=1
	if frame_index==2:
		if arrival.contains("action"):begin_probe()
		if arrival.contains("ui"):state.ui_open=true
func run()->void:
	await process_frame
	create_timer(120).timeout.connect(func():push_error("Frame order timeout");quit(1))
	state=root.get_node("GameState")
	state.set_process(false)
	var seed:Dictionary=state._make_save_data()
	var actor:=Actor.new()
	actor.owner_test=self
	root.add_child(actor)
	state.sound_requested.connect(func(_kind):record.sounds+=1)
	state.bedtime_reached.connect(func():record.notices+=1;state.ui_open=true)
	var file=FileAccess.open(OS.get_environment("FRAME_ORDER_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	var frames:=0
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row:Dictionary=CODEC.parse(line)
		check(state.load_game_data(seed.duplicate(true)),"reset")
		record={"moves":0,"commits":0,"sounds":0,"notices":0}
		state.player_settings.speed=row.speed
		state.feedback.prefs.pace="normal"
		state.current_interior=""
		state.ui_open=row.initial=="ui"
		state.minutes=1319.99
		state._source_update_tick=0.0
		state.scene_fade_remaining=0.3
		var clock:float=state.npc_movement.clock
		arrival=row.arrival
		if row.initial=="action":begin_probe()
		for i in range(row.samples.size()):
			frame_index=i
			var sample:Dictionary=row.samples[i]
			if sample.panel=="close":state.ui_open=false
			if sample.panel=="open":state.ui_open=true
			state.advance_simulation_frame(float(sample.delta),actor)
			var expected:Dictionary=sample.expected
			var label:=str(cases)+"/"+str(i)
			check(state.minutes==float(expected.minutes),label+"/minutes")
			check(state._source_update_tick==float(expected.tick),label+"/tick")
			check(state.ui_open==bool(expected.ui),label+"/UI")
			var elapsed:Variant=state.action_sequence.active.get("elapsed")
			check(elapsed==expected.elapsed,label+"/action elapsed")
			check(is_equal_approx(state.npc_movement.clock-clock,float(expected.worldClock)),label+"/world before actions")
			check(is_equal_approx(state.scene_fade_remaining,float(expected.fade)),label+"/fade")
			for key in record:check(record[key]==expected[key],label+"/"+key)
			frames+=1
		cases+=1
	check(cases==72 and frames==10080,"fixture coverage")
	# Exercise a real player's final waypoint and synchronous interaction.
	state.load_game_data(seed.duplicate(true))
	state.current_interior=""
	state.ui_open=false
	state.player_settings.speed="normal"
	state.set_player_navigation_position({"x":2831.0,"y":1652.0,"direction":"down"})
	var host=load("res://tools/frame_arrival_probe.gd").new()
	root.add_child(host)
	var player=load("res://scripts/player.gd").new()
	host.add_child(player)
	player.set_physics_process(false)
	player.global_position=Vector2(2831,1652)
	for mode in ["action","ui"]:
		state.cancel_action()
		state.ui_open=false
		host.mode=mode
		host.calls=0
		player.walk_path.clear()
		player.walk_path.append(Vector2(2831,1652))
		player.walk_source_path=[{"x":2831.0,"y":1652.0}]
		player.walk_index=0
		player.walk_source=true
		player.walk_is_exit=false
		state.walking_target={"kind":"ambient","auto_interact":true,"x":2831.0,"y":1652.0}
		var before:float=state.minutes
		state.advance_simulation_frame(0.05,player)
		check(host.calls==1,mode+"/arrival dispatch same frame")
		check(state.minutes==before+0.05*1.55,mode+"/arrival retains frame time")
		if mode=="action":
			check(state.action_busy() and state.action_sequence.active.elapsed==0.05,"arrival action tick same frame")
		else:check(state.ui_open and not state.action_busy(),"arrival UI same frame")
	# Production _process owns the frame; the physics callback cannot double it.
	state.cancel_action()
	state.ui_open=false
	host.mode="action"
	host.calls=0
	player.walk_path.clear()
	player.walk_path.append(Vector2(2831,1652))
	player.walk_source_path=[{"x":2831.0,"y":1652.0}]
	player.walk_index=0
	state.walking_target={"kind":"ambient","auto_interact":true,"x":2831.0,"y":1652.0}
	state.minutes=600.0
	state._source_update_tick=0.0
	state.set_process(true)
	state._process(0.05)
	check(host.calls==1 and state.action_sequence.active.elapsed==0.05,"production arrival begins and ticks once")
	var admitted_time:float=state.minutes
	player._physics_process(0.05)
	check(state.minutes==admitted_time and state.action_sequence.active.elapsed==0.05,"physics cannot duplicate production simulation")
	state._process(0.05)
	state._process(0.05)
	check(not state.action_busy() and state.minutes==admitted_time,"completion frame remains locked for movement and time")
	state._process(0.05)
	check(state.minutes==admitted_time+0.05*1.55,"frame after completion resumes time")
	state.set_process(false)
	host.queue_free()
	actor.queue_free()
	await process_frame
	print("FRAME_ORDER_SOURCE_SMOKE: %d passed, %d failed; %d cases, %d frames"%[passed,failed,cases,frames])
	await root.get_node("AudioService").prepare_exit()
	quit(0 if failed==0 else 1)
