extends SceneTree
var passed: int=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:passed+=1
 else:failures.append(label);printerr("FAIL ",label)
func frames(count: int) -> void:
 for i: int in count:await physics_frame
func key(code: Key,down: bool) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
 Input.parse_input_event(event)
func run() -> void:
 create_timer(90).timeout.connect(func():quit(2))
 var s: Node=root.get_node("GameState")
 var original_hash:=FileAccess.get_sha256(s.LEGACY_SAVE_PATH)
 check(s.incompatible_save,"real v33 copy reproduces incompatible startup")
 check(not FileAccess.file_exists(s.SAVE_PATH),"no v38 life created without consent")
 change_scene_to_file("res://scenes/main.tscn")
 await frames(12)
 var hud: Node=current_scene.hud
 var panel: Control=hud.save_panel
 check(panel.visible and s.ui_open,"startup opens visible save choice")
 check(panel.notice.text.contains("不能移动"),"visible notice explains frozen movement")
 check(panel.new_game_button.text.contains("保留旧档"),"new life choice explicitly preserves legacy")
 panel.close()
 check(panel.visible,"dismiss cannot expose silently frozen world")
 panel.new_game_button.pressed.emit();await frames(2)
 check(panel.new_game_confirmation.visible,"separate new life confirmation displayed")
 check(panel.new_game_confirmation.detail_label.text.contains("不继承旧进度"),"confirmation explains progress boundary")
 panel.new_game_confirmation.cancel_button.pressed.emit();await frames(2)
 check(s.incompatible_save and not FileAccess.file_exists(s.SAVE_PATH),"cancel leaves legacy and progress unchanged")
 panel.new_game_button.pressed.emit();await frames(2)
 panel.new_game_confirmation.confirm_button.pressed.emit();await frames(20)
 check(not s.incompatible_save,"explicit confirmation unlocks simulation")
 check(FileAccess.get_sha256(s.LEGACY_SAVE_PATH)==original_hash,"legacy source byte-identical after new life")
 check(FileAccess.file_exists(s.SAVE_PATH),"independent v38 save created")
 check(not current_scene.hud.save_panel.visible and not s.ui_open,"new playable scene has no blocking save dialog")
 var player: Node2D=current_scene.player
 var before: Vector2=player.position
 key(KEY_D,true);await frames(30);key(KEY_D,false);await frames(3)
 check(player.position.distance_to(before)>15,"D key moves after real legacy recovery")
 before=player.position
 key(KEY_UP,true);await frames(30);key(KEY_UP,false);await frames(3)
 check(player.position.distance_to(before)>15,"arrow key moves after real legacy recovery")
 s.save_game(s.SAVE_PATH,true);await s.wait_for_saves()
 check(s.load_game(),"new life saves and reloads successfully")
 check(not s.incompatible_save,"saved v38 remains compatible")
 change_scene_to_file("res://scenes/main.tscn");await frames(15)
 check(not current_scene.hud.save_panel.visible,"compatible restart skips legacy notice")
 check(FileAccess.get_sha256(s.LEGACY_SAVE_PATH)==original_hash,"legacy unchanged after save/load and scene reload")
 var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/legacy-startup.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failures":failures,"seed_version":33,"isolated_profile":true},"  "));file.close()
 print("LEGACY_STARTUP passed=",passed," failures=",failures.size())
 current_scene.queue_free();await process_frame
 await s.wait_for_saves();await root.get_node("AudioService").prepare_exit();quit(0 if failures.is_empty() else 1)
