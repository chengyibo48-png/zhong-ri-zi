extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FISHING_SESSION_FIXTURE")))
 if not parsed is Dictionary:quit(1);return
 var row:Dictionary=parsed.rows[0]
 var state=root.get_node("GameState")
 state.set_process(false)
 check(state.load_game_data(state.convert_external_save(row.before)),"实际场景导入源钓鱼状态")
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var point:Dictionary=row.spot.duplicate(true)
 var at:=Vector2(float(point.x),float(point.y))
 state.player_position=at+Vector2(-30,0)
 world.player.global_position=state.player_position
 state.ui_open=false
 var before:Dictionary=state.inventory.duplicate(true)
 state.minutes=float(row.before.minutes)
 var before_minutes:float=state.minutes
 var before_stamina:int=state.stamina
 world._interact_target(point)
 check(state.fishing_active() and state.action_busy(),"真实岸边交互直接抛竿")
 check(not state.ui_open and not world.hud.fishing_panel.visible,"实际抛竿保持世界和实时钓鱼 HUD")
 check(world.hud.fishing_panel.live_panel.visible and world.hud.fishing_panel.fishing_cancel_button.is_visible_in_tree(),"钓鱼实时提示和取消按钮可见")
 check(str(state.action_snapshot().kind)=="fish" and absf(float(state.action_snapshot().duration)-float(row.begun.spec.duration))<0.000001,"完整原版钓鱼动作规格")
 check(state.action_snapshot().waterX==point.waterX and state.action_snapshot().waterY==point.waterY,"动作捕获实际水面坐标")
 check(not state.begin_fishing(str(point.id)) and state.message=="先收好手里的鱼竿。","同一时间仅一竿")
 state.pass_time(10.0)
 check(state.minutes==before_minutes,"完整动作锁定期间世界时钟不额外推进")
 state._process_action(0.1)
 var paused_time:float=state.fishing_snapshot().time
 state.ui_open=true
 for i in range(5):state._process_action(0.1)
 check(absf(float(state.fishing_snapshot().time)-(paused_time+0.5))<0.000001 and absf(float(state.action_snapshot().progress)*float(state.action_snapshot().duration)-float(state.fishing_snapshot().time))<0.000001,"原版界面状态不暂停鱼线，鱼线与动作同步推进")
 state.ui_open=false
 check(not state._make_save_data().has("fishing_session"),"活跃鱼线不写入持久存档")
 world.hud.fishing_panel.fishing_cancel_button.pressed.emit()
 check(not state.fishing_active() and not state.action_busy() and not world.hud.fishing_panel.live_panel.visible,"取消完整清理鱼线动作和 HUD")
 check(state.inventory==before and state.minutes==before_minutes and state.stamina==before_stamina,"取消不扣饵不扣劳动成本")
 check(not state.begin_fishing("missing") and state.message=="先沿路走到这处水岸。","未知钓点拒绝")
 state.player_position=at+Vector2(76,0)
 check(not state.begin_fishing(str(point.id)),"超过七十五像素拒绝")
 state.player_position=at+Vector2(75,0)
 check(state.begin_fishing(str(point.id)),"七十五像素边界可抛竿")
 state.cancel_action()
 state.current_interior="house-granny"
 check(not state.begin_fishing(str(point.id)),"室内不能向户外水岸抛竿")
 state.current_interior=""
 state.player_position=at+Vector2(-30,0)
 var actual_visual=world.player.character_visual
 check(state.begin_fishing(str(point.id)),"恢复岸边抛竿")
 var landing_seen:=false
 var landing_art_seen:=false
 for i in range(100):
  if not state.action_busy():break
  state._process_action(0.1)
  if state.fishing_active() and bool(state.fishing_snapshot().caught):
   landing_seen=true
   check(state.inventory==before and state.minutes==before_minutes,"抄鱼期间仍未提前结算")
   if float(state.action_snapshot().progress)>0.83:
    for command in actual_visual.source_action_frame():
     if str(command.op)=="item":landing_art_seen=true
 check(landing_seen and landing_art_seen,"真实角色使用原版末阶段抄鱼图元")
 check(not state.fishing_active() and not state.action_busy(),"到完整时长才结束这一竿")
 check(state.message==str(row.result.msg),"真实动作结算文案对照原版")
 check(state.minutes==float(row.expected.minutes) and state.stamina==int(row.expected.stamina),"真实动作成本对照原版")
 check(int(state.player_stats.fish)==int(row.expected.fish),"真实动作鱼获次数对照原版")
 check(not world.hud.fishing_panel.live_panel.visible,"收杆后实时 HUD 清理")
 check(state.begin_fishing(str(point.id)),"读档前启动待结算钓鱼")
 state._process_action(0.1)
 var saved:Dictionary=state._make_save_data()
 var load_ok:bool=state.load_game_data(saved)
 if not load_ok:print("Fishing reload rejected: ",state.message)
 check(load_ok and not state.fishing_active() and not state.action_busy(),"读档清除鱼线回调与动作")
 check(not world.hud.fishing_panel.live_panel.visible,"读档清除钓鱼 HUD")
 state.fishing.mode="standard"
 check(state.begin_fishing(str(point.id)),"手动模式开始")
 for i in range(30):
  if state.fishing_phase()=="咬钩":break
  state._process_action(0.1)
 var key:=InputEventKey.new()
 key.keycode=KEY_SPACE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 check(bool(state.fishing_snapshot().hooked),"实际输入路由接收空格提竿")
 check(bool(state.fishing_snapshot().hooked) and bool(state.fishing_snapshot().holding),"空格实际提竿并收线")
 Input.parse_input_event(key)
 await process_frame
 check(not bool(state.fishing_snapshot().holding),"再按空格实际放线")
 var pad:=InputEventJoypadButton.new()
 pad.button_index=JOY_BUTTON_A
 pad.pressed=true
 Input.parse_input_event(pad)
 await process_frame
 state.poll_source_gamepad(1000.0,world.player,{"connected":true,"buttons":[true],"axes":[0.0,0.0]})
 check(not bool(state.fishing_snapshot().holding),"原版动作锁期间手柄 A 不收放线")
 state.current_interior="test-room"
 state._process_action(0.1)
 check(not state.fishing_active() and not state.action_busy(),"场景变化使待结算垂钓失效")
 state.current_interior=""
 state.fishing.mode="relaxed"
 state.fishing.release=true
 check(state.begin_fishing(str(point.id)),"观察后放流开始")
 var release_art_seen:=false
 for i in range(100):
  if not state.action_busy():break
  state._process_action(0.1)
  if state.fishing_active() and bool(state.fishing_snapshot().caught) and float(state.action_snapshot().progress)>0.96:
   for command in actual_visual.source_action_frame():
    if str(command.get("color",""))=="#c9e8de66":release_art_seen=true
 check(release_art_seen and bool(state.fishing.last.released),"真实放流动作传递源鱼获状态并绘制回水涟漪")
 check(int(state.fishing.waters.river.casts)==0,"放流结算恢复水域压力")
 state.fishing.release=false
 state.fishing.mode="relaxed"
 state.fishing.bait="grain"
 state.inventory.rice=0
 check(not state.begin_fishing(str(point.id)) and state.message=="鱼饵不足，可在垂钓手记换成免费的随手素饵。","缺饵拒绝开始")
 state.fishing.bait="plain"
 state.stamina=0
 check(not state.begin_fishing(str(point.id)) and state.message=="先歇歇或吃点东西，钓鱼需要体力。","开始检查未减免的基础体力门槛")
 world.queue_free()
 await process_frame
 print("Fishing native action: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
