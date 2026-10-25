extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:failed+=1;push_error(label)
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in range(a.size()):
   if not same(a[i],b[i]):return false
  return true
 return a==b
func run():
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 var fixture_file=FileAccess.open(OS.get_environment("SOURCE_SAVE_VALIDATION_FIXTURE"),FileAccess.READ)
 if fixture_file==null:push_error("Missing source save fixture");quit(1);return
 var validator=preload("res://scripts/source_save_validation.gd")
 var cases:=0
 var expected_cases:=0
 while not fixture_file.eof_reached():
  var line:String=fixture_file.get_line()
  if line=="":continue
  var parsed:Variant=preload("res://scripts/save_json.gd").parse(line)
  if not parsed is Dictionary:push_error("Invalid source fixture row %d"%cases);quit(1);return
  var row:Dictionary=parsed
  if row.has("caseCount"):expected_cases=int(row.caseCount);continue
  cases+=1
  if cases%100==0:print("SOURCE_SAVE_PROGRESS: %d"%cases)
  var actual_error:String=validator.error(row.before,state.item_catalog,state.crop_catalog,state.content.scenes,state.content,state.system_catalog,state.world_village)
  check(actual_error==row.error,"source rejection "+row.label+" got "+actual_error+" expected "+str(row.error))
  var save_path:="user://validation-save.json";var recovery:="user://validation-recovery.json";var backup:="user://validation-backup.json"
  check(state.save_game(save_path,true) and state._write_snapshot(recovery) and state._write_snapshot(backup),"baseline files")
  var before_files:=[FileAccess.get_file_as_string(save_path),FileAccess.get_file_as_string(recovery),FileAccess.get_file_as_string(backup)]
  var prior:Dictionary={"money":state.money,"day":state.day,"inventory":state.inventory.duplicate(true),"plots":state.plots.duplicate(true)}
  var ok:bool=state._import_external_save_to_paths(row.before,save_path,recovery,backup)
  if row.error!="":
   check(not ok and state.message==row.error,"actual import rejects before conversion "+row.label)
   check(state.money==prior.money and state.day==prior.day and state.inventory==prior.inventory and state.plots==prior.plots,"rejected progress unchanged")
   check(before_files==[FileAccess.get_file_as_string(save_path),FileAccess.get_file_as_string(recovery),FileAccess.get_file_as_string(backup)],"rejected import preserves all three files")
  else:
   check(ok,"valid import preserved "+row.label)
   check(same(state.kitchen,row.expected.kitchen) and same(state.economy,row.expected.economy),"valid imported complete kitchen and economy "+row.label)
   check(same(state.toolkit,row.expected.toolkit) and same(state.fishing,row.expected.fishing),"valid imported complete toolkit and fishing "+row.label)
   var farm:Dictionary=state.farm.duplicate(true)
   check(farm.get("stock",[]).is_empty() and (row.expected.farm.has("selectedSoil") or farm.get("selectedSoil","loam")=="loam"),"native-only farm metadata "+row.label)
   if not row.expected.farm.has("stock"):farm.erase("stock")
   if not row.expected.farm.has("selectedSoil"):farm.erase("selectedSoil")
   check(same(farm,row.expected.farm),"valid imported complete farm "+row.label)
   check(same(state.building,row.expected.building),"valid imported complete building "+row.label)
   check(same(state.environment,row.expected.environment),"valid imported complete weather history "+row.label)
   check(same(state.forage,row.expected.forage),"valid imported complete resource regeneration and finds "+row.label)
   check(same(state.ranch,row.expected.ranch),"valid imported complete ranch "+row.label+" got "+JSON.stringify(state.ranch)+" expected "+JSON.stringify(row.expected.ranch))
   check(same(state.animals,row.expected.animals),"valid imported complete animals "+row.label+" got "+JSON.stringify(state.animals)+" expected "+JSON.stringify(row.expected.animals))
 check(expected_cases>1256 and cases==expected_cases,"all declared source cases executed")
 print("SOURCE_SAVE_VALIDATION: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
