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
  for k in b:
   if not a.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in range(a.size()):
   if not same(a[i],b[i]):return false
  return true
 return a==b
func source_flags(state)->Dictionary:
 var flags:Dictionary=state.flags.duplicate(true);flags.erase("godot_onboarding");return flags
func run():
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RANCH_ORDERS_FIXTURE")))
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"load ranch order")
  check(state.ranch.get("delivered",[])==row.loadedDone and same(source_flags(state),row.loadedFlags),"restored delivered flags")
  var ok:bool=state.fulfill_legacy_order(row.id)
  check(ok==row.result.ok and state.message==row.result.msg,"first delivery "+row.variant)
  ok=state.fulfill_legacy_order(row.id)
  check(ok==row.second.ok and state.message==row.second.msg,"repeat delivery "+row.variant)
  check(state.ranch.get("delivered",[])==row.expected.ranch.delivered and same(source_flags(state),row.expected.flags),"delivery records")
  check(state.money==row.expected.money and same(state.relations,row.expected.relations),"delivery rewards")
  for id in state.item_catalog:check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"delivery bag")
  check(state.save_game("user://ranch-orders.json",true) and state.load_game("user://ranch-orders.json"),"ranch order roundtrip")
  check(state.ranch.get("delivered",[])==row.expected.ranch.delivered,"saved delivery records")
 for invalid in fixture.invalid:
  var data:Dictionary=state._make_save_data().duplicate(true);data.ranch.delivered=invalid
  var money:int=state.money;var ranch:Dictionary=state.ranch.duplicate(true)
  check(not state.load_game_data(data) and state.message=="牧场心愿记录无效。" and state.money==money and state.ranch==ranch,"invalid delivery rejects atomically")
 print("RANCH_ORDERS: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
