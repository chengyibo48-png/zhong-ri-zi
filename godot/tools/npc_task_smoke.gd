extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<12:push_error(label)
func json(v:Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func equivalent(a:Variant,b:Variant)->bool:
 if b==null:return a==null or (a is Dictionary and a.is_empty())
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in b:
   if not a.has(key) or not equivalent(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in range(b.size()):
   if not equivalent(a[i],b[i]):return false
  return true
 return a==b
func stock(a:Dictionary,b:Dictionary)->bool:
 for id in a:
  if int(a[id])!=int(b.get(id,0)):return false
 for id in b:
  if int(b[id])!=int(a.get(id,0)):return false
 return true
func finish(state:Node):
 for i in range(40):
  if not state.action_busy():break
  state._process_action(0.1)
 await process_frame
 await process_frame
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 create_timer(180).timeout.connect(func():quit(1))
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NPC_TASK_FIXTURE")))
 var script=load("res://scripts/game_state.gd")
 var model=script.new()
 model._load_content()
 model._load_initial_state()
 for row in fixture.specs:
  check(json(model.npc_task_action({"id":row.id,"npcId":row.id,"op":row.op}))==json(row.spec),"原版居民特殊动作 "+str(row.id)+"/"+str(row.op))
 for row in fixture.rows:
  check(model.load_game_data(model.convert_external_save(row.before)),"原版委托输入")
  model.current_interior=""
  model.npc_positions={str(row.id):Vector2(2831,1652)}
  var ok:bool=model.resolve_npc_event(str(row.id),str(row.op),int(row.eventDay))
  var label:=str(row.id)+"/"+str(row.op)+"/"+str(row.variant)
  check(ok==bool(row.result.ok),"原版委托成功 "+label)
  check(model.message==str(row.result.msg),"原版委托文案 "+label+" actual="+model.message)
  check(stock(model.inventory,row.expected.bag),"原版委托材料 "+label)
  check(json(model.relations)==json(row.expected.relations),"原版委托关系 "+label)
  check(equivalent(model.neighbors.people[str(row.id)],row.expected.people),"原版委托居民状态 "+label)
  check(json(model.neighbors.history)==json(row.expected.history),"原版委托历史 "+label)
  check(model.money==int(row.expected.money) and model.minutes==int(row.expected.minutes) and model.stamina==int(row.expected.stamina),"原版委托时间体力金币 "+label)
 model.free()
 var state=root.get_node("GameState")
 state.set_process(false)
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame
 await process_frame
 var world=current_scene
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var source:Dictionary={}
 for row in fixture.rows:
  if row.id=="granny" and row.op=="supply" and row.variant=="accepted":source=row;break
 check(not source.is_empty(),"找到供料原版输入")
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=""
 state.npc_positions={"granny":Vector2(2831,1652)}
 world.player.global_position=Vector2(2831,1652)
 state.player_position=world.player.global_position
 state.ui_open=false
 world.hud.show_neighbors("granny")
 world.hud.neighbor_journal._on_event_action("supply")
 check(state.action_busy() and state.action_snapshot().kind=="trade" and not state.ui_open,"实际委托按钮启动交接")
 check(stock(state.inventory,source.before.bag),"交接未完成不扣材料")
 state.stop_walking()
 check(state.npc_task.is_empty() and stock(state.inventory,source.before.bag),"取消交接保留材料")
 state.queue_npc_task("granny","supply",{"day":2})
 state.npc_positions.granny=Vector2(3100,1652)
 await finish(state)
 check(stock(state.inventory,source.before.bag) and state.message=="对方走开了，先靠近再聊。" and not world.hud.neighbors_open(),"对方离开不交材料")
 state.npc_positions.granny=Vector2(2831,1652)
 state.queue_npc_task("granny","supply",{"day":2})
 await finish(state)
 check(stock(state.inventory,source.expected.bag) and json(state.neighbors.people.granny.event)==json(source.expected.people.event),"完成交接源结果")
 check(world.hud.npc_dialogue.visible and world.hud.npc_dialogue.npc_id=="granny" and state.ui_open,"完成回到同一居民页面")
 check(not state._make_save_data().has("npc_task"),"活动回调不入存档")
 world.hud.close_top_panel()
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=""
 state.player_position=Vector2(2831,1652)
 state.npc_positions={"granny":Vector2(2831,1652)}
 var item_id:=str(state.system_catalog.npc.profiles.granny.item)
 state.queue_npc_task("granny","supply",{"day":2})
 state.inventory[item_id]=0
 await finish(state)
 check(state.inventory[item_id]==0 and str(state.neighbors.people.granny.event.status)=="accepted","完成前缺料重新拒绝")
 world.hud.close_top_panel()
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=""
 state.player_position=Vector2(2831,1652)
 state.npc_positions={"granny":Vector2(2831,1652)}
 var before:int=state.stamina
 state.queue_npc_task("granny","join",{"day":2})
 check(state.stamina==before and state.action_snapshot().duration==2.8,"共同劳动准备未扣体力")
 state.stop_walking()
 check(state.stamina==before,"取消劳动未扣体力")
 state.queue_npc_task("granny","join",{"day":2})
 await finish(state)
 check(state.stamina==before-3 and state.minutes==int(source.before.minutes)+20,"完成共同劳动源消耗")
 world.hud.close_top_panel()
 state.load_game_data(state.convert_external_save(source.before))
 state.current_interior=""
 state.player_position=Vector2(2831,1652)
 state.npc_positions={"granny":Vector2(2831,1652)}
 world.hud.show_neighbors("granny")
 var before_relation:int=state.relations.granny.points
 world.hud.neighbor_journal._on_dialogue_topic("advice")
 check(state.action_busy() and state.action_snapshot().kind=="greet" and state.relations.granny.points==before_relation,"话题按钮先动作后交谈")
 state.stop_walking()
 check(state.relations.granny.points==before_relation,"话题动作取消无关系变化")
 state.queue_npc_task("granny","talk",{"topic":"advice"})
 await finish(state)
 check(state.neighbors.people.granny.introduced and world.hud.npc_dialogue.visible,"完成话题记录初识并重开")
 world.hud.close_top_panel()
 state.npc_positions.he=Vector2(2831,1652)
 state.relations.he.points=100
 state.npc_stories.he={"step":0,"choices":[],"lastDay":-1}
 var event:Dictionary=state.content.arcs.he[0]
 for id in event.get("needs",{}):state.inventory[id]=maxi(int(state.inventory.get(id,0)),int(event.needs[id]))
 world.hud.show_neighbors("he")
 world.hud.neighbor_journal._on_story_choice(0)
 check(state.action_busy() and state.action_snapshot().kind=="read" and is_equal_approx(float(state.action_snapshot().duration),1.15) and int(state.npc_stories.he.step)==0,"UI故事回应按原版先阅读后推进")
 state.stop_walking()
 check(int(state.npc_stories.he.step)==0,"取消故事不推进")
 state.queue_npc_task("he","story",{"choice":0})
 await finish(state)
 check(int(state.npc_stories.he.step)==1 and state.npc_stories.he.choices==[0] and world.hud.npc_story_panel.visible,"完成故事保存选择并重开")
 world.hud.close_top_panel()
 state.npc_positions.granny=Vector2(2831,1652)
 state.current_interior="test-room"
 state.interior_position=Vector2(480,540)
 state.interior_npc_positions={"granny":Vector2(500,540)}
 state.queue_npc_task("granny","talk",{"topic":"daily"})
 check(state.action_busy(),"室内居民动作可启动")
 state.current_interior=""
 state._process_action(0.1)
 check(not state.action_busy() and state.npc_task.is_empty(),"房间变化清除居民待办")
 print("NPC task smoke: %d passed, %d failed; specs %d, event rows %d"%[passed,failed,fixture.specs.size(),fixture.rows.size()])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
