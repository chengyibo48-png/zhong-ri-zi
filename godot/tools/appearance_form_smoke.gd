extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<12:push_error(label)
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
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("APPEARANCE_FORM_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入原版换装状态")
  var before:Dictionary=state._make_save_data().duplicate(true)
  check(state.apply_player_appearance(row.form),"合法表单可提交")
  check(state.player_name==str(row.expected.name) and state.player_gender==str(row.expected.gender) and same(state.appearance,row.expected.appearance),"原版姓名称呼与8项衣着")
  check(state.message=="换好了，还是熟悉的你。","原版换装提示")
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["inventory","money","minutes","player_stats","player_journal","legacy_systems","skills","relations","marriage","partners"]:
   check(same(before[key],after[key]),"换装无其他副作用 "+key)
 var row:Dictionary=fixture.rows[fixture.rows.size()-6]
 var base:Dictionary=state.convert_external_save(row.before)
 state.load_game_data(base.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.settings_panel
 panel.open_panel()
 var old:Dictionary=state.appearance.duplicate(true)
 var old_name:=str(state.player_name)
 panel._restore_appearance_form(row.form)
 panel.appearance_options.shirt.item_selected.emit(panel.appearance_options.shirt.selected)
 panel.appearance_toggles.bag.toggled.emit(panel.appearance_toggles.bag.button_pressed)
 check(same(state.appearance,old) and state.player_name==old_name,"表单编辑不提前换装")
 state.changed.emit()
 check(same(panel._appearance_form(),row.form),"其他设置刷新保留换装草稿")
 panel.appearance_apply_button.pressed.emit()
 check(state.action_busy() and not panel.visible and same(state.appearance,old),"换装开始不修改外观")
 check(state.action_snapshot().kind=="dress" and is_equal_approx(float(state.action_snapshot().duration),1.1),"原版1.1秒dress动作")
 await escape()
 await process_frame
 check(panel.visible and same(state.appearance,old) and same(panel._appearance_form(),row.form),"Esc不换装并恢复整份表单")
 check(root.gui_get_focus_owner()==panel.appearance_apply_button,"取消恢复提交焦点")
 panel.appearance_apply_button.pressed.emit()
 panel.player_name_edit.text="改动后的控件"
 panel.appearance_options.shirt.select(0)
 finish(state)
 await process_frame
 check(state.player_name==row.expected.name and same(state.appearance,row.expected.appearance),"完成使用开始捕获的整份表单")
 check(panel.visible and same(panel._appearance_form(),row.form),"完成恢复开始表单")
 check(state.message=="换好了，还是熟悉的你。","自动保存不覆盖换装提示")
 var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(saved is Dictionary and str(saved.player_name)==str(row.expected.name) and same(saved.appearance,row.expected.appearance),"完成后立即写入真实自动存档")
 check(state.load_game(state.SAVE_PATH) and state.player_name==row.expected.name and same(state.appearance,row.expected.appearance),"真实自动存档可读回外观")
 panel.close()
 state.load_game_data(base.duplicate(true))
 panel.open_panel()
 panel._restore_appearance_form(row.form)
 panel.appearance_apply_button.pressed.emit()
 var snapshot:Dictionary=state._make_save_data().duplicate(true)
 state.load_game_data(snapshot)
 finish(state)
 check(same(state.appearance,old) and state.player_name==old_name and not state.action_busy(),"读档清除换装回调")
 panel.open_panel()
 panel._restore_appearance_form(row.form)
 panel.appearance_apply_button.pressed.emit()
 state.current_interior="other"
 finish(state)
 check(not panel.visible and same(state.appearance,old),"换房不换装或恢复旧面板")
 state.current_interior=""
 panel.open_panel()
 panel._restore_appearance_form(row.form)
 state.feedback.prefs.pace="brisk"
 panel.appearance_apply_button.pressed.emit()
 check(is_equal_approx(float(state.action_snapshot().duration),0.715),"快速节奏dress动作")
 state.cancel_action()
 await process_frame
 panel.close()
 print("APPEARANCE_FORM_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
