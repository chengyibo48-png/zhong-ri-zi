extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<20:push_error(label)
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
 if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b))<0.000001
 return a==b
func stock(a:Dictionary,b:Dictionary)->bool:
 for k in a:
  if int(a[k])!=int(b.get(k,0)):return false
 for k in b:
  if int(b[k])!=int(a.get(k,0)):return false
 return true
func grades(a:Dictionary,b:Dictionary)->bool:
 var ids:=a.keys()
 for k in b:
  if not ids.has(k):ids.append(k)
 for k in ids:
  var left:Array=a.get(k,[])
  var right:Array=b.get(k,[])
  for i in range(maxi(left.size(),right.size())):
   if int(left[i] if i<left.size() else 0)!=int(right[i] if i<right.size() else 0):return false
 return true
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FISHING_SESSION_FIXTURE")))
 if not parsed is Dictionary:push_error("Missing fishing source fixture");quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var model=load("res://scripts/fishing_session.gd").new()
 for row in parsed.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"源输入 "+row.label)
  var plan:Dictionary=state.fishing_plan(str(row.spot.water))
  check(same(plan,row.trace[0].game.plan),"预测和鱼竿快照 "+row.label)
  model.start(plan,row.spot)
  for frame in row.trace:
   if bool(frame.toggle):model.toggle()
   model.tick(float(frame.dt),bool(frame.paused))
   check(same(model.snapshot(),frame.game),"原版逐帧状态 "+row.label)
   check(model.phase()==str(frame.phase),"原版阶段 "+row.label)
  var game:Dictionary=model.snapshot()
  check(state.load_game_data(state.convert_external_save(row.finishBefore)),"结算输入 "+row.label)
  var ok:bool=state.finish_fishing(game.plan,bool(game.caught),float(game.safe),float(game.total),"张力过高或收线不足" if bool(game.hooked) else "错过咬钩窗口")
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版结算文案 "+row.label+" actual="+state.message+" expected="+str(row.result.msg))
  check(same(state.fishing,row.expected.fishing),"原版水域鱼获记录 "+row.label)
  check(stock(state.inventory,row.expected.bag),"原版鱼饵库存 "+row.label)
  check(state.minutes==int(row.expected.minutes) and state.stamina==int(row.expected.stamina),"原版劳动成本 "+row.label)
  check(same(state.tool_data("rod"),row.expected.tool),"原版钓竿经验 "+row.label)
  check(int(state.player_stats.fish)==int(row.expected.fish),"原版鱼获计数 "+row.label)
  check(grades(state.quality,row.expected.quality),"原版鱼获品质 "+row.label)
  check(same(state.kitchen.lots,row.expected.lots),"原版鱼饵和鱼获新鲜度批次 "+row.label+" actual="+JSON.stringify(state.kitchen.lots)+" expected="+JSON.stringify(row.expected.lots))
  model.cancel()
 print("Fishing session rules: %d passed, %d failed; sessions %d"%[passed,failed,parsed.rows.size()])
 quit(0 if failed==0 else 1)
