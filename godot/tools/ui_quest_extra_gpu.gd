extends "res://tools/ui_quest_gpu.gd"
func extra(name: String) -> void:
	w.hud.ui_stack.leave();await settle()
	match name:
		"forage":w.hud.show_forage()
		"facilities":w.hud.farm_facility_panel.open_panel(false,0)
		"history":w.hud.npc_history_panel.open_panel("granny")
		"heat":w.hud.kitchen_heat_panel.open_panel({"id":"greens","n":1,"op":"k-cook"})
		"wedding":w.hud.wedding_panel.open_panel("qiao")
		"separation":w.hud.separation_panel.open_panel("qiao")
	await settle()
func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func():push_error("extra UI GPU timeout");quit(1))
	var touch: bool=OS.get_environment("ZRZ_FORCE_TOUCH")=="1"
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.current_interior=""
	if touch:root.size=Vector2i(1280,720)
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.player.set_physics_process(false);Input.warp_mouse(Vector2(1,1));w.hud.hover_card.hide()
	var sizes: Array=[Vector2i(1280,720)] if touch else [Vector2i(960,600),Vector2i(1280,800),Vector2i(1280,720)]
	for screen: Vector2i in sizes:
		root.size=screen
		for name: String in ["forage","facilities","history","heat","wedding","separation"]:
			await extra(name);validate(name)
			var active: Control=w.hud.ui_stack.active()
			var papers: Array=active.find_children("*","PanelContainer",true,false)
			if not papers.is_empty():check(root.get_visible_rect().encloses(papers[0].get_global_rect()),"nested panel fits "+name+str(screen))
			await capture(("touch-extra-" if touch else "extra-")+name+"-%dx%d" % [screen.x,screen.y])
	s.player_settings.textScale=1.25;s.player_settings.contrast=true;s.changed.emit()
	if not touch:root.size=Vector2i(960,600)
	for name: String in ["forage","facilities","history","heat","wedding","separation"]:
		await extra(name);validate("large-"+name)
		var papers: Array=w.hud.ui_stack.active().find_children("*","PanelContainer",true,false)
		if not papers.is_empty():check(root.get_visible_rect().encloses(papers[0].get_global_rect()),"large nested panel fits "+name)
		await capture(("touch-extra-large-" if touch else "extra-large-")+name)
	var file:=FileAccess.open("res://artifacts/ui-quests-20261017/"+("extra-touch-report.json" if touch else "extra-gpu-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"screenshots":screens,"touchPolicy":touch},"  "))
	print("Extra UI GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
