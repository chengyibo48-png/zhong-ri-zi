extends SceneTree
var passed:=0
var failed:=0
var failures: Dictionary = {}
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  var category := label.get_slice(" ",0)
  failures[category] = int(failures.get(category,0))+1
  if int(failures[category])<3:push_error(label)
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
 if b==null and a is Dictionary and a.is_empty():return true
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
 var file:=FileAccess.open(OS.get_environment("STORY_CHOICE_FIXTURE"),FileAccess.READ)
 if file==null:quit(1);return
 create_timer(240).timeout.connect(func():push_error("Story choice smoke timed out");quit(1))
 var state=root.get_node("GameState")
 state.set_process(false)
 var seed:Dictionary
 var case_count:=0
 while not file.eof_reached():
  var line:=file.get_line()
  if line=="":continue
  var row:Dictionary=JSON.parse_string(line)
  var id:String=row.id
  var label:String=id+"/"+str(row.before.stories[id].step)+"/"+str(row.choice)+"/"+str(row.variant)
  check(state.load_game_data(state.convert_external_save(row.before)),"导入 "+label)
  state.current_interior=""
  state.npc_positions={id:Vector2(2831,1652)}
  var before:Dictionary=state._make_save_data().duplicate(true)
  if id=="qiao" and int(row.before.stories[id].step)==0 and row.choice==0 and row.variant=="ready":seed=before.duplicate(true)
  var ready:Dictionary=state.npc_story_readiness(id)
  check(bool(ready.ok)==bool(row.ready.ok) and str(ready.message)==str(row.ready.msg),"原版故事条件 "+label+" "+str(ready.message))
  check(state.choose_npc_story(id,int(row.choice))==bool(row.result.ok) and state.message==str(row.result.msg),"原版回应 "+label)
  for item_id in state.item_catalog:
   var qty:int=row.expected.bag.get(item_id,0)
   check(int(state.inventory.get(item_id,0))==qty,"物品 "+label+" "+item_id)
   var q:Array=row.expected.quality.get(item_id,[0,0,0])
   while q.size()<3:q.append(0)
   check(same(state._quality_counts(item_id),[qty-int(q[0])-int(q[1])-int(q[2]),q[0],q[1],q[2]]),"品质 "+label+" "+item_id)
  check(same(state.kitchen.lots,row.expected.lots),"批次 "+label)
  check(same(state.npc_stories,row.expected.stories) and same(state.partners,row.expected.partners),"故事和关系确认 "+label)
  check(same(state.relations,row.expected.relations) and same(state.skills,row.expected.skills),"关系与经验 "+label)
  check(same(state.known_recipes,row.expected.recipes) and same(state.archives,row.expected.archives),"配方和旧物 "+label)
  if row.variant=="completed":check(same(state.archives,row.loadedArchives),"原版允许已完成且未持有旧物 "+label)
  check(same(state.legacy_systems.discovered,row.expected.discovered),"奖励发现 "+label)
  check(same(state.journal_entries(),row.expected.journal) and same(state.legacy_systems.eventLog,row.expected.eventLog),"原版日志顺序和上限 "+label)
  check(same(state.neighbors.people[id],row.expected.people) and same(state.neighbors.history,row.expected.history),"完整对话记忆 "+label)
  var after:Dictionary=state._make_save_data().duplicate(true)
  for key in ["money","minutes","stamina","player_stats","storage","marriage"]:
   check(same(before[key],after[key]),"无额外副作用 "+key+" "+label)
  case_count+=1
 file.close()
 check(not seed.is_empty(),"合法首章样例")
 state.load_game_data(seed.duplicate(true))
 var world=load("res://scenes/main.tscn").instantiate()
 root.add_child(world)
 await process_frame
 await process_frame
 world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 state.npc_positions.qiao=state.player_position
 var panel=world.hud.npc_story_panel
 panel.open_panel("qiao")
 var old:Dictionary=state.npc_stories.duplicate(true)
 panel.choice_buttons[0].pressed.emit()
 check(state.action_busy() and not panel.visible and same(state.npc_stories,old),"回应开始不提前结算")
 check(state.action_snapshot().kind=="read" and is_equal_approx(float(state.action_snapshot().duration),1.15),"实际原版故事任务动作")
 await escape();await process_frame
 check(not panel.visible and same(state.npc_stories,old),"真实Esc回到世界且不结算")
 panel.open_panel("qiao");panel.choice_buttons[1].pressed.emit()
 world.hud.show_npc_story("lin")
 finish(state);await process_frame
 check(state.npc_stories.qiao.step==1 and state.npc_stories.qiao.choices==[1] and int(state.npc_stories.lin.step)==0,"完成使用捕获候选人和选择")
 check(panel.visible and panel.npc_id=="qiao","完成返回独立人物故事页")
 check(root.gui_get_focus_owner()==panel.close_button,"完成恢复可用焦点")
 var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
 check(saved is Dictionary and saved.npc_stories.qiao.step==1,"完成立即静默保存")
 check(state.save_game("user://story-choice.json",true) and state.load_game("user://story-choice.json") and state.npc_stories.qiao.choices==[1],"实际文件存读回应")
 panel.close()
 for reason in ["load","room","day","far"]:
  state.load_game_data(seed.duplicate(true));state.npc_positions.qiao=state.player_position
  panel.open_panel("qiao");panel.choice_buttons[0].pressed.emit()
  if reason=="load":state.load_game_data(state._make_save_data().duplicate(true))
  elif reason=="room":state.current_interior="other"
  elif reason=="day":state.day+=1
  else:state.npc_positions.qiao=state.player_position+Vector2(200,0)
  finish(state);await process_frame
  if reason=="day":
   # app.startAction only guards state identity and room; same-object day edits are committed.
   check(state.npc_stories.qiao.step==1 and int(state.npc_stories.qiao.lastDay)==state.day and not state.action_busy(),"同一状态只改日期按原版在当前日结算")
   check(panel.visible and panel.npc_id=="qiao","同一状态只改日期返回故事页")
  else:
   check(state.npc_stories.qiao.step==0 and not state.action_busy(),"完成重查和旧回调取消 "+reason)
   if reason=="far":check(not panel.visible and state.message=="对方走开了，先靠近再聊。","离开后不推进且保留原任务提示")
   else:check(not panel.visible,"状态替换不恢复旧故事页 "+reason)
  state.current_interior="";panel.close()
 state.load_game_data(seed.duplicate(true));state.npc_positions.qiao=state.player_position
 state.feedback.prefs.pace="brisk"
 panel.open_panel("qiao");panel.choice_buttons[0].pressed.emit()
 check(is_equal_approx(float(state.action_snapshot().duration),0.7475),"故事回应快速节奏")
 state.cancel_action();await process_frame;panel.close()
 if failed>0:print("FAILURE CATEGORIES: ",failures)
 state.load_game_data(seed.duplicate(true))
 state.npc_stories.granny={"step":state.content.arcs.granny.size(),"choices":[0,0,0],"lastDay":5}
 state.archives.assign(["key"])
 state._museum_sync()
 check(state.archives==["key"],"图鉴同步不补发结章旧物")
 check(state.save_game("user://completed-story.json",true) and state.load_game("user://completed-story.json") and state.archives==["key"],"实际文件读回不补发结章旧物")
 print("STORY_CHOICE_SMOKE: %d cases, %d passed, %d failed"%[case_count,passed,failed])
 world.queue_free();await process_frame
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
