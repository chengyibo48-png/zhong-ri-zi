extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func same(a:Variant,b:Variant) -> bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for k in a:
   if not b.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in range(a.size()):
   if not same(a[i],b[i]):return false
  return true
 if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b))<0.0001
 return a==b
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<12:push_error(label)
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 create_timer(60).timeout.connect(func():quit(1))
 var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ACTION_ART_FIXTURE")))
 if not raw is Dictionary:
  quit(1)
  return
 var fixture:Dictionary=raw
 var art=load("res://scripts/action_art.gd")
 if art==null or not art.can_instantiate():
  quit(1)
  return
 for row in fixture.rows:
  var direction:Vector2={"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN}[row.player.direction]
  var player:=Vector2(float(row.player.x),float(row.player.y))
  var label:=str(row.action.kind)+"/"+str(row.player.direction)+"/"+str(row.action.progress)+"/"+str(row.action.get("animalType",""))
  var previous_failed:=failed
  check(same(art.pose(player,direction,row.action),row.pose),"原版动作姿态 "+label)
  var frame:Array=art.frame(player,direction,row.action,row.skin,float(row.clock),bool(row.known),row.game)
  check(same(frame,row.frame),"原版动作绘制 "+label)
  if failed>previous_failed and failed==1:
   print("First mismatch actual=",JSON.stringify(frame)," expected=",JSON.stringify(row.frame))
 for row in fixture.ballistic:
  check(same(art.xy(art.ballistic(art.vec(row.from),art.vec(row.to),float(row.t),float(row.lift))),row.result),"原版抛物轨迹")
 var state=root.get_node("GameState")
 state.set_process(false)
 state.current_interior=""
 state._ranch_new_animal("sheep","female","local",112)
 var character_script=load("res://scripts/character_visual.gd")
 if character_script==null or not character_script.can_instantiate():
  push_error("人物脚本未编译，停止场景验收")
  quit(1)
  return
 root.size=Vector2i(960,600)
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame
 await process_frame
 var hud=current_scene.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.ui_open=false
 var visual=current_scene.player.character_visual
 var position:Vector2=current_scene.player.global_position
 var rules=load("res://scripts/action_rules.gd")
 for type in ["cow","sheep"]:
  var found:=false
  for animal in state.animals:
   if str(animal.type)!=type:continue
   found=true
   var target:Dictionary={"kind":"ranch-task","animalId":animal.id,"x":position.x+31.0,"y":position.y+17.0}
   check(state.begin_action(rules.spec("harvest"),target,func():pass),"实际 "+type+" 收取开始")
   check(str(state.action_snapshot().animalType)==type and str(state.action_snapshot().item)==str(animal.product),"实际 "+type+" 类型和物产随动作传递")
   state._process_action(0.1)
   check(str(visual.sequence_snapshot.animalType)==type,"人物收到 "+type+" 动作分支")
   var local:Dictionary=visual.local_action_snapshot()
   check(absf(float(local.x)-31.0)<0.001 and absf(float(local.y)-17.0)<0.001,"世界目标转换人物局部坐标")
   check(same(visual.source_action_frame(),art.frame(Vector2.ZERO,visual.facing,local,str(visual.appearance.skin),visual.walk_clock,true)),"实际人物调用原版帧模型")
   state.cancel_action()
   check(visual.sequence_snapshot.is_empty(),"取消清理人物目标与物产")
   break
  check(found,"验证场景含 "+type)
 # Exercise the real ranch arrival wrapper, which must carry the animal ID.
 var animal:Dictionary=state.animals[2]
 animal.position={"x":position.x+31.0,"y":position.y+17.0,"room":null,"inside":{}}
 state.ranch_active_task={"animalId":animal.id,"action":"collect"}
 var destination:Dictionary=state.ranch_task_destination(state.ranch_active_task)
 state.finish_ranch_task(destination)
 check(state.action_busy() and str(state.action_snapshot().get("animalType",""))==str(animal.type),"实际牧场任务抵达携带动物类型")
 check(str(state.action_snapshot().get("item",""))==str(animal.product),"实际牧场任务携带产物图标")
 state.stop_walking()
 state.plots[0].crop="cabbage"
 var plot:Vector2=state.farm_plot_position(0)
 check(state.begin_action(rules.spec("harvest"),{"kind":"farm-task","index":0,"x":plot.x,"y":plot.y},func():pass),"实际田块收获开始")
 check(str(state.action_snapshot().item)=="cabbage","实际田块动作携带作物图标")
 state.cancel_action()
 state.plots[1].crop=null
 state.begin_action(rules.spec("water"),{"kind":"farm-task","index":1},func():pass)
 check(state.action_snapshot().has("item") and state.action_snapshot().item==null,"空田块物产保留原版 null")
 state.cancel_action()
 current_scene.world_effects.burst("harvest",position,true)
 check(not current_scene.world_effects.bursts.is_empty(),"准备旧动作粒子")
 state.begin_action(rules.spec("read"),{"kind":"test"},func():pass)
 check(current_scene.world_effects.bursts.is_empty(),"开始新序列清理旧动作粒子")
 current_scene.world_effects.burst("water",position)
 state.cancel_action()
 check(current_scene.world_effects.bursts.is_empty(),"取消序列清理手边粒子")
 var burst_count:int=current_scene.world_effects.bursts.size()
 state.begin_action(rules.spec("water"),{"kind":"test"},func():current_scene._emit_world_effect("water",position))
 for i in range(13):state._process_action(0.1)
 check(current_scene.world_effects.bursts.size()==burst_count and visual.action_state=="","序列完成后不重播人物和场景粒子")
 if current_scene!=null:current_scene.queue_free()
 await process_frame
 await root.get_node("AudioService").prepare_exit()
 print("Action art smoke: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
