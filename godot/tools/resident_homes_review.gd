extends SceneTree
var s:Node
var out:String
var checks:int=0
func _initialize()->void:call_deferred("run")
func settle()->void:
	for i:int in 5:await process_frame
func shot(path:String)->void:
	RenderingServer.force_draw();var e:int=root.get_texture().get_image().save_png(path);assert(e==OK);checks+=1
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.ui_open=false;s.minutes=500;s.day=30;s.animals.clear()
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	out=OS.get_environment("ZRZ_ART_OUTPUT")+"/homes-"+OS.get_environment("ZRZ_RESIDENT_PHASE");DirAccess.make_dir_recursive_absolute(out)
	for person:Dictionary in s.npc_catalog:
		var id:String=str(person.id);var room:String="home-"+id;s.current_interior=room;s.interior_position=Vector2(480,540)
		s.npc_residents[id].room=room
		var row:Dictionary=s.system_catalog.interiors.layouts[room].rows[0];s.npc_movement.actors[id]={"inside":{"x":row.x,"y":float(row.y)+33,"direction":"up"},"walking":false,"plan":{"key":"work"},"activity":s.system_catalog.npc.profiles[id].work}
		change_scene_to_file("res://scenes/interior.tscn");await settle();current_scene.hud.hide();current_scene.player.set_physics_process(false)
		shot(out+"/"+id+"-day.png")
		s.minutes=1240;s.clock_changed.emit();await settle();shot(out+"/"+id+"-night.png");s.minutes=500
		s.npc_stories[id]={"step":s.content.arcs[id].size(),"choices":[],"lastDay":s.day}
		for i:int in s.content.arcs[id].size():s.npc_stories[id].choices.append(0)
		s.domain_changed.emit("relations");s.clock_changed.emit();await settle();shot(out+"/"+id+"-memory.png")
	# Actual native movement and indoor intentions; a later edit must not be judged only by pose pages.
	if OS.get_environment("ZRZ_RESIDENT_PHASE")=="after":
		var frame:int=0;var trace:Array=[];var movies:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-motion";DirAccess.make_dir_recursive_absolute(movies)
		for id:String in ["chen","an","lan"]:
			var room:String="home-"+id;s.current_interior=room;s.interior_position=Vector2(480,540);s.minutes=470;s.npc_movement.actors.erase(id);s.npc_residents[id].room=room
			s.advance_npc_movement(.001)
			var work_kind:String=str(load("res://scripts/resident_life.gd").profile(id).workStation)
			for row:Dictionary in s.system_catalog.interiors.layouts[room].rows:
				if str(row.kind)==work_kind:
					s.npc_movement.actors[id].inside=s.npc_movement.navigation.safe(s,room,{"x":row.x,"y":float(row.y)+90,"direction":"up"});break
			change_scene_to_file("res://scenes/interior.tscn");await settle();current_scene.hud.hide();current_scene.player.set_physics_process(false)
			for tick:int in 192:
				s.ui_open=false;s.source_frame_time+=1.0/24;s.advance_npc_movement(1.0/24)
				await process_frame;RenderingServer.force_draw()
				root.get_texture().get_image().save_jpg(movies+"/frame-%04d.jpg"%frame,.93)
				var actor:Dictionary=s.npc_movement.actors.get(id,{});trace.append({"frame":frame,"id":id,"inside":actor.get("inside",{}).duplicate(),"walking":actor.get("walking",false),"plan":actor.get("plan",{}).get("key",""),"activity":actor.get("activity","")});frame+=1
		var f:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-movement-trace.json",FileAccess.WRITE);f.store_string(JSON.stringify(trace));f.close()
	print("RESIDENT_HOMES_GPU: ",checks," pages; actual native motion=",OS.get_environment("ZRZ_RESIDENT_PHASE")=="after");await root.get_node("AudioService").prepare_exit();quit()
