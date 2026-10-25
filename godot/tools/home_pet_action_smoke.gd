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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOME_PET_ACTION_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入宠物状态")
  var before:Dictionary=state._make_save_data().duplicate(true)
  if row.op=="name":check(state.rename_companion(str(row.name),str(row.type)),"合法命名")
  else:state.pat_companion()
  check(state.message==str(row.result.msg),"原版宠物提示")
  check(same(state.pet_state,row.expected.pet) and same(state.ranch.pet,row.expected.ranchPet),"名字类型每日亲近与精力")
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["inventory","money","minutes","player_stats","player_journal","legacy_systems","relations","skills","marriage"]:
   check(same(before[key],after[key]),"宠物操作无额外副作用 "+key)
 var base:Dictionary=state.convert_external_save(fixture.rows[0].before)
 state.load_game_data(base.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.home_panel
 for op in ["name","play"]:
  state.load_game_data(base.duplicate(true))
  panel.open_panel()
  panel.pet_name.text="  春团  "
  panel.pet_type.select(1)
  var button:Button=panel.pet_save if op=="name" else panel.pet_play
  var old:Dictionary=state.pet_state.duplicate(true)
  var energy:int=state.ranch.pet.energy
  button.pressed.emit()
  check(state.action_busy() and not panel.visible and same(state.pet_state,old),"动作开始不改宠物 "+op)
  check(state.action_snapshot().kind==("read" if op=="name" else "pet") and is_equal_approx(float(state.action_snapshot().duration),0.7 if op=="name" else 1.1),"原版动作种类与时长 "+op)
  await escape()
  await process_frame
  check(panel.visible and same(state.pet_state,old) and panel.pet_name.text=="  春团  " and panel.pet_type.selected==1,"Esc恢复名字类型且不结算 "+op)
  check(root.gui_get_focus_owner()==button,"取消恢复按钮焦点 "+op)
  button.pressed.emit()
  panel.pet_name.text="后来改的"
  panel.pet_type.select(0)
  finish(state)
  await process_frame
  if op=="name":
   check(state.pet_state.name=="春团" and state.pet_state.type=="dog","命名使用捕获表单")
   var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
   check(saved is Dictionary and saved.pet.name=="春团" and saved.pet.type=="dog","命名立即保存完整状态")
   check(state.message=="记住了这个名字。","静默保存保留命名提示")
  else:
   check(state.pet_state.bond==3 and state.pet_state.patted==state.day and state.ranch.pet.energy==mini(100,energy+5),"陪玩完成增加亲近和精力")
   check(panel.pet_play.disabled and root.gui_get_focus_owner()==panel.close_button,"今日已陪玩时转可操作焦点")
  check(panel.visible and panel.pet_name.text=="  春团  " and panel.pet_type.selected==1,"完成恢复原表单 "+op)
  check(state.save_game("user://home-pet-action.json",true) and state.load_game("user://home-pet-action.json"),"真实文件存读 "+op)
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel()
  panel.pet_name.text="春团"
  panel.pet_type.select(1)
  button.pressed.emit()
  var snap:Dictionary=state._make_save_data().duplicate(true)
  state.load_game_data(snap)
  finish(state)
  check(same(state.pet_state,old) and not state.action_busy(),"读档取消旧宠物回调 "+op)
  panel.open_panel()
  button.pressed.emit()
  state.current_interior="other"
  finish(state)
  check(same(state.pet_state,old) and not panel.visible and not state.action_busy(),"房间变化不结算 "+op)
  state.current_interior=""
  state.feedback.prefs.pace="brisk"
  panel.open_panel()
  button.pressed.emit()
  check(is_equal_approx(float(state.action_snapshot().duration),0.455 if op=="name" else 0.715),"快速节奏 "+op)
  state.cancel_action()
  await process_frame
  panel.close()
 print("HOME_PET_ACTION_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
