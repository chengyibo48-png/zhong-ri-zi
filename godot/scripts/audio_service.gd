extends Node
class_name AudioServiceNode
const RULES = preload("res://scripts/source_audio_rules.gd")
const SAMPLE_RATE := 44100
signal sound_played(kind: String)
signal ambient_scheduled(plan: Dictionary)
var rng := RandomNumberGenerator.new()
var sfx_players: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var ambient_players: Array[AudioStreamPlayer] = []
var stream_cache: Dictionary = {}
var music_cache: Dictionary = {}
var current_music: AudioStreamPlayer
var music_tween: Tween
var shutting_down := false
var quit_requested := false
var context_active := false
var melody_at := 0.0

func _ready() -> void:
 get_tree().auto_accept_quit = false
 rng.randomize()
 for spec in [["SFX",sfx_players,6],["Music",music_players,2],["Ambience",ambient_players,2]]:
  for index in range(int(spec[2])):
   var player := AudioStreamPlayer.new()
   if OS.has_feature("web"):player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
   player.bus = str(spec[0])
   add_child(player)
   spec[1].append(player)
 GameState.sound_requested.connect(_on_sound_requested)
 GameState.vibration_requested.connect(_on_vibration_requested)
 GameState.changed.connect(apply_settings)
 apply_settings()

func _on_sound_requested(kind: String) -> void:
 play_sfx(kind)

func _on_vibration_requested() -> void:
 var pads := Input.get_connected_joypads()
 if not pads.is_empty():Input.start_joy_vibration(int(pads[0]),0.12,0.0,0.06)

func apply_settings() -> void:
 # Source amplitudes are baked into each short-lived stream. Do not multiply
 # the settings twice or alter voices already scheduled by the original plan.
 for player in sfx_players+music_players+ambient_players:
  player.stream_paused=not bool(GameState.player_settings.get("sound",true))
 for name in ["Master","Music","Ambience","SFX"]:
  var index := AudioServer.get_bus_index(name)
  if index<0:continue
  AudioServer.set_bus_volume_db(index,0.0)
  AudioServer.set_bus_mute(index,name=="Master" and not bool(GameState.player_settings.get("sound",true)))

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST:
  request_quit()

func request_quit(exit_code: int = 0) -> void:
 if quit_requested: return
 quit_requested = true
 if is_instance_valid(GameState) and not GameState.save_game(GameState.SAVE_PATH,true):
  quit_requested = false
  return
 await prepare_exit()
 get_tree().quit(exit_code)

func prepare_exit() -> void:
 shutdown()
 # stop() queues playback cleanup on the audio thread. Keep the tree alive
 # briefly so the audio driver and main-thread disposal queue can run.
 var deadline := Time.get_ticks_msec() + 150
 while Time.get_ticks_msec() < deadline:
  await get_tree().create_timer(0.01, true, false, true).timeout
 await get_tree().process_frame
 await get_tree().process_frame

func shutdown() -> void:
 if shutting_down: return
 shutting_down = true
 set_process(false)
 if music_tween != null and music_tween.is_valid(): music_tween.kill()
 music_tween = null
 if is_instance_valid(GameState):
  if GameState.sound_requested.is_connected(_on_sound_requested):
   GameState.sound_requested.disconnect(_on_sound_requested)
  if GameState.vibration_requested.is_connected(_on_vibration_requested):
   GameState.vibration_requested.disconnect(_on_vibration_requested)
  if GameState.changed.is_connected(apply_settings):
   GameState.changed.disconnect(apply_settings)
 for player in sfx_players + music_players + ambient_players:
  if is_instance_valid(player):
   player.stop()
   player.stream = null
 current_music = null
 stream_cache.clear()
 music_cache.clear()

func _exit_tree() -> void:
 shutdown()


func play_sfx(kind: String) -> void:
 if shutting_down or sfx_players.is_empty():return
 var recipe := RULES.sound(kind,GameState.player_settings)
 if bool(recipe.activate):context_active = true
 if recipe.voices.is_empty():return
 var key := JSON.stringify(recipe)
 if not stream_cache.has(key):
  if stream_cache.size()>=64:stream_cache.clear()
  stream_cache[key] = _make_stream(recipe.voices)
 var player := _free_player(sfx_players)
 player.stream = stream_cache[key]
 player.pitch_scale = 1.0
 player.play()
 sound_played.emit(kind)

func _free_player(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
 for player in players:
  if not player.playing:return player
 return players[0]

func _process(_delta: float) -> void:
 if shutting_down:return
 ambient_at(float(Time.get_ticks_msec())/1000.0)

func ambient_at(seconds: float) -> Dictionary:
 if shutting_down:return {"next":melody_at,"music":[],"ambient":[]}
 var region := GameState.atlas_region_point(GameState.player_position.x,GameState.player_position.y)
 var wet: bool = GameState.weather_for(GameState.day) in ["雨","台风"] or region=="river"
 var plan := RULES.ambient(seconds,melody_at,context_active,GameState.simulation_hidden(),GameState.ui_open,GameState.player_settings,GameState.season_index(),wet,GameState.minutes>1140.0,region=="town",GameState.current_interior!="")
 if float(plan.next)==melody_at:return plan
 melody_at = float(plan.next)
 if not plan.music.is_empty():
  var key := JSON.stringify(plan.music)
  if not music_cache.has(key):
   if music_cache.size()>=64:music_cache.clear()
   music_cache[key] = _make_stream(plan.music)
  current_music = _free_player(music_players)
  current_music.stream = music_cache[key]
  current_music.play()
 if not plan.ambient.is_empty():
  var player := _free_player(ambient_players)
  player.stream = _make_stream(plan.ambient)
  player.play()
 ambient_scheduled.emit(plan)
 return plan

func _make_sfx_stream(kind: String) -> AudioStreamWAV:
 return _make_stream(RULES.sound(kind,GameState.player_settings).voices)

func _make_stream(voices: Array) -> AudioStreamWAV:
 var duration := 0.0
 for voice in voices:duration=maxf(duration,float(voice.end))
 var frame_count := int(round(duration*SAMPLE_RATE))
 var mixed := PackedFloat64Array()
 mixed.resize(frame_count)
 for voice in voices:
  var first := int(round(float(voice.start)*SAMPLE_RATE))
  var last := mini(frame_count,int(round(float(voice.end)*SAMPLE_RATE)))
  var noise := str(voice.wave)=="noise"
  var a0 := 1.0
  var a1 := 0.0
  var a2 := 0.0
  var b0 := 0.0
  var b1 := 0.0
  var b2 := 0.0
  if noise:
   var omega := TAU*float(voice.filter)/SAMPLE_RATE
   var cosine := cos(omega)
   # Web Audio lowpass Q defaults to 1 dB, not Butterworth Q.
   # https://www.w3.org/TR/webaudio-1.0/#filters-characteristics
   var alpha := sin(omega)/(2.0*pow(10.0,float(voice.get("q",1.0))/20.0))
   a0=1.0+alpha;a1=-2.0*cosine/a0;a2=(1.0-alpha)/a0
   b0=(1.0-cosine)/2.0/a0;b1=(1.0-cosine)/a0;b2=b0
  var x1 := 0.0
  var x2 := 0.0
  var y1 := 0.0
  var y2 := 0.0
  for frame in range(first,last):
   var seconds := float(frame)/SAMPLE_RATE
   var tone := 0.0
   if noise:
    var x := rng.randf_range(-1.0,1.0)*float(voice.noise)
    tone=b0*x+b1*x1+b2*x2-a1*y1-a2*y2
    x2=x1;x1=x;y2=y1;y1=tone
   else:
    tone=sin(RULES.phase(voice,seconds))
    if str(voice.wave)=="triangle":tone=asin(tone)*2.0/PI
   mixed[frame]+=tone*RULES.envelope(voice,seconds)
 var bytes := PackedByteArray()
 bytes.resize(frame_count*2)
 for frame in range(frame_count):_write_sample(bytes,frame,mixed[frame])
 var stream := AudioStreamWAV.new()
 stream.format=AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate=SAMPLE_RATE
 stream.stereo=false
 stream.data=bytes
 return stream

func _write_sample(bytes: PackedByteArray, frame: int, value: float) -> void:
 var pcm := clampi(roundi(clampf(value,-1.0,1.0)*32767.0),-32767,32767)
 bytes[frame*2]=pcm&255
 bytes[frame*2+1]=(pcm>>8)&255
