extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
 if ok:passed += 1
 else:
  failed += 1
  if failed < 16:push_error(label)
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 await process_frame
 var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
 if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 var state := root.get_node("GameState")
 state.set_process(false)
 var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RELATIONS_FIXTURE")))
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 var world = current_scene
 world.set_process(false)
 world.player.set_physics_process(false)
 var hud = world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 var panel = hud.relations_panel
 for row in fixture.cases:
  check(state.load_game_data(state.convert_external_save(row.state)), "import source scenario")
  hud.show_neighbors()
  panel.set_filter(str(row.filter))
  var before: Dictionary = state._make_save_data().duplicate(true)
  var actual: Array = panel.people_rows()
  check(actual.size() == row.expected.size(), "count " + str(row.filter))
  for i in row.expected.size():
   for field in row.expected[i]:
    check(actual[i][field] == row.expected[i][field], str(row.scenario) + "/" + str(row.filter) + "/" + str(row.expected[i].id) + "/" + str(field) + " EXPECT=" + str(row.expected[i][field]) + " ACTUAL=" + str(actual[i][field]))
   check(panel.cards.has(str(row.expected[i].id)), "rendered source card")
   check((panel.cards[str(row.expected[i].id)].story == null) == (row.filter == "画像册"), "gallery only offers find")
  check(state._make_save_data() == before, "read only view")
  check(hud._gamepad_panel() == panel and hud.neighbors_open(), "modal focus registered")
  hud.close_top_panel()
  check(not panel.visible and not state.ui_open, "escape closure")
 hud._select_life_menu("relations")
 check(panel.visible and not hud.neighbor_journal.visible, "menu opens source roster")
 panel.set_filter("孩子们")
 var id: String = panel.people_rows()[0].id
 panel.cards[id].story.pressed.emit()
 check(not panel.visible and hud.npc_story_panel.visible, "story routed to original story page")
 hud.close_top_panel()
 hud.show_neighbors()
 panel.cards[id].find.pressed.emit()
 check(not panel.visible and not state.ui_open, "find closes roster and starts navigation")
 state._interrupt_navigation_for_ui()
 hud.show_neighbors()
 panel.set_filter("画像册")
 state.current_interior = "home-granny"
 change_scene_to_file("res://scenes/interior.tscn")
 await settle()
 var interior = current_scene
 interior.set_process(false)
 interior.player.set_physics_process(false)
 hud = interior.hud
 hud.show_neighbors()
 check(state.relations_ui_filter == "画像册" and hud.relations_panel.cards.size() == 24, "runtime source filter survives scene rebuild")
 hud.close_top_panel()
 print("Relations UI: %d passed, %d failed" % [passed, failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
