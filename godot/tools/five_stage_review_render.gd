extends SceneTree
var state:Node
var folder:String
var review_weather:Control
class Backdrop extends Node2D:
	func _draw()->void:
		draw_rect(Rect2(0,0,1280,800),Color("a6af92"))
		for row in range(4):draw_line(Vector2(25,180+row*190),Vector2(1255,180+row*190),Color("818d77"),1)
func _initialize()->void:call_deferred("run")
func settle()->void:
	for i in range(8):await process_frame
func shot(name:String)->void:
	if is_instance_valid(review_weather):review_weather.phase=0;review_weather.queue_redraw()
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK)
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_hud_visible=false;state.minutes=720
	folder=OS.get_environment("ZRZ_ART_OUTPUT")+"/"+OS.get_environment("ZRZ_REVIEW_STAGE")
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var world:Node=current_scene;world.set_process(false);world.hud.hide();state.ui_open=false
	var atmosphere:=CanvasLayer.new();atmosphere.layer=80;world.add_child(atmosphere)
	review_weather=load("res://scripts/weather_overlay.gd").new();atmosphere.add_child(review_weather);review_weather.set_process(false)
	var player:Node2D=world.player;player.set_physics_process(false)
	var n:=0
	for at:Vector2 in [Vector2(2800,1800),Vector2(2860,650),Vector2(1500,2725)]:
		player.global_position=at;state.player_position=at;player.camera.zoom=Vector2(1.35,1.35);player.camera.reset_smoothing();player.camera.force_update_scroll()
		await shot("world-"+str(n));n+=1
	var original_day:int=state.day
	# Additional same-camera lighting samples in the actual farm scene.
	player.global_position=Vector2(2800,1800);state.player_position=player.global_position;player.camera.reset_smoothing();player.camera.force_update_scroll()
	for minute in [720,1200,1260]:
		state.minutes=minute;state.clock_changed.emit();state.changed.emit();player.character_visual.queue_redraw()
		await shot("farm-light-"+str(minute))
	for day in range(28):
		if int(state.weather_profile(day).get("rain",0))<=0:continue
		state.day=day;state.minutes=720;state.clock_changed.emit();state.changed.emit();player.character_visual.queue_redraw()
		await shot("farm-rain");break
	state.day=original_day;state.minutes=720;state.clock_changed.emit();state.changed.emit()
	var durations:Array[float]=[]
	for i in range(120):
		var started:=Time.get_ticks_usec()
		player.character_visual._process(1.0/60)
		await process_frame
		durations.append(float(Time.get_ticks_usec()-started)/1000)
	durations.sort();print("REVIEW_FRAME_MS median=",durations[60]," p95=",durations[114]," renderer=",RenderingServer.get_video_adapter_name())
	world.queue_free();await process_frame;current_scene=null
	var page:=Backdrop.new();root.add_child(page)
	var actors:Array=[]
	var ids:Array=load("res://scripts/character_art.gd").data().actors.keys();ids.erase("player");ids.sort()
	for i in ids.size():
		var visual:Node2D=load("res://scripts/character_visual.gd").new();visual.configure(str(ids[i]))
		visual.position=Vector2(110+(i%6)*210,175+floori(i/6.0)*190);visual.scale*=Vector2(2.6,2.6)
		page.add_child(visual);visual.set_process(false);actors.append(visual)
		var label:=Label.new();label.text=str(ids[i]);label.position=visual.position+Vector2(-40,4);page.add_child(label)
	for direction:Vector2 in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		for actor in actors:actor.set_pose(direction,false);actor.walk_clock=0;actor.queue_redraw()
		await shot("residents-idle-"+str(direction))
	for step in range(4):
		for actor in actors:actor.set_pose(Vector2.RIGHT,true);actor.walk_clock=step*TAU/32.0;actor.queue_redraw()
		await shot("residents-walk-"+str(step))
	print("REVIEW: actual world and 24 resident GPU pages saved ",folder)
	await root.get_node("AudioService").prepare_exit();quit()
