extends "res://tools/ui_quest_gpu.gd"
func run() -> void:
	create_timer(80,true,false,true).timeout.connect(func():quit(1))
	s=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.ui_open=false;s.current_interior=""
	change_scene_to_file("res://scenes/main.tscn");await settle();w=current_scene;w.player.set_physics_process(false);Input.warp_mouse(Vector2(1,1))
	for screen: Vector2i in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1280,720)]:
		root.size=screen
		for scale: float in [1.0,1.25]:
			s.player_settings.textScale=scale;s.player_settings.contrast=scale>1;s.changed.emit();await open("map");validate("map final")
			check(w.hud.map_panel.map_canvas.label_font_size()>=14,"map labels respect readable font minimum")
			check(w.hud.map_panel.map_hint_label.text.contains("图钉"),"map statistics use scalable UI text")
			await capture("map-final-%dx%d-%.2f" % [screen.x,screen.y,scale])
	var file:=FileAccess.open("res://artifacts/ui-quests-20261017/map-gpu-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"screenshots":screens},"  "))
	print("UI map GPU: %d passed, %d failed" % [passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed>0 else 0)
