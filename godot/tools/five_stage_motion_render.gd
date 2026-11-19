extends SceneTree
const KINDS:=["hoe","dig","chop","cut","water","seed","harvest","gather"]
var state:Node
var visuals:Array=[]
var folder:String
var worst_contact:=0.0
class Paper extends Node2D:
	func _draw()->void:
		draw_rect(Rect2(0,0,1280,800),Color("d4d5bc"))
		for col in range(8):draw_string(ThemeDB.fallback_font,Vector2(24+col*160,27),str(["hoe","dig","chop","cut","water","seed","harvest","gather"][col]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("35463d"))
func _initialize()->void:call_deferred("run")
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.minutes=720;state.current_interior=""
	folder=OS.get_environment("ZRZ_ART_OUTPUT")+"/motion-frames";DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var page:=Paper.new();root.add_child(page)
	for row in range(4):
		for col in range(8):
			var visual:Node2D=load("res://scripts/character_visual.gd").new();page.add_child(visual);visual.configure_player()
			visual.position=Vector2(80+col*160,170+row*200);visual.scale=Vector2(2.75,2.75)
			visual.set_pose([Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][row],false);visual.set_process(false);visuals.append(visual)
	for frame in range(120):
		for i in visuals.size():
			var visual:Node=visuals[i];var kind:String=KINDS[i%8];var duration:float=state.ACTION_RULES.spec(kind).duration
			var progress:=fposmod(frame/24.0,duration)/duration
			var distance:float=load("res://scripts/action_contact.gd").stand_distance(kind)
			var at:Vector2=visual.to_global(visual.facing*distance)
			visual.set_sequence_snapshot({"kind":kind,"duration":duration,"progress":progress,"x":at.x,"y":at.y})
			visual._process(1.0/24);visual.set_process(false)
		await process_frame;await RenderingServer.frame_post_draw
		for i in visuals.size():
			var visual:Node=visuals[i];var contact:Dictionary=visual.wardrobe.rig_frame.get("contact",{})
			if not contact.is_empty() and float(contact.phase)>.51 and float(contact.phase)<.61 and str(contact.kind) in ["hoe","dig","chop","cut","harvest","gather"]:worst_contact=maxf(worst_contact,float(contact.error))
		assert(root.get_texture().get_image().save_png(folder+"/frame-%04d.png"%frame)==OK)
	print("MOTION_GPU: 120 actual frames at 24 Hz, 8 actions x 4 directions; worst_contact=",worst_contact)
	await root.get_node("AudioService").prepare_exit();quit(0 if worst_contact<1.5 else 1)
