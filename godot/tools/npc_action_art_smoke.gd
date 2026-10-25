extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 var state=root.get_node("GameState")
 state.set_process(false)
 state.ui_open=false
 state.current_interior=""
 var inventory:Dictionary=state.inventory.duplicate(true)
 var animals:Array=state.animals.duplicate(true)
 var residents:Dictionary=state.npc_residents.duplicate(true)
 var actors:Dictionary={}
 for id in ["lin","chen","qiao"]:
  var node=load("res://scripts/world_npc.gd").new()
  node.npc_id=id
  for row in state.npc_catalog:
   if str(row.id)==id:node.npc_data=row.duplicate(true)
  root.add_child(node);actors[id]=node
 var lin=actors.lin.character_visual
 var other=actors.qiao.character_visual
 var calls:Dictionary={"commit":0}
 var commit:=func():calls.commit+=1
 check(state.begin_action({"kind":"greet","duration":1.1},{"kind":"npc-task","npcId":"lin","x":200,"y":200},commit),"real action entry accepted")
 check(lin.sequence_managed and lin.action_state=="greet","target NPC receives live greeting snapshot")
 check(not other.sequence_managed,"unrelated resident keeps its own animation")
 state.action_sequence.active.elapsed=0.55
 state._sync_action_visual()
 check(is_equal_approx(lin.action_elapsed/lin.action_duration,0.5),"NPC uses exact existing action progress")
 check(calls.commit==0,"render sync does not commit gameplay")
 check(state.cancel_action(),"real cancellation accepted")
 check(not lin.sequence_managed and lin.action_state=="","cancel clears target NPC animation")
 check(calls.commit==0,"cancel does not settle interaction")
 check(state.begin_action({"kind":"greet","duration":1.1},{"kind":"npc-task","npcId":"lin","x":200,"y":200},commit),"second action starts")
 state.action_sequence.active.elapsed=1.09
 state.action_sequence.tick(0.1)
 state._sync_action_visual()
 check(calls.commit==1,"completed action settles exactly once")
 check(not lin.sequence_managed and lin.action_state=="","completion clears target animation")
 state._sync_action_visual()
 check(calls.commit==1,"repeated render sync cannot repeat reward")
 check(state.begin_action({"kind":"greet","duration":1.1},{"kind":"npc-task","npcId":"lin","x":200,"y":200},commit),"scene-switch action starts")
 state.current_interior="home-lin";state._process_action(0.1)
 check(not state.action_busy() and not lin.sequence_managed,"room change cancels and clears NPC snapshot")
 check(calls.commit==1,"room cancellation cannot commit")
 state.current_interior=""
 check(state.begin_action({"kind":"sleep","duration":1.1},{"kind":"npc-task","npcId":"qiao","x":200,"y":200},commit),"unfinished resident clip action remains valid")
 check(not other.sequence_managed,"missing painted action keeps existing renderer")
 state.cancel_action()
 check(state.inventory==inventory,"animation preserves item quantities")
 check(state.animals==animals,"animation preserves animal state")
 check(state.npc_residents==residents,"animation preserves authoritative resident positions")
 for actor in actors.values():actor.queue_free()
 await process_frame
 state._sync_action_visual()
 check(get_nodes_in_group("resident_visual_actor").is_empty(),"freed actors leave group safely")
 print("NPC_ACTION_ART: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
