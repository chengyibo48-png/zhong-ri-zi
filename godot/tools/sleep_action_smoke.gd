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
 var state=root.get_node("GameState")
 state.set_process(false)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.ui_open=false
 var panel=world.hud.sleep_panel
 var original_day:int=state.day
 state.stamina=31
 var before:Dictionary=state._make_save_data()
 panel.open_panel()
 panel.sleep_button.pressed.emit()
 check(state.action_busy() and state.day==original_day and state.stamina==31,"确认先入睡而不提前跨日或恢复体力")
 check(not panel.visible and not state.ui_open,"确认关闭面板显示世界动作")
 var snapshot:Dictionary=state.action_snapshot()
 check(str(snapshot.kind)=="sleep" and absf(float(snapshot.duration)-2.2)<0.000001 and str(snapshot.label)==panel.sleep_button.text,"原版 next-day 动作规格")
 check(not state._make_save_data().has("sleep_task"),"睡眠回调不入存档")
 for i in range(10):state._process_action(0.1)
 check(state.day==original_day and state.stamina==31 and state.action_darkness()>0.5,"入梦渐暗期间未结算")
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE
 key.pressed=true
 Input.parse_input_event(key)
 await process_frame
 check(not state.action_busy() and panel.visible and state.ui_open,"Esc 取消恢复原确认面板")
 check(state.day==original_day and state.stamina==31,"取消保留当天和体力")
 check(root.gui_get_focus_owner()==panel.sleep_button,"取消恢复睡觉按钮焦点")
 panel.close()
 state.feedback.prefs.pace="brisk"
 panel.open_panel()
 panel.sleep_button.pressed.emit()
 check(absf(float(state.action_snapshot().duration)-2.2)<0.000001,"利落节奏保留完整入梦时长")
 for i in range(21):state._process_action(0.1)
 check(state.day==original_day and state.stamina==31,"最后收势前仍未跨日")
 state._process_action(0.1)
 check(not state.action_busy() and state.day==original_day+1 and state.stamina==100 and state.minutes==390,"完整结束后执行跨日规则")
 check(not panel.visible and not state.ui_open,"睡醒不重新打开旧确认")
 state.load_game_data(before)
 state.ui_open=false
 panel.open_panel()
 panel.sleep_button.pressed.emit()
 state.current_interior="changed-room"
 state._process_action(0.1)
 check(not state.action_busy() and state.day==original_day and not panel.visible,"场景改变使原睡眠回调失效且不恢复旧面板")
 state.current_interior=""
 state.ui_open=false
 panel.open_panel()
 panel.sleep_button.pressed.emit()
 state.load_game_data(before)
 check(not state.action_busy() and state.day==original_day,"读档清除未完成入梦回调")
 for i in range(30):state._process_action(0.1)
 check(state.day==original_day,"读档后旧回调不再跨日")
 world.queue_free()
 await process_frame
 print("Sleep action migration: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
