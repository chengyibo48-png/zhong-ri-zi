extends SceneTree
const RULES=preload("res://scripts/source_audio_rules.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:
  failed+=1
  if failed<12:push_error(label)
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b))<=1e-12
 return a==b
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 var audio:=root.get_node("AudioService");audio.set_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("AUDIO_FIXTURE")))
 for row in fixture.sounds:
  check(same(RULES.sound(str(row.kind),row.settings),row.expected),"source sound recipe "+str(row.kind)+str(row.settings))
 for row in fixture.ambient:
  var p:Dictionary=row.options
  check(same(RULES.ambient(float(row.seconds),float(p.next),bool(row.active),bool(p.hidden),bool(p.panel),row.settings,int(p.season),bool(p.wet),bool(p.night),bool(p.town),bool(p.indoors)),row.expected),"source ambient "+str(p))
 check(not audio.context_active and audio.current_music==null,"no music before first enabled sound")
 state.player_settings.sound=false
 audio.play_sfx("good")
 check(not audio.context_active,"disabled sound does not activate")
 state.player_settings.sound=true;state.player_settings.volume=0.2;state.player_settings.effects=0.6;state.player_settings.music=0.35;state.player_settings.ambient=0.3
 var kinds:Array=[];audio.sound_played.connect(func(kind:String):kinds.append(kind))
 audio.play_sfx("seed")
 check(audio.context_active and kinds==["seed"],"explicit sound activates once")
 var player=audio.sfx_players[0]
 check(player.pitch_scale==1.0 and player.stream.data.size()==int(0.32*audio.SAMPLE_RATE)*2 and player.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"source duration and fixed pitch")
 state.ui_open=true
 var next:float=audio.melody_at
 audio.ambient_at(100)
 check(audio.melody_at==next and audio.current_music==null,"modal pauses ambient scheduler")
 state.ui_open=false
 var plan:Dictionary=audio.ambient_at(100)
 check(audio.melody_at==108 and not plan.music.is_empty(),"source eight-second scheduling")
 check(audio.current_music.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and audio.current_music.stream.data.size()==int(2.9*audio.SAMPLE_RATE)*2,"three scheduled notes without continuous loop")
 var second:Dictionary=audio.ambient_at(107.999)
 check(second.music.is_empty() and second.ambient.is_empty() and audio.melody_at==108,"no early ambient")
 for name in ["Master","Music","SFX","Ambience"]:
  check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(name))==0.0,"source gains not multiplied twice")
 var active_voices:Array=[]
 for pool in [audio.sfx_players,audio.music_players,audio.ambient_players]:
  for voice in pool:
   if voice.playing:active_voices.append(voice)
 check(not active_voices.is_empty(),"real voices playing before suspend")
 state.player_settings.sound=false;state.changed.emit()
 for voice in active_voices:check(voice.stream_paused,"source suspend pauses existing voices")
 state.player_settings.sound=true;state.changed.emit()
 for voice in active_voices:check(not voice.stream_paused,"source resume keeps existing voices")
 var recipe:Dictionary=RULES.sound("good",state.player_settings)
 check(RULES.envelope(recipe.voices[0],0)==0.0 and is_equal_approx(RULES.envelope(recipe.voices[0],0.02),0.0264) and is_equal_approx(RULES.envelope(recipe.voices[0],0.3),0.0001),"sample envelope landmarks")
 audio.shutdown()
 check(audio.current_music==null and audio.stream_cache.is_empty() and audio.music_cache.is_empty(),"shutdown releases all streams")
 for pool in [audio.sfx_players,audio.music_players,audio.ambient_players]:
  for voice in pool:check(voice.stream==null and not voice.playing,"voice cleanup")
 print("Source audio: %d passed, %d failed"%[passed,failed])
 await audio.prepare_exit()
 quit(1 if failed else 0)
