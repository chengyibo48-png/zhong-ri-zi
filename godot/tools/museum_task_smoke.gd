extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<15:push_error(label)
func canonical(v:Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func stock(a:Dictionary,b:Dictionary)->bool:
 for id in a:
  if int(a[id])!=int(b.get(id,0)):return false
 for id in b:
  if int(b[id])!=int(a.get(id,0)):return false
 return true
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 create_timer(110).timeout.connect(func():quit(1))
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("MUSEUM_TASK_FIXTURE")))
 var script=load("res://scripts/game_state.gd")
 for row in fixture.rows:
  var state=script.new()
  state._load_content()
  state._load_initial_state()
  check(state.load_game_data(state.convert_external_save(row.before)),"原版村史馆输入")
  state.current_interior=str(row.before.village.interior)
  state.interior_position=Vector2(float(row.before.player.x),float(row.before.player.y))
  var spec:Dictionary=state.museum_task_action(row.task)
  check(canonical(spec)==canonical(row.spec),"原版特殊办理动作 "+str(row.task))
  var ok:bool=false
  match str(row.task.op):
   "donate":ok=state.museum_donate(str(row.task.id),str(row.task.mode),int(row.task.grade))
   "claim":ok=state.museum_claim(str(row.task.id))
   "upgrade":ok=state.museum_upgrade()
   "feature":ok=state.museum_feature(str(row.task.id))
  check(ok==bool(row.result.ok),"原版事务成功 "+str(row.task)+"/"+str(row.variant))
  check(state.message==str(row.result.msg),"原版事务文案 "+str(row.task)+"/"+str(row.variant)+" actual="+state.message)
  check(stock(state.inventory,row.expected.bag),"馆藏实物消耗")
  check(canonical(state.collection.donated)==canonical(row.expected.collection.donated),"捐赠记录")
  check(canonical(state.collection.featured)==canonical(row.expected.collection.featured),"常设展")
  check(canonical(state.collection.claimed)==canonical(row.expected.collection.claimed),"收集包领奖")
  check(int(state.collection.level)==int(row.expected.collection.level),"展馆等级")
  check(stock(state.furniture,row.expected.furniture),"纪念陈设")
  check(state.money==int(row.expected.money) and state.minutes==int(row.expected.minutes) and state.stamina==int(row.expected.stamina),"办理时间体力金币")
  var quality_ok:=true
  var ids:Array=state.quality.keys()
  for id in row.expected.quality:
   if not ids.has(id):ids.append(id)
  for id in ids:
   quality_ok=quality_ok and canonical(state.quality.get(id,[0,0,0]))==canonical(row.expected.quality.get(id,[0,0,0]))
  check(quality_ok,"样品品质扣除")
  state.free()
 var state=root.get_node("GameState")
 state.set_process(false)
 state.current_interior=str(fixture.house.id)
 state.interior_position=Vector2(480,550)
 change_scene_to_file("res://scenes/interior.tscn")
 await process_frame
 await process_frame
 var world=current_scene
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var source:Dictionary={}
 for row in fixture.rows:
  if str(row.task.op)=="donate" and str(row.task.id)=="item:cabbage" and str(row.variant)=="ready" and int(row.task.grade)==0:
   source=row
   break
 check(not source.is_empty(),"找到实物原版基准")
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=str(fixture.house.id)
 state.interior_position=Vector2(480,550)
 world.player.global_position=state.interior_position
 state.ui_open=false
 world.hud.show_museum("donate","item:cabbage")
 var panel=world.hud.museum_panel
 panel.grade_option.select(0)
 panel._donate()
 check(panel.donation_confirmation.visible and not state.action_busy(),"捐赠先核对")
 check(stock(state.inventory,source.before.bag),"核对未扣实物")
 panel.donation_confirmation.canceled.emit()
 panel.donation_confirmation.hide()
 check(panel.pending_donation.is_empty() and stock(state.inventory,source.before.bag),"核对取消保留实物")
 panel._donate()
 panel._confirm_donation()
 check(not state.museum_task.is_empty() and not state.walking_target.is_empty() and not state.ui_open,"确认后登记桌行走")
 var target:Dictionary=state.museum_task.duplicate(true)
 state.stop_walking()
 check(state.museum_task.is_empty() and stock(state.inventory,source.before.bag),"取消行走无扣除")
 state.finish_museum_task(target)
 check(not state.action_busy(),"失效回调无结算")
 check(state.queue_museum_task("donate","item:cabbage","sample",0),"登记桌任务路线可达")
 target=state.museum_task.duplicate(true)
 world.player.global_position=Vector2(480,540)
 state.interior_position=world.player.global_position
 state.walking_target.clear()
 state.finish_museum_task(target)
 check(state.action_busy() and stock(state.inventory,source.before.bag),"登记动作未完成不扣除")
 state.stop_walking()
 check(not state.action_busy() and stock(state.inventory,source.before.bag),"取消登记无扣除")
 check(state.queue_museum_task("donate","item:cabbage","sample",0),"登记桌任务路线可达")
 target=state.museum_task.duplicate(true)
 state.walking_target.clear()
 state.finish_museum_task(target)
 for i in range(20):
  if not state.action_busy():break
  state._process_action(0.1)
 check(int(state.inventory.cabbage)==int(source.expected.bag.cabbage) and state.collection.donated.has("item:cabbage"),"动作结束真实登记")
 check(world.hud.museum_open() and state.ui_open,"完成重开馆藏")
 check(not state._make_save_data().has("museum_task"),"办理回调不入存档")
 world.hud.close_museum()
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=str(fixture.house.id)
 state.interior_position=Vector2(480,550)
 world.player.global_position=state.interior_position
 world.player.set_physics_process(true)
 state.set_process(true)
 check(state.queue_museum_task("donate","item:cabbage","sample",0),"登记桌任务路线可达")
 for frame in range(1200):
  if state.museum_task.is_empty() and state.walking_target.is_empty() and not state.action_busy():break
  await physics_frame
 check(state.collection.donated.has("item:cabbage") and world.hud.museum_open(),"真实物理行走至登记桌后办理")
 state.set_process(false)
 world.player.set_physics_process(false)
 world.hud.close_museum()
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=str(fixture.house.id)
 world.player.global_position=Vector2(480,540)
 state.interior_position=world.player.global_position
 check(state.queue_museum_task("donate","item:cabbage","sample",0),"登记桌任务路线可达")
 target=state.museum_task.duplicate(true)
 state.walking_target.clear()
 state.finish_museum_task(target)
 state.inventory.cabbage=0
 for i in range(20):
  if not state.action_busy():break
  state._process_action(0.1)
 check(not state.collection.donated.has("item:cabbage") and state.inventory.cabbage==0,"提交前实物变动重新拒绝")
 world.hud.close_museum()
 state.current_interior=str(fixture.house.id)
 state.interior_position=Vector2(100,100)
 check(not state.museum_near(),"馆内远离登记桌不可办理")
 state.current_interior=""
 state.player_position=Vector2(float(fixture.house.door.x),float(fixture.house.door.y))
 check(not state.museum_near(),"户外馆门不可办理")

 print("Museum task smoke: %d passed, %d failed; transactions %d"%[passed,failed,fixture.rows.size()])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
