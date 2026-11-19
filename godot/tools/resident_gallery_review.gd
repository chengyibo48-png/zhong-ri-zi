extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.minutes=660;s.ui_open=false
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var layer:=CanvasLayer.new();root.add_child(layer);var paper:=ColorRect.new();paper.size=Vector2(1280,800);paper.color=Color("ded5b9");layer.add_child(paper)
	var actors:Array=[];var script:Script=load("res://scripts/character_visual.gd")
	for i:int in s.npc_catalog.size():
		var person:Dictionary=s.npc_catalog[i];var actor:Node2D=script.new();actor.configure(str(person.id),person);layer.add_child(actor);actor.position=Vector2(105+(i%6)*211,146+(i/6)*188);actor.scale*=2.55;actor.set_process(false);actors.append(actor)
		var text:=Label.new();text.text=str(person.name)+" / "+str(person.age);text.position=Vector2(36+(i%6)*211,160+(i/6)*188);text.add_theme_color_override("font_color",Color("4e483a"));layer.add_child(text)
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-gallery-motion";DirAccess.make_dir_recursive_absolute(out);var inverted:int=0
	for frame:int in 384:
		var time:float=float(frame)/24;var segment:int=mini(3,int(time/4));var direction:Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT][segment]
		for i:int in actors.size():
			var actor:Node2D=actors[i];actor.walk_clock=time;actor.resident_context={"key":"morning"}
			actor.set_locomotion_sample(direction*1.0 if segment==1 else Vector2.ZERO,1.0/24);actor.set_pose(direction,segment==1)
			if segment==2:actor.set_sequence_snapshot({"kind":str(load("res://scripts/resident_life.gd").profile(actor.character_key).workKind),"duration":4.0,"progress":fmod(time,4)/4})
			elif segment==3:actor.set_sequence_snapshot({"kind":"greet","duration":4.0,"progress":fmod(time,4)/4})
			else:actor.set_sequence_snapshot({})
			actor.player_locomotion.advance(1.0/24);actor.set_process(false);actor.queue_redraw()
		await process_frame;RenderingServer.force_draw()
		for actor:Node2D in actors:
			var mesh:ArrayMesh=actor.get_meta("resident_mesh_ref",null)
			if mesh==null:printerr("Missing native resident surface");quit(1);return
			var v:PackedVector2Array=mesh.get_meta("vertices");var ix:PackedInt32Array=mesh.get_meta("indices")
			for i:int in range(0,ix.size(),3):
				if (v[ix[i+1]]-v[ix[i]]).cross(v[ix[i+2]]-v[ix[i]])>=0:inverted+=1
		var image:Image=root.get_texture().get_image();image.save_jpg(out+"/frame-%04d.jpg"%frame,.94)
		if frame in [48,130,240,330]:image.save_png(OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-gallery-%03d.png"%frame)
	print("RESIDENT_GALLERY_GPU: 24 identities x 384 continuous frames; inverted=",inverted,"; action rehearsal is not a task settlement test")
	await root.get_node("AudioService").prepare_exit();quit(1 if inverted else 0)
