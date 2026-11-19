extends SceneTree
var frame:int=0
var out:String=""
var trace:Array=[]
var s:Node
func _initialize()->void:call_deferred("run")
func record(seconds:float,update:Callable=Callable())->void:
	var start:float=Time.get_ticks_usec()/1000000.0;var next:float=start
	while Time.get_ticks_usec()/1000000.0-start<seconds:
		await process_frame
		var now:float=Time.get_ticks_usec()/1000000.0
		if update.is_valid():update.call(clampf((now-start)/seconds,0,1))
		if now<next:continue
		next+=1.0/24
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(out+"/frame-%04d.jpg"%frame,.92)==OK)
		var p:Vector2=current_scene.player.global_position
		trace.append({"frame":frame,"at":now,"x":p.x,"y":p.y,"phase":int(s.house_activity.active.get("step",-1)),"action":str(s.action_snapshot().get("kind","")),"minutes":s.minutes});frame+=1
func run()->void:
	Engine.max_fps=60;root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	s=root.get_node("GameState");s.flags.introDone=true;s.current_interior="building-town-8";s.interior_position=Vector2(480,567);s.day=30;s.minutes=660
	change_scene_to_file("res://scenes/interior.tscn")
	for f:int in 12:await process_frame
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/house-walk";DirAccess.make_dir_recursive_absolute(out)
	var point:Dictionary=load("res://scripts/house_geometry.gd").points(s.current_interior)[0]
	var world:Node=current_scene;var panel:Control=world.hud.house_activity_panel;var origin:Vector2=world.player.global_position
	world._click_at(Vector2(point.x,point.y))
	for attempt:int in 8:
		await record(.5)
		if panel.visible:break
	assert(panel.visible and world.player.global_position.distance_to(origin)>50)
	await record(.6);panel.choices.get_child(0).pressed.emit();await record(.6)
	var target:float=float(s.house_activity.active.view.steps[1].target)
	await record(1.4,func(t:float):panel.slider.value=lerpf(.1,target,t))
	panel.slider.value=target;panel.confirm.pressed.emit();await record(.8)
	panel.choices.get_child(1).pressed.emit();await record(2.4)
	assert(s.interior_state.household.receipts.has(s.current_interior+":theme"))
	world._click_at(Vector2(point.x,point.y));await record(.6);assert(panel.visible)
	var before:float=s.minutes;world.hud.ui_stack.back();assert(s.minutes==before and s.house_activity.active.is_empty());await record(.8)
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/house-walk-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"  "));file.close()
	print("HOUSE_NATIVE_WALK: ",frame," frames; actual path, three UI stages, animation, keepsake and cancel")
	await root.get_node("AudioService").prepare_exit();quit()
