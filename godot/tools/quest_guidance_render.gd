extends SceneTree
var passed:=0
var failed:=0
var out:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle()->void:
	for i:int in 12:await process_frame
func capture(name:String)->void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"GPU screenshot "+name)
func run()->void:
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/guidance";DirAccess.make_dir_recursive_absolute(out)
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
	var q:Script=load("res://scripts/quest_service.gd")
	s.flags.introDone=true;s.current_interior="";s.player_position=Vector2(3150,2185);s.minutes=600
	for id:String in s.relations:s.relations[id].talked=-1
	s.relations.granny.talked=0;s.quests=q.defaults();s.quests.journey.stage=1;s.player_stats.harvested=1
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var hud:Node=current_scene.hud;var panel:Control=hud.life_plan_panel
	s.quest_runtime.reset();q.sync(s);panel.open_panel("journey:0:1");await capture("chapter-next-goal")
	hud.ui_stack.leave()
	check(not s.ui_open and hud.quest_tracker.visible,"closing journal immediately restores the live task HUD")
	hud.quest_tracker.refresh(hud);await capture("hud-next-unfinished")
	var texts:String=""
	for button:Node in hud.quest_tracker.rows.get_children():
		if button is Button:texts+=button.text
	check(texts.contains("生活目标 1 / 2") and texts.contains("做一道家常菜"),"live HUD presents the next incomplete choice")
	var order:Dictionary=s.economy_weekly_orders()[2]
	var item:String=str(order.id);s.inventory[item]=3;s.quality[item]=[2,0,0]
	s.kitchen.lots.bag[item]=[{"qty":1,"grade":0,"age":0.0},{"qty":1,"grade":1,"age":999.0},{"qty":1,"grade":1,"age":0.0}]
	check(q.accept(s,"weekly:"+str(order.key)),"real weekly order accepts")
	s.quest_runtime.reset();q.sync(s);panel.open_panel("weekly:"+str(order.key));await capture("mixed-lot-details")
	var selected:Dictionary=panel.current_rows[panel.task_list.get_selected_items()[0]]
	check(selected.blockers.size()==2 and int(selected.progress[0].eligible)==1,"handbook displays separate freshness and quality causes")
	s.player_settings.textScale=1.25;s.source_input_mode="touch";s.changed.emit();root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	panel.refresh();await capture("mixed-lot-large-text")
	check(panel.detail_scroll.get_global_rect().end.x<=root.get_visible_rect().end.x,"long reasons fit the scrollable viewport")
	panel.open_panel("story:granny:0");await capture("story-context")
	var content:String="";var story_buttons:int=0
	for label:Node in panel.detail.get_children():
		if label is Label:content+=label.text
	for button:Node in panel.action_dock.get_children():
		if button is Button and button.text.contains("故事"):story_buttons+=1
	check(content.contains(str(s.content.arcs.granny[0].text)) and content.contains("第 1 / 4 段"),"handbook shows authored story and stage count")
	check(story_buttons==1,"story has one main action instead of duplicate entrances")
	print("QUEST_GUIDANCE_GPU: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
