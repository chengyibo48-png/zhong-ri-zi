extends SceneTree
const LAYOUT := preload("res://scripts/farm_layout.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func settle() -> void:
	for frame in range(5): await process_frame
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func(): push_error("7x7 test timeout"); quit(1))
	var s := root.get_node("GameState")
	s.set_process(false)
	check(s.plots.size() == 97 and s.initial_state.plots.size() == 97,"97 current-format plots initialized")
	check(s.farm_filtered_indices("all","home").size() == 49 and s.farm_filtered_indices("all","slope").size() == 48,"49 main plots and 48 east plots")
	var positions: Dictionary = {}
	for i in range(97):
		var at: Vector2 = s.farm_plot_position(i)
		check(not positions.has(at),"unique plot coordinate "+str(i)); positions[at] = true
		check(at == s._farm_position(i),"same action and facility coordinate "+str(i))
		check((i < 49 and LAYOUT.columns(i) == 7) or (i >= 49 and LAYOUT.columns(i) == 12),"correct region width "+str(i))
		if i < 49:
			check(at == Vector2(2710+(i%7)*42,1731+int(i/7)*36),"7x7 cell geometry "+str(i))
			check(bool(s.plots[i].tilled),"main field prepared "+str(i))
			for corner: Vector2 in [Vector2(-21,-11),Vector2(21,17)]:
				var cell := Vector2i(floori((at.x+corner.x)/32),floori((at.y+corner.y)/32))
				check(preload("res://scripts/world_layout.gd").ground_column(cell,7) == 4,"new cell cleared of crossing stone road "+str(i))
	s.toolkit.tools.water.level = 2
	s.toolkit.tools.water.shape = "cross"
	s.toolkit.tools.water.branch = "broad"
	for i in range(97):
		for other in s._farm_targets(i,"water"):
			check(other >= LAYOUT.first(i) and other < LAYOUT.end(i),"tool never crosses farm regions")
	check(not s._farm_targets(6,"water").has(7),"tool does not wrap from seventh column into next row")
	check(not s._farm_targets(48,"water").has(49),"tool does not jump from main field to east field")
	var file := "user://farm-grid-7x7-test.json"
	check(s.save_game(file,true),"current layout can save")
	var copy = load("res://scripts/game_state.gd").new()
	copy._load_content(); copy._load_initial_state()
	check(copy.load_game(file) and copy.plots.size() == 97,"current layout reads its own save")
	copy.free()
	s.flags.introDone = true
	s.ui_open = false
	s.current_interior = ""
	s.player_position = LAYOUT.MAIN_ORIGIN+Vector2(-55,30)
	change_scene_to_file("res://scenes/main.tscn"); await settle()
	var world := current_scene
	check(world.plot_nodes.size() == 97,"all actual scene plots created")
	for i in range(97):
		var soil: Node = world.plot_nodes[i].get_node("CultivatedSoil")
		soil.call("set_state",s.plots[i])
		check(world.plot_nodes[i].position == s.farm_plot_position(i),"visible and actionable plot coincide "+str(i))
	check(world.plot_nodes[6].get_node("CultivatedSoil").snapshot.joined == Vector2(1,0),"seventh column closes its bed end")
	check(world.plot_nodes[7].get_node("CultivatedSoil").snapshot.joined == Vector2(0,1),"next row opens at column one")
	world.hud.show_farm_planner(false,96)
	check(world.hud.farm_planner_panel.plot_box.max_value == 97 and world.hud.farm_planner_panel.plot_box.value == 97,"planner addresses last east plot")
	world.hud.close_top_panel()
	world.hud.farm_facility_panel.open_panel(false,96)
	check(world.hud.farm_facility_panel.anchor_box.max_value == 97 and world.hud.farm_facility_panel.target_box.max_value == 97,"facilities address every plot")
	world.hud.close_top_panel()
	# Each new cell must support actual sowing and harvesting, not just rendering.
	s.farm.seedKind = "normal"; s.farm.density = "balanced"
	s.inventory.cabbageSeed = 200
	for i in range(49):
		s.plots[i] = s._new_plot(); s.plots[i].tilled = true
		s.stamina = 100
		check(s._farm_plot_action_single(i,"seed",{"crop":"cabbage"}),"sow on every cell "+str(i))
		s.plots[i].growth = 3
		check(s._farm_plot_action_single(i,"hand") and s.plots[i].crop == "","harvest on every cell "+str(i))
		s.plots[i].crop = "cabbage"; s.plots[i].moisture = 0
	var tasks: Array = s.farm_batch_plan(s.farm_filtered_indices("all","home"),"water")
	check(tasks.size() == 49,"all 49 cells enter actual batch work")
	s.toolkit.tools.water.level = 0; s.toolkit.tools.water.shape = "single"
	s.stamina = 100; s.minutes = 390; s.set_process(true)
	Engine.time_scale = 4.0
	check(s.queue_farm_tasks(tasks),"real walking batch starts")
	var deadline := Time.get_ticks_msec()+120000
	var next_report := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline:
		if s.farm_queue.is_empty() and s.farm_active_task.is_empty() and s.walking_target.is_empty(): break
		if Time.get_ticks_msec() >= next_report:
			print("7x7 walking progress: ",s.farm_completed," / 49; ",s.message)
			next_report = Time.get_ticks_msec()+10000
		await physics_frame
	check(s.farm_completed == 49,"player walks and waters every main-field cell")
	for i in range(49): check(float(s.plots[i].moisture) >= 30,"watering really settles "+str(i))
	Engine.time_scale = 1.0
	s.cancel_farm_queue(); s.set_process(false)
	print("Farm grid 7x7: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit(); quit(1 if failed else 0)
