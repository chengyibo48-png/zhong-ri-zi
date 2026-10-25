extends SceneTree
var PET: Script
var FORAGE: Script
var WILD: Script
var INTERIOR: Script
var passed := 0
var failed := 0
var snapshots: Array[String] = []
class Board extends Node2D:
	var heading := ""
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,900), Color("#e9dfc6"))
		draw_string(ThemeDB.fallback_font, Vector2(30,38), heading, HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("#3e513d"))
class Specimen extends Node2D:
	var mode := "pet"
	var identity := ""
	var caption := ""
	var payload: Dictionary = {}
	var action: Dictionary = {}
	var clock := 10.0
	var minutes := 720.0
	var selected: Dictionary = {}
	var painted := false
	func _draw() -> void:
		var state: Node = get_tree().root.get_node("GameState")
		if mode == "pet":
			var old: Dictionary = state.pet_visual_action
			state.pet_visual_action = action
			painted = load("res://scripts/pet_art.gd").draw(self,payload,{"type":identity},Vector2.ZERO,minutes,clock)
			state.pet_visual_action = old
		elif mode == "forage": painted = load("res://scripts/forage_art.gd").draw(self,identity,payload)
		elif mode == "wildlife": load("res://scripts/wildlife_art.gd").draw(self,{"id":identity,"x":0,"y":0},clock)
		elif mode == "prop": painted = load("res://scripts/world_art.gd").draw_prop(self,payload,0,720)
		elif mode == "furniture":
			var old: Array = state.kitchen.get("jobs", [])
			state.kitchen.jobs = [{"station":"probe","ready":state._kitchen_now()+30}]
			painted = load("res://scripts/interior_art.gd").draw_furniture(self,payload,minutes,selected)
			state.kitchen.jobs = old
		draw_string(ThemeDB.fallback_font,Vector2(-30,14),caption,HORIZONTAL_ALIGNMENT_CENTER,60,7,Color("#4c5a42"))
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func settle(frames: int = 5) -> void:
	for i in range(frames): await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> Image:
	await settle()
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Real OpenGL framebuffer " + name)
	if image != null:
		var path := "res://artifacts/optimization-20261014/" + name + ".png"
		check(image.save_png(path) == OK, "Saved render " + name)
		snapshots.append(path)
	return image
func board(name: String) -> Board:
	var canvas := Board.new();canvas.heading=name;root.add_child(canvas);return canvas
func sample(canvas: Node2D, mode: String, identity: String, at: Vector2, magnify: float = 1.0) -> Specimen:
	var specimen := Specimen.new();specimen.mode=mode;specimen.identity=identity;specimen.position=at;specimen.scale=Vector2.ONE*magnify;canvas.add_child(specimen);return specimen
func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("GPU optimization review timeout");quit(1))
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
	var state := root.get_node("GameState");state.set_process(false);state.ui_open=false;state.flags.introDone=true
	PET = load("res://scripts/pet_art.gd")
	FORAGE = load("res://scripts/forage_art.gd")
	WILD = load("res://scripts/wildlife_art.gd")
	INTERIOR = load("res://scripts/interior_art.gd")

	state.visual_fx.motion="full";state.visual_fx.density="standard"
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,900);root.content_scale_size=Vector2i(1280,900)
	state.minutes=720;state.day=0
	var canvas := board("Companions | 4 directions x idle / strides / feeding / petting / sleeping")
	for companion in range(2):
		for pose_index in range(6):
			for direction in range(4):
				var identity := "cat" if companion==0 else "dog"
				var p := sample(canvas,"pet",identity,Vector2(80+(companion*4+direction)*160,145+pose_index*136),2.8)
				p.payload={"position":{"direction":["down","left","right","up"][direction],"walking":pose_index in [1,2]},"energy":10 if pose_index==5 else 100,"hunger":70}
				p.clock=10.125 if pose_index==2 else 10.0
				p.action={"kind":"feed" if pose_index==3 else "pet","at":10.0,"until":12.8} if pose_index in [3,4] else {}
				p.caption=identity+" "+PET.POSES[pose_index]
	await capture("pets-poses")
	for p in canvas.get_children(): check(bool(p.painted),"Actual companion pose draw")
	canvas.queue_free();await settle()
	canvas=board("Gathering resources | spring / summer / autumn / winter; depleted / regrowing / mature")
	var keys := ["bamboo","berry","mushroom","shoot","tea","wildHerb","wood"]
	for row in range(7):
		for season in range(4):
			for stage in range(3):
				var p := sample(canvas,"forage",keys[row],Vector2(52+(season*3+stage)*105,150+row*106),2.0)
				p.payload={"season":season,"stage":[0.2,0.6,1.0][stage],"ready":stage==2,"in_season":true,"motion":false}
				p.caption=keys[row]+" "+str(season)+"/"+str(stage)
	await capture("forage-seasons-stages")
	for p in canvas.get_children():check(bool(p.painted),"Actual forage stage draw")
	canvas.queue_free();await settle()
	canvas=board("Wildlife | resting / walking / foraging / takeoff / flight / landing")
	for row in range(3):
		var identity: String=["egret","sparrow","butterfly"][row]
		for index in range(6):
			var p:=sample(canvas,"wildlife",identity,Vector2(100+index*210,220+row*280),3.0)
			for tick in range(1920):
				if int(WILD.activity(identity,tick/80.0).frame)==index:p.clock=tick/80.0;break
			p.caption=identity+" pose "+str(index)
	await capture("wildlife-poses")
	canvas.queue_free();await settle()
	canvas=board("125 accepted furniture state images | actual interior renderer")
	var receipts:Array=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/continuation-art-20261013/generation-receipts.json"))
	var index:=0
	for item:Dictionary in receipts:
		if item.status!="imported_static_review_only":continue
		var p:=sample(canvas,"furniture",str(item.id).get_slice("/",1),Vector2(48+(index%13)*98,100+int(index/13)*80))
		p.payload={"kind":p.identity,"x":0,"y":0,"w":90,"h":46,"point":{"id":"sample","kind":"kitchen-station" if item.state=="working" else "decoration","station":"probe"}}
		p.selected={"id":"sample"} if item.state=="focused" else {}
		p.minutes=1260 if item.state=="night" else 720
		p.caption=str(index+1)+" "+str(item.state)
		index+=1
	await capture("furniture-125-states")
	check(index==125,"All 125 states exercised")
	for p in canvas.get_children():check(bool(p.painted),"Accepted image uses real furniture drawing")
	canvas.queue_free();await settle()
	canvas=board("Trees | four seasons; root anchored wind bending")
	var trees:Array[Node2D]=[]
	for season in range(4):
		state.day=season*28
		for column in range(4):
			var prop:=Node2D.new();prop.set_script(load("res://scripts/world_prop.gd"));prop.set("data",{"kind":["tree","willow","orchard","blossom"][column]});prop.position=Vector2(160+column*320,240+season*210);prop.scale=Vector2.ONE*2;canvas.add_child(prop);prop.set_process(false);trees.append(prop)
			if prop.material is ShaderMaterial:
				prop.material.set_shader_parameter("wind",3.0);prop.material.set_shader_parameter("clock",1.0)
	var a:Image=await capture("trees-wind-a")
	for prop in trees:
		check(prop.material is ShaderMaterial,"Wind shader on painted tree")
		prop.material.set_shader_parameter("clock",3.5)
	var b:Image=await capture("trees-wind-b")
	check(a.get_data()!=b.get_data(),"Tree crown deformation changes actual framebuffer")
	canvas.queue_free();await settle()
	canvas=board("16 newly covered scene props | painted base artwork fitted to authored dimensions")
	var props=["bambooBundle","grainMat","haybale","hayrack","jars","loom","netCoil","plants","scale","seedTray","stones","teaCrate","washstone","weather","woodpile","wall"]
	for prop_index in range(props.size()):
		var row: Dictionary=load("res://scripts/world_art.gd").entries().get("props/"+props[prop_index],{})
		var p:=sample(canvas,"prop",props[prop_index],Vector2(160+(prop_index%4)*320,220+int(prop_index/4)*210),2.5)
		var bounds: Array=row.get("worldRect",[-24,-40,48,40])
		p.payload={"kind":props[prop_index],"w":float(bounds[2]),"h":float(bounds[3])};p.caption=props[prop_index]
	await capture("scene-props-16")
	for p in canvas.get_children():check(bool(p.painted),"Actual additional prop draw")
	canvas.queue_free();await settle()
	state.day=0;state.minutes=720;state.pet_visual_action.clear()
	change_scene_to_file("res://scenes/main.tscn");await settle(20)
	var world:=current_scene
	world.player.set_physics_process(false)
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	state.ui_open=false
	var missing_props:=0
	for prop in world.get_children():
		if prop.get_script()==load("res://scripts/world_prop.gd") and not bool(prop.painted_active):missing_props+=1
	check(missing_props==0,"Every authored map prop uses imported artwork")
	var static_draws:int=world.map_draw_count
	await settle(24)
	var idle_redraw_delta:int=int(world.map_draw_count)-static_draws
	check(idle_redraw_delta==0,"Idle ambient animation does not invalidate map draw list")
	state.ranch.pet.position={"x":2822.0,"y":1603.0,"direction":"right","walking":false};state.pet_state.type="cat";state.ranch.pet.hunger=20;state.ranch.pet.fed=-1
	check(state.ranch_pet_action("feed"),"Actual world feed operation")
	await capture("world-cat-feeding")
	state.pet_state.patted=-1;check(state.pat_companion(),"Actual world pet operation")
	await capture("world-cat-petting")
	state.pet_state.type="dog";state.pet_visual_action.clear();state.ranch.pet.energy=10;state.changed.emit()
	await capture("world-dog-sleeping")
	state.day=95;state.minutes=720;state.changed.emit();await settle(20)
	check(bool(state.weather_profile().snow),"Actual snow weather")
	await capture("world-winter-snow")
	state.day=3;state.minutes=720;state.changed.emit();await settle(20)
	check(int(state.weather_profile().rain)>0,"Actual rain weather")
	await capture("world-rain")
	state.day=0;state.minutes=1260;state.changed.emit();await settle(20)
	var hidden:=0
	for actor in world.get_children():
		if actor.get_script()==load("res://scripts/ambient_actor.gd") and not bool(actor.companion) and not actor.visible:hidden+=1
	check(hidden==3,"Night wildlife absent in actual world scene")
	current_scene.queue_free();await settle()
	var file:=FileAccess.open("res://artifacts/optimization-20261014/gpu-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"date":"2026-10-14","passed":passed,"failed":failed,"snapshots":snapshots,"renderer":RenderingServer.get_video_adapter_name(),"staticMapRedrawsDuringIdle":idle_redraw_delta},"\t"));file.close()
	print("LIFE_OPTIMIZATION_GPU: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
