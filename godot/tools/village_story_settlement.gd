extends SceneTree
var s:Node
var Q:Script
var M:Script=preload("res://scripts/quest_model.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func finish()->void:
	for i:int in 100:
		if not s.action_busy():break
		s._process_action(.1)
	check(not s.action_busy(),"action reaches a completion or a validated cancellation")
func run()->void:
	await process_frame
	Q=load("res://scripts/quest_service.gd");s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.autosave_coordinator.pending=false;s.autosave_coordinator.inline_for_tests=true
	# All authored choices execute through the real story and action commands.
	s.current_interior="";s.player_position=Vector2(2500,1800);s.money=10000
	for branch:int in 2:
		s.quests=Q.defaults();s.quest_runtime.reset()
		for id:String in s.content.arcs:
			s.npc_stories[id]={"step":0,"choices":[],"lastDay":-1};s.relations[id].points=0;s.npc_positions[id]=s.player_position
			var arc:Array=s.content.arcs[id]
			for i:int in arc.size():
				s.relations[id].points=i*10
				for item:String in arc[i].needs:s.inventory[item]=10
				if arc[i].has("activity"):
					check(not bool(s.npc_story_readiness(id).ok),"activity is a genuine prerequisite "+id)
					check(s.start_npc_story_activity(id),"start activity "+id);finish()
					check(not s.start_npc_story_activity(id),"activity cannot repeat "+id)
				var points:int=int(s.relations[id].points);var cash:int=s.money
				check(s.choose_npc_story(id,branch),"story branch %d %s-%d"%[branch,id,i])
				check(int(s.relations[id].points)==points+5,"exactly five relation points")
				check(s.money-cash==M.story_compensation(s,arc[i]),"materials compensated at base value")
				var actual:Dictionary=s.npc_stories[id].duplicate(true)
				s.npc_stories[id].step=i;s.npc_stories[id].choices.resize(i)
				check(not s.choose_npc_story(id,branch),"settlement receipt rejects event replay")
				s.npc_stories[id]=actual
			check(s.quests.memorials.has(id),"persistent choice memorial "+id)
		check(s.quests.memorials.size()==24,"all residents retain a conclusion without marriage")

	check(s.load_game_data(s._make_save_data().duplicate(true)),"all story choices survive validated v38 roundtrip")
	print("STORY_BRANCHES %d passed %d failed; 104 nodes x 2 choices"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
