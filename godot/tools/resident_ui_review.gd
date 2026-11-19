extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.flags.introDone=true;s.current_interior="";s.ui_open=false;s.day=30;s.minutes=660
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn")
	for frame:int in 12:await process_frame
	var panel:Control=current_scene.hud.npc_story_panel;var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/resident-ui";DirAccess.make_dir_recursive_absolute(out);var checks:int=0
	for mode:String in ["desktop","portrait"]:
		if mode=="portrait":root.size=Vector2i(720,1280);root.content_scale_size=Vector2i(720,1280)
		for id:String in ["chen","an","lan"]:
			s.npc_stories[id]={"step":1,"choices":[0],"lastDay":-1};s.relations[id].points=10
			panel.open_panel(id)
			for frame:int in 6:await process_frame
			panel.quote.visible_characters=-1;await process_frame;RenderingServer.force_draw()
			assert(root.get_visible_rect().encloses(panel.panel.get_global_rect()))
			assert(panel.close_button.has_focus());assert(panel.last_view.activity.kind==str(load("res://scripts/resident_life.gd").profile(id).storyKind));checks+=3
			root.get_texture().get_image().save_png(out+"/"+mode+"-"+id+".png")
			panel.refresh()
			for frame:int in 3:await process_frame
			assert(panel.close_button.has_focus());assert(panel.quote.visible_characters==-1);checks+=2
			panel.close()
	print("RESIDENT_STORY_UI: ",checks," checks, 6 rendered panels; portrait is simulated viewport, not device certification")
	await root.get_node("AudioService").prepare_exit();quit()
