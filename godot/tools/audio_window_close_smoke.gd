extends SceneTree

var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		quit(1)
		return
	var state = root.get_node("GameState")
	var audio = root.get_node("AudioService")
	state.set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	check(is_instance_valid(world.hud) and is_instance_valid(world.player), "实际主场景就绪")
	check(audio.current_music == null and not audio.context_active, "首个声音前不自动播放音乐")
	state.ui_open = false
	audio.play_sfx("good")
	audio.ambient_at(1000.0)
	check(audio.current_music != null and audio.current_music.playing, "退出时有原版三枚音符")
	check(audio.ambient_players[0].stream != null, "退出时有环境声音")
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(audio.quit_requested and audio.shutting_down, "窗口关闭通知开始清理")
	check(audio.current_music == null and audio.stream_cache.is_empty() and audio.music_cache.is_empty(), "关闭清空音频引用")
	for pool in [audio.sfx_players, audio.music_players, audio.ambient_players]:
		for voice in pool:check(voice.stream == null and not voice.playing, "关闭释放声音流")
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(audio.quit_requested and audio.music_tween == null, "重复通知不重启回调")
	print("Audio window close migration: %d passed, %d failed" % [passed, failed])
	# AudioService owns the deferred quit; a failed assertion retains nonzero status.
	if failed > 0:
		await audio.prepare_exit()
		quit(1)
