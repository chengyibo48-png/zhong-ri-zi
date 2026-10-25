extends SceneTree
const SELECTOR=preload("res://scripts/interaction_selection.gd")
const DESCRIBE=preload("res://scripts/interaction_description.gd")
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
var probes:=0
var state:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=15:push_error(label)
func readiness(point:Dictionary,tool:String)->bool:
 probes+=1
 return bool(DESCRIBE.describe(state,point,tool).get("ready",false))
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SELECTION_READINESS_FIXTURE"))))
 for row in fixture.rows:
  var input:Dictionary=row.before
  var converted:Dictionary=state.convert_external_save(input)
  state.plots.assign(converted.plots);state.farm=input.farm.duplicate(true);state._normalize_plots()
  state.day=int(input.day);state.minutes=float(input.minutes);state.stamina=int(input.stamina);state.selected_seed=str(input.seed);state.money=int(input.money)
  state.inventory=input.bag.duplicate(true);state.toolkit=input.toolkit.duplicate(true);state.skills=input.skills.duplicate(true)
  state.legacy_systems.buffs=input.buffs.duplicate(true);state.legacy_systems.toolUpgrades=input.toolUpgrades.duplicate(true);state.kitchen=input.kitchen.duplicate(true)
  var saved:Dictionary=state._make_save_data().duplicate(true)
  var selection:=SELECTOR.new()
  for step in row.steps:
   probes=0
   var chosen:Dictionary=selection.choose(Vector2(100,100),Vector2.DOWN,row.points,step.hover if step.hover is Dictionary else {},row.tool,"",readiness)
   var label:String=row.variant+"/"+str(row.stamina)+"/"+row.tool
   check(selection.target_key(chosen)==step.expected,"chosen "+label)
   check(probes==5,"only nearby candidates probed "+label)
   var order:Array=[]
   for option in selection.options:order.append(selection.target_key(option))
   check(order==step.order,"order "+label)
   for i in range(selection.options.size()):
    check(selection.target_key(selection.options[i])==step.options[i].key,"key "+label)
    check(float(selection.options[i].score)==float(step.options[i].score),"score "+label)
    check(selection.options[i].ready==step.options[i].ready,"ready "+label)
  check(state._make_save_data()==saved,"selection is read-only")
 # Check both real worlds pass the same production readiness callback.
 for scene in ["res://scenes/main.tscn","res://scenes/interior.tscn"]:
  if scene.contains("interior"):state.current_interior="building-river-10"
  change_scene_to_file(scene)
  await process_frame
  await process_frame
  var world=current_scene
  if world==null:check(false,"real scene loaded");continue
  world.set_process(false)
  state.stamina=0
  var candidates:Array=world._world_target_candidates() if scene.contains("main") else world._room_target_candidates()
  if candidates.is_empty():check(false,"real world candidates");continue
  world.player.global_position=Vector2(float(candidates[0].x),float(candidates[0].y))
  if scene.contains("main"):world._refresh_world_target()
  else:world._refresh_room_target()
  for option in world.interaction_selection.options:
   check(option.ready==readiness(option,state.selected_tool),"actual world readiness "+scene)
 await root.get_node("AudioService").prepare_exit()
 print("SELECTION_READINESS_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",fixture.rows.size()," states")
 quit(0 if failed==0 else 1)
