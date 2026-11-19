extends SceneTree
var visuals:Array=[]
var state:Node
var folder:String
class Paper extends Node2D:
	var caption:=""
	func _draw()->void:
		draw_rect(Rect2(0,0,1280,800),Color("d4d5bc"))
		draw_string(ThemeDB.fallback_font,Vector2(25,35),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("35463d"))
func _initialize()->void:call_deferred("run")
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_open=false;state.minutes=720
	var stage:=OS.get_environment("ZRZ_REVIEW_STAGE")
	folder=OS.get_environment("ZRZ_ART_OUTPUT")+"/"+stage+"-gait";DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var paper:=Paper.new();root.add_child(paper)
	var ids:Array=["player","player","player","player","an","granny","chen","lin","bao","xiaohe","zhouSenior","luo"]
	for i in ids.size():
		var visual:Node2D=load("res://scripts/character_visual.gd").new();paper.add_child(visual)
		if str(ids[i])=="player":visual.configure_player()
		else:visual.configure(str(ids[i]))
		visual.position=Vector2(160+(i%4)*310,210+floori(i/4.0)*250);visual.scale*=Vector2(3,3)
		visual.set_process(false);visuals.append(visual)
	var frozen:=0
	for frame in range(120):
		var moving:bool=frame<36 or frame>=48 and frame<84 or frame>=96
		var speed:=265.0 if frame>=48 and frame<84 else 195.0
		paper.caption="Normal walk / weight transfer" if frame<36 else "Stop / settle" if frame<48 else "Fast walk" if frame<84 else "Stop with resident walk flag held" if frame<96 else "Turn and resume"
		paper.queue_redraw()
		for i in visuals.size():
			var visual:Node=visuals[i];var index:=i%4
			if frame>=96:index=(index+(frame-96)/6)%4
			var direction:Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][index]
			visual.set_locomotion_sample(direction*speed/24.0 if moving else Vector2.ZERO,1.0/24)
			visual.set_pose(direction,moving or i>=4 and frame>=84 and frame<96)
			visual._process(1.0/24);visual.set_process(false)
		await process_frame;await RenderingServer.frame_post_draw
		if frame==95:
			for i in range(4,visuals.size()):
				if str(visuals[i].get_meta("resident_clip",""))!="idle":frozen+=1
		assert(root.get_texture().get_image().save_png(folder+"/frame-%04d.png"%frame)==OK)
	print("DEEPENING_MOTION_GPU frames=120 fps=24 actors=12 frozen_residents=",frozen," stage=",stage)
	await root.get_node("AudioService").prepare_exit();quit(1 if stage=="after" and frozen>0 else 0)
