extends SceneTree
const PRODUCTS = preload("res://scripts/ranch_products.gd")
var passed := 0
var failed := 0
var s: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(6):await process_frame
func queue_finished(seconds: int = 35) -> void:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<deadline:
		if s.ranch_queue.is_empty() and s.ranch_active_task.is_empty() and s.walking_target.is_empty() and not s.action_busy():return
		await physics_frame
	check(false,"walking batch timeout: "+str(s.message))
func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func():push_error("ranch walking timeout");quit(1))
	s=root.get_node("GameState");s.set_process(false);s.ui_open=false;s.day=0;s.minutes=800;s.flags.introDone=true
	s.current_interior="";s.animals.clear();s.ranch.products=[];s.ranch.policy="safe"
	for d: int in range(28):
		if s.weather_for(d)=="晴":s.day=d;break
	for b: Dictionary in s.ranch.barns.values():b.built=true;b.trough={};b.autoFeed=false;b.autoClean=false;b.autoCollect=false
	var nav=load("res://scripts/npc_navigation.gd").new();nav.refresh(s)
	var hub: Dictionary=nav.safe(s,"",{"x":3050,"y":2600},true)
	for home: String in s.system_catalog.ranch.barns:
		var house: Dictionary=s.house_data(str(s.system_catalog.ranch.barns[home].house))
		check(not nav.route(s,"",hub,house.door,true).is_empty(),"real route reaches barn "+home)
		for dx: int in range(-24,25,8):
			check(not nav.blocked(s,"",float(house.door.x)+dx,float(house.door.y)+10,true),"48px clear barn approach "+home+str(dx))
		check(not nav.route(s,str(house.id),{"x":480,"y":567},{"x":250,"y":492},true).is_empty(),"interior trough reachable "+home)
		check(not nav.route(s,str(house.id),{"x":480,"y":567},{"x":730,"y":492},true).is_empty(),"interior collection box reachable "+home)
	for pen: Dictionary in s.system_catalog.forage.pens:
		for dx: int in range(-24,25,8):check(not nav.blocked(s,"",float(pen.gate)+dx,float(pen.y)+3,true),"48px clear pen gate")
	check(not nav.route(s,"",hub,{"x":3258,"y":3018},true).is_empty(),"duck shallow bay physically reachable")
	var compost:Dictionary=s.ranch_task_destination({"barnId":"pigpen","action":"craft","arg":"compost"})
	check(Vector2(float(compost.x),float(compost.y))==Vector2(3690,2600) and not nav.route(s,"",hub,{"x":compost.x,"y":compost.y},true).is_empty(),"pig compost station is a real reachable processing destination")
	# Actual moving ranch actors leave each barn and return in bad weather.
	for type: String in s.system_catalog.ranch.species:
		s._ranch_new_animal(type,"female","local",30)
	var movement=load("res://scripts/ranch_movement.gd").new()
	for tick: int in range(700):
		s.ranch_actor_clock+=0.5;movement.advance(s,0.5)
	for a: Dictionary in s.animals:
		check(a.position.get("room")==null,str(a.type)+" actually exits barn")
		check(not nav.blocked(s,"",float(a.position.x),float(a.position.y),true),str(a.type)+" rests on walkable ground")
	var duck: Dictionary=s.animals[1]
	check(Vector2(float(duck.position.x),float(duck.position.y)).distance_to(Vector2(3258,3018))<150,"duck visits shallow bay")
	s.minutes=1100
	for tick: int in range(700):s.ranch_actor_clock+=0.5;movement.advance(s,0.5)
	for a: Dictionary in s.animals:check(a.position.get("room")!=null,str(a.type)+" actually returns to barn")
	for d: int in range(112):
		if s.weather_for(d) in ["台风","寒潮","小雪"]:
			s.day=d;s.minutes=800
			for a: Dictionary in s.animals:check(not movement.safe_out(s,a),str(a.type)+" severe weather stays inside")
			break
	# Actual player batch actions, cancellation, and material shortage.
	s.animals.clear();s.ranch.products=[];s.day=0;s.minutes=500;s.stamina=100;s.inventory.feed=20;s.ranch.policy="inside";s.ranch.feed="feed"
	s.player_position=Vector2(2720,2630)
	for n: int in range(3):
		var a: Dictionary=s._ranch_new_animal("goat","female","local",12)
		a.position.room=null;a.position.x=2700+n*30;a.position.y=2680;a.hunger=30
	change_scene_to_file("res://scenes/main.tscn");await settle()
	s.set_process(true);Engine.time_scale=3
	var tasks: Array=s.ranch_batch_plan(s.ranch_filtered_ids("all"),"feed")
	check(tasks.size()==3,"batch includes genuinely hungry companions")
	check(s.queue_ranch_tasks(tasks),"player starts real batch walking")
	s.cancel_ranch_queue();s.walking_target.clear();await settle()
	check(int(s.inventory.feed)==20,"cancel before completion spends no feed")
	check(not s.ranch_actor_held(str(s.animals[0].id)),"cancel immediately releases pending companion")
	s.inventory.feed=4
	check(s.queue_ranch_tasks(tasks),"resource limited batch starts")
	await queue_finished()
	check(s.ranch_completed==2 and int(s.inventory.feed)==0,"resource shortage stops after completed meals")
	check(int(s.animals[0].care.feed)==0 and int(s.animals[1].care.feed)==0 and int(s.animals[2].care.feed)!=0,"completed results survive shortage")
	# Cancel after one completion keeps that completed action only.
	for a: Dictionary in s.animals:a.hunger=30;a.mealDay=-1;a.mealUnits=0;a.care.feed=-1
	s.inventory.feed=20;s.stamina=100;s.minutes=500
	check(s.queue_ranch_tasks(tasks),"second batch starts")
	var limit:=Time.get_ticks_msec()+25000
	while s.ranch_completed<1 and Time.get_ticks_msec()<limit:await physics_frame
	s.cancel_ranch_queue();s.walking_target.clear();await settle()
	check(s.ranch_completed==1 and int(s.inventory.feed)==18,"cancel keeps one completed result and stops later charges")
	# The player walks into the coop to pick a real egg, then empties the box.
	s.stamina=100;s.minutes=500
	var hen: Dictionary=s._ranch_new_animal("hen","female","local",6)
	PRODUCTS.produce(s,hen,"egg",1,2,s.day);PRODUCTS.sync(s)
	var eggs_before: int=int(s.inventory.get("egg",0))
	check(s.queue_ranch_tasks([{"animalId":str(hen.id),"action":"collect"}]),"real nest harvest route starts")
	await queue_finished(45)
	check(s.current_interior=="ranch-poultry" and int(s.inventory.get("egg",0))==eggs_before+1,"player actually enters coop and collects nest egg")
	PRODUCTS.produce(s,hen,"egg",2,1,s.day);PRODUCTS.auto_collect(s,"poultry")
	var player:Node=get_nodes_in_group("player")[0]
	player.global_position=Vector2(730,520);s.interior_position=player.global_position
	current_scene._interact_target({"kind":"ranch-box","id":"poultry","x":730,"y":492,"name":"本舍收集箱"})
	var end:=Time.get_ticks_msec()+8000
	while s.action_busy() and Time.get_ticks_msec()<end:await physics_frame
	check(PRODUCTS.box_count(s,"poultry")==0 and int(s.inventory.get("egg",0))==eggs_before+3,"actual completed box action transfers outputs")
	s.stamina=100;s.minutes=500
	PRODUCTS.produce(s,s.animals[0],"goatMilk",2,1,s.day);PRODUCTS.auto_collect(s,"sheepfold")
	var milk_before:int=int(s.inventory.get("goatMilk",0))
	var panel:Control=current_scene.hud.ranch_panel
	panel.open_panel();panel._visit_box("sheepfold")
	await queue_finished(45)
	check(s.current_interior=="ranch-sheepfold" and PRODUCTS.box_count(s,"sheepfold")==0 and int(s.inventory.get("goatMilk",0))==milk_before+2,"products page button walks between barns and claims actual box")
	Engine.time_scale=1;s.cancel_ranch_queue();s.set_process(false)
	FileAccess.open("res://artifacts/ranch-overhaul-20261016/walk-report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("Ranch walking: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
