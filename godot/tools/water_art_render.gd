extends SceneTree
var passed:=0
var failed:=0
var output: String
var state: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func settle() -> void:
	for i: int in range(7):await process_frame
func capture(name: String) -> void:
	await settle()
	current_scene.hud.restore_hud_button.hide()
	for key: String in ["notification_stack","hover_card","interaction_prompt","context_actions"]:current_scene.hud.get(key).hide()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"Capture actual scene "+name)
func move_camera(at: Vector2) -> void:
	current_scene.player.global_position=at;state.player_position=at
	current_scene.player.camera.reset_smoothing();current_scene.player.camera.force_update_scroll()
func run() -> void:
	create_timer(120,true,false,true).timeout.connect(func():quit(1))
	state=root.get_node("GameState");state.set_process(false)
	var saved: Dictionary=state._make_save_data().duplicate(true)
	state.flags.introDone=true;state.current_interior="";state.player_position=Vector2(1060,1832);state.ui_hud_visible=false
	output=OS.get_environment("ZRZ_ART_OUTPUT")
	if output=="":output="user://water-art-v3"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
	current_scene.player.set_physics_process(false);current_scene.hud.ambient_hud.hide()
	var garden: Node=current_scene.get_node("WaterGarden")
	check(garden.plants.size()>0,"Actual farm scene contains the new water plants")
	check(garden.reflection_rows.size()>0 and garden.reflection_rows.size()<=64,"Reused tree reflections are present and bounded")
	check(garden.find_children("*","CollisionObject2D",true,false).is_empty(),"New water models add no physical blockers")
	for season: int in range(4):
		state.day=season*28;state.minutes=720;state.world_changed.emit();state.clock_changed.emit();state.changed.emit()
		move_camera(Vector2(1060,1832));await capture("bamboo-pond-"+["spring","summer","autumn","winter"][season])
		check(garden.season==season,"Actual seasonal models follow the clock")
	state.day=28;state.minutes=720;state.world_changed.emit();state.clock_changed.emit();state.changed.emit()
	move_camera(Vector2(3550,1925));await capture("farm-lotus-summer")
	state.minutes=1260;state.clock_changed.emit();await capture("farm-lotus-night")
	move_camera(Vector2(1015,2820));state.minutes=720;state.clock_changed.emit();await capture("bridge-water-mask")
	for plant: Dictionary in garden.plants:
		if str(plant.kind)!="reeds":continue
		move_camera(Vector2(plant.at));current_scene.player.visible=false;current_scene.player.camera.zoom=Vector2(2.3,2.3)
		current_scene.player.camera.reset_smoothing();current_scene.player.camera.force_update_scroll()
		for day: int in [28,84]:
			state.day=day;state.world_changed.emit();state.clock_changed.emit();state.changed.emit()
			await capture("reeds-"+("summer" if day==28 else "winter"))
		current_scene.player.visible=true;break
	state.visual_fx.motion="reduced";garden._process(.1)
	check(float(garden.reflection_material.get_shader_parameter("motion"))==0.0,"Reduced motion freezes reflection ripples")
	check(float(current_scene.ground_layer.material.get_shader_parameter("water_motion"))==0.0,"Reduced motion freezes water glints")
	var paused_clock: float=garden.clock;garden._process(.25)
	check(is_equal_approx(float(garden.clock),paused_clock),"Reduced motion keeps the actual water animation clock fixed")
	state.player_settings.performance="light";garden.refresh()
	var visible_count:=0
	for item: Dictionary in garden.reflection_rows:visible_count+=1 if item.node.visible else 0
	check(visible_count<=12,"Existing light performance mode caps reflections")
	state.player_settings.performance="auto";garden.refresh()
	await reflection_fixture()
	check(state.inventory==saved.inventory and state.money==saved.money and state.plots==saved.plots,"Actual water rendering preserves economy and crops")
	var metrics: Dictionary={"plants":garden.plants.size(),"reflections":garden.reflection_rows.size(),"device":RenderingServer.get_video_adapter_name(),"quality":"source GPU validation; no export"}
	metrics.placements=[]
	for plant: Dictionary in garden.plants:metrics.placements.append({"kind":plant.kind,"x":plant.at.x,"y":plant.at.y,"region":plant.region})
	FileAccess.open(output+"/water-art-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	current_scene.queue_free();await process_frame
	print("WATER_ART_GPU: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)

func reflection_fixture() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(512,512);viewport.disable_3d=true;viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var background:=ColorRect.new();background.size=Vector2(512,512);background.color=Color("8e9d94");viewport.add_child(background)
	var lookup:=Image.create(120,120,false,Image.FORMAT_RGBA8)
	var columns: Dictionary={}
	for y: int in range(120):
		for x: int in range(120):
			var kind:=8 if x>=4 and x<11 and y>=2 and y<14 else 4
			if x==8 and y>=2 and y<14:kind=9
			columns[Vector2i(x,y)]=kind;lookup.set_pixel(x,y,Color(kind/255.0,0,0,1))
	var mat:=ShaderMaterial.new();mat.shader=load("res://art/shaders/water_reflection.gdshader")
	mat.set_shader_parameter("water_cells",ImageTexture.create_from_image(lookup))
	mat.set_shader_parameter("water_depth",ImageTexture.create_from_image(load("res://scripts/water_geometry.gd").depth_image(columns)))
	var script: Script=load("res://scripts/water_garden.gd")
	var reflection: Node2D=script.Reflection.new();reflection.position=Vector2(256,64);reflection.rectangle=Rect2(-160,0,320,352)
	reflection.texture=load("res://scripts/character_art.gd").texture("res://art/world/props/tree/spring.png");reflection.material=mat
	viewport.add_child(reflection)
	await settle();await RenderingServer.frame_post_draw
	var visible_image:=viewport.get_texture().get_image();visible_image.convert(Image.FORMAT_RGBA8)
	visible_image.save_png(output+"/reflection-mask-fixture.png")
	reflection.hide();await settle();await RenderingServer.frame_post_draw
	var hidden_image:=viewport.get_texture().get_image();hidden_image.convert(Image.FORMAT_RGBA8)
	var a:=visible_image.get_data();var b:=hidden_image.get_data();var leaked:=0;var water_changed:=0
	for y: int in range(512):
		for x: int in range(512):
			var index:=(y*512+x)*4
			var difference:=absi(int(a[index])-int(b[index]))+absi(int(a[index+1])-int(b[index+1]))+absi(int(a[index+2])-int(b[index+2]))
			if difference<=3:continue
			if int(columns[Vector2i(int(x/32),int(y/32))])==8:water_changed+=1
			else:leaked+=1
	check(water_changed>50,"Actual reflection shader visibly paints water")
	check(leaked==0,"Actual reflection shader paints zero land/bridge pixels")
	print("WATER_REFLECTION_MASK wet_pixels=",water_changed," leaked_pixels=",leaked)
	viewport.queue_free();await process_frame
