extends SceneTree
var passed := 0
var failed := 0
var commits := 0
var cancels := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
 if ok:passed += 1
 else:
  failed += 1
  push_error(label)
func same(a: Variant,b: Variant) -> bool:
 if b==null:return a is Dictionary and a.is_empty()
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not same(a[key],b[key]):return false
  return true
 if a is float or a is int:
  return (b is float or b is int) and is_equal_approx(float(a),float(b))
 return a==b
func _run() -> void:
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 create_timer(60).timeout.connect(func():quit(1))
 root.size=Vector2i(960,600)
 var rules=load("res://scripts/action_rules.gd")
 var sequence=load("res://scripts/action_sequence.gd").new()
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ACTION_SEQUENCE_FIXTURE")))
 for row in fixture.specs:
  check(same(rules.spec(row.kind),row.spec),"动作目录 "+row.kind)
  check(is_equal_approx(rules.duration(rules.spec(row.kind),"brisk"),float(row.brisk)),"利落时长 "+row.kind)
 for row in fixture.ui:check(same(rules.ui(row.id,"按钮"),row.spec),"按钮映射 "+row.id)
 for row in fixture.points:check(same(rules.point(row.p,row.tool),row.spec),"世界映射 "+str(row.p))
 check(sequence.start({"kind":"read","label":"测试","duration":0.5},func():commits+=1,func():cancels+=1),"首次开始")
 check(not sequence.start({"duration":1},func():commits+=10),"拒绝并行开始")
 for row in fixture.trace:
  check(sequence.tick(float(row.dt),bool(row.paused))==bool(row.finished),"逐帧结束")
  check(same(sequence.snapshot(),row.snapshot),"逐帧阶段")
  check(commits==int(row.commits) and cancels==int(row.cancels),"逐帧回调")
 check(not sequence.cancel(),"已结束不可取消")
 sequence.start({"duration":0.1},func():commits+=1,func():cancels+=1)
 check(sequence.cancel() and cancels==1 and commits==1,"取消不提交")
 check(not sequence.cancel(),"取消幂等")
 sequence.start({"duration":0.1},func():commits+=10,func():cancels+=10)
 check(sequence.cancel(false) and cancels==1 and commits==1,"替换状态丢弃取消回调")
 check(sequence.snapshot().is_empty() and not sequence.tick(0.1),"丢弃动作不延后提交")
 check(not sequence.cancel(false),"丢弃动作幂等")
 sequence.start({"duration":0.1},func():check(sequence.start({"duration":1.0},func():pass),"提交前释放序列"))
 sequence.tick(0.1)
 sequence.cancel()
 var state=root.get_node("GameState")
 state.set_process(false)
 var character_script=load("res://scripts/character_visual.gd")
 if character_script==null or not character_script.can_instantiate():
  push_error("人物脚本未编译，停止场景验收")
  quit(1)
  return
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame
 await process_frame
 var hud=current_scene.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.ui_open=false
 state.feedback.prefs.pace="normal"
 var before:int=commits
 check(state.begin_action(rules.spec("build"),{"kind":"test","x":state.player_position.x+20,"y":state.player_position.y},func():commits+=1),"实际服务开始")
 check(hud.action_progress.visible,"进度界面显示")
 check(hud.action_progress.cancel_button.has_focus(),"动作开始焦点进入取消按钮")
 check(current_scene.player.character_visual.sequence_managed,"人物由序列控制")
 check(hud.action_progress.mouse_filter==Control.MOUSE_FILTER_IGNORE and hud.action_progress.card.mouse_filter==Control.MOUSE_FILTER_STOP,"原版进度卡片拦截指针，周围透明区域交由动作输入锁处理")
 state._process_action(1.0)
 check(is_equal_approx(float(state.action_snapshot().progress),0.1/1.7),"真实服务限制帧跨度")
 check(commits==before,"动作未完成不结算")
 state.ui_open=true
 state._process_action(0.1)
 check(is_equal_approx(float(state.action_snapshot().progress),0.2/1.7),"界面状态不冻结已开始动作（原版仅隐藏暂停）")
 state.ui_open=false
 var key:=InputEventKey.new()
 key.pressed=true
 key.keycode=KEY_ESCAPE
 check(hud.handle_life_menu_key(key),"Esc 被动作处理")
 check(not state.action_busy() and commits==before,"Esc 取消不提交")
 check(not hud.action_progress.visible and not current_scene.player.character_visual.sequence_managed,"取消清理界面与人物")
 state.feedback.prefs.pace="brisk"
 state.begin_action(rules.spec("water"),{"kind":"test"},func():commits+=1)
 check(is_equal_approx(float(state.action_snapshot().duration),0.8125),"真实利落节奏")
 for i in range(9):state._process_action(0.1)
 check(commits==before+1 and not state.action_busy(),"全部阶段后提交一次")
 state._process_action(0.1)
 check(commits==before+1,"提交幂等")
 check(current_scene.player.character_visual.action_state=="","提交后不重播动作")
 state.begin_action(rules.spec("read"),{"kind":"test"},func():commits+=1)
 state.current_interior="test-room"
 state._process_action(0.1)
 check(not state.action_busy() and commits==before+1,"场景变更取消未完成动作")
 state.current_interior=""
 # Real viewport input cannot activate a previously focused toolbar/menu button.
 state.begin_action(rules.spec("build"),{"kind":"test"},func():commits+=1)
 var blocked:=InputEventKey.new()
 blocked.pressed=true
 blocked.keycode=KEY_K
 Input.parse_input_event(blocked)
 await process_frame
 check(state.action_busy() and not state.ui_open and not hud.kitchen_open(),"真实按键不穿透到厨房")
 var escape:=InputEventKey.new()
 escape.pressed=true
 escape.keycode=KEY_ESCAPE
 Input.parse_input_event(escape)
 await process_frame
 check(not state.action_busy() and commits==before+1,"真实 Esc 在 GUI 之前取消")
 state.begin_action(rules.spec("read"),{"kind":"test"},func():commits+=1)
 check(not state.queue_building_task({"op":"invalid"}) and state.action_busy(),"营造预检拒绝不打断已有动作")
 check(not state.queue_kitchen_task({"op":"invalid"}) and state.action_busy(),"厨房预检拒绝不打断已有动作")
 state.cancel_action()
 # Real economic queue: materials remain untouched during a visible action.
 state.feedback.prefs.pace="normal"
 state.money=1000
 state.inventory.cabbageSeed=0
 var target:Dictionary=state.building_task_destination({"op":"economy-buy","id":"cabbageSeed","n":1})
 state.player_position=Vector2(float(target.x)+70,float(target.y)+70)
 current_scene.player.global_position=state.player_position
 check(state.queue_building_task({"op":"economy-buy","id":"cabbageSeed","n":1}),"创建实际买种任务")
 for i in range(600):
  if state.action_busy():break
  await physics_frame
 check(state.action_busy(),"柜台抵达后进入动作")
 check(state.money==1000 and int(state.inventory.cabbageSeed)==0,"动作期间不扣钱不增加种子")
 state._process_action(0.1)
 state.stop_walking()
 check(state.money==1000 and int(state.inventory.cabbageSeed)==0 and state.building_task.is_empty(),"取消实际买种不结算")
 check(state.queue_building_task({"op":"economy-buy","id":"cabbageSeed","n":1}),"再次预约买种")
 for i in range(600):
  if state.action_busy():break
  await physics_frame
 check(state.action_busy(),"第二次抵达进入动作")
 state.money=0
 for i in range(17):state._process_action(0.1)
 check(state.money==0 and int(state.inventory.cabbageSeed)==0 and state.building_task.is_empty(),"结算前缺钱重新验证并拒绝")
 state.money=1000
 check(state.queue_building_task({"op":"economy-buy","id":"cabbageSeed","n":1}),"第三次预约买种")
 for i in range(600):
  if state.action_busy():break
  await physics_frame
 check(state.action_busy(),"第三次抵达进入动作")
 for i in range(15):state._process_action(0.1)
 check(state.money==1000 and int(state.inventory.cabbageSeed)==0,"收好阶段前仍不结算")
 state._process_action(0.1)
 check(state.money<1000 and int(state.inventory.cabbageSeed)==1 and state.building_task.is_empty(),"完整交接后买种结算")
 check(not state._make_save_data().has("action_sequence"),"回调与动作进度不进入存档")
 # Same-day/same-room replacement must never invoke the previous UI restore.
 var saved_state:Dictionary=state._make_save_data().duplicate(true)
 var callback_count: int = cancels
 var commit_count: int = commits
 for target_kind in ["ui","farm-task","ranch-task"]:
  check(state.begin_action(rules.spec("read"),{"kind":target_kind},func():commits+=10,func():cancels+=10),"开始读档前动作 "+target_kind)
  check(state.load_game_data(saved_state.duplicate(true)),"同日同房间读回 "+target_kind)
  state._process_action(0.1)
  check(cancels==callback_count and commits==commit_count and not state.action_busy(),"读档丢弃旧提交和恢复回调 "+target_kind)
 check(state.begin_action(rules.spec("read"),{"kind":"ui"},func():commits+=10,func():cancels+=1),"读档后仍可开始动作")
 check(state.cancel_action() and cancels==callback_count+1 and commits==commit_count,"普通取消仍运行恢复回调")
 print("Action sequence smoke: %d passed, %d failed" % [passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
