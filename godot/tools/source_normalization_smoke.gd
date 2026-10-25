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
 var state=root.get_node("GameState");state.set_process(false)
 var file=FileAccess.open(OS.get_environment("SOURCE_NORMALIZATION_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 var count:=0
 while not file.eof_reached():
  var line:String=file.get_line()
  if line=="":continue
  var row:Variant=preload("res://scripts/save_json.gd").parse(line)
  if not row is Dictionary:quit(1);return
  count+=1
  var prior:Dictionary=state._make_save_data().duplicate(true)
  var ok:bool=state._import_external_save_to_paths(row.before,"user://normalize-save.json","user://normalize-recovery.json","user://normalize-backup.json")
  if row.error!="":
   check(not ok and state.message==row.error,"reject "+str(row.label)+" got "+state.message+" expected "+str(row.error))
   check(same(state._make_save_data(),prior),"rejected normalization leaves progress "+str(row.label))
  else:
   check(ok,"accept "+str(row.label))
   check(same(state.interior_state.memories,row.expected.memories),"memories "+str(row.label))
   check(same(state.interior_state.chores,row.expected.chores),"chores "+str(row.label))
   if int(row.before.version)<3:
    var map:Dictionary={"storage":"storage","quality":"quality","storageQuality":"storage_quality","knownRecipes":"known_recipes","stories":"npc_stories","partners":"partners","marriage":"marriage","projects":"community_projects","chapters":"legacy_chapters","letters":"letters","mailRead":"mail_read","furniture":"furniture","skills":"skills","archives":"archives","achievements":"achievements","pet":"pet_state","yearPlans":"year_plans"}
    for life_key in map:
     var got:Variant=state.get(map[life_key])
     if life_key=="pet":
      for pet_key in row.expected.life.pet:check(same(got.get(pet_key),row.expected.life.pet[pet_key]),"old pet "+str(row.label)+"/"+str(pet_key))
     elif life_key=="projects":
      for project_key in row.expected.life.projects:check(same(got.get(project_key),row.expected.life.projects[project_key]),"old project "+str(row.label)+"/"+str(project_key))
     elif life_key=="marriage":
      var expected_marriage:Dictionary=row.expected.life.marriage.duplicate(true)
      if expected_marriage.spouse==null:expected_marriage.spouse=""
      check(same(got,expected_marriage),"old marriage "+str(row.label))
     else:check(same(got,row.expected.life[life_key]),"old life "+str(row.label)+"/"+life_key)
   for id in row.expected.neighbors.people:
    check(same(state.neighbors.people[id].recent,row.expected.neighbors.people[id].recent),"recent "+str(row.label)+"/"+str(id))
 check(count==18,"all 18 normalization cases")
 print("SOURCE_NORMALIZATION: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
