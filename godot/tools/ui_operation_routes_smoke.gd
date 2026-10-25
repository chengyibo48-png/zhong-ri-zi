extends SceneTree
var passed:=0
var failed:=0
var sounds:Array=[]
var vibrations:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 var audio:=root.get_node("AudioService");audio.set_process(false)
 state.sound_requested.connect(func(kind:String):sounds.append(kind))
 state.vibration_requested.connect(func():vibrations+=1)
 state.player_settings.vibration=true
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.building.house=3
 hud.show_building({},true)
 var panel=hud.building_panel
 for setting in ["style","roomUse","showcase"]:
  var control=panel.style_option if setting=="style" else panel.room_use_option if setting=="roomUse" else panel.showcase_option
  var index:=1 if control.item_count>1 else 0
  var revision:int=state.building.revision
  check(state.save_game(state.SAVE_PATH,true),"prepare dropdown baseline")
  var previous_file:=FileAccess.get_file_as_string(state.SAVE_PATH)
  sounds.clear();vibrations=0
  control.item_selected.emit(index)
  check(state.building.revision==revision+1 and sounds==["good"] and vibrations==1,"actual building dropdown "+setting)
  var saved:Variant=state._read_save_json(state.SAVE_PATH)
  check(saved is Dictionary and int(saved.building.revision)==revision+1 and saved.building.get(setting)==state.building.get(setting),"actual building dropdown immediately saved "+setting)
  check(FileAccess.get_file_as_string(state.SAVE_PATH+".bak")==previous_file,"dropdown keeps previous save backup "+setting)
 hud.close_top_panel()
 for field in ["branch","shape"]:
  for ready in [true,false]:
   state.toolkit.tools.hoe.level=2 if ready else 0
   state.toolkit.tools.hoe.branch="broad";state.toolkit.tools.hoe.shape="single"
   hud.show_tools(true)
   hud.tool_panel.selected_id="hoe";hud.tool_panel.refresh()
   sounds.clear();vibrations=0
   if field=="branch":hud.tool_panel.branch_button.pressed.emit()
   else:hud.tool_panel.shape_button.pressed.emit()
   check(state.action_busy() and not hud.tool_panel.visible and sounds.is_empty(),"tool starts read action")
   check(state.toolkit.tools.hoe.branch=="broad" and state.toolkit.tools.hoe.shape=="single","tool no early commit")
   for step in range(60):state._process_action(0.1)
   var expected:Variant=("care" if field=="branch" else "row") if ready else ("broad" if field=="branch" else "single")
   check(state.toolkit.tools.hoe[field]==expected,"tool commit result")
   check(sounds==(["read","good"] if ready else ["read"]) and vibrations==(1 if ready else 0),"tool middle/confirm/haptic")
   check(hud.tool_panel.visible and state.ui_open,"tool page restored")
   hud.close_top_panel()
 state.toolkit.tools.hoe.level=2;state.toolkit.tools.hoe.branch="broad"
 hud.show_tools(true)
 sounds.clear();vibrations=0
 hud.tool_panel.branch_button.pressed.emit();state.cancel_action()
 for step in range(60):state._process_action(0.1)
 check(state.toolkit.tools.hoe.branch=="broad" and sounds.is_empty() and vibrations==0,"tool cancelled no commit")
 check(hud.tool_panel.visible and state.ui_open,"tool cancelled page restored")
 print("UI operation routes: %d passed, %d failed"%[passed,failed])
 await audio.prepare_exit()
 quit(1 if failed else 0)
