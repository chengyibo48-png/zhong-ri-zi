extends SceneTree
const L=preload("res://scripts/house_life.gd")
var frame:int=0
var out:String=""
var trace:Array=[]
var s:Node
var next:float=0
func _initialize()->void:call_deferred("run")
func record(seconds:float)->void:
	var start:float=Time.get_ticks_usec()/1000000.0;next=start
	while Time.get_ticks_usec()/1000000.0-start<seconds:
		await process_frame;var now:float=Time.get_ticks_usec()/1000000.0
		if now<next:continue
		next+=1.0/24;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(out+"/frame-%04d.jpg"%frame,.92)==OK)
		var pos:Vector2=current_scene.player.global_position
		trace.append({"frame":frame,"at":now,"room":s.current_interior,"x":pos.x,"y":pos.y,"walking":not s.walking_target.is_empty(),"action":str(s.action_snapshot().get("kind","")),"fixture_states":s.interior_state.household.get("fixtureStates",{}).duplicate(true)});frame+=1
func run()->void:
	Engine.max_fps=60;root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);s=root.get_node("GameState");s.flags.introDone=true;s.day=30;s.minutes=660
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/village-walk";DirAccess.make_dir_recursive_absolute(out)
	for room:String in ["home-granny","home-chen","home-lan","building-farm-13"]:
		s.current_interior=room;s.interior_position=Vector2(480,567);s.ui_open=false;change_scene_to_file("res://scenes/interior.tscn")
		for f:int in 12:await process_frame
		await record(.5)
		for point:Dictionary in L.points(s,room):
			var old:bool=L.state(s,room,str(point.id));current_scene._click_at(Vector2(point.x,point.y))
			for attempt:int in 24:
				await record(.5)
				if L.state(s,room,str(point.id))!=old and not s.action_busy():break
			assert(L.state(s,room,str(point.id))!=old)
			await record(.6)
	s.current_interior="building-farm-12";s.interior_position=Vector2(480,567);change_scene_to_file("res://scenes/interior.tscn")
	for f:int in 12:await process_frame
	current_scene._click_at(Vector2(420,555))
	for attempt:int in 16:
		await record(.5)
		if current_scene.hud.house_activity_panel.visible:break
	assert(current_scene.hud.house_activity_panel.home_preview)
	await record(1);current_scene.hud.house_activity_panel.choices.get_child(0).pressed.emit();await record(1)
	assert(bool(s.interior_state.household.homePreset))
	var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/village-walk-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"  "));file.close()
	print("VILLAGE_WALK: ",frame," native frames; actual paths, 8 fixtures, 4 sample rooms and home preview")
	await root.get_node("AudioService").prepare_exit();quit()
