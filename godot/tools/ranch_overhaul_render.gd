extends SceneTree
var VISUAL: Script
const ART = preload("res://scripts/animal_art.gd")
var passed := 0
var failed := 0
var s: Node
class PaintedAnimal extends Node2D:
	var animal: Dictionary
	var catalog: Dictionary
	var pose: Dictionary = {}
	var painted := false
	func _draw() -> void:
		painted=load("res://scripts/ranch_visual.gd").animal(self,animal,Vector2.ZERO,catalog,2.1,pose)
		if not pose.is_empty():load("res://scripts/ranch_visual.gd").action(self,animal,Vector2.ZERO,{"id":animal.id,"kind":str(pose.action),"at":1.3,"room":null},"",2.1)
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(8):await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	check(img!=null and img.get_size().x>0,"actual GPU image "+name)
	check(img.save_png("res://artifacts/ranch-overhaul-20261016/"+name+".png")==OK,"save screenshot "+name)
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("ranch render timeout");quit(1))
	VISUAL=load("res://scripts/ranch_visual.gd")
	s=root.get_node("GameState");s.set_process(false);s.day=0;s.minutes=800;s.flags.introDone=true;s.ui_open=false
	s.current_interior="";s._reset_animals();s.animals.clear();s.ranch.products=[];s.ranch.stores={"feed":30,"hay":20,"grainFeed":10,"healthFeed":4,"bedding":8};s.inventory.feed=40;s.stamina=100
	for b: Dictionary in s.ranch.barns.values():b.built=true;b.trough={"feed":8};b.autoCollect=true
	var i:=0
	for type: String in s.system_catalog.ranch.species:
		var a: Dictionary=s._ranch_new_animal(type,"female","local",30)
		a.position.room=null;a.position.x=2640+(i%4)*65;a.position.y=2700+int(i/4)*85;a.ready=0;i+=1
		if type=="duck":a.position.x=3258;a.position.y=3018
		if type in ["hen","goat"]:preload("res://scripts/ranch_products.gd").produce(s,a,str(a.product),1,1,0)
	preload("res://scripts/ranch_products.gd").sync(s)
	s.player_position=Vector2(3050,2750)
	root.size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var world: Node=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
	world.player.camera.zoom=Vector2(0.75,0.75);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	await capture("pasture-day")
	s.minutes=1250;s.clock_changed.emit();await capture("pasture-night")
	for weather_day: int in [3,95]:
		s.day=weather_day;s.minutes=800;s.clock_changed.emit();world._refresh()
		await capture("pasture-"+s.weather_for(weather_day))
	s.visual_fx.motion="reduced"
	for animal_node: Node in world.animal_nodes:animal_node.queue_redraw()
	await capture("pasture-reduced-motion")
	s.visual_fx.motion="full";s.day=0;s.minutes=800
	# All special states use painted artwork for every species and direction.
	var gallery:=CanvasLayer.new();gallery.layer=1000;root.add_child(gallery)
	var paper:=ColorRect.new();paper.color=Color("e9dfc7");paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);gallery.add_child(paper)
	var logical:Vector2=root.get_visible_rect().size
	var cases: Array=["正常","幼崽","进食","休息","脏污","不适","互动","生产"]
	var probes: Array=[]
	for direction: String in ["down","left","right","up"]:
		for child: Node in paper.get_children():child.queue_free()
		probes.clear();await settle()
		for row: int in range(cases.size()):
			var label:=Label.new();label.text=str(cases[row]);label.position=Vector2(8,logical.y*(row+0.8)/9);label.add_theme_color_override("font_color",Color("4f5f47"));paper.add_child(label)
			for col: int in range(s.animals.size()):
				var probe:=PaintedAnimal.new();probe.animal=s.animals[col].duplicate(true);probe.catalog=s.system_catalog.ranch
				probe.animal.position.direction=direction;probe.animal.position.walking=true
				probe.animal.trait="friendly";probe.animal.breed="hardy";probe.animal.ready=0
				match row:
					1:probe.animal.age=0
					2:probe.pose={"action":"feed","until":9}
					3:probe.animal.rest=true
					4:probe.animal.clean=10
					5:probe.animal.illness=50
					6:probe.pose={"action":"pet","until":9}
					7:probe.pose={"action":"collect","until":9};probe.animal.ready=1
				probe.position=Vector2(100+(logical.x-130)*(col+0.5)/7,logical.y*(row+1.3)/9);probe.scale=Vector2.ONE*1.25
				paper.add_child(probe);probes.append(probe)
		await capture("animal-states-"+direction)
		for probe: PaintedAnimal in probes:
			check(probe.painted,"painted special state "+str(probe.animal.type)+direction)
			var desc:Dictionary=ART.frame(probe.animal,VISUAL.appearance(probe.animal,probe.catalog,2.1,probe.pose),2.1)
			check(not desc.is_empty(),"real atlas descriptor for special state")
	gallery.queue_free();await settle()
	# Four pages at both required screen sizes, plus landscape touch.
	var layer:=CanvasLayer.new();layer.layer=1001;root.add_child(layer)
	var panel:Control=load("res://scripts/ranch_panel.gd").new();layer.add_child(panel);panel.open_panel();await settle()
	for screen: Vector2i in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1280,720)]:
		root.size=screen
		s.source_input_mode="touch" if screen.y==720 else "keyboard"
		await settle()
		check(panel.pages.get_tab_count()==4,"four ranch pages")
		for page: int in range(4):
			panel.pages.current_tab=page;await settle()
			check(root.get_visible_rect().encloses(panel.pages.get_global_rect()),"page fits screen "+str(screen)+str(page))
			await capture("ranch-page-%d-%dx%d" % [page,screen.x,screen.y])
	panel.close();layer.queue_free();await settle()
	# Real interiors share the same fixtures and aisle, including rabbitry.
	for home: String in ["poultry","sheepfold","rabbitry"]:
		s.current_interior=str(s.system_catalog.ranch.barns[home].house);s.interior_position=Vector2(480,530)
		for a: Dictionary in s.animals:
			if s._ranch_home_for(str(a.type))==home:a.position.room=s.current_interior
		change_scene_to_file("res://scenes/interior.tscn");await settle()
		if current_scene.get("hud")!=null:current_scene.hud.hide()
		await capture("interior-"+home)
		var fixtures:Node=current_scene.get_node("RanchFixtures")
		check(fixtures.y_sort_enabled and fixtures.get_child_count()==4,"painted furniture has independent depth "+home)
		if home=="sheepfold":
			var goat_index:int=s.ranch_animal_index(str(s.animals[5].id))
			s.animals[goat_index].position.inside={"x":240,"y":380,"direction":"down"};s.ranch_positions_changed.emit();current_scene.queue_redraw()
			await capture("occlusion-behind-bed")
			s.animals[goat_index].position.inside={"x":240,"y":420,"direction":"down"};s.ranch_positions_changed.emit();current_scene.queue_redraw()
			await capture("occlusion-in-front-of-bed")
	FileAccess.open("res://artifacts/ranch-overhaul-20261016/gpu-report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed,"renderer":RenderingServer.get_video_adapter_name()},"  "))
	print("Ranch GPU: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
