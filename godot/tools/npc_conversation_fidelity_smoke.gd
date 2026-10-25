extends SceneTree
var passed:=0
var failed:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 if ok:passed+=1
 else:
  failed+=1
  if failed<110:push_error(label)
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
func prepare(state:Node,before:Dictionary,id:String):
 check(state.load_game_data(state.convert_external_save(before)),"源对话输入")
 state.current_interior=""
 state.npc_positions={id:Vector2(2831,1652)}
 # Source state examples retain the requested authored event while generated daily events are preserved.
func compare(state:Node,row:Dictionary,label:String):
 check(state.message==str(row.result.msg),"原版对白 "+label+" actual="+state.message+" expected="+str(row.result.msg))
 check(equivalent(state.neighbors.people[str(row.id)],row.expected.people),"原版近期对白 "+label)
 check(equivalent(state.neighbors.history,row.expected.history),"原版对话历史 "+label)
 check(equivalent(state.relations,row.expected.relations),"原版交谈关系 "+label)
 check(stock(state.inventory,row.expected.bag),"原版交谈物品 "+label)
 check(equivalent(state.known_recipes,row.expected.knownRecipes),"原版请教配方 "+label)
 check(equivalent(state.skills,row.expected.skills),"原版交谈经验 "+label)
 check(equivalent(state.legacy_systems.get("eventLog",[]),row.expected.eventLog),"原版学艺事件日志 "+label)
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):
  quit(1)
  return
 var fixture=FileAccess.open(OS.get_environment("NPC_CONVERSATION_FIXTURE"),FileAccess.READ)
 if fixture==null:
  push_error("Missing source conversation fixture")
  quit(1)
  return
 var script=load("res://scripts/game_state.gd")
 var state=script.new()
 state._load_content()
 state._load_initial_state()
 var cases:=0
 var sequences:=0
 while not fixture.eof_reached():
  var line:=fixture.get_line()
  if line.is_empty():continue
  var row:Dictionary=JSON.parse_string(line)
  prepare(state,row.before,str(row.id))
  if str(row.type)=="case":
   cases+=1
   var person:Dictionary={}
   for n in state.npc_catalog:
    if str(n.id)==str(row.id):person=n;break
   var candidates:Array=state.npc_dialogue_candidates(person,str(row.topic))
   check(equivalent(candidates,row.candidates),"原版候选列表 "+str(row.id)+"/"+str(row.variant)+"/"+str(row.topic)+" actual="+JSON.stringify(candidates)+" expected="+JSON.stringify(row.candidates))
   state.talk_to_npc(str(row.id),str(row.topic))
   compare(state,row,str(row.id)+"/"+str(row.variant)+"/"+str(row.topic))
  else:
   sequences+=1
   for index in range(row.turns.size()):
    var expected:Dictionary=row.turns[index]
    state.talk_to_npc(str(row.id),str(row.topic))
    compare(state,{"id":row.id,"result":expected.result,"expected":expected},str(row.id)+"/"+str(row.topic)+"/"+str(index))
 fixture.close()
 state.free()
 print("NPC conversation fidelity: %d passed, %d failed; cases %d, repeated sequences %d"%[passed,failed,cases,sequences])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed==0 else 1)
