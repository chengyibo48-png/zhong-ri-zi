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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("INVENTORY_LIFECYCLE_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"源取得输入")
  for step in row.steps:
   var task:Dictionary=step.task
   match str(task.op):
    "add":state._grant_quality(str(task.id),int(task.n),0)
    "add-quality":state._grant_quality(str(task.id),int(task.n),int(task.grade))
    "consume":state._consume_item(str(task.id),int(task.n))
    "store":state.economy_transfer(str(task.id),int(task.n),true)
    "take":state.economy_transfer(str(task.id),int(task.n),false)
    "reload":
     check(state.save_game("user://inventory-lifecycle.json",true),"生命周期文件保存")
     check(state.load_game("user://inventory-lifecycle.json"),"生命周期文件读取")
   state._reconcile_kitchen_lots()
   var order:Array=[]
   for id in state.inventory:
    if int(state.inventory[id])>0:order.append(id)
   var label:="%s/%s"%[row.id,task.op]
   check(same(order,step.expected.order),"原版取得顺序 "+label)
   check(same(state.kitchen.lots,step.expected.lots),"陈放批次 "+label)
   for id in state.item_catalog:
    check(int(state.inventory.get(id,0))==int(step.expected.bag.get(id,0)),"背包数量 "+label+"/"+id)
    check(int(state.storage.get(id,0))==int(step.expected.storage.get(id,0)),"储物数量 "+label+"/"+id)
    check(same(state._quality_counts(id),counts(step.expected.bag,step.expected.quality,id)),"背包品质 "+label+"/"+id)
    check(same(state._storage_quality_counts(id),counts(step.expected.storage,step.expected.storageQuality,id)),"储物品质 "+label+"/"+id)
 print("Inventory lifecycle migration: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)

func counts(stock:Dictionary,quality:Dictionary,id:String)->Array:
 var q:Array=quality.get(id,[0,0,0])
 var first:int=q[0] if q.size()>0 else 0
 var second:int=q[1] if q.size()>1 else 0
 var third:int=q[2] if q.size()>2 else 0
 return [maxi(0,int(stock.get(id,0))-first-second-third),first,second,third]
