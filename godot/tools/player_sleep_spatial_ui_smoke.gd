extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func same_point(state: Node,expected: Dictionary,label: String) -> void:
	var point: Dictionary=state.player_navigation_position()
	check(float(point.x)==float(expected.player.x),label+"/x")
	check(float(point.y)==float(expected.player.y),label+"/y")
	check(state.player_direction==str(expected.player.get("direction","down")),label+"/direction")
	check(state.current_interior==("" if expected.room==null else str(expected.room)),label+"/room")
	check(state.interior_return_source==expected.back,label+"/back")
	check(state.day==int(expected.day) and state.minutes==float(expected.minutes) and state.stamina==int(expected.stamina),label+"/daily")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	var state=root.get_node("GameState")
	state.set_process(false)
	var wanted: Array=["","home-granny","ranch-poultry",str(state.system_catalog.museum.house.id)]
	var selected: Array=[]
	var file=FileAccess.open(OS.get_environment("PLAYER_SPATIAL_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=CODEC.parse(line)
		if not str(row.label).begins_with("day/"):continue
		var room: String="" if row.before.village.interior==null else str(row.before.village.interior)
		if room in wanted and int(row.before.day) in [0,111]:selected.append(row)
	check(selected.size()==8,"eight independent sleep cases")
	for row in selected:
		check(state.load_game_data(state.convert_external_save(row.before)),"source loaded")
		state.set_player_navigation_position(row.before.player)
		state.interior_return_source=row.before.village.returnPoint.duplicate(true) if row.before.village.returnPoint is Dictionary else null
		var world=load("res://scenes/main.tscn" if state.current_interior=="" else "res://scenes/interior.tscn").instantiate()
		root.add_child(world)
		current_scene=world
		world.set_process(false)
		world.player.set_physics_process(false)
		if world.hud.onboarding_open():world.hud.toggle_onboarding()
		state.ui_open=false
		var panel=world.hud.sleep_panel
		var prior: Dictionary=state.player_navigation_position()
		var day_before: int=state.day
		panel.open_panel()
		panel.sleep_button.pressed.emit()
		check(state.action_busy() and state.day==day_before,"sleep awaits completion")
		var action: Dictionary=state.action_snapshot()
		check(float(action.x)==float(prior.x) and float(action.y)==float(prior.y),"sleep target keeps source precision")
		check(not panel.visible and not state.ui_open,"sleep shows world action")
		for i in range(21):state._process_action(0.1)
		check(state.day==day_before,"sleep before final frame")
		state._process_action(0.1)
		same_point(state,row.samples[0].expected,str(row.label))
		check(current_scene==world and is_instance_valid(world),"sleep keeps original actual scene")
		check(world.player.global_position==Vector2(prior.x,prior.y),"sleep retains displayed player")
		if day_before==111:
			check(world.hud.community_open() and state.ui_open,"year review opens in current room")
			world.hud.close_community()
		else:check(not world.hud.community_open() and not state.ui_open,"ordinary morning remains playable")
		check(state.save_game("user://sleep-spatial-ui.json",true),"write UI state")
		var position: Dictionary=state.player_navigation_position()
		check(state.load_game("user://sleep-spatial-ui.json"),"read UI state")
		check(state.player_navigation_position()==position,"UI save retains exact active position")
		world.queue_free()
		current_scene=null
		await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Actual sleep spatial UI: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
