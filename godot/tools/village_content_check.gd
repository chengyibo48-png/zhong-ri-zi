extends SceneTree
var Q:Script
var count:int=0
var failed:Array=[]
func check(ok:bool,label:String)->void:
	count+=1
	if not ok:failed.append(label);print("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	Q=load("res://scripts/quest_service.gd")
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	var baseline:Dictionary=s._new_game_snapshot();var model:Script=load("res://scripts/quest_model.gd")
	var nodes:int=0;var options:int=0;var titles:Dictionary={};var replies:Dictionary={}
	for id:String in s.content.arcs:
		var arc:Array=s.content.arcs[id];check(arc.size() in [4,5],"story chain "+id)
		for i:int in arc.size():
			var node:Dictionary=arc[i];nodes+=1;check(int(node.points)==i*10,"relationship threshold "+str(node.id));check(not titles.has(node.title),"distinct title "+str(node.id));titles[node.title]=true
			check(node.choices.size()==2,"two choices "+str(node.id))
			for choice:Dictionary in node.choices:options+=1;check(not replies.has(choice.reply),"independent response "+str(node.id));replies[choice.reply]=true
			for item:String in node.needs:check(s.item_catalog.has(item),"real story material "+item)
	check(nodes==104 and options==208 and s.content.arcs.size()==24,"preserved 104 nodes and 208 choices")
	# Combinatorial domain fixtures. They are deliberately distinct from balance play.
	for chapter:int in 4:
		for first:int in 5:
			for second:int in range(first+1,5):
				s.load_game_data(baseline);s.quests.journey={"chapter":chapter,"stage":1}
				for i:int in [first,second]:
					var goal:Array=model.CHAPTERS[chapter].goals[i];var key:String=str(goal[0]);var required:int=int(goal[1])
					match key:
						"talk":
							for id:String in ["granny","chen","xu"]:s.relations[id].talked=0
						"rodSpecies":
							for f:String in ["fish","perch","loach"].slice(0,required):s.fishing.records[f]={"rod":1}
						"rodCatch":s.fishing.records.fish={"rod":1}
						"weeklyComplete":s.economy.claimed=["fixture"]
						"donate":s.collection.donated={"fixture-a":{},"fixture-b":{}}
						"storyFinal":s.npc_stories.granny.step=s.content.arcs.granny.size()
						"nurseryRecord":s.village_progress.growth={"fixture":0}
						_:Q.event(s,key,"",required)
				check(str(Q.snapshot(s,model.chapter_definition(s)).status)=="reward","two-of-five %d/%d/%d"%[chapter,first,second])
	var families:Dictionary={};var homes:int=0
	for room:Dictionary in preload("res://scripts/house_geometry.gd").all().values():
		if str(room.owner)=="":continue
		homes+=1;families[int(room.layoutFamily)]=true
		check(str(room.steps[1].kind) in ["assembly","compare","record"],"authored light activity "+str(room.owner))
		check(Rect2(float(room.bounds[0]),float(room.bounds[1]),float(room.bounds[2]),float(room.bounds[3]))==Rect2(102,104,756,500),"residence area unchanged "+str(room.owner))
	check(homes==24 and families.size()>=6,"six actual residential layouts")
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/village-content-check.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":count,"failed":failed,"storyNodes":nodes,"choices":options,"chapterGoalPairs":40,"note":"Static and injected domain fixture coverage; not normal playthrough evidence"},"\t"))
	print("CONTENT ",count," / ",failed);await root.get_node("AudioService").prepare_exit();quit(0 if failed.is_empty() else 1)
