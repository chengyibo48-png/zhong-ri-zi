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
	Q=load("res://scripts/quest_service.gd");s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	check(OS.get_user_data_dir().replace("\\","/").begins_with(OS.get_environment("TEMP").replace("\\","/")+"/"),"isolated user storage")
	s.flags.introDone=true;s.day=0;s.minutes=600;s.current_interior="";s.money=10000
	var count:int=0;var titles:Dictionary={};var choices:Dictionary={}
	for id:String in s.content.arcs:
		var arc:Array=s.content.arcs[id];count+=arc.size()
		check(arc.size()==(5 if id in ["qiao","lin","zhou","mei","ning","an","yu","yan"] else 4),"individual chain length "+id)
		for i:int in arc.size():
			var e:Dictionary=arc[i]
			check(int(e.points)==i*10 and e.choices.size()==2,"threshold and two choices "+str(e.id))
			check(not titles.has(str(e.title)),"unique authored title "+str(e.title));titles[str(e.title)]=true
			for response:Dictionary in e.choices:
				check(not choices.has(str(response.reply)),"independent response "+str(e.id));choices[str(response.reply)]=true
			for item:String in e.needs:check(s.item_catalog.has(item),"real story material "+item)
	check(count==104 and s.content.arcs.size()==24,"104 nodes across all 24 identities")
	# Getter purity and deferred completion are separate from command mutation.
	s.quests=Q.defaults();s.quest_runtime.reset();Q.sync(s)
	Q.event(s,"visit:bag");var before:Dictionary=s.quests.duplicate(true)
	for i:int in 4:Q.rows(s)
	check(before==s.quests,"snapshot reads do not settle or grant")
	s.quest_runtime._process(.02);s.quest_runtime._process(.02)
	check(str(s.quests.entries.get("guide:home:bag",{}).get("status",""))=="completed","tutorial completes in mutation queue")
	check(not Q.claim(s,"guide:home:bag"),"tutorial receipt rejects repeated claim")
	var emitted:Array=[];s.quest_changed.connect(func():emitted.append(true))
	Q.sync(s);var signals:int=emitted.size();Q.sync(s)
	check(emitted.size()==signals,"unchanged visible snapshot does not notify")
	# Each 2-of-3 combination works without a date or rare-item prerequisite.
	for chapter:int in 4:
		for excluded:int in 3:
			s.quests=Q.defaults();s.quests.journey={"chapter":chapter,"stage":1}
			s.player_stats={};s.collection.donated={};s.economy.claimed=[]
			for id:String in s.npc_stories:s.npc_stories[id]={"step":0,"choices":[],"lastDay":-1}
			for id:String in s.relations:s.relations[id].talked=-1
			for i:int in 3:
				if i==excluded:continue
				var goal:Array=M.CHAPTERS[chapter].goals[i];var key:String=str(goal[0])
				if key=="talk":
					for j:int in 3:s.relations[s.relations.keys()[j]].talked=0
				elif key=="weeklyComplete":s.economy.claimed=["fixture"]
				elif key=="donate":s.collection.donated={"cabbage":{"day":0,"grade":0,"mode":"sample"}}
				elif key=="storyFinal":s.npc_stories.granny={"step":4,"choices":[0,0,0,0],"lastDay":0}
				else:Q.event(s,key,"",int(goal[1]))
			check(str(Q.snapshot(s,M.chapter_definition(s)).status)=="reward","two-of-three chapter %d omit %d"%[chapter,excluded])
	# Complete real project commands and exactly sixteen stages on day zero.
	s.quests=Q.defaults();s.quest_runtime.reset();s.community_projects={};s.flags.bridge=false;s.day=0
	for chapter:int in 4:
		check(Q.claim(s,str(M.chapter_definition(s).id)),"chapter introduction")
		for goal:Array in M.CHAPTERS[chapter].goals:
			match str(goal[0]):
				"weeklyComplete":s.economy.claimed=["fixture"]
				"donate":s.collection.donated={"cabbage":{"day":0,"grade":0,"mode":"sample"}}
				"storyFinal":s.npc_stories.granny={"step":4,"choices":[0,0,0,0],"lastDay":0}
				_:Q.event(s,str(goal[0]),"",int(goal[1]))
		check(Q.claim(s,str(M.chapter_definition(s).id)),"chapter life goals")
		var project:String=str(M.CHAPTERS[chapter].project)
		for item:String in s.content.projects[project].needs:s.inventory[item]=100
		var site:Dictionary=Q.PROJECT_SITES[project];s.player_position=Vector2(float(site.x),float(site.y));s.current_interior=""
		check(s.complete_community_project(project),"actual project domain settles without season wait "+project)
		check(not s.complete_community_project(project),"project cannot pay or consume twice "+project)
		check(Q.claim(s,str(M.chapter_definition(s).id)),"chapter build stage")
		s.current_interior=str(Q.KNOWLEDGE._house(s,"home").id)
		check(Q.claim(s,str(M.chapter_definition(s).id)),"chapter home epilogue")
	check(int(s.quests.journey.chapter)==4 and s.quests.receipts.size()==16,"four chapters sixteen persisted receipts")
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
	var snapshot:Dictionary=s._make_save_data().duplicate(true)
	print("SAVE_DIAGNOSTIC ",preload("res://scripts/native_save_schema.gd").error(snapshot,s.initial_state)," / ",preload("res://scripts/native_save_schema.gd").fishing_error(snapshot))
	check(int(snapshot.version)==37 and Q.validate(snapshot.quests,s.day),"current v37 task envelope validates")
	check(s.load_game_data(snapshot),"new story state native round trip")
	var old:Dictionary=snapshot.duplicate(true);old.version=33;old.quests.version=1
	var live:Dictionary=s.quests.duplicate(true)
	check(not s.load_game_data(old) and s.quests==live,"old task version rejects without live-state changes")
	check(s.save_game("user://quest-overhaul.json",true) and s.load_game("user://quest-overhaul.json"),"disk round trip")
	print("QUEST_OVERHAUL: %d passed, %d failed; nodes=%d choices=208"%[passed,failed,count])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
