extends SceneTree
const CODEC := preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
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
 if (a is int or a is float) and (b is int or b is float):return float(a)==float(b)
 return a==b
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(180).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 var file:=FileAccess.open(OS.get_environment("STAMINA_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 var cases:=0
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var row:Dictionary=CODEC.parse(line)
  var label:=str(cases)+"/"+str(row.kind)
  check(state.load_game_data(state.convert_external_save(row.before)),"source import "+label)
  check(state.stamina==float(row.before.stamina),"exact fractional import "+label)
  var ok:=true
  match row.kind:
   "labor":ok=state.spend_energy(float(row.cost),float(row.time),"",false)
   "rest":state.rest_at_home()
   "eat":ok=state.eat_item(str(row.id))
  check(ok==row.result.ok,"source success "+label)
  if state.stamina!=float(row.expected.stamina) and failed<15:print("ACTUAL ",CODEC.stringify(state.stamina)," EXPECTED ",CODEC.stringify(row.expected.stamina))
  check(state.stamina==float(row.expected.stamina) and state.minutes==float(row.expected.minutes),"exact operation stamina and clock "+label)
  if row.kind!="labor":check(state.message==row.result.msg,"exact fractional message "+label)
  if row.kind=="eat":
   var ids:Dictionary={}
   for id in state.inventory:ids[id]=true
   for id in row.expected.bag:ids[id]=true
   var matches:=true
   for id in ids:
    if int(state.inventory.get(id,0))!=int(row.expected.bag.get(id,0)):matches=false
   check(matches and same(state.quality,row.expected.quality),"item consumption quality "+label)
   check(same(state.kitchen,row.expected.kitchen),"food lots and buffs "+label)
  if cases%37==0:
   var wanted:float=state.stamina
   check(state.save_game("user://stamina-roundtrip.json",true),"actual fractional write "+label)
   state.stamina=0
   check(state.load_game("user://stamina-roundtrip.json") and state.stamina==wanted,"exact fractional actual read "+label)
  cases+=1
 # Reject invalid native data before changing the in-memory world.
 var saved:Dictionary=state._make_save_data()
 for invalid in [-0.01,100.01,NAN,INF,true,"25.75",null]:
  var attempted:Dictionary=saved.duplicate(true);attempted.stamina=invalid
  var previous:float=state.stamina
  check(not state.load_game_data(attempted) and state.stamina==previous,"reject invalid stamina "+str(invalid))
 print("Fractional stamina source: %d cases, %d passed, %d failed"%[cases,passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
