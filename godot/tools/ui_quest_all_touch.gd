extends "res://tools/ui_quest_extra_gpu.gd"
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func():push_error("all touch UI timeout");quit(1))
	check(OS.get_environment("ZRZ_FORCE_TOUCH")=="1","mobile sizing policy active")
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.current_interior="";root.size=Vector2i(1280,720)
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.player.set_physics_process(false);Input.warp_mouse(Vector2(1,1))
	var names: Array[String]=["tasks","menu","bag","map","calendar","farm","ranch","fishing","kitchen","processing","building","tools","skills","neighbors","person","dialogue","story","gift","knowledge","portable","community","projects","home","mail","settings","saves","sleep","help","feedback","seeds","festival","forage","facilities","history","heat","wedding","separation"]
	for name: String in names:
		if name in ["forage","facilities","history","heat","wedding","separation"]:await extra(name)
		else:await open(name)
		validate("all-touch-"+name)
		for node: Node in w.hud.ui_stack.active().find_children("*","BaseButton",true,false):
			if node.is_visible_in_tree():check(node.size.y>=48,"mobile target height "+name+str(node.name))
		await capture("touch-all-"+name)
	var file:=FileAccess.open("res://artifacts/ui-quests-20261017/all-touch-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"screenshots":screens,"views":names,"physicalScreen":[1280,720],"logicalViewport":str(root.get_visible_rect()),"policy":"Windows GPU simulated mobile policy, not Android hardware"},"  "))
	print("All UI touch GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
