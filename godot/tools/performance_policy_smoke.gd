extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1
	else: failed += 1;push_error(title)
func run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
	var policy := preload("res://scripts/performance_policy.gd")
	for adapter: String in ["Intel UHD Graphics 620","Intel Iris Xe Graphics","AMD Radeon(TM) Graphics","AMD Radeon Graphics","AMD Radeon Vega 8 Graphics","AMD Radeon 780M","AMD Radeon(TM) 890M Graphics"]:
		check(policy.integrated_adapter(adapter),"Recognize conservative integrated names: "+adapter)
		check(policy.frame_cap(adapter,false)==60,"Automatic integrated cap: "+adapter)
	for adapter: String in ["NVIDIA GeForce RTX 3060 Laptop GPU","AMD Radeon RX 7800 XT","AMD Radeon RX 6800M","AMD Radeon Pro W7900"]:
		check(not policy.integrated_adapter(adapter),"Do not classify discrete AMD as integrated: "+adapter)
		check(policy.frame_cap(adapter,false)==0,"Retain automatic discrete policy: "+adapter)
	check(policy.frame_cap("NVIDIA",false,"light")==30,"Manual saving mode cap")
	check(policy.frame_cap("NVIDIA",true)==30,"Phone automatic cap")
	check(policy.frame_cap("NVIDIA",false,"auto",true)==60,"Existing forced light environment remains compatible")
	var state := root.get_node("GameState")
	state.set_process(false)
	var baseline: Dictionary = state._make_save_data().duplicate(true)
	var light := baseline.duplicate(true);light.player_settings.performance="light";light.player_settings.textSpeed="slow"
	check(state.load_game_data(light) and Engine.max_fps==30,"Load applies saved frame mode immediately")
	var saved: Dictionary = state._make_save_data().duplicate(true)
	check(saved.player_settings.performance=="light","Mode survives snapshot capture")
	var panel: Control = load("res://scripts/settings_panel.gd").new()
	root.add_child(panel);panel.visible=true;panel.refresh()
	check(panel.performance_option.selected==1,"Settings reflect loaded mode")
	check(panel.text_speed_option.selected==2,"Settings reflect the saved dialogue speed")
	panel._choose_option(0,"textSpeed",panel.text_speed_option)
	check(state.player_settings.textSpeed=="instant","Restored dialogue speed remains editable")
	panel._choose_option(0,"performance",panel.performance_option)
	check(state.player_settings.performance=="auto","Manual automatic option persists")
	check(Engine.max_fps==policy.frame_cap(RenderingServer.get_video_adapter_name(),false),"Switching back restores automatic policy")
	panel.queue_free();await process_frame
	check(state.load_game_data(baseline),"Restore original save")
	print("Performance policy: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
