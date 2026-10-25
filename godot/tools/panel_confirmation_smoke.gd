extends SceneTree
var passed:=0
var failed:=0
var sounds:Array=[]
var vibrations:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:
  failed+=1
  if failed<12:push_error(label)
func normalized(v:Variant)->Variant:return preload("res://scripts/save_json.gd").parse(preload("res://scripts/save_json.gd").encode(v))
func settle()->void:
 await process_frame
 await process_frame
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var fixture:Dictionary=preload("res://scripts/save_json.gd").parse(FileAccess.get_file_as_string(OS.get_environment("PANEL_CONFIRMATION_FIXTURE")))
 var state:=root.get_node("GameState");state.set_process(false)
 var audio:=root.get_node("AudioService");audio.set_process(false)
 state.sound_requested.connect(func(kind:String):sounds.append(kind))
 state.vibration_requested.connect(func():vibrations+=1)
 for row in fixture.missing:
  check(state.load_game_data(state.convert_external_save(row.before)),"missing optional source import")
  for key in row.keys:
   var actual:Dictionary=normalized(state.get(str(key)))
   var expected:Dictionary=row.expected[key].duplicate(true)
   if key=="neighbors":
    for id in expected.people:
     for field in ["event","last"]:
      if expected.people[id][field]==null:expected.people[id][field]={}
   if key=="farm" and not expected.has("stock"):
    check(actual.get("stock",[])==[],"native empty reusable facility stock")
    actual.erase("stock")
   check(actual==expected,"missing system defaults "+str(key))
  var snap:Dictionary=state.feedback_action_snapshot()
  check(snap.has("world") and snap.world.has("fishCasts"),"old save actual action snapshot")
 for row in fixture.claims:
  state.building=row.before.building.duplicate(true);state.furniture=row.before.furniture.duplicate(true)
  state.player_settings.vibration=true;sounds.clear();vibrations=0
  var ok:bool=state.confirm_operation(state.claim_building_milestone(str(row.id)))
  check(ok==row.result.ok and state.message==row.result.msg,"source milestone outcome")
  check(normalized(state.building)==row.after.building and normalized(state.furniture)==row.after.furniture,"source milestone exact state")
  check(sounds==(["good"] if ok else []) and vibrations==(1 if ok else 0),"milestone feedback")
 for row in fixture.retire:
  check(state.load_game_data(state.convert_external_save(row.before)),"retire valid source import")
  check(state.perform_ranch_task(row.task)==row.result.ok and state.message==row.result.msg,"source retirement result")
  var index:int=state.ranch_animal_index(str(row.id))
  check(normalized(state.animals[index])==row.after,"retirement exact animal")
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.building.house=1;state.building.claimed=[];state.furniture.lantern=999
 state.player_settings.vibration=true
 hud.show_building({},true)
 sounds.clear();vibrations=0
 hud.building_panel.milestone_buttons.home.pressed.emit()
 check(state.furniture.lantern==1000 and state.building.claimed.has("home"),"actual milestone button over 999")
 check(sounds==["good"] and vibrations==1,"actual milestone button confirms")
 sounds.clear();vibrations=0
 hud.building_panel.milestone_buttons.home.pressed.emit()
 check(sounds.is_empty() and vibrations==0 and state.furniture.lantern==1000,"repeat claim no reward/sound")
 hud.close_top_panel()
 for row in fixture.retire:
  check(state.load_game_data(state.convert_external_save(row.before)),"UI retirement source state")
  var index:int=state.ranch_animal_index(str(row.id))
  var animal:Dictionary=state.animals[index]
  animal.position.room=null
  world.player.position=Vector2(float(animal.position.x)+38,float(animal.position.y))
  state.player_position=world.player.position
  hud.show_ranch()
  hud.ranch_panel.selected_animal_id=str(row.id)
  var retired_before:bool=animal.retired
  sounds.clear();vibrations=0
  hud.ranch_panel._toggle_retirement()
  check(not hud.ranch_panel.visible and (not state.ranch_active_task.is_empty() or state.action_busy()),"retirement closes panel and queues actual travel")
  check(bool(animal.retired)==retired_before and sounds.is_empty(),"retirement does not commit before action")
  var at:Dictionary=state.ranch_task_destination(state.ranch_active_task)
  world.player.position=Vector2(float(at.x),float(at.y))
  state.walking_target.clear()
  state.finish_ranch_task(at)
  for step in range(60):state._process_action(0.1)
  check(bool(animal.retired)==bool(row.after.retired),"actual retirement UI settles")
  check(sounds==(["pet","good"] if row.result.ok else ["pet"]),"retirement middle and success sounds")
  check(vibrations==0,"queued retirement no apply vibration")
  state.cancel_ranch_queue();state.cancel_action()
 print("Panel confirmation: %d passed, %d failed"%[passed,failed])
 await audio.prepare_exit()
 quit(1 if failed else 0)
