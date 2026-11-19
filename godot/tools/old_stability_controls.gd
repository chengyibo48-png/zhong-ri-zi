extends SceneTree
var passed: int=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:passed+=1
 else:failures.append(label);printerr("FAIL ",label)
func key(code: Key,down: bool) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
 Input.parse_input_event(event)
func frames(count: int) -> void:
 for i: int in count:await physics_frame
func run() -> void:
 create_timer(90).timeout.connect(func():quit(2))
 var s: Node=root.get_node("GameState")
 s.flags.introDone=true;s.quest_runtime.set_process(false)
 await s.wait_for_saves();s.current_interior="";s.ui_open=false
 change_scene_to_file("res://scenes/main.tscn")
 await frames(8)
 DisplayServer.window_set_title("种日子 · 自动操作验证（结束后打开正常游戏）")
 var world: Node=current_scene;var hud: Node=world.hud;var player: Node2D=world.player
 if hud.onboarding_open():hud.toggle_onboarding()
 s.ui_open=false;s.cancel_player_action();await s.wait_for_saves();await frames(3)
 var before: Vector2=player.position
 key(KEY_D,true);await frames(30);key(KEY_D,false);await frames(3)
 check(player.position.distance_to(before)>15,"native keyboard input moves original player")
 var stopped: Vector2=player.position
 await frames(10)
 check(player.position.distance_to(stopped)<1,"key release stops original player")
 hud.show_ranch();await frames(3)
 check(hud.ranch_panel.visible and s.ui_open,"original ranch menu opens")
 check(hud.ranch_panel.animal_list.item_count==s.animals.size(),"opened ranch menu populates current herd")
 before=player.position;key(KEY_D,true);await frames(10);key(KEY_D,false)
 check(player.position.distance_to(before)<1,"open modal prevents unwanted movement")
 hud.close_top_panel();await frames(3)
 check(not hud.ranch_panel.visible and not s.ui_open,"ranch menu closes and returns movement")
 var panel: Control=hud.ranch_panel
 hud.remove_child(panel);panel.refresh();s.changed.emit();hud.add_child(panel)
 check(panel.is_inside_tree() and not panel.visible,"detached ranch refresh safely ignored and panel restored")
 hud.show_ranch();await frames(2)
 check(panel.visible and panel.animal_list.item_count==s.animals.size(),"ranch reopens with correct current entries")
 hud.close_top_panel();await frames(2)
 for method: String in ["show_map","show_kitchen","show_settings","show_neighbor_book"]:
  await s.wait_for_saves();hud.call(method);await frames(2)
  check(s.ui_open,"open existing UI "+method)
  hud.close_top_panel();await frames(2)
  check(not s.ui_open,"close existing UI "+method)
 s.set_process(false);s.quest_runtime.set_process(false);await s.wait_for_saves()
 var wanted: Dictionary={"money":s.money,"inventory":s.inventory.duplicate(true),"animals":s.animals.duplicate(true),"position":s.player_position}
 check(s.save_game("user://old-controls-v38.json",true),"original v38 save writes")
 await s.wait_for_saves()
 s.money=0
 check(s.load_game("user://old-controls-v38.json"),"original v38 save reloads")
 check(s.money==wanted.money and s.inventory==wanted.inventory and s.animals.size()==wanted.animals.size() and s.player_position.distance_to(wanted.position)<0.1,"money inventory herd and position survive save/load")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("ZRZ_ART_OUTPUT")+"/controls.png")
 var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/controls.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failures":failures,"native_input_event_pipeline":true,"pixel_updates":false,"isolated_save":true},"  "));file.close()
 print("OLD_STABILITY_CONTROLS passed=",passed," failures=",failures.size())
 current_scene.queue_free();await process_frame
 await root.get_node("AudioService").prepare_exit();quit(0 if failures.is_empty() else 1)
