extends SceneTree
var passed:=0
var failed:=0
var sounds:Array=[]
var played:Array=[]
var vibrations:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func finish(state:Node)->void:
 for step in range(60):state._process_action(0.1)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 var audio:=root.get_node("AudioService");audio.set_process(false)
 state.sound_requested.connect(func(kind:String):sounds.append(kind))
 state.vibration_requested.connect(func():vibrations+=1)
 audio.sound_played.connect(func(kind:String):played.append(kind))
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("OPERATION_AUDIO_FIXTURE")))
 for row in fixture.confirmations:
  state.player_settings.merge(row.settings,true);audio.apply_settings()
  sounds.clear();played.clear();vibrations=0
  check(state.confirm_operation(bool(row.ok))==row.result,"source apply result")
  check(sounds==row.sounds and played==row.played,"requested and actually played sounds")
  check(vibrations==row.rumble.size(),"source apply haptic only")
 state.player_settings.sound=true;state.player_settings.volume=0.2;state.player_settings.effects=0.6;state.player_settings.vibration=true;audio.apply_settings()
 for row in fixture.fills:
  check(state.load_game_data(state.convert_external_save(row.before)),"source fill state import")
  state.player_settings.vibration=true
  sounds.clear();vibrations=0
  var ok:bool=state.confirm_operation(state.fill_farm_water())
  check(ok==row.result.ok and state.message==row.result.msg,"source F.fillWater outcome")
  check(state.farm.water==row.after.water and state.money==row.after.money and state.stamina==row.after.stamina and state.minutes==row.after.minutes and state.legacy_systems.waterReserve==row.after.reserve,"source water costs/time/legacy reserve")
  check(sounds==(["good"] if ok else []) and vibrations==(1 if ok else 0),"fill confirms exact outcome")
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.player_settings.sound=true;state.player_settings.effects=0.6;state.player_settings.volume=0.2;state.player_settings.vibration=true
 for ready in [true,false]:
  hud.close_top_panel();state.cancel_action()
  state.skills.farming={"xp":30 if ready else 0,"choice":null}
  hud.show_skills()
  sounds.clear();vibrations=0
  hud.skills_panel._select_skill("farming","gentle")
  check(state.action_busy() and sounds.is_empty(),"no sound before middle")
  finish(state)
  check(sounds==(["read","good"] if ready else ["read"]),"real skill UI middle and success only")
  check(vibrations==(1 if ready else 0),"real UI haptics on apply only")
  hud.close_top_panel()
 # A valid operation whose state does not change still gets its source confirmation.
 state.stamina=100;state.minutes=1320
 sounds.clear();vibrations=0
 world._interact_target({"kind":"rest","x":world.player.position.x,"y":world.player.position.y},true)
 check(sounds==["good"] and vibrations==1,"successful no-change rest")
 sounds.clear();vibrations=0
 state.money+=10;state.relations.granny.points+=1;state.farm.beds[0].moisture=0
 state.changed.emit()
 check(sounds.is_empty() and vibrations==0,"arbitrary state changes never infer a sound")
 sounds.clear()
 state._make_save_data();hud.show_neighbors();hud.close_top_panel()
 check(sounds.is_empty(),"save snapshots and roster reads silent")
 sounds.clear()
 check(state.begin_action(state.ACTION_RULES.spec("read","取消"),{"kind":"ui","x":0,"y":0},func():state.confirm_operation(true)),"start cancellable action")
 state.cancel_action()
 finish(state)
 check(sounds.is_empty(),"cancelled before middle no sound or confirmation")
 print("Operation audio: %d passed, %d failed"%[passed,failed])
 await audio.prepare_exit()
 quit(1 if failed else 0)
