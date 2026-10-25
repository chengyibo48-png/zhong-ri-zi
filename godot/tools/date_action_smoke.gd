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
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("DATE_ACTION_FIXTURE")))
 if not fixture is Dictionary:quit(1);return
 var state=root.get_node("GameState")
 state.set_process(false)
 var seed:Dictionary
 for row in fixture.rows:
  var label:String=str(row.id)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"导入 "+label)
  var before:Dictionary=state._make_save_data().duplicate(true)
  if row.id=="qiao" and row.variant=="friend":seed=before.duplicate(true)
  check(state.date_npc(str(row.id))==bool(row.result.ok) and state.message==str(row.result.msg),"原版结果提示 "+label)
  check(same(state.partners,row.expected.partners),"完整交往状态 "+label)
  check(same(state.journal_entries(),row.expected.journal),"原版生活日志 "+label)
  check(same(state.legacy_systems.eventLog,row.expected.eventLog),"原版事件记录 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["inventory","storage","quality","kitchen","money","minutes","player_stats","relations","npc_stories","neighbors","known_recipes","skills","marriage"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
 check(not seed.is_empty(),"合法四章朋友状态")
 state.load_game_data(seed.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var panel=world.hud.neighbor_journal
 state.npc_positions.qiao=Vector2(10,10)
 state.relations.qiao.points=0
 state.upgrades.room=false
 panel.open_panel("qiao")
 check(panel.date_button.visible and not panel.date_button.disabled and not state.npc_is_near("qiao"),"四章后低信任远程无厢房仍可表达")
 var old:Dictionary=state.partners.duplicate(true)
 panel.date_button.pressed.emit()
 check(state.action_busy() and not panel.visible and same(state.partners,old),"动作开始尚未改变心意")
 check(state.action_snapshot().kind=="trade" and state.action_snapshot().item=="qiao" and is_equal_approx(float(state.action_snapshot().duration),1.6),"原版交接动作与ID")
 await escape()
 await process_frame
 check(panel.visible and same(state.partners,old) and panel._selected_npc_id()=="qiao","真实Esc恢复原候选人与状态")
 check(root.gui_get_focus_owner()==panel.date_button,"取消恢复表达按钮焦点")
 panel.date_button.pressed.emit()
 panel.refresh("lin")
 finish(state)
 await process_frame
 check(state.partners.qiao=="dating" and not state.partners.has("lin"),"完成使用捕获候选人")
 check(not panel.visible and world.hud.npc_story_panel.visible and world.hud.npc_story_panel.npc_id=="qiao","完成转候选人独立故事页")
 check(world.hud.npc_story_panel.relationship_button.text=="商量婚礼" and root.gui_get_focus_owner()==world.hud.npc_story_panel.close_button,"确认心意后可继续商量婚礼")
 var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(saved is Dictionary and saved.partners.qiao=="dating","完成立即静默自动保存")
 check(state.message=="把心意说开了。对方愿意和你慢慢走下去。","静默保存保留原提示")
 check(state.save_game("user://date-action.json",true) and state.load_game("user://date-action.json") and state.partners.qiao=="dating","真实文件存读保留心意")
 world.hud.close_top_panel()
 # Recheck the story milestone when the animation ends.
 state.load_game_data(seed.duplicate(true))
 panel.open_panel("qiao")
 panel.date_button.pressed.emit()
 state.npc_stories.qiao.step=3
 finish(state)
 await process_frame
 check(state.partners.qiao=="friend" and panel.visible,"完成重查四章不结算")
 check(state.message=="先走过对方的关系确认故事。","完成失败原版提示")
 panel.close()
 for reason in ["load","room","day"]:
  state.load_game_data(seed.duplicate(true))
  panel.open_panel("qiao")
  panel.date_button.pressed.emit()
  if reason=="load":
   var snap:Dictionary=state._make_save_data().duplicate(true)
   state.load_game_data(snap)
  elif reason=="room":state.current_interior="other"
  else:state.day+=1
  finish(state)
  if reason=="day":
   check(state.partners.qiao=="dating" and not state.action_busy() and world.hud.npc_story_panel.visible,"同一状态日期改变按原版完成 "+reason)
   world.hud.close_top_panel()
  else:check(state.partners.qiao=="friend" and not state.action_busy() and not panel.visible,"旧回调不作用新状态 "+reason)
  state.current_interior=""
 state.load_game_data(seed.duplicate(true))
 state.feedback.prefs.pace="brisk"
 panel.open_panel("qiao")
 panel.date_button.pressed.emit()
 check(is_equal_approx(float(state.action_snapshot().duration),1.04),"快速节奏")
 state.cancel_action()
 await process_frame
 panel.close()
 for row in fixture.rows:
  if str(row.id)!="qiao":continue
  state.load_game_data(state.convert_external_save(row.before))
  panel.open_panel("qiao")
  var allowed:bool=str(row.variant) in ["ready","friend","full","trust0","other-spouse"]
  check(panel.date_button.visible==allowed,"入口条件 "+str(row.variant))
  panel.close()
 state.load_game_data(seed.duplicate(true))
 panel.open_panel("granny")
 check(not panel.date_button.visible,"普通邻居不显示候选人入口")
 panel.open_panel("lan")
 check(not panel.date_button.visible,"孩子不显示候选人入口")
 panel.close()
 # Normal friend separation followed by renewed intent should survive a real file.
 state.load_game_data(seed.duplicate(true))
 state.partners.qiao="dating"
 state.upgrades.room=true
 state.relations.qiao.points=70
 check(state.marry_npc("qiao") and state.separate_from_partner() and state.date_npc("qiao"),"婚礼分开重新表达完整链")
 check(state.save_game("user://date-chain.json",true) and state.load_game("user://date-chain.json") and state.marriage.spouse=="" and state.partners.qiao=="dating" and int(state.npc_stories.qiao.step)==4,"关系链文件存读不丢故事")
 print("DATE_ACTION_SMOKE: %d passed, %d failed"%[passed,failed])
 world.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
