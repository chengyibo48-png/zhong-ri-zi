extends SceneTree
const DESCRIBE=preload("res://scripts/interaction_description.gd")
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;if failed<=15:push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=CODEC.decode(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PLOT_INTERACTION_FIXTURE"))))
 for row in fixture.rows:
  var input:Dictionary=row.before
  var converted:Dictionary=state.convert_external_save(input)
  state.plots.assign(converted.plots)
  state.farm=input.farm.duplicate(true)
  state._normalize_plots()
  state.day=int(input.day);state.minutes=float(input.minutes);state.stamina=int(input.stamina);state.selected_seed=str(input.seed)
  state.inventory=input.bag.duplicate(true);state.toolkit=input.toolkit.duplicate(true);state.skills=input.skills.duplicate(true)
  state.legacy_systems.buffs=input.buffs.duplicate(true);state.legacy_systems.toolUpgrades=input.toolUpgrades.duplicate(true)
  state.kitchen=input.kitchen.duplicate(true)
  var before:Dictionary=state._make_save_data().duplicate(true)
  var label:String=row.crop+"/"+row.variant
  var index:int=int(row.index)
  for sample in row.samples:
   var actual:Dictionary=DESCRIBE.describe(state,{"kind":"plot","index":index},sample.tool)
   for field in ["name","verb","state","reason","detail","ready"]:
    check(actual.get(field)==sample.expected[field],label+"/"+sample.tool+" "+field+" got "+str(actual.get(field))+" expected "+str(sample.expected[field]))
  check(DESCRIBE.plot_stage(state,index)==row.stage,"plot stage "+label)
  var preview:Dictionary=DESCRIBE.plot_preview(state,index)
  if row.preview==null:check(preview.is_empty(),"empty plot preview "+label)
  else:
   check(float(preview.grade)==float(row.preview.grade),"plot preview grade "+label)
   check(float(preview.qty)==float(row.preview.qty),"plot preview qty "+label)
   check(preview.seed==row.preview.seed,"plot preview seed "+label)
  check(state._make_save_data()==before,"read-only plot description "+label)
 await root.get_node("AudioService").prepare_exit()
 print("PLOT_INTERACTION_SOURCE_SMOKE: ",passed," passed, ",failed," failed; ",fixture.rows.size()," states")
 quit(0 if failed==0 else 1)
