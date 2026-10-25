extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
class Actor extends Node2D:
	var walk_source_path:Array=[]
	var walk_path:Array=[]
	var walk_index:=0
	var walk_is_exit:=false
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=20:push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
		quit(1)
		return
	create_timer(120).timeout.connect(func():push_error("Queue dispatch timeout");quit(1))
	var state=root.get_node("GameState")
	state.set_process(false)
	var raw:Dictionary=CODEC.parse(FileAccess.get_file_as_string(OS.get_environment("QUEUE_DISPATCH_FIXTURE")))
	var probe=load("res://tools/queue_dispatch_probe.gd").new()
	var actor:=Actor.new()
	probe.probe_actor=actor
	for row in raw.rows:
		probe.cancel_action(false)
		probe.starts=[]
		probe.building_task={} if not int(row.mask)&1 else {"id":"probe"}
		probe.kitchen_task={} if not int(row.mask)&2 else {"id":"probe"}
		probe.ranch_queue=[] if not int(row.mask)&4 else [{}]
		probe.farm_queue=[] if not int(row.mask)&8 else [{}]
		probe.ranch_active_task={}
		probe.farm_active_task={}
		probe.source_frame_time=float(row.at)
		probe.ranch_next_at=1.1
		probe.farm_next_at=0.85
		probe.fail_routes=bool(row.fail)
		probe.hidden_probe=row.blocked=="hidden"
		probe.ui_open=row.blocked=="panel"
		probe.walking_target={"kind":"pending"} if row.blocked in ["pending","exit"] else {}
		actor.walk_source_path=[{"x":1,"y":1}] if row.blocked=="route" else []
		actor.walk_path=[]
		if row.blocked=="action":probe.action_sequence.start({"duration":1.0},func():pass)
		probe.advance_navigation_queues(actor)
		check(probe.starts==row.expected,"original dispatch "+str(row))
	check(raw.rows.size()==1792,"dispatch coverage")
	root.add_child(actor)
	actor.add_to_group("player")
	root.add_child(probe)
	probe.set_process(false)
	for row in raw.commits:
		probe.source_frame_time=float(row.at)
		probe.perform_ok=bool(row.ok)
		probe.farm_completed=2
		probe.ranch_completed=2
		probe.farm_queue=[{}]
		probe.ranch_queue=[{}]
		probe.farm_active_task={"index":0,"action":"water"}
		probe.ranch_active_task={"pet":true,"action":"water"}
		var target:Dictionary={"x":0.0,"y":0.0,"ranch_stage":"action","house":"","_sequence_resolved":true}
		if row.kind=="farm":
			probe.finish_farm_task(target)
			check(probe.farm_next_at==float(row.nextAt),"farm completion exact deadline")
			check(probe.farm_completed==int(row.completed) and probe.farm_queue.size()==int(row.remaining),"farm completion count and failure stop")
		else:
			probe.finish_ranch_task(target)
			check(probe.ranch_next_at==float(row.nextAt),"ranch completion exact deadline")
			check(probe.ranch_completed==int(row.completed) and probe.ranch_queue.size()==int(row.remaining),"ranch completion count and failure stop")
	check(raw.commits.size()==24,"completion coverage")
	probe.free()
	actor.free()
	# Verify all common UI openings clear live native queues and route caches.
	var world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.player.set_physics_process(false)
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	var seed:Dictionary=state._make_save_data()
	var panels=[world.hud.life_menu,world.hud.map_panel,world.hud.weather_panel,world.hud.forage_panel,world.hud.feedback_panel,world.hud.help_panel,world.hud.sleep_panel]
	for panel in panels:
		state.load_game_data(seed.duplicate(true))
		state.ui_open=false
		state.farm_queue=[{"index":0,"action":"water"}]
		state.farm_active_task={"index":1,"action":"water"}
		state.ranch_queue=[{"pet":true,"action":"pet"}]
		state.ranch_active_task={"pet":true,"action":"pet"}
		state.building_task={"id":"probe"}
		state.kitchen_task={"id":"probe"}
		state.walking_target={"kind":"walk"}
		world.player.walk_path.append(Vector2(2831,1652))
		world.player.walk_source_path.append({"x":2831.0,"y":1652.0})
		panel.open_panel()
		check(state.ui_open and panel.visible,"actual panel opens")
		check(state.farm_queue.is_empty() and state.farm_active_task.is_empty() and state.ranch_queue.is_empty() and state.ranch_active_task.is_empty(),"UI cancels both batches")
		check(state.building_task.is_empty() and state.kitchen_task.is_empty() and state.walking_target.is_empty(),"UI discards pending work")
		check(world.player.walk_path.is_empty() and world.player.walk_source_path.is_empty(),"UI discards native route caches")
		panel.close()
		check(state.walking_target.is_empty(),"closing cannot resume old work")
		state.begin_action({"kind":"read","duration":1.0},{"kind":"test"},func():pass)
		panel.open_panel()
		check(not state.ui_open and not panel.visible and state.action_busy(),"UI open respects action lock")
		state.cancel_action()
	world.queue_free()
	await process_frame
	print("QUEUE_DISPATCH_SOURCE_SMOKE: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
