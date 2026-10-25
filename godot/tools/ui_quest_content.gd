extends SceneTree
var s: Node
var w: Node
var Q: GDScript
var passed:=0
var failed:=0
var completed: Array[String]=[]
var plot_index:=0
var trap_id: String=""
func _initialize() -> void:call_deferred("run")
func check(value: bool,text: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(text)
func settle() -> void:
	for i: int in range(4):await process_frame
func near_npc(id: String) -> void:
	s.current_interior="";s.npc_positions[id]=Vector2(2690,1912);s.player_position=s.npc_positions[id];w.player.global_position=s.player_position
func process_food() -> void:
	s.upgrades.mill=true;s.inventory.wheat=10
	check(s.process_recipe("flour",1),"real processing enqueue")
	if not s.kitchen.jobs.is_empty():
		var job: Dictionary=s.kitchen.jobs[-1];s.minutes=maxf(s.minutes,float(job.ready)-s.day*1440)
		check(s.collect_kitchen_job(int(job.key)),"real processing claim")
func perform(id: String) -> void:
	s.stamina=100;s.current_interior="";w.hud.ui_stack.leave()
	match id:
		"guide:home:bag":w.hud.show_market("inventory",false);await settle()
		"guide:home:tools":check(s.select_toolbar_tool("water"),"real toolbar selection")
		"guide:home:map":w.hud.show_map();await settle()
		"guide:home:rest":s.advance_day();await settle()
		"guide:home:plans":check(s.quest_pin(id),"actual task pin")
		"guide:home:help":w.hud.show_help();await settle()
		"guide:farm:seed":check(Q.metric(s,"seasonSeed")>0,"actual season-appropriate starting seed")
		"guide:farm:sow":
			s.plots[plot_index].crop="";s.plots[plot_index].tilled=false;s.selected_seed="cabbage"
			check(s._farm_plot_action_single(plot_index,"hoe"),"real till action")
			check(s._farm_plot_action_single(plot_index,"seed"),"real sow action")
		"guide:farm:water":s.plots[plot_index].moisture=10;check(s._farm_plot_action_single(plot_index,"water"),"real watering action")
		"guide:farm:harvest":s.plots[plot_index].growth=s.crop_days("cabbage");check(s._farm_plot_action_single(plot_index,"hand"),"real harvest action")
		"guide:farm:soil":s.plots[plot_index].fertility=60;s.inventory.compost=2;check(s._farm_plot_action_single(plot_index,"fertilizer"),"real fertilizer action")
		"guide:farm:process","guide:cook:process":process_food()
		"guide:ranch:home":w.hud.show_ranch();await settle()
		"guide:ranch:movein":check(not s.animals.is_empty(),"actual resident animal")
		"guide:ranch:care":check(s.ranch_tend(0,"pet"),"real animal pet action")
		"guide:ranch:collect":
			var products: Array=s.ranch.get("products",[])
			if products.is_empty():s.advance_day();products=s.ranch.products
			check(not products.is_empty(),"real daily ranch output exists")
			if not products.is_empty():
				var product: Dictionary=products[0];s.current_interior="" if product.room==null else str(product.room);s.interior_position=Vector2(float(product.x),float(product.y));s.player_position=s.interior_position
				check(s.ranch_fixture_action("ranch-product",str(product.id)),"real animal product pickup")
		"guide:ranch:graze":
			var a: Dictionary=s.animals[0];var spec: Dictionary=s.system_catalog.ranch.species[str(a.type)];var pen: Dictionary=s.system_catalog.forage.pens[int(spec.get("grazingZone",s.ranch.zone))]
			a.age=int(spec.adult);a.hunger=40;a.mealDay=s.day;a.mealUnits=0;a.position={"room":null,"walking":false,"x":float(pen.x)+100,"y":float(pen.y)+150};s.ranch.policy="day";s.ranch.grass=[100,100]
			load("res://scripts/ranch_care.gd").graze(s,a,3.1);s.changed.emit()
		"guide:fish:prepare":
			s.player_position=Vector2(749,2790);w.player.global_position=s.player_position;w.hud.show_fishing("river","fishing");await settle()
		"guide:fish:catch":
			s.player_position=Vector2(749,2790);w.player.global_position=s.player_position;s.minutes=480;s.fishing.bait="plain"
			check(s.begin_fishing("fishing"),"real tracking session begins")
			for frame: int in range(1400):
				if not s.fishing_active():break
				var g: Dictionary=s.fishing_session.game
				if str(g.stage)=="fight":g.holding=clampf((float(g.fishPos)-float(g.barPos))*5,-.6,.6)>float(g.velocity)
				s._process_action(.04)
			check(not s.fishing.pending.is_empty() and s.fishing_resolve(false),"actual fish kept through decision")
		"guide:fish:result":w.hud.show_museum("catalog","item:fish");await settle()
		"guide:fish:trap":
			s.inventory.wood=100;s.inventory.bamboo=100;s.inventory.rice=10
			check(s.fishing_craft("fishTrap") and s.fishing_craft("grainBait"),"actual cage and bait crafting")
			var slot: Dictionary=s.system_catalog.fishing.trapSlots[0];trap_id=str(slot.id);s.player_position=Vector2(float(slot.x),float(slot.y))
			check(load("res://scripts/fishing_service.gd").trap_action(s,trap_id,"place"),"actual legal cage placement")
			check(load("res://scripts/fishing_service.gd").trap_action(s,trap_id,"bait","grain"),"actual cage baiting")
		"guide:fish:collect":
			s.advance_day();var slot: Dictionary=load("res://scripts/fishing_service.gd").slot(s,trap_id);s.player_position=Vector2(float(slot.x),float(slot.y))
			check(load("res://scripts/fishing_service.gd").trap_action(s,trap_id,"take"),"actual next-day cage claim")
		"guide:cook:ingredients":s._grant_legacy_item("cabbage",2);s._reconcile_kitchen_lots()
		"guide:cook:meal":check(s.cook_recipe("greens",1),"real greens cooking")
		"guide:cook:fresh":w.hud.show_market("inventory",false);await settle()
		"guide:cook:share":near_npc("granny");check(s.gift_npc("granny","rice"),"real face-to-face food sharing")
		"guide:neighbor:hello":near_npc("granny");check(s.talk_to_npc("granny"),"real neighbor conversation")
		"guide:neighbor:gift":near_npc("chen");check(s.gift_npc("chen","rice"),"real neighbor gift")
		"guide:neighbor:wish":
			near_npc("granny");s.inventory.greens=maxi(1,int(s.inventory.get("greens",0)));s._reconcile_kitchen_lots();s.quest_accept("wish:firstDish")
			check(s.quest_submit("wish:firstDish"),"real wish action begins");finish_action()
			check(bool(s.flags.get("firstDish",false)),"real wish completes after action")
		"guide:neighbor:story":near_npc("granny");check(s.choose_npc_story("granny",0),"real story choice")
		"guide:neighbor:together":s.player_position=Vector2(960,700);check(s.attend_small_gathering("tea"),"actual tea gathering region")
		"guide:village:bridge","guide:village:canal","guide:village:market","guide:village:stage":
			var ref: String=id.get_slice(":",2);var project: Dictionary=s.content.projects[ref];s.day=maxi(s.day,int(project.season)*28);s.minutes=480;s.stamina=100;s.inventory.wood=100;s.inventory.bamboo=100
			var destination: Dictionary=Q.target(s,{"id":"project:"+ref,"source":"project:"+ref});s.player_position=Vector2(float(destination.x),float(destination.y));w.player.global_position=s.player_position
			s.quest_accept("project:"+ref);check(s.quest_submit("project:"+ref),"real on-site build begins "+ref);finish_action();check(bool(s.community_projects.get(ref,false)),"real public project finished "+ref)
		"guide:memory:season":w.hud.show_weather();await settle()
		"guide:memory:research":
			s.current_interior=str(s.system_catalog.museum.house.id);s.interior_position=Vector2(480,510);s._museum_sync();check(s.museum_research("item:wood"),"actual on-site research")
		"guide:memory:donate":
			s.current_interior=str(s.system_catalog.museum.house.id);s.interior_position=Vector2(480,510);s._grant_legacy_item("cabbage",1);s._museum_sync();check(s.museum_donate("item:cabbage","sample",0),"actual museum donation")
		"guide:memory:year":s.day=112;w.hud.community_panel.open_panel("year");await settle()
	w.hud.ui_stack.leave();Q.sync(s)
func finish_action() -> void:
	for frame: int in range(150):
		if not s.action_busy():break
		s._process_action(.1)
	check(not s.action_busy(),"action sequence reaches a real completion")
func run() -> void:
	create_timer(160,true,false,true).timeout.connect(func():push_error("guide content timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.current_interior="";Q=load("res://scripts/quest_service.gd")
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.set_process(false);w.player.set_physics_process(false);s.quests=Q.defaults();Q.sync(s)
	for definition: Dictionary in Q.guides():
		var id: String=definition.id
		if not s.quests.entries.has(id):check(s.quest_accept(id),"accept guide "+id)
		await perform(id)
		var state: Dictionary=Q.snapshot(s,Q.definition(s,id))
		check(str(state.status)=="reward","real objective completed "+id+" metric="+str(state.current)+" "+s.message)
		check(s.quest_claim(id),"claim guide "+id)
		check(not s.quest_claim(id),"claim-once guide "+id)
		if str(s.quests.entries.get(id,{}).get("status",""))=="completed":completed.append(id)
	check(completed.size()==40,"all forty configured nodes complete through gameplay sources")
	var filtered: Array=s.quest_snapshot({"category":"人物","search":"阿婆"})
	check(not filtered.is_empty() and filtered.all(func(row: Dictionary):return str(row.category)=="人物" and (str(row.title)+str(row.text)).contains("阿婆")),"task category and text filters agree with actual rows")
	check(s.quest_snapshot({"search":"a-quest-that-does-not-exist"}).is_empty(),"empty search result is truthful")
	check(s.quest_snapshot().any(func(row: Dictionary):return str(row.id)=="story:granny:0" and str(row.status)=="completed"),"completed story retained in unified journal")
	var f:=FileAccess.open("res://artifacts/ui-quests-20261017/content-report.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"failed":failed,"completedGuides":completed,"fixtures":"Accelerated growth/dates and supplied materials; task progress originates from real domain operations and UI input."},"  "))
	print("UI quest content: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
