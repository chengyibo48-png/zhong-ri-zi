extends SceneTree
const ART = preload("res://scripts/world_art.gd")
const TEXTURES = preload("res://scripts/character_art.gd")
var passed: int = 0
var failed: int = 0
class ArtProbe extends Node2D:
	var interior_renderer: Script
	var data: Dictionary = {}
	var season: int = 0
	var minutes: float = 720
	var house: String = ""
	var painted: bool = false
	func _draw() -> void:
		if house.is_empty():
			painted = ART.draw_prop(self, data, season, minutes)
		else:
			painted = interior_renderer.draw_room(self, house, minutes)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func settle() -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Fine art runtime timeout"); quit(1))
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		quit(1); return
	var state = root.get_node("GameState")
	state.set_process(false)
	state.flags.introDone = true
	var queue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/independent-fine-art-20261011/queue.json"))
	for job: Dictionary in queue.jobs:
		if job.status != "imported_not_gameplay_tested": continue
		var texture: Texture2D = TEXTURES.texture(str(job.runtimePath))
		check(texture != null, "Actual runtime texture " + str(job.id) + "/" + str(job.state))
		if texture == null: continue
		var image: Image = texture.get_image()
		check(not image.is_empty() and image.get_used_rect().has_area(), "Nonempty rendered image " + str(job.id))
		check(FileAccess.get_sha256(str(job.runtimePath)) == str(job.runtimeSha256), "Bound image matches accepted PNG " + str(job.id))
	var probe := ArtProbe.new()
	probe.interior_renderer = load("res://scripts/interior_art.gd")
	probe.position = Vector2(480, 350)
	root.add_child(probe)
	var entries: Dictionary = ART.entries()
	for key: String in entries:
		if not key.begins_with("buildings/"): continue
		var row: Dictionary = entries[key]
		check(not bool(row.get("rapidSeasonMaterial", false)), "Painted seasonal binding replaces rapid material " + key)
		probe.data = {"kind":"house", "id":key.get_slice("/",1)}
		for season in range(4):
			probe.season = season
			for time in [720, 1260]:
				probe.minutes = time; probe.painted = false; probe.queue_redraw()
				await settle()
				check(probe.painted, "Live building drawing " + key + "/" + str(season) + "/" + str(time))
	probe.house = "building-farm-12"
	probe.position = Vector2.ZERO
	for key: String in entries:
		if not key.begins_with("interiors/"): continue
		probe.house = "building-farm-12" if key == "interiors/player_home" else key.get_slice("/",1)
		for time in [720, 1260]:
			probe.minutes = time; probe.painted = false; probe.queue_redraw()
			await settle()
			check(probe.painted, "Live room day/night drawing " + key + "/" + str(time))
	probe.queue_free(); await process_frame
	root.size = Vector2i(1280, 800)
	for id: String in ["home-qiao", "home-an", "building-town-1", "building-farm-12"]:
		state.current_interior = id
		state.interior_position = Vector2(480, 550)
		change_scene_to_file("res://scenes/interior.tscn")
		await settle()
		var room = current_scene
		check(room.get_script().resource_path == "res://scripts/interior_world.gd", "Real interior scene " + id)
		room.set_process(false); room.player.set_physics_process(false)
		if room.hud.onboarding_open(): room.hud.toggle_onboarding()
		for time in [720, 1260]:
			state.minutes = time; state.changed.emit(); room.queue_redraw()
			await settle()
			check(bool(room.painted_floor_active), "Actual scene uses painted room " + id)
			var screenshot: Image = root.get_texture().get_image()
			check(screenshot != null and not screenshot.is_empty(), "Actual room framebuffer " + id)
			if screenshot != null:
				check(screenshot.save_png("res://artifacts/optimization-20261014/rooms/" + id + "-" + str(time) + ".png") == OK, "Room screenshot " + id)
			var fixed_bodies: int = 0
			for child: Node in room.get_children():
				if child is StaticBody2D and child.get_child_count() > 0: fixed_bodies += 1
			check(fixed_bodies >= 5, "Authored wall and furniture bodies retained " + id)
	check(is_equal_approx(ART.night_factor(360), 1.0) and is_zero_approx(ART.night_factor(420)), "Dawn transition endpoints")
	check(is_zero_approx(ART.night_factor(1140)) and is_equal_approx(ART.night_factor(1260), 1.0), "Dusk transition endpoints")
	current_scene.queue_free(); await process_frame
	print("FINE_ART_RUNTIME: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
