extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
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
func finish(state):
 for i in range(35):state._process_action(0.1)
func escape():
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 key=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=false
 Input.parse_input_event(key)
 await process_frame
func near(a:float,b:float)->bool:
 return absf(a-b)<=0.00000001
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(120).timeout.connect(func():push_error("Clock timeout");quit(1))
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FRACTIONAL_CLOCK_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var seed:Dictionary
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"原版分数分钟导入")
  check(near(state.minutes,float(row.loaded)),"与原版C.load保留同一时刻")
  if row.speed=="relaxed" and row.before.minutes==600.25 and row.pause=="none":seed=state._make_save_data().duplicate(true)
  state.ui_open=row.pause=="panel"
  if row.pause=="action":state.begin_action(state.ACTION_RULES.spec("read","读物件"),{"kind":"ui"},func():pass)
  state.pass_time(float(row.delta))
  check(near(state.minutes,float(row.expected)),"实际原版帧时钟 "+str(row.speed)+"/"+str(row.delta)+"/"+str(row.pause))
  state.cancel_action(false)
  state.ui_open=false
 for row in fixture.labor:
  state.load_game_data(state.convert_external_save(row.before))
  check(state.spend_energy(2,15)==bool(row.ok) and near(state.minutes,float(row.minutes)) and state.stamina==int(row.stamina),"劳动保留分数并封顶")
 for row in fixture.deadlines:
  state.load_game_data(state.convert_external_save(row.before))
  check(near(state.minutes,float(row.loaded)),"原版加工期限输入分数存读")
  check(state.collect_kitchen_job(int(row.before.kitchen.jobs[0].key))==bool(row.result.ok) and state.message==str(row.result.msg),"原版真实投料加工期限结果")
  check(same(state.kitchen.jobs,row.jobs),"原版加工期限前后队列")
  for id in state.item_catalog:
   var qty:int=row.bag.get(id,0)
   check(int(state.inventory.get(id,0))==qty,"期限原版全部库存")
   var q:Array=row.quality.get(id,[0,0,0])
   check(same(state._quality_counts(id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"期限原版全部品质")
 state.load_game_data(seed.duplicate(true))
 state.pass_time(0.013)
 var saved_time:float=state.minutes
 check(saved_time>600.25 and saved_time<601,"不足一分钟仍实时保存")
 check(state.save_game("user://fractional-clock.json",true) and state.load_game("user://fractional-clock.json") and near(state.minutes,saved_time),"真实文件读回不丢分数")
 state.pass_time(0.021)
 check(near(state.minutes,saved_time+0.021*1.04),"读回后从保存时刻继续")
 check(state.time_text()=="10:00","显示小时分钟仍按原版取整")
 state.load_game_data(seed.duplicate(true))
 var now:float=state._kitchen_now()
 state.kitchen.buff={"kind":"暖胃","until":now+0.01}
 check(state.kitchen_active_buff()=="暖胃","分数增益截止前保持")
 state.minutes+=0.01
 check(state.kitchen_active_buff()=="","截止相等时增益失效")
 state.load_game_data(seed.duplicate(true))
 now=state._kitchen_now()
 state.kitchen.jobs=[{"key":1,"recipe":"flour","id":"flour","qty":1,"station":"mill","start":now,"ready":now+0.1,"grade":0,"cooking":false,"weatherDelay":0}]
 state.kitchen.nextId=2
 var old:int=state.inventory.get("flour",0)
 check(not state.collect_kitchen_job(1) and int(state.inventory.get("flour",0))==old,"分数加工期限前不收取")
 check(state.save_game("user://fractional-job.json",true) and state.load_game("user://fractional-job.json") and near(float(state.kitchen.jobs[0].ready),now+0.1),"加工分数期限存读保留")
 state.minutes+=0.1
 check(state.collect_kitchen_job(1) and int(state.inventory.get("flour",0))==old+1,"期限相等时准确收取")
 state.load_game_data(seed.duplicate(true))
 state.minutes=1319.99
 state._source_update_tick=0.0
 var notices:Dictionary={"count":0}
 var listener:=func():notices.count+=1
 state.bedtime_reached.connect(listener)
 state.pass_time(0.05)
 state.pass_time(0.05)
 check(state.minutes==1320.0 and notices.count==0,"封顶后等待原版一秒更新节奏")
 for i in range(20):state.pass_time(0.05)
 check(notices.count==1,"一秒更新节奏发出夜间提示")
 state.load_game_data(seed.duplicate(true))
 state.minutes=1319.99
 state._source_update_tick=1.0
 state.pass_time(0.05)
 check(notices.count==2,"读档重置夜间提示状态")
 state.bedtime_reached.disconnect(listener)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.kitchen_panel
 for row in fixture.deadlines:
  state.load_game_data(state.convert_external_save(row.before))
  panel.open_panel(false,"jobs")
  check(panel.list.item_count==1 and panel.selected_id==str(row.before.kitchen.jobs[0].key),"真实加工队列分数输入")
  check(panel.action_button.disabled==not bool(row.result.ok),"真实界面期限前禁用到期可收")
  check(panel.action_button.text==("收取成品" if row.result.ok else "尚未完成"),"真实界面期限文字")
  panel.close()
 world.queue_free()
 await process_frame
 print("FRACTIONAL_CLOCK_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
