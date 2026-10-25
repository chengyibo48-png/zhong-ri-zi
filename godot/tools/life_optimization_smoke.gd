extends SceneTree
var PET: Script
var FORAGE: Script
var LIFE: Script
var WILD: Script
var TEXTURES: Script
var passed := 0
var failed := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		failures.append(message)
		push_error(message)
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	var state := root.get_node("GameState")
	state.set_process(false)
	state.ui_open = false
	state.visual_fx.motion = "full"
	state.visual_fx.density = "standard"
	PET = load("res://scripts/pet_art.gd")
	FORAGE = load("res://scripts/forage_art.gd")
	LIFE = load("res://scripts/life_presentation.gd")
	WILD = load("res://scripts/wildlife_art.gd")
	TEXTURES = load("res://scripts/character_art.gd")

	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"), "Isolated save directory")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
	for key: String in manifest.entries:
		var entry: Dictionary = manifest.entries[key]
		check(str(entry.get("status", "")) != "missing", "No missing catalogue resource " + key)
		check(entry.get("pendingPaintedStates", []).is_empty(), "No stale pending state " + key)
	for pet_type in ["cat", "dog"]:
		var atlas: Texture2D = TEXTURES.texture(str(manifest.entries["pets/" + pet_type].actionAtlas))
		check(atlas != null and atlas.get_size() == Vector2(1024, 960), "Complete four-direction six-pose atlas " + pet_type)
		if atlas == null: continue
		var hashes: Dictionary = {}
		for row in range(6):
			for direction in range(4):
				var cell := atlas.get_image().get_region(Rect2i(direction * 256, row * 160, 256, 160))
				check(cell.get_used_rect().has_area() and cell.detect_alpha() != Image.ALPHA_NONE, "Nonempty transparent pose " + pet_type)
				var hash_value := hash(cell.get_data())
				check(not hashes.has(hash_value), "Distinct generated pose " + pet_type)
				hashes[hash_value] = true
		for direction in ["down", "left", "right", "up"]:
			var actor := {"position":{"direction":direction,"walking":false},"energy":100,"hunger":70}
			var before := actor.duplicate(true)
			state.pet_visual_action = {"kind":"feed","at":10.0,"until":12.8}
			check(PET.action_frame(actor, {"type":pet_type}, 720, 10).state == "feeding", "Feed selects eating artwork")
			state.pet_visual_action = {"kind":"pet","at":10.0,"until":12.2}
			check(PET.action_frame(actor, {"type":pet_type}, 720, 10).state == "petting", "Pat selects happy artwork")
			check(PET.action_frame(actor, {"type":pet_type}, 720, 14).state == "idle", "Expired interaction returns to idle")
			actor.energy = 10
			check(PET.action_frame(actor, {"type":pet_type}, 720, 14).state == "sleeping", "Tired pet curls asleep")
			actor.energy = 100
			check(PET.action_frame(actor, {"type":pet_type}, 1200, 14).state == "sleeping", "Night selects sleeping artwork")
			state.pet_visual_action.clear()
			actor.position.walking = true
			check(PET.action_frame(actor, {"type":pet_type}, 720, 10).state == "walk_a" and PET.action_frame(actor, {"type":pet_type}, 720, 10.125).state == "walk_b", "Alternating walk strides")
			actor.position.walking = false
			check(actor == before, "Pose selection preserves pet data")
	for key in ["bamboo", "berry", "mushroom", "shoot", "tea", "wildHerb", "wood"]:
		var hashes: Dictionary = {}
		for season in range(4):
			for value in [0.2, 0.6, 1.0]:
				var ecological := {"season":season,"stage":value,"ready":value >= 1.0,"in_season":true}
				var before := ecological.duplicate(true)
				var descriptor: Dictionary = FORAGE.descriptor(key, ecological)
				check(not descriptor.is_empty() and bool(descriptor.get("paintedSeason", false)), "Painted seasonal stage " + key)
				if descriptor.is_empty(): continue
				var region: Rect2 = descriptor.source
				var image: Image = descriptor.texture.get_image().get_region(Rect2i(region))
				var hash_value := hash(image.get_data())
				check(not hashes.has(hash_value) and image.get_used_rect().has_area(), "Distinct season and regeneration silhouette " + key)
				hashes[hash_value] = true
				check(ecological == before, "Drawing preserves ecology")
	check(int(FORAGE.descriptor("berry", {"season":0,"stage":0.75,"harvested_today":true}).stage)==0, "Same-day harvested resource shows depleted silhouette")
	check(LIFE.wildlife_available("butterfly",0,720,{"rain":0,"extreme":false}), "Spring butterfly visible")
	check(not LIFE.wildlife_available("butterfly",2,720,{"rain":0,"extreme":false}), "Autumn butterfly hidden")
	check(not LIFE.wildlife_available("egret",0,1200,{"rain":0,"extreme":false}), "Night bird hidden")
	check(not LIFE.wildlife_available("sparrow",0,720,{"rain":34,"extreme":false}), "Rain bird hidden")
	for identity in ["egret", "sparrow", "butterfly"]:
		var frames: Dictionary = {}
		for i in range(1920): frames[WILD.activity(identity, i / 80.0).frame] = true
		check(frames.size() == 6, "Activity cycle uses all six poses " + identity)
	for category in ["ui", "effects"]:
		for key: String in manifest.entries:
			if not key.begins_with(category + "/"): continue
			check(load("res://scripts/detail_art.gd").texture(key) != null, "Actual vector/detail texture " + key)
	var receipts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/continuation-art-20261013/generation-receipts.json"))
	var state_count := 0
	for receipt: Dictionary in receipts:
		if str(receipt.status) != "imported_static_review_only": continue
		state_count += 1
		check(FileAccess.get_sha256(receipt.runtimePath) == str(receipt.runtimeSha256), "Accepted state image hash " + str(receipt.id))
		check(manifest.entries[receipt.id].states[receipt.state] == receipt.runtimePath, "Accepted state is bound " + str(receipt.id))
	check(state_count == 125, "All 125 accepted state images retained")
	state.pet_visual_action.clear()
	state.ranch.pet.fed = -1; state.ranch.pet.hunger = 20
	check(state.ranch_pet_action("feed") and str(state.pet_visual_action.get("kind", "")) == "feed", "Successful feed operation starts eating action")
	state.pet_state.patted = -1
	check(state.pat_companion() and str(state.pet_visual_action.get("kind", "")) == "pet", "Successful pet operation starts happy action")
	state.ranch_pet_action("switch_pet")
	check(state.pet_visual_action.is_empty(), "Switching companion clears stale action")
	var report := {"date":"2026-10-14","passed":passed,"failed":failed,"failures":failures,"stateImages":state_count}
	var file := FileAccess.open("res://artifacts/optimization-20261014/smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LIFE_OPTIMIZATION: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
