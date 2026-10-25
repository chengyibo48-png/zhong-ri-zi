extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else: failed += 1;push_error(message)
func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Quality smoke timeout");quit(1))
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
	var state := root.get_node("GameState")
	state.set_process(false)
	var baseline: Dictionary = state._make_save_data().duplicate(true)
	state.save_game("user://quality-valid.json",true)
	var before_disk := FileAccess.get_file_as_string("user://quality-valid.json")
	for field: String in ["version","day","minutes","stamina","money","player","inventory"]:
		for invalid: Variant in [[],{},true,"bad",INF,NAN]:
			var broken := baseline.duplicate(true)
			broken[field] = invalid
			# A dictionary is valid for player and inventory; test a broken member.
			if field == "player" and invalid is Dictionary: broken.player={"x":[]}
			if field == "inventory" and invalid is Dictionary: broken.inventory={"wood":[]}
			check(not state.load_game_data(broken),"Native rejection "+field+"/"+str(invalid))
			if field == "version":
				check(state.convert_external_save(broken).is_empty(),"Malformed native version rejected before conversion")
				check(not state._import_external_save_to_paths(broken,"user://invalid-import.json","user://invalid-recovery.json","user://invalid-backup.json"),"Malformed native import rejected safely")
			check(state.money == baseline.money and state.day == baseline.day and state.plots == baseline.plots,"Reject before live-state mutation")
			check(FileAccess.get_file_as_string("user://quality-valid.json") == before_disk,"Reject preserves disk")
	for version: int in range(1,32):
		var compatible := baseline.duplicate(true);compatible.version=version
		check(state.load_game_data(compatible),"Existing native version remains readable "+str(version))
	check(state.load_game_data(baseline),"Current snapshot round trip")
	var farm_care := baseline.duplicate(true)
	farm_care.plots[0].care = 2
	check(state.load_game_data(farm_care),"Numeric farm care remains loadable")
	farm_care.plots[0].care = {}
	check(not state.load_game_data(farm_care),"Animal care dictionary is invalid on a farm plot")
	check(state.load_game_data(baseline),"Restore after care compatibility check")
	var detached := Node2D.new()
	check(not load("res://scripts/life_presentation.gd").visible_rect(detached).has_area(),"Detached scene signal has no viewport")
	detached.free()
	var rig := preload("res://scripts/painted_wardrobe.gd")
	var first: Dictionary = rig.pose_for("bike",0,-1,1)
	var half: Dictionary = rig.pose_for("bike",1.0/6.0,-1,1)
	check(first.leg_near != half.leg_near and first.leg_far != half.leg_far,"Bicycle pedals move continuously")
	check(is_equal_approx(float(half.leg_near)+float(half.leg_far),1.2),"Pedals remain half a cycle apart")
	var animation := preload("res://scripts/interior_animation.gd")
	check(animation.pose("mill",0,true,{}, {},true) != animation.pose("mill",0.42,true,{}, {},true),"Processing furniture has authored moving frames")
	check(animation.pose("mill",0.42,true,{}, {},false).offset == Vector2.ZERO,"Reduced animation preserves static furniture")
	var master := AudioServer.get_bus_index("Master")
	check(AudioServer.get_bus_effect_count(master) == 1 and AudioServer.get_bus_effect(master,0) is AudioEffectHardLimiter,"Master mixer limits overlapping peaks")
	check(is_equal_approx(AudioServer.get_bus_effect(master,0).ceiling_db,-1.0),"Mixer retains one decibel headroom")
	print("QUALITY_PASS: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
