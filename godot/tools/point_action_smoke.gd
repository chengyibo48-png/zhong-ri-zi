extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  push_error(label)
func json(v:Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func stock(actual:Dictionary,expected:Dictionary)->bool:
 for id in actual:
  if int(actual[id])!=int(expected.get(id,0)):return false
 for id in expected:
  if int(expected[id])!=int(actual.get(id,0)):return false
 return true
func quality(actual:Dictionary,expected:Dictionary)->bool:
 var ids:Array=actual.keys()
 for id in expected:
  if not ids.has(id):ids.append(id)
 for id in ids:
  if json(actual.get(id,[0,0,0]))!=json(expected.get(id,[0,0,0])):return false
 return true
func finish(state:Node):
 for i in range(80):
  if not state.action_busy():break
  state._process_action(0.1)
 await process_frame
 await process_frame
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 create_timer(120).timeout.connect(func():quit(1))
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POINT_ACTION_FIXTURE")))
 var state=root.get_node("GameState")
 state.set_process(false)
 root.size=Vector2i(960,600)
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame
 await process_frame
 var world=current_scene
 world.set_process(false)
 world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 for row in fixture.fades:
  var sample:Variant={} if row.a==null else row.a
  check(is_equal_approx(state.action_darkness(sample,float(row.remaining),str(row.motion)),float(row.expected)),"原版渐暗曲线 "+str(row.a)+"/"+str(row.motion))
 # Check every canonical point across four seasons, including actual scene nodes.
 var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_gather_points.json"))
 for season in range(4):
  state.day=season*28
  state.forage.patches={}
  state.forage.xp=0
  state.forage.mode="gentle"
  state.gathered={}
  world._refresh()
  check(world.legacy_gather_nodes.size()==12,"换季保留十二个原版采集节点")
  for point in legacy[str(season)]:
   var id:=str(point.id)
   var node:Node2D=world.legacy_gather_nodes.get(id,null)
   check(node!=null and node.global_position.is_equal_approx(Vector2(float(point.x),float(point.y))),"原版采集点实际坐标 "+id)
   check(node!=null and str(node.item_id)==str(point.item) and str(node.node_name)==str(point.name),"原版采集点四季物产与再生提示 "+id)
   var found:=0
   for registered in state.forage_points:
    if str(registered.id)==id:
     found+=1
     check(str(registered.item)==str(point.item) and str(registered.name)==str(point.name),"采集目录随状态刷新 "+id)
   check(found==1,"换季不重复注册采集点 "+id)
   var actual:Dictionary=world.resolve_interaction_target(point)
   check(not actual.is_empty() and str(actual.item)==str(point.item),"实际交互候选物产 "+id)
 state.day=0
 world._refresh()
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"世界事务源状态导入")
  state.ui_open=false
  state.current_interior=""
  world.player.global_position=Vector2(float(row.point.x),float(row.point.y))+Vector2(0,8)
  state.player_position=world.player.global_position
  var target:Dictionary=row.point.duplicate(true)
  if row.kind=="gather":
   target=world.resolve_interaction_target(row.point)
   check(not target.is_empty() and str(target.get("item",""))==str(row.point.item),"采集点携带实际物产")
   if target.is_empty():continue
  var before:Dictionary=state._make_save_data()
  world._interact_target(target)
  check(state.action_busy() and state.action_snapshot().kind==row.spec.kind,"原版普通交互开始动作 "+str(row.point))
  check(stock(state.inventory,row.before.bag) and state.stamina==int(row.before.stamina) and state.minutes==int(row.before.minutes),"未完成不提前执行 "+str(row.kind))
  state.stop_walking()
  check(stock(state.inventory,row.before.bag) and state.stamina==int(row.before.stamina),"取消不结算 "+str(row.kind))
  world._interact_target(target)
  # Changing hover must never change the captured action target.
  world.hovered_resource="other"
  world.hovered_pet=false
  world.hovered_plot=12
  await finish(state)
  check(not state.action_busy(),"世界事务结束 "+str(row.kind))
  check(state.stamina==int(row.expected.stamina) and state.minutes==int(row.expected.minutes) and state.money==int(row.expected.money),"普通交互原版体力时间金币 "+str(row.kind)+"/"+str(row.variant))
  check(stock(state.inventory,row.expected.bag) and quality(state.quality,row.expected.quality),"普通交互原版库存品质 "+str(row.kind))
  if row.kind=="pet":
   check(json(state.pet_state)==json(row.expected.pet),"原版宠物状态")
  if row.kind=="gather":
   check(json(state.forage)==json(row.expected.forage),"原版采集生态状态")
 # The full UI is opened only after read animation.
 world.hud.close_top_panel()
 state.ui_open=false
 var mailbox:Dictionary={}
 for point in world._world_target_candidates():
  if str(point.kind)=="mail":mailbox=point;break
 check(not mailbox.is_empty(),"世界含信箱")
 world._interact_target(mailbox)
 check(state.action_busy() and not world.hud.mail_open(),"翻阅未完成不开信件")
 await finish(state)
 check(world.hud.mail_open(),"完成翻阅打开信件")
 world.hud.close_mail()
 # Actual manual door entry, cancellation and exit.
 var house:Dictionary=world.world_data.village.houses[0]
 var door:Dictionary={"kind":"enter","id":house.id,"house":house.id,"x":house.door.x,"y":house.door.y}
 world.player.global_position=Vector2(float(door.x),float(door.y))+Vector2(0,8)
 state.player_position=world.player.global_position
 world._interact_target(door)
 check(state.action_busy() and state.current_interior=="","推门未完成不换屋")
 state.stop_walking()
 check(state.current_interior=="","推门取消留在户外")
 world._interact_target(door)
 for i in range(7):state._process_action(0.1)
 check(state.current_interior=="" and world.hud.scene_fade.visible,"推门末阶段渐暗而未切换")
 state._process_action(0.1)
 await process_frame
 await process_frame
 world=current_scene
 world.set_process(false)
 world.player.set_physics_process(false)
 check(state.current_interior==str(house.id) and world.name=="InteriorWorld","推门完整后实际进入")
 check(state.scene_fade_remaining>0.0 and world.hud.scene_fade.visible,"跨场景保留门口渐暗")
 state._advance_scene_fade(0.1)
 state._advance_scene_fade(0.1)
 state._advance_scene_fade(0.1)
 check(not world.hud.scene_fade.visible,"门口渐暗在 0.3 秒清理")
 state.stamina=50
 var tea:Dictionary={"kind":"tea","id":"test-tea","x":world.player.global_position.x,"y":world.player.global_position.y}
 world._interact_target(tea)
 check(state.stamina==50 and state.action_busy(),"室内饮茶延迟执行")
 await finish(state)
 check(state.stamina==58,"室内饮茶完成恢复八体力")
 world._interact_target({"kind":"exit","id":"exit","x":480,"y":550})
 check(state.current_interior==str(house.id) and state.action_busy(),"出屋推门延迟切换")
 state.stop_walking()
 check(state.current_interior==str(house.id),"取消出屋保留房间")
 world._interact_target({"kind":"exit","id":"exit","x":480,"y":550})
 await finish(state)
 check(state.current_interior=="" and current_scene.name=="FarmWorld","完成推门实际出屋")
 print("Point action smoke: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
