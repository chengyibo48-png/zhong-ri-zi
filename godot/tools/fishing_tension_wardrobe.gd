extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle()->void:
	for i:int in 8:await process_frame
	await RenderingServer.frame_post_draw
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.flags.introDone=true
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/wardrobe";DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;change_scene_to_file("res://scenes/main.tscn");await settle()
	current_scene.set_process(false);current_scene.player.set_physics_process(false);current_scene.hud.hide();current_scene.player.character_visual.hide()
	var layer:=CanvasLayer.new();layer.layer=100;current_scene.add_child(layer)
	var view:Vector2=root.get_visible_rect().size
	var paper:=ColorRect.new();paper.color=Color("e9dfc2");paper.size=view;layer.add_child(paper)
	var nodes:Array=[];var visual:Script=load("res://scripts/character_visual.gd")
	for row:int in 4:
		for col:int in 3:
			var node:Node2D=visual.new();layer.add_child(node);node.position=view*Vector2(.17+col*.31,.215+row*.245);node.scale=Vector2.ONE*3.6*view.x/1280;node.configure_player();node.set_process(false);nodes.append(node)
	for outfit:String in ["field","apron","traveler","festival","rain","cold"]:
		s.appearance={"shirt":1,"skin":1,"hair":2,"hairColor":1,"hat":true,"bag":true,"outfit":outfit if outfit in ["field","apron","traveler","festival"] else "field","weatherDress":false}
		for index:int in nodes.size():
			var node:Node2D=nodes[index];node.appearance.rain=outfit=="rain";node.appearance.cold=outfit=="cold";node.appearance.festival=outfit=="festival"
			node.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][index/3];node.fishing_state="fight";node.fishing_tension=[0.0,.55,1.0][index%3];node.walk_clock=.7;node.queue_redraw()
		await settle()
		for node:Node in nodes:
			check(node.painted_active and node.wardrobe.painted_active,"six outfits remain fully painted")
			var a:Dictionary=node.contact_attachments();check(not a.is_empty() and a.kind=="fish_reel","four-direction rod attachment exists")
			check(absf(float(node.wardrobe.rig_frame.rod_bend))<=3.5,"rod bend never stretches limbs")
		check(root.get_texture().get_image().save_png(out+"/"+outfit+"-four-directions.png")==OK,"wardrobe GPU sheet "+outfit)
	print("FISHING_WARDROBE_GPU: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
