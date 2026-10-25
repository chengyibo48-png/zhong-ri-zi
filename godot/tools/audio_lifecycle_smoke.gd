extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	await process_frame
	var state := root.get_node("GameState")
	var audio := root.get_node("AudioService")
	state.set_process(false); audio.set_process(false)
	state.ui_open = false
	check(not auto_accept_quit, "window close waits for audio disposal")
	check(audio.sfx_players.size() == 6 and audio.music_players.size() == 2 and audio.ambient_players.size() == 2, "all source playback pools")
	check(audio.current_music == null and not audio.context_active, "source context activates on first sound")
	audio.play_sfx("good")
	audio.ambient_at(1000.0)
	check(audio.context_active and audio.current_music != null, "first interaction activates source melody")
	check(not audio.stream_cache.is_empty() and not audio.music_cache.is_empty(), "active caches populated")
	var refs: Array = []
	for player in audio.sfx_players + audio.music_players + audio.ambient_players:
		if player.stream != null:
			check(player.stream.mix_rate == audio.SAMPLE_RATE and not player.stream.data.is_empty(), "real PCM stream")
			refs.append(weakref(player.stream))
		if player.has_stream_playback(): refs.append(weakref(player.get_stream_playback()))
	state.player_settings.sound = false; audio.apply_settings()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "sound setting mutes all buses")
	state.player_settings.sound = true; audio.apply_settings()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "sound setting restores source audio")
	audio.shutdown()
	check(audio.shutting_down and not audio.is_processing(), "shutdown stops scheduling")
	check(audio.current_music == null and audio.music_tween == null and audio.stream_cache.is_empty() and audio.music_cache.is_empty(), "shutdown releases all caches")
	for player in audio.sfx_players + audio.music_players + audio.ambient_players:
		check(not player.playing and player.stream == null, "shutdown clears every player")
	check(not state.sound_requested.is_connected(audio._on_sound_requested), "disconnect sound signal")
	check(not state.changed.is_connected(audio.apply_settings), "disconnect settings signal")
	check(not state.vibration_requested.is_connected(audio._on_vibration_requested), "disconnect haptics signal")
	audio.shutdown(); audio.play_sfx("harvest")
	var plan: Dictionary = audio.ambient_at(2000.0)
	check(plan.music.is_empty() and plan.ambient.is_empty() and audio.current_music == null, "late scheduler cannot restart music after shutdown")
	await audio.prepare_exit()
	for reference in refs: check(reference.get_ref() == null, "audio thread releases streams and playback")
	print("Audio lifecycle migration: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
