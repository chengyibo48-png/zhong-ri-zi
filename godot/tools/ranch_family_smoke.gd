extends SceneTree
var passed:=0
var failed:=0
var errors:Dictionary={}
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  var key:=label.get_slice(" ",0)
  errors[key]=int(errors.get(key,0))+1
  if failed<18:push_error(label)
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for k in b:
   if not a.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in range(a.size()):
   if not same(a[i],b[i]):return false
  return true
 return a==b
func compare(state,e:Dictionary,label:String):
 var fields:Dictionary={"day":"day","minutes":"minutes","stamina":"stamina","money":"money","kitchen":"kitchen","skills":"skills","stats":"player_stats","ranch":"ranch","animals":"animals","pet":"pet_state","processing":"legacy_processing","toolkit":"toolkit","storage":"storage","storageQuality":"storage_quality","upgrades":"upgrades","knownRecipes":"known_recipes"}
 for key in fields:check(same(state.get(fields[key]),e[key]),key+" "+label)
 check(same(state.journal_entries(),e.journal),"journal "+label)
 check(same(state.legacy_systems.eventLog,e.eventLog),"eventLog "+label)
 check(same(state.legacy_systems.discovered,e.discovered),"discovered "+label)
 for key in e.flags:check(state.flags.get(key)==e.flags[key],"flags "+label)
 for id in state.item_catalog:
  var qty:int=e.bag.get(id,0)
  check(state.inventory.get(id,0)==qty,"inventory "+label)
  var q:Array=e.quality.get(id,[0,0,0])
  check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"quality "+label)
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture=FileAccess.open(OS.get_environment("RANCH_FAMILY_FIXTURE"),FileAccess.READ)
 if fixture==null:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 while not fixture.eof_reached():
  var line:=fixture.get_line()
  if line.strip_edges()=="":continue
  var row:Variant=load("res://scripts/save_json.gd").decode(JSON.parse_string(line))
  var label:String=str(row.op)+"/"+str(row.id)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"load "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  var ok:=false
  match str(row.op):
   "buy":ok=state.ranch_buy_animal(str(row.id),str(row.sex),str(row.breed),bool(row.young))
   "breed":ok=state.ranch_breed(str(row.mother),str(row.father))
   "incubate":ok=state.ranch_incubate(str(row.id))
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"result "+label+" actual="+state.message+" expected="+str(row.result.msg))
  compare(state,row.expected,label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["relations","neighbors","marriage","npc_stories","partners","building","farm","plots"]:
   check(same(before[key],after[key]),"unrelated "+key+" "+label)
  for step in row.steps:
   state.advance_day()
   compare(state,step.expected,label+"/overnight")
   check(state.message==str(step.result.msg),"morning "+label)
  if row.variant in ["normal","premium","mixed"] and row.result.ok:
   var path:String=load("res://tools/smoke_files.gd").create_path("ranch_craft_store")
   check(state.save_game(path,true),"save "+label)
   var restored=load("res://scripts/game_state.gd").new()
   restored._load_content()
   check(restored.load_game(path),"restore "+label)
   check(same(restored.kitchen,state.kitchen) and same(restored.legacy_processing,state.legacy_processing) and same(restored.quality,state.quality) and same(restored.ranch,state.ranch),"roundtrip "+label)
   check(same(restored.animals,state.animals) and same(restored.pet_state,state.pet_state) and same(restored.inventory,state.inventory),"animal-roundtrip "+label)
   restored.free()
   load("res://tools/smoke_files.gd").remove(path)
 print("Ranch family failure fields: ",errors)
 print("RANCH_FAMILY_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
