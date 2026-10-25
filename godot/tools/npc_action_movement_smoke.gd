extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 var state=root.get_node("GameState");state.set_process(false)
 var person:Dictionary={}
 for row in state.npc_catalog:
  if str(row.id)=="lin":person=row
 var home:=""
 for house in state.world_village.houses:
  if str(house.get("owner",""))=="lin":home=str(house.id)
 check(not person.is_empty() and home!="","original resident and home found")
 state.minutes=600
 for indoors in [false,true]:
  state.current_interior=home if indoors else ""
  state.player_position=Vector2(540,850);state.interior_position=Vector2(480,520)
  state.npc_residents.lin={"x":600.0,"y":850.0,"direction":"down","room":home if indoors else null}
  state.npc_movement.actors.lin={"walking":true,"emotion":"worried","wait":0.0,"path":[],"phase":"","inside":{"x":480.0,"y":550.0,"direction":"down"}}
  state.npc_movement.clock=123.0
  check(state.action_sequence.start({"kind":"greet","duration":1.1,"npcId":"lin"},func():pass),"actual wrapped sequence started")
  state.npc_movement.update_actor(state,person,state.npc_catalog.find(person),0.1)
  var runtime:Dictionary=state.npc_movement.actors.lin
  var position:Dictionary=runtime.inside if indoors else state.npc_residents.lin
  check(not runtime.walking,"addressed NPC stops walking "+str(indoors))
  check(position.x==(480.0 if indoors else 600.0) and position.y==(550.0 if indoors else 850.0),"addressed NPC keeps exact original position "+str(indoors))
  check(str(position.direction)==("up" if indoors else "left"),"addressed NPC faces player "+str(indoors))
  check(runtime.get("emotion")=="focus","original interaction focus preserved "+str(indoors))
  check(is_equal_approx(float(runtime.get("emotionUntil",-1)),125.0),"original focus duration preserved "+str(indoors))
  state.action_sequence.cancel(false)
 # Old flat fixture representation still follows the original JavaScript contract.
 state.current_interior=""
 state.npc_residents.lin={"x":600.0,"y":850.0,"direction":"down","room":null}
 state.npc_movement.actors.lin={"walking":true,"inside":{}}
 state.action_sequence.active={"npcId":"lin"}
 state.npc_movement.update_actor(state,person,state.npc_catalog.find(person),0.1)
 check(not state.npc_movement.actors.lin.walking,"legacy flat sequence fixture remains compatible")
 check(state.npc_residents.lin.x==600.0 and state.npc_residents.lin.y==850.0,"legacy fixture keeps exact position")
 state.action_sequence.active={}
 print("NPC_ACTION_MOVEMENT: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
