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
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SKILL_CHOICE_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"导入原版风格选择")
  var before:Dictionary=state._make_save_data().duplicate(true)
  var ok:bool=state.choose_skill(str(row.skill),str(row.choice))
  var label:="%s/%s/xp%d/%s"%[row.skill,row.choice,int(row.xp),str(row.selected)]
  check(ok==bool(row.result.ok) and state.message==str(row.result.msg),"原版条件与提示 "+label)
  check(same(state.skills,row.expected),"只改对应风格 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["inventory","storage","quality","storage_quality","kitchen","money","minutes","player_stats","player_journal","legacy_systems","relations","community_projects"]:
   check(same(after.get(key),before.get(key)),"无附加副作用 "+label+"/"+key)
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.skills_panel
 for skill_id in state.content.skillNames:
  var row:Dictionary={}
  for candidate in fixture.rows:
   if candidate.skill==skill_id and int(candidate.xp)==25 and candidate.selected==null and bool(candidate.result.ok):
    row=candidate
    break
  var base:Dictionary=state.convert_external_save(row.before)
  var key:=str(skill_id)+":"+str(row.choice)
  state.load_game_data(base.duplicate(true))
  state.current_interior=""
  panel.open_panel()
  check(not panel.choice_buttons[key].disabled,"null选择且xp25按钮开放 "+str(skill_id))
  var child_count:int=panel.card_list.get_child_count()
  panel.refresh()
  panel.refresh()
  check(panel.card_list.get_child_count()==child_count,"重复刷新不叠加卡片 "+str(skill_id))
  panel.choice_buttons[key].pressed.emit()
  check(state.action_busy() and not panel.visible and state.skills[skill_id].choice==null,"开始动作不选择 "+str(skill_id))
  check(state.action_snapshot().kind=="read" and state.action_snapshot().item==skill_id and is_equal_approx(float(state.action_snapshot().duration),0.7),"原版read与捕获技能 "+str(skill_id))
  await escape()
  await process_frame
  check(panel.visible and state.skills[skill_id].choice==null and root.gui_get_focus_owner()==panel.choice_buttons[key],"Esc恢复焦点且未选择 "+str(skill_id))
  panel.choice_buttons[key].pressed.emit()
  finish(state)
  await process_frame
  check(state.skills[skill_id].choice==row.choice and panel.visible,"完成选择 "+str(skill_id))
  check(panel.choice_buttons[key].disabled and root.gui_get_focus_owner()==panel.close_button,"完成按钮禁用及焦点恢复 "+str(skill_id))
  check(state.save_game("user://skill-choice.json",true) and state.load_game("user://skill-choice.json") and state.skills[skill_id].choice==row.choice,"真实文件保留风格 "+str(skill_id))
  panel.close()
  state.load_game_data(base.duplicate(true))
  state.skills[skill_id].xp=24
  panel.open_panel()
  check(panel.choice_buttons[key].disabled,"24点未开放 "+str(skill_id))
  state.skills[skill_id].xp=25
  panel.refresh()
  panel.choice_buttons[key].pressed.emit()
  state.skills[skill_id].xp=24
  finish(state)
  await process_frame
  check(state.skills[skill_id].choice==null and panel.visible and state.message=="熟练度达到 25 后可以选一种做事风格。","完成时重查熟练度 "+str(skill_id))
  panel.close()
  state.load_game_data(base.duplicate(true))
  panel.open_panel()
  panel.choice_buttons[key].pressed.emit()
  var saved:Dictionary=state._make_save_data().duplicate(true)
  state.load_game_data(saved)
  finish(state)
  check(state.skills[skill_id].choice==null and not state.action_busy(),"读档清除回调 "+str(skill_id))
  panel.open_panel()
  panel.choice_buttons[key].pressed.emit()
  state.current_interior="other"
  finish(state)
  check(state.skills[skill_id].choice==null and not panel.visible,"房间变化不选择或恢复面板 "+str(skill_id))
  state.current_interior=""
  state.load_game_data(base.duplicate(true))
  state.feedback.prefs.pace="brisk"
  panel.open_panel()
  panel.choice_buttons[key].pressed.emit()
  check(is_equal_approx(float(state.action_snapshot().duration),0.455),"快速节奏 "+str(skill_id))
  state.cancel_action()
  await process_frame
  panel.close()
 print("SKILL_CHOICE_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
