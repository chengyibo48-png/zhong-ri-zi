extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<10:push_error(label)
func same(a:Variant,b:Variant)->bool:
 if b==null:return a==null or a is Dictionary and a.is_empty()
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
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("STORAGE_SORT_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"源粮仓输入")
  var label:="%s/%s/%s"%[row.category,row.withdraw,row.variant]
  var ok:bool=state.sort_building_storage(str(row.category),bool(row.withdraw))
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版粮仓结算 "+label)
  for id in state.item_catalog:
   check(int(state.inventory.get(id,0))==int(row.expected.bag.get(id,0)),"背包 "+label+"/"+id)
   check(int(state.storage.get(id,0))==int(row.expected.storage.get(id,0)),"粮仓 "+label+"/"+id)
   check(same(state._quality_counts(id),counts(row.expected.bag,row.expected.quality,id)),"背包品质 "+label+"/"+id)
   check(same(state._storage_quality_counts(id),counts(row.expected.storage,row.expected.storageQuality,id)),"粮仓品质 "+label+"/"+id)
  check(same(state.kitchen.lots,row.expected.lots),"陈放批次 "+label)
  check(same(state.economy,row.expected.economy),"经济锁定状态 "+label)
 print("Storage sort fidelity migration: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)

func counts(stock:Dictionary,quality:Dictionary,id:String)->Array:
 var q:Array=quality.get(id,[0,0,0])
 var first:int=q[0] if q.size()>0 else 0
 var second:int=q[1] if q.size()>1 else 0
 var third:int=q[2] if q.size()>2 else 0
 return [maxi(0,int(stock.get(id,0))-first-second-third),first,second,third]
