extends SceneTree
## Isolated visual comparison; never modifies world data or production resources.
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else: failed += 1; push_error(label)
func settle() -> void:
 for frame in range(8): await process_frame
func capture(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 check(image != null and not image.is_empty(), "viewport image")
 if image != null: check(image.save_png("res://artifacts/tree-visibility-probe-20261009/" + name + ".png") == OK, "saved " + name)
func run() -> void:
 create_timer(60).timeout.connect(func(): quit(1))
 var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
 if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"): quit(1); return
 var state := root.get_node("GameState")
 state.set_process(false)
 state.ui_art.theme = "paper"
 state.flags.introDone = true
 var art = load("res://scripts/character_art.gd")
 state.appearance = art.data().playerProfile.duplicate(true)
 state.appearance.weatherDress = false
 root.size = Vector2i(1280,800)
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 var world = current_scene
 world.set_process(false)
 world.player.set_physics_process(false)
 world.pointer_hover = {}
 world.selected_world_target = {}
 if world.hud.onboarding_open(): world.hud.toggle_onboarding()
 root.get_node("UIArtService").apply_all()
 var world_art = load("res://scripts/world_art.gd")
 var entries: Dictionary = world_art.entries()
 var door: Dictionary = entries["buildings/home-lin"].door
 world.player.global_position = Vector2(float(door.x),float(door.y)+45.0)
 world.player.camera.zoom = Vector2(3,3)
 world.player.camera.reset_smoothing()
 world.player.camera.force_update_scroll()
 var before_world_text := FileAccess.get_file_as_string("res://data/world.json")
 var actor_rectangle := Rect2(world.player.global_position+Vector2(-8,-32),Vector2(16,32))
 var occluders: Array = []
 var observations: Array = []
 for prop in world.get_children():
  if prop.get_script() == null or prop.get_script().resource_path != "res://scripts/world_prop.gd": continue
  var data: Dictionary = prop.get("data")
  if str(data.get("kind","")) != "tree" or prop.global_position.y <= world.player.global_position.y: continue
  var rect: Array = entries["props/tree"].worldRect
  var bounds := Rect2(prop.global_position+Vector2(float(rect[0]),float(rect[1])),Vector2(float(rect[2]),float(rect[3])))
  if bounds.intersects(actor_rectangle):
   occluders.append(prop)
   observations.append({"tree_position":[prop.global_position.x,prop.global_position.y],"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"actor_feet":[world.player.global_position.x,world.player.global_position.y]})
 check(occluders.size()>0,"real foreground tree overlaps Lin doorstep avatar")
 await capture("before")
 for prop in occluders: prop.modulate.a = 0.42
 await capture("opacity-prototype")
 for prop in occluders: prop.modulate.a = 1.0
 await capture("restored")
 check(before_world_text == FileAccess.get_file_as_string("res://data/world.json"),"authored world remains byte-identical")
 var file := FileAccess.open("res://artifacts/tree-visibility-probe-20261009/observations.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"isolated live opacity prototype, no production fix","occluders":observations,"passed":passed,"failed":failed},"  "));file.close()
 await root.get_node("AudioService").prepare_exit()
 print("TREE_VISIBILITY_PROBE: ",passed," passed, ",failed," failed")
 quit(0 if failed==0 else 1)
