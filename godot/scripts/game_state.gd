extends Node
const FARM_LAYOUT := preload("res://scripts/farm_layout.gd")
const PROFILE = preload("res://scripts/presentation_profile.gd")

const JS_TEXT = preload("res://scripts/js_string.gd")
const BUILDING_GEOMETRY = preload("res://scripts/building_geometry.gd")

signal changed
signal quest_changed
const QUESTS=preload("res://scripts/quest_service.gd")
var quests: Dictionary={}
var quest_action: Dictionary={}
var quest_action_serial: int=0
signal clock_changed
signal domain_changed(domain: String)
signal world_changed
var state_changes := preload("res://scripts/state_changes.gd").new()
var _periodic_autosave_elapsed := 0.0
var _autosave_timer: Timer
var _urgent_autosave := false
signal ranch_positions_changed
signal message_requested(text: String)
signal player_moved(position: Vector2)
signal interior_moved(position: Vector2)
signal bedtime_reached
signal year_review_requested
signal feedback_toast_requested(text: String, priority: int)
# Presentation context is transient and never part of the save.
var presenting_action_delta := false
var pet_visual_action: Dictionary = {}
signal action_sequence_changed(snapshot: Dictionary)
signal scene_fade_changed(alpha: float)
signal sound_requested(kind: String)
signal vibration_requested

const SAVE_PATH := "user://zhenrizhi_godot_save.json"
const INVENTORY_METADATA_PATH := "res://data/inventory_metadata.json"
const CONTENT_PATH := "res://data/content.json"
const INITIAL_STATE_PATH := "res://data/initial_state.json"
const SYSTEMS_PATH := "res://data/systems.json"
const WORLD_DATA_PATH := "res://data/world.json"
const ENVIRONMENT_RULES := preload("res://scripts/environment_rules.gd")
const RANCH_MOVEMENT_SCRIPT := preload("res://scripts/ranch_movement.gd")
const FORAGE_RULES := preload("res://scripts/forage_rules.gd")
const FISHING_SESSION := preload("res://scripts/fishing_session.gd")
const FISHING_RULES := preload("res://scripts/fishing_rules.gd")
const VILLAGE_NAVIGATION_SCRIPT := preload("res://scripts/village_navigation.gd")
const NPC_SCHEDULE_RULES := preload("res://scripts/npc_schedule.gd")
const STARTER_SUPPLIES := {"cabbageSeed": 8, "radishSeed": 4, "rice": 4, "egg": 2, "feed": 9}
const STARTER_ANIMALS := [
	{"id": "hen", "name": "点点", "species": "鸡", "product": "egg", "bond": 0, "fed": false, "ready": 1},
	{"id": "duck", "name": "小水", "species": "鸭", "product": "duckEgg", "bond": 0, "fed": false, "ready": 0},
	{"id": "cow", "name": "阿黄", "species": "牛", "product": "milk", "bond": 0, "fed": false, "ready": 0}
]
const VISUAL_FX_DEFAULT = PROFILE.VISUAL_FX_DEFAULT
const UI_ART_DEFAULT = PROFILE.UI_ART_DEFAULT
const APPEARANCE_DEFAULT = PROFILE.APPEARANCE_DEFAULT
const FEEDBACK_PREFS_DEFAULT = PROFILE.FEEDBACK_PREFS_DEFAULT
const FEEDBACK_TYPES = PROFILE.FEEDBACK_TYPES
const FEEDBACK_LINKS = PROFILE.FEEDBACK_LINKS
const LEGACY_TOOL_UPGRADES := ["hoe", "water", "gather", "rod"]
const ANIMAL_ACTIONS := ["auto", "feed", "pet", "clean", "treat", "rest", "rescue"]
const ANIMAL_ACTION_NAMES := {"auto": "顺手照料", "feed": "添饲料", "pet": "抚摸", "clean": "梳洗", "treat": "治疗", "rest": "留舍休养", "rescue": "带回畜舍"}
const ONBOARDING_FLAG := "godot_onboarding"
const ONBOARDING_STEPS := ["guide", "sow", "harvest", "neighbor"]

var inventory_metadata: Dictionary = {}
var day := 0
var minutes := 390.0
var stamina := 100.0
var money := 180
var player_name := "小满"
var player_gender := "不设定"
var player_settings: Dictionary = {}
var visual_fx: Dictionary = VISUAL_FX_DEFAULT.duplicate(true)
var ui_art: Dictionary = UI_ART_DEFAULT.duplicate(true)
var appearance: Dictionary = APPEARANCE_DEFAULT.duplicate(true)
var feedback: Dictionary = {"version": 1, "next": 1, "rows": [], "days": [], "seen": [], "prefs": FEEDBACK_PREFS_DEFAULT.duplicate(true)}
var player_stats: Dictionary = {}
var player_journal: Array[Dictionary] = []
var letters: Array[Dictionary] = []
var mail_read: Array[String] = []
var legacy_archive: Dictionary = {}
var player_source_position: Dictionary={"x":2831.0,"y":1652.0}
var player_position: Vector2:
	get:return Vector2(float(player_source_position.x),float(player_source_position.y))
	set(value):player_source_position={"x":float(value.x),"y":float(value.y)}
var player_direction := "down"
var interior_source_position: Dictionary={"x":480.0,"y":567.0}
var interior_position: Vector2:
	get:return Vector2(float(interior_source_position.x),float(interior_source_position.y))
	set(value):interior_source_position={"x":float(value.x),"y":float(value.y)}
var current_interior := ""
var interior_return_source: Variant=null
var interior_return_position: Vector2:
	get:return Vector2(float(interior_return_source.x),float(interior_return_source.y)) if interior_return_source is Dictionary else Vector2.ZERO
	set(value):interior_return_source=null if value==Vector2.ZERO else {"x":float(value.x),"y":float(value.y),"direction":"down"}
var riding := false
var walking_target: Dictionary = {}
var kitchen_task: Dictionary = {}
var building_task: Dictionary = {}
var ranch_queue: Array = []
var ranch_active_task: Dictionary = {}
var ranch_completed := 0
var ranch_queue_generation := 0
var ranch_next_at := 0.0
var ranch_holds: Dictionary = {}
var ranch_actor_clock := 0.0
var ranch_actor_focus: Dictionary = {}
var ranch_actor_poses: Dictionary = {}
var ranch_actor_action: Dictionary = {}
var ranch_movement: RefCounted
var farm_queue: Array = []
var farm_active_task: Dictionary = {}
var farm_completed := 0
var farm_queue_generation := 0
var farm_next_at := 0.0
var source_frame_time := 0.0
var year_review_pending := false
var interior_state: Dictionary = {"memories": {}, "chores": {}}
const TOOLBAR_IDS := ["hoe", "seed", "water", "hand", "rod", "axe", "sickle", "build"]
const TOOLBAR_NAMES := {"hoe": "锄头", "seed": "种子", "water": "水壶", "hand": "双手", "rod": "鱼竿", "axe": "斧头", "sickle": "采集镰刀", "build": "布置工具"}
var selected_tool := "hoe"
var selected_seed := "cabbage"
var selected_recipe := "greens"
var selected_animal_action := "auto"
var content: Dictionary = {}
var initial_state: Dictionary = {}
var system_catalog: Dictionary = {}
var world_village: Dictionary = {}
var atlas_catalog: Dictionary = {}
var atlas_source_navigation: RefCounted
var atlas_navigation: RefCounted
var museum_entries: Dictionary = {}
var crop_catalog: Dictionary = {}
var item_catalog: Dictionary = {}
var npc_catalog: Array = []
var inventory: Dictionary = {}
var storage: Dictionary = {}
var quality: Dictionary = {}
var storage_quality: Dictionary = {}
var plots: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var ranch: Dictionary = {}
var economy: Dictionary = {}
var environment: Dictionary = {}
var forage: Dictionary = {}
signal fishing_session_changed(snapshot: Dictionary)
var fishing_session := FISHING_SESSION.new()
var fishing: Dictionary = {}
var kitchen: Dictionary = {}
var legacy_processing: Array[Dictionary] = []
var toolkit: Dictionary = {}
var skills: Dictionary = {}
var community_projects: Dictionary = {}
var legacy_chapters: Dictionary = {}
var year_plans: Dictionary = {}
var achievements: Array[String] = []
var legacy_systems: Dictionary = {}
var farm: Dictionary = {}
var building: Dictionary = {}
var building_epoch: int = 0
var known_recipes: Array[String] = []
var forage_points: Array[Dictionary] = []
var ui_window_mode_before_fullscreen := Window.MODE_WINDOWED
var ui_hud_visible := true
var ui_open := false:
	set(value):
		var opening := value and not ui_open
		ui_open = value
		if is_inside_tree():
			if opening or not value:source_keyboard.clear()
			if opening and not action_busy():_interrupt_navigation_for_ui()
			if opening:
				for actor in get_tree().get_nodes_in_group("player"):
					var world:Node=actor.get_parent()
					if world.has_method("_pointer_leave"):world._pointer_leave()
var upgrades: Dictionary = {}
var relations: Dictionary = {}
var neighbors: Dictionary = {}
var npc_residents: Dictionary = {}
# Like npc-ui.js closure state: retained across rooms, excluded from save data.
var notification_queue:RefCounted=preload("res://scripts/notification_queue.gd").new()
var relations_ui_filter: String = "全部"
var neighbor_book_ui:Dictionary={"tab":"people","person":"all","kind":"all","search":""}
var npc_movement: RefCounted
var npc_positions: Dictionary = {}
var interior_npc_positions: Dictionary = {}
var last_gifts: Dictionary = {}
var npc_stories: Dictionary = {}
var partners: Dictionary = {}
var marriage: Dictionary = {"spouse": "", "day": -1, "weekly": {}, "memories": []}
var collection: Dictionary = {}
var atlas: Dictionary = {}
var archives: Array[String] = []
var furniture: Dictionary = {}
var pet_state: Dictionary = {}
var festivals: Array[String] = []
var season_events: Dictionary = {}
var seen_world_region := ""
var flags: Dictionary = {}
var gathered: Dictionary = {}
var fish_caught := 0
var message := "欢迎回到禾溪村。收获成熟的青菜，再试着播下一批。":
	set(value):
		message = value
		if not _suppress_message_notifications:message_requested.emit(value)
var _suppress_message_notifications:=false
var _writing_save := false
var _recovered_save_path := ""
var _autosave_queued := false
var _movement_autosave_timer: Timer
var _bedtime_prompted := false
var _source_update_tick := 0.0
var _keyboard_was_hidden := false
const SOURCE_GAMEPAD := preload("res://scripts/source_gamepad.gd")
var source_gamepad:RefCounted=SOURCE_GAMEPAD.new()
signal input_mode_changed(mode: String)
var source_input_mode:String="keyboard"
func set_source_input_mode(mode:String) -> void:
	if mode not in ["keyboard","pad","touch"] or mode==source_input_mode:return
	source_input_mode=mode
	input_mode_changed.emit(mode)
func interaction_input_label() -> String:
	if preload("res://scripts/performance_policy.gd").touch_device(): return "点按"
	if source_input_mode=="pad":return "A"
	if source_input_mode=="touch":return "点按"
	return str(player_settings.get("bindings",{}).get("interact","e")).to_upper()
func cancel_input_label() -> String:
	if preload("res://scripts/performance_policy.gd").touch_device(): return "点按"
	return "B" if source_input_mode=="pad" else "点按" if source_input_mode=="touch" else "Esc"
func target_cycle_input_label() -> String:
	return "L3" if source_input_mode=="pad" else "点按" if source_input_mode=="touch" else "[ / ]"

const SOURCE_KEYBOARD := preload("res://scripts/source_keyboard.gd")
var source_keyboard: RefCounted = SOURCE_KEYBOARD.new()
var _feedback_snapshot: Dictionary = {}
var feedback_action_runtime: Dictionary = {"floats": [], "clock": 0.0, "serial": 0}
var _feedback_state_generation := 0
var _feedback_poll_at:=0.0
var _feedback_poll_added:Array=[]
const ACTION_RULES := preload("res://scripts/action_rules.gd")
const ACTION_SEQUENCE := preload("res://scripts/action_sequence.gd")
var action_sequence: RefCounted = ACTION_SEQUENCE.new()
var npc_task: Dictionary = {}
var npc_task_serial := 0
var museum_task: Dictionary = {}
var museum_task_serial := 0
var scene_fade_remaining := 0.0
var action_room := ""
var action_sound_fired := false
var action_commit_in_progress := false
var action_commit_kind := ""


func _ready() -> void:
	changed.connect(_refresh_quests)
	_load_content()
	if not load_game():
		_load_initial_state()
		inventory = _new_inventory()
		storage = initial_state.get("storage", {}).duplicate(true)
		storage_quality = initial_state.get("storageQuality", {}).duplicate(true)
		building = _building_default()
		_reset_plots()
		_reset_animals()
		_merge_legacy_animal_care()
	if neighbors.is_empty():
		_normalize_neighbors()
	ensure_neighbor_events()
	_museum_sync()
	player_moved.connect(museum_record_region)
	_movement_autosave_timer = Timer.new()
	_movement_autosave_timer.one_shot = true
	_movement_autosave_timer.wait_time = 1.0
	_movement_autosave_timer.timeout.connect(func(): save_game(SAVE_PATH,true))
	add_child(_movement_autosave_timer)
	player_moved.connect(_schedule_position_autosave)
	interior_moved.connect(_schedule_position_autosave)
	museum_record_region(player_position)
	_remember_weather()
	_feedback_snapshot = _feedback_snapshot_state()
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = 0.25
	_autosave_timer.timeout.connect(_flush_autosave)
	add_child(_autosave_timer)
	changed.connect(func(): state_changes.publish(self))
	changed.connect(_queue_autosave)
	changed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	if event is not InputEventKey:return
	# The original document keydown listener runs even when a panel captures it.
	if event.pressed:set_source_input_mode("keyboard")
	var hud:Variant=null
	var players:=get_tree().get_nodes_in_group("player")
	if not players.is_empty():hud=players[0].get_parent().get("hud")
	# Capture-phase fishing Space precedes even settings binding capture.
	if event.pressed and hud!=null and (fishing_active() and event.keycode==KEY_SPACE or bool(hud.call("settings_capture_active"))):
		hud.call("handle_source_key",event)
		return
	var focus:Control=get_viewport().gui_get_focus_owner()
	var typing:=focus is LineEdit or focus is TextEdit or focus is OptionButton
	if source_keyboard.accept(event,player_settings.get("bindings",{}),ui_open or action_busy() or simulation_hidden(),typing):
		_interrupt_navigation_for_ui()
		get_viewport().set_input_as_handled()
	if hud!=null:hud.call("handle_source_key",event)


var fishing_focus_paused: bool=false
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		fishing_focus_paused=true
		if fishing_active():fishing_input("clear")
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:fishing_focus_paused=false
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready() and not content.is_empty(): save_game(SAVE_PATH,true)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED] and source_keyboard!=null:
		source_keyboard.clear()

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	advance_simulation_frame(delta, players[0] if not players.is_empty() else null)
	_poll_feedback_frame(Time.get_ticks_usec()/1000000.0,simulation_hidden())

func _poll_feedback_frame(at:float,hidden:bool)->bool:
	if at<=_feedback_poll_at or hidden:return false
	_feedback_poll_at=at+4.0
	if _feedback_poll(false):
		save_game(SAVE_PATH,true)
		changed.emit()
		_present_polled_feedback()
	return true

# Keep the original app frame order: world, movement/time, then action commit.
# An arrival may start an action or open UI; the admitted frame still earns time.
func advance_simulation_frame(frame_delta: float, actor: Node=null, at: float=-1.0) -> void:
	var wall_time:float=float(Time.get_ticks_usec())/1000000.0 if at < 0.0 else at
	poll_source_gamepad(wall_time*1000.0,actor)
	source_frame_time=wall_time
	var delta := clampf(frame_delta, 0.0, 0.05)
	var hidden := simulation_hidden()
	if hidden != _keyboard_was_hidden:
		source_keyboard.clear()
		_keyboard_was_hidden=hidden
	if not ui_open and not hidden:
		advance_ranch_movement(delta)
		advance_npc_movement(delta)
		atlas_visit()
	var admitted := not ui_open and not hidden and not action_busy()
	if is_instance_valid(actor):
		if admitted:
			actor.call("advance_player_frame", delta)
			_advance_frame_time(delta)
		else:
			actor.call("pause_player_frame")
	_process_action(delta)
	_advance_scene_fade(delta)

func poll_source_gamepad(now:float,actor:Node=null,sample:Dictionary={})->Array[Dictionary]:
	var hud:Variant=null
	if is_instance_valid(actor):hud=actor.get_parent().get("hud")
	if hud==null:
		var players:=get_tree().get_nodes_in_group("player")
		if not players.is_empty():hud=players[0].get_parent().get("hud")
	var focus_kind:String=str(hud.call("gamepad_focus_kind")) if hud!=null else "none"
	var input_sample:Dictionary=source_gamepad.sample_native() if sample.is_empty() else sample
	if fishing_active() and bool(player_settings.get("gamepad",true)) and not ui_open and not simulation_hidden():
		var buttons: Array=input_sample.get("buttons",[])
		var down: bool=bool(input_sample.get("connected",false)) and not buttons.is_empty() and bool(buttons[0])
		var previous: bool=bool(fishing_session.game.get("padDown",false))
		if down!=previous:fishing_input("press" if down else "release")
		fishing_session.game.padDown=down
		if buttons.size()>1 and source_gamepad.edge(buttons,1):cancel_player_action()
		elif buttons.size()>9 and source_gamepad.edge(buttons,9) and hud!=null:hud.show_settings()
		source_gamepad.previous=buttons.duplicate()
		return []
	var commands:Array[Dictionary]=source_gamepad.poll(input_sample,bool(player_settings.get("gamepad",true)),simulation_hidden(),action_busy(),ui_open,now,focus_kind)
	if source_gamepad.used:set_source_input_mode("pad")
	for command in commands:
		if command.kind=="interrupt":_interrupt_navigation_for_ui()
		elif command.kind=="cancel":cancel_player_action()
		elif hud!=null:hud.call("apply_source_gamepad",command)
	return commands

func _interrupt_navigation_for_ui() -> void:
	fishing["queue"]=[]
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	building_task.clear()
	museum_task.clear()
	npc_task.clear()
	walking_target.clear()
	for actor in get_tree().get_nodes_in_group("player"):
		actor.walk_path.clear()
		actor.walk_source_path.clear()
		actor.walk_index = 0
		actor.walk_is_exit = false

func _queue_navigation_idle(actor: Node) -> bool:
	return walking_target.is_empty() and actor.walk_source_path.is_empty() and (actor.walk_path.is_empty() or actor.walk_index >= actor.walk_path.size())

# This is the start of the original move(dt), using wall-clock frame deadlines.
# A due task may only start from an admitted movement frame and an idle route.
func advance_navigation_queues(actor: Node) -> void:
	if ui_open or action_busy() or simulation_hidden():return
	if not fishing.get("queue",[]).is_empty() and _queue_navigation_idle(actor):
		preload("res://scripts/fishing_service.gd").advance_queue(self,actor)
		return
	if not building_task.is_empty() and _queue_navigation_idle(actor):advance_building_task()
	if not kitchen_task.is_empty() and _queue_navigation_idle(actor):advance_kitchen_task()
	if (not ranch_queue.is_empty() or not ranch_active_task.is_empty()) and _queue_navigation_idle(actor) and source_frame_time >= ranch_next_at:advance_ranch_task()
	if (not farm_queue.is_empty() or not farm_active_task.is_empty()) and _queue_navigation_idle(actor) and (not farm_active_task.is_empty() or source_frame_time >= farm_next_at):advance_farm_task()

func _load_content() -> void:
	if not FileAccess.file_exists(CONTENT_PATH):
		push_error("Godot 内容目录不存在：" + CONTENT_PATH)
		return
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取 Godot 内容目录。")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Godot 内容目录格式无效。")
		return
	content = parsed
	crop_catalog = content.get("crops", {})
	item_catalog = content.get("items", {})
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_METADATA_PATH))
	if metadata is Dictionary: inventory_metadata = metadata
	npc_catalog = content.get("npcs", [])
	var initial_file := FileAccess.open(INITIAL_STATE_PATH, FileAccess.READ)
	if initial_file != null:
		var initial_parsed: Variant = JSON.parse_string(initial_file.get_as_text())
		if initial_parsed is Dictionary:
			initial_state = initial_parsed
	var systems_file := FileAccess.open(SYSTEMS_PATH, FileAccess.READ)
	if systems_file != null:
		var systems_parsed: Variant = JSON.parse_string(systems_file.get_as_text())
		if systems_parsed is Dictionary:
			system_catalog = systems_parsed
			for entry in system_catalog.get("museum", {}).get("entries", []):
				museum_entries[str(entry.get("key", ""))] = entry
	var world_file := FileAccess.open(WORLD_DATA_PATH, FileAccess.READ)
	if world_file != null:
		var world_parsed: Variant = load("res://scripts/save_json.gd").decode(JSON.parse_string(world_file.get_as_text()))
		if world_parsed is Dictionary:
			world_village = world_parsed.get("world", world_parsed).get("village", {})
			world_village["navigation_collisions"] = world_parsed.get("world", world_parsed).get("tiles", {}).get("collisions", [])
	var atlas_file := FileAccess.open("res://data/atlas_catalog.json", FileAccess.READ)
	if atlas_file != null:
		var atlas_parsed: Variant = load("res://scripts/save_json.gd").decode(JSON.parse_string(atlas_file.get_as_text()))
		if atlas_parsed is Dictionary: atlas_catalog = atlas_parsed
	atlas_navigation = VILLAGE_NAVIGATION_SCRIPT.new(world_village)

func _load_initial_state() -> void:
	quest_action.clear();quest_action_serial+=1
	quests = initial_state.get("quests",QUESTS.defaults()).duplicate(true)
	player_name = str(initial_state.get("name", "小满"))
	player_gender = str(initial_state.get("gender", "不设定"))
	player_settings = initial_state.get("settings", {}).duplicate(true)
	_normalize_player_settings()
	visual_fx = _normalize_visual_fx(initial_state.get("visualFx", {}), initial_state.get("feedback", {}), initial_state.get("settings", {}))
	ui_art = _normalize_ui_art(initial_state.get("uiArt", {}))
	appearance = _normalize_appearance(initial_state.get("appearance", {}))
	feedback = _normalize_feedback(initial_state.get("feedback", {}))
	feedback.prefs.motion = str(visual_fx.motion)
	player_stats = initial_state.get("stats", {}).duplicate(true)
	legacy_systems = _normalize_legacy_systems(initial_state)
	player_journal.clear()
	interior_state = {"memories": {}, "chores": {}}
	riding = false
	letters.clear()
	mail_read.clear()
	for letter in initial_state.get("letters", []):
		if letter is Dictionary: letters.append(letter.duplicate(true))
	for letter_id in initial_state.get("mailRead", []):
		if str(letter_id) != "" and not mail_read.has(str(letter_id)): mail_read.append(str(letter_id))
	for entry in initial_state.get("journal", []):
		if entry is Dictionary: player_journal.append(entry.duplicate(true))
	day = int(initial_state.get("day", 0))
	minutes = float(initial_state.get("minutes", 390))
	stamina = float(initial_state.get("stamina", 100))
	money = int(initial_state.get("money", 180))
	selected_seed = str(initial_state.get("seed", "cabbage"))
	var player_data: Dictionary = initial_state.get("player", {})
	player_source_position={"x":float(player_data.get("x",2831)),"y":float(player_data.get("y",1652))}
	player_direction = str(player_data.get("direction", "down")) if str(player_data.get("direction", "down")) in ["up", "down", "left", "right"] else "down"
	relations = initial_state.get("relations", {}).duplicate(true)
	flags = initial_state.get("flags", {}).duplicate(true)
	_normalize_community_projects(initial_state.get("projects", {}))
	legacy_chapters = initial_state.get("chapters", {}).duplicate(true) if initial_state.get("chapters", {}) is Dictionary else {}
	year_plans = initial_state.get("yearPlans", {}).duplicate(true) if initial_state.get("yearPlans", {}) is Dictionary else {}
	_normalize_achievements(initial_state.get("achievements", []))
	_normalize_onboarding(true)
	upgrades = initial_state.get("upgrades", {}).duplicate(true)
	economy = initial_state.get("economy", {}).duplicate(true)
	environment = initial_state.get("environment", {"version": 1, "history": []}).duplicate(true)
	forage = initial_state.get("forage", {"version": 1, "mode": "gentle", "xp": 0, "patches": {}, "discovered": [], "finds": []}).duplicate(true)
	fishing = initial_state.get("fishing", {"version": 1, "mode": "relaxed", "bait": "plain", "release": false, "waters": {}, "records": {}, "last": null}).duplicate(true)
	kitchen = initial_state.get("kitchen", {"version": 1, "jobs": [], "nextId": 1, "equipment": {}, "lots": {"bag": {}, "storage": {}}, "cold": false, "mastery": {}, "experiments": [], "buff": null}).duplicate(true)
	legacy_processing = _normalize_legacy_processing(initial_state.get("processing", []))
	toolkit = initial_state.get("toolkit", {"version": 1, "tools": {}, "stock": [], "selected": "hoe", "overlay": true}).duplicate(true)
	_normalize_skills(initial_state.get("skills", {}))
	farm = initial_state.get("farm", {}).duplicate(true)
	_normalize_farm()
	_normalize_building(initial_state.get("building", {}))
	known_recipes.clear()
	for recipe_id in initial_state.get("knownRecipes", []):
		known_recipes.append(str(recipe_id))
	last_gifts = {}
	_museum_normalize(initial_state.get("collection", _museum_default()))
	_import_legacy_discoveries()
	_atlas_normalize(initial_state.get("atlas"))
	archives.clear()
	for archive_id in initial_state.get("archives", ["key"]):
		archives.append(str(archive_id))
	furniture = initial_state.get("furniture", {}).duplicate(true)
	pet_state = initial_state.get("pet", {"type": "cat", "name": "小团", "bond": 0, "patted": -1}).duplicate(true)
	festivals.clear()
	for festival_key in initial_state.get("festivals", []): festivals.append(str(festival_key))
	season_events = initial_state.get("seasonEvents", {}).duplicate(true)
	_normalize_npc_social()
	_merge_legacy_animal_care()
	_migrate_legacy_layouts(initial_state.get("layouts", []))

	_normalize_npc_residents(initial_state.get("village", {}).get("npc", {}))

func _normalize_legacy_systems(raw: Variant) -> Dictionary:
	var source: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var archive: Variant = source.get("legacy_archive", {})
	if archive is Dictionary:
		for key in ["toolUpgrades", "buffs", "layouts", "waterReserve", "greenhouse", "freeRange", "animalCare", "resourcePressure", "marketDays", "eventLog", "discovered"]:
			if not source.has(key) and archive.has(key): source[key] = archive[key]
	var legacy: Dictionary = source.get("legacy_systems", {}).duplicate(true) if source.get("legacy_systems", {}) is Dictionary else {}
	var tool_upgrades_raw: Variant = legacy.get("toolUpgrades", source.get("toolUpgrades", source.get("tool_upgrades", {})))
	var tool_upgrades: Dictionary = tool_upgrades_raw if tool_upgrades_raw is Dictionary else {}
	var clean_tools: Dictionary = {}
	for tool_id in LEGACY_TOOL_UPGRADES:
		clean_tools[tool_id] = bool(tool_upgrades.get(tool_id, false))
	var raw_buffs: Variant = legacy.get("buffs", source.get("buffs", {}))
	var buffs: Dictionary = raw_buffs if raw_buffs is Dictionary else {}
	var labor_day := int(buffs.get("laborDay", buffs.get("labor_day", -1)))
	var raw_layouts: Variant = legacy.get("layouts", source.get("layouts", []))
	var layouts: Array = []
	var used_slots: Dictionary = {}
	if raw_layouts is Array:
		for entry in raw_layouts:
			if not entry is Dictionary or layouts.size() >= 24: continue
			var furniture_id := str(entry.get("id", entry.get("type", "")))
			var slot := int(entry.get("slot", -1))
			if not content.get("furniture", {}).has(furniture_id) or slot < 0 or slot >= 24 or used_slots.has(slot): continue
			used_slots[slot] = true
			layouts.append({"id": furniture_id, "slot": slot})
	var raw_pressure: Variant = legacy.get("resourcePressure", source.get("resourcePressure", source.get("resource_pressure", {})))
	var resource_pressure: Dictionary = {}
	if raw_pressure is Dictionary:
		for region_id in raw_pressure:
			var entry: Variant = raw_pressure[region_id]
			if entry is Dictionary:
				resource_pressure[str(region_id)] = {"day": maxi(0, int(entry.get("day", 0))), "count": clampi(int(entry.get("count", 0)), 0, 99)}
	var raw_animal_care: Variant = legacy.get("animalCare", source.get("animalCare", source.get("animal_care", {})))
	var animal_care: Dictionary = {}
	if raw_animal_care is Dictionary:
		for care_key in raw_animal_care:
			var parts := str(care_key).split("-")
			if parts.size() == 2 and parts[0] in ["hen", "duck", "cow"] and parts[1] in ["pet", "clean"]:
				animal_care[str(care_key)] = clampi(int(raw_animal_care[care_key]), 0, int(source.get("day", day)))
	var raw_log: Variant = legacy.get("eventLog", source.get("eventLog", source.get("event_log", [])))
	var event_log: Array = []
	if raw_log is Array:
		for entry in raw_log:
			if entry is Dictionary and event_log.size() < 200 and str(entry.get("text", "")) != "":
				event_log.append({"day": clampi(int(entry.get("day", 0)), 0, int(source.get("day", day))), "text": str(entry.get("text", "")).left(600)})
	var raw_market_days: Variant = legacy.get("marketDays", source.get("marketDays", source.get("market_days", [])))
	var raw_discovered: Variant = legacy.get("discovered", source.get("discovered", null))
	if raw_discovered == null:
		var old_bag: Variant = source.get("bag", {})
		raw_discovered = old_bag.keys() if old_bag is Dictionary else []
	return {
		"toolUpgrades": clean_tools,
		"buffs": {"laborDay": clampi(labor_day, -1, int(source.get("day", day)))},
		"waterReserve": clampi(int(legacy.get("waterReserve", source.get("waterReserve", source.get("water_reserve", 0)))), 0, 3),
		"greenhouse": bool(legacy.get("greenhouse", source.get("greenhouse", false))),
		"freeRange": bool(legacy.get("freeRange", source.get("freeRange", source.get("free_range", true)))),
		"discovered": _normalize_legacy_discoveries(raw_discovered),
		"animalCare": animal_care,
		"resourcePressure": resource_pressure,
		"marketDays": raw_market_days.slice(0, 1000).duplicate(true) if raw_market_days is Array else [],
		"eventLog": event_log,
		"layouts": layouts,
		"layoutMigrationComplete": bool(legacy.get("layoutMigrationComplete", false))
	}

func _normalize_legacy_processing(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw is Array:
		return result
	for entry in raw:
		if not entry is Dictionary or result.size() >= 400: continue
		var item_id := str(entry.get("id", ""))
		var quantity := int(entry.get("qty", 0))
		var ready_day := int(entry.get("readyDay", entry.get("ready_day", -1)))
		var station := str(entry.get("station", ""))
		if station == "" and item_id == "pickles": station = "腌菜坛"
		if not item_catalog.has(item_id) or quantity < 1 or quantity > 400 or ready_day < day or ready_day > day + 3:
			continue
		if station not in ["晾晒架", "腌菜坛", "堆肥箱"]: continue
		var cooking: Variant = entry.get("cooking", true)
		if not cooking is bool: cooking = true
		var job := {"id": item_id, "qty": quantity, "readyDay": ready_day, "station": station, "cooking": cooking}
		if entry.has("farmGrade") or entry.has("farm_grade"):
			var grade := int(entry.get("farmGrade", entry.get("farm_grade", 0)))
			if grade < 1 or grade > 3: continue
			job["farmGrade"] = grade
		result.append(job)
	return result

func _normalize_legacy_discoveries(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for item_id in raw:
			var key := str(item_id)
			if key == "cabbage_seed": key = "cabbageSeed"
			elif key == "radish_seed": key = "radishSeed"
			if item_catalog.has(key) and not result.has(key) and result.size() < 250:
				result.append(key)
	return result

func _import_legacy_discoveries() -> void:
	for item_id in legacy_systems.get("discovered", []):
		_museum_record("item:" + str(item_id), true, false, true)

func _merge_legacy_animal_care() -> void:
	for animal in animals:
		var type_id := str(animal.get("type", animal.get("id", "")))
		var care: Dictionary = animal.get("care", {})
		for action in ["pet", "clean"]:
			var key := "%s-%s" % [type_id, action]
			if legacy_systems.get("animalCare", {}).has(key):
				care[action] = maxi(int(care.get(action, -1)), int(legacy_systems.animalCare[key]))
		animal.care = care

func _migrate_legacy_layouts(raw_layouts: Variant) -> void:
	if bool(legacy_systems.get("layoutMigrationComplete", false)) or not raw_layouts is Array or raw_layouts.is_empty():
		return
	var remaining: Array = legacy_systems.get("layouts", []).duplicate(true)
	var zones: Dictionary = system_catalog.get("building", {}).get("zones", {})
	var court: Dictionary = zones.get("court", {})
	if court.is_empty() or not bool(upgrades.get("yard", false)):
		return
	var cols := int(court.get("cols", 8))
	var rows := int(court.get("rows", 5))
	var defs: Dictionary = system_catalog.get("building", {}).get("defs", {})
	var cells: Array[int] = []
	for row in range(maxi(0, rows - 1)):
		for col in [0, 1, 2, 4, 5, 6, 7]:
			if col < cols: cells.append(row * cols + col)
	var pending: Array = []
	for entry in remaining:
		pending.append(entry)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.slot) < int(b.slot))
	var still_legacy: Array = []
	for entry in pending:
		var type_id := str(entry.get("id", ""))
		var definition: Dictionary = defs.get(type_id, {})
		var placed := false
		if not definition.is_empty():
			for cell in cells:
				var piece := {"key": int(building.get("nextId", 1)), "type": type_id, "zone": "court", "cell": cell, "rotation": 0}
				var placement := building_placement_valid(piece, building.get("layout", []))
				if bool(placement.get("ok", false)):
					building.layout.append(piece)
					building.nextId = int(building.nextId) + 1
					cells.erase(cell)
					furniture[type_id] = maxi(0, int(furniture.get(type_id, 0)) - 1)
					placed = true
					break
		if not placed:
			still_legacy.append(entry)
	legacy_systems.layouts = still_legacy
	legacy_systems.layoutMigrationComplete = true
	if not still_legacy.is_empty():
		legacy_systems.greenhouse = still_legacy.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == "greenhouse")
	building.revision = int(building.get("revision", 0)) + 1

func weather_profile(target_day: int = -1) -> Dictionary:
	var events: Array = system_catalog.get("environment", {}).get("events", [])
	return ENVIRONMENT_RULES.profile(day if target_day < 0 else target_day, minutes, events)

func _normalize_onboarding(show_for_new_game: bool) -> void:
	var raw: Variant = flags.get(ONBOARDING_FLAG, {})
	var state: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var raw_done: Variant = state.get("done", {})
	var done: Dictionary = raw_done.duplicate(true) if raw_done is Dictionary else {}
	for step in ONBOARDING_STEPS:
		done[step] = bool(done.get(step, false))
	state["version"] = 1
	state["done"] = done
	state["hidden"] = bool(state.get("hidden", not show_for_new_game))
	flags[ONBOARDING_FLAG] = state

func onboarding_state() -> Dictionary:
	_normalize_onboarding(false)
	return (flags[ONBOARDING_FLAG] as Dictionary).duplicate(true)

func onboarding_mark(step: String) -> void:
	if not ONBOARDING_STEPS.has(step):
		return
	_normalize_onboarding(false)
	var state: Dictionary = flags[ONBOARDING_FLAG]
	var done: Dictionary = state["done"]
	if bool(done.get(step, false)):
		return
	done[step] = true
	state["done"] = done
	flags[ONBOARDING_FLAG] = state
	if ONBOARDING_STEPS.all(func(step_id: String) -> bool: return bool(done.get(step_id, false))):
		message = "新手手记完成了。禾溪的日子，现在由你自己安排。"
	changed.emit()

func onboarding_show() -> void:
	_normalize_onboarding(false)
	var state: Dictionary = flags[ONBOARDING_FLAG]
	state["hidden"] = false
	flags[ONBOARDING_FLAG] = state
	changed.emit()

func onboarding_hide() -> void:
	_normalize_onboarding(false)
	var state: Dictionary = flags[ONBOARDING_FLAG]
	state["hidden"] = true
	flags[ONBOARDING_FLAG] = state
	changed.emit()

func weather_forecast(count: int = 4) -> Array[Dictionary]:
	var events: Array = system_catalog.get("environment", {}).get("events", [])
	return ENVIRONMENT_RULES.forecast(day, minutes, events, count)

func weather_warning() -> String:
	var events: Array = system_catalog.get("environment", {}).get("events", [])
	return ENVIRONMENT_RULES.warning(day, events)

func action_busy() -> bool:
	return not action_sequence.active.is_empty()

func action_snapshot() -> Dictionary:
	return action_sequence.snapshot()

func _begin_task_action(target: Dictionary,finish: Callable) -> bool:
	var spec := ACTION_RULES.point(target)
	if spec.is_empty():return false
	var resolved := target.duplicate(true)
	resolved["_sequence_resolved"] = true
	return begin_action(spec,target,finish.bind(resolved))

func begin_point_action(target: Dictionary,commit: Callable) -> bool:
	# Fishing owns a distinct begin/finish flow and is integrated separately.
	if str(target.get("kind",""))=="fish":return false
	var spec:=ACTION_RULES.point(target,selected_tool)
	if spec.is_empty():return false
	return begin_action(spec,target,commit)

func begin_action(spec: Dictionary,target: Dictionary,commit: Callable,cancel: Callable=Callable()) -> bool:
	if action_busy():return false
	var running := spec.duplicate(true)
	running.duration = ACTION_RULES.duration(running,str(feedback.get("prefs",{}).get("pace","normal")))
	running.x = float(target.get("x",player_position.x))
	running.y = float(target.get("y",player_position.y))
	running.targetKind = str(target.get("kind",""))
	if target.has("npcId"):running.npcId=target.npcId
	if target.has("animalId"):
		running.animalId=target.animalId
		var index:=ranch_animal_index(str(target.animalId))
		if index>=0:
			running.animalType=str(animals[index].get("type",""))
			running.item=str(animals[index].get("product",""))
	elif str(target.get("kind",""))=="farm-task":
		var index:=int(target.get("index",-1))
		if index>=0 and index<plots.size():running.item=plots[index].get("crop",null)

	action_room = current_interior
	action_sound_fired = false
	var feedback_before := feedback_action_snapshot(target)
	if not action_sequence.start(running,_commit_action.bind(commit,str(running.kind),bool(running.get("door",false)),feedback_before,target.duplicate(true),spec.duplicate(true),_feedback_state_generation,action_room,cancel),cancel):return false
	source_keyboard.clear()
	_clear_action_effects()
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var direction: Vector2 = Vector2(float(running.x),float(running.y))-players[0].global_position
		if direction.length()>1.0:
			set_player_direction_from_vector(direction)
			players[0].facing = direction
	_sync_action_visual()
	action_sequence_changed.emit(action_snapshot())
	return true

func _commit_action(commit: Callable,kind: String,door: bool=false,before: Dictionary={},point: Dictionary={},spec: Dictionary={},generation: int=-1,room: String="",cancel: Callable=Callable()) -> void:
	if generation != _feedback_state_generation or current_interior != room:
		if cancel.is_valid():cancel.call()
		return
	_sync_action_visual()
	action_sequence_changed.emit({})
	action_commit_in_progress = true
	action_commit_kind = kind
	if commit.is_valid():commit.call()
	action_commit_in_progress = false
	action_commit_kind = ""
	if generation == _feedback_state_generation and not before.is_empty():
		var result: Variant = finish_action_feedback(before,point,spec)
		if result != null:
			save_game(SAVE_PATH,true)
			changed.emit()
			if int(result.row.priority)>0:
				presenting_action_delta = true
				feedback_toast_requested.emit(str(result.row.text),int(result.row.priority))
				presenting_action_delta = false
	if door:
		scene_fade_remaining=0.3
		scene_fade_changed.emit(action_darkness())

func cancel_action(invoke_callback: bool=true) -> bool:
	quest_action.clear()
	var cancelled:bool=action_sequence.cancel(invoke_callback)
	if cancelled:
		source_keyboard.clear()
		_clear_action_effects()
		_sync_action_visual()
		action_sequence_changed.emit({})
	return cancelled

# The source cancelAction is a player command; internal load/queue cancellation
# keeps using cancel_action so it does not create user feedback or autosaves.
func cancel_player_action() -> bool:
	var fishing_paid: bool=fishing_active() and bool(fishing_session.game.get("paid",false))
	if not cancel_action():return false
	_interrupt_navigation_for_ui()
	_feedback_note({"key":"cancel/"+str(day),"title":"已停下手边动作","text":"落水时已使用的饵料、体力与时间保留消耗；没有新增鱼获。" if fishing_paid else "未完成的这一步没有结算；此前已经做完的部分保留。","type":"未完成","merge":true})
	message="已收竿；落水时使用的饵料、体力与时间保留消耗。" if fishing_paid else "已停下手边的动作，未结算这次操作。"
	changed.emit()
	_queue_autosave()
	return true

func action_darkness(snapshot: Variant=null,remaining: float=-1.0,motion: String="") -> float:
	if snapshot==null:snapshot=action_snapshot()
	var preference:=str(feedback.get("prefs",{}).get("motion","full")) if motion=="" else motion
	if preference=="reduced":return 0.0
	if bool(snapshot.get("door",false)):return maxf(0.0,(float(snapshot.get("progress",0.0))-0.6)/0.4)*0.7
	if str(snapshot.get("kind",""))=="sleep":return sin(float(snapshot.get("progress",0.0))*PI)*0.6
	return (scene_fade_remaining if remaining<0.0 else remaining)/0.3*0.7

func _advance_scene_fade(delta: float) -> void:
	if scene_fade_remaining<=0.0:return
	scene_fade_remaining=maxf(0.0,scene_fade_remaining-clampf(delta,0.0,0.1))
	scene_fade_changed.emit(action_darkness())

func _clear_action_effects() -> void:
	if not is_inside_tree():return
	for player in get_tree().get_nodes_in_group("player"):
		var effects:Node=player.get_parent().get_node_or_null("WorldEffects")
		if effects!=null and effects.has_method("clear_action_bursts"):effects.call("clear_action_bursts")

func _sync_action_visual() -> void:
	if not is_inside_tree():return
	var snapshot := action_snapshot()
	for player in get_tree().get_nodes_in_group("player"):
		var visual:Node=player.get("character_visual")
		if visual!=null and visual.has_method("set_sequence_snapshot"):visual.set_sequence_snapshot(snapshot)
	get_tree().call_group("resident_visual_actor", "sync_action_visual", snapshot)

func _process_action(delta: float) -> void:
	if not action_busy():return
	if current_interior!=action_room:
		stop_walking()
		return
	var paused := simulation_hidden()
	if not paused and not action_sound_fired and float(action_sequence.active.elapsed)+clampf(delta,0.0,0.1)>=float(action_sequence.active.spec.duration)*0.5:
		action_sound_fired=true
		sound_requested.emit(str(action_sequence.active.spec.kind))
	if fishing_active():
		fishing_session.tick(delta,paused or ui_open or fishing_focus_paused)
		var game: Dictionary=fishing_session.game
		if bool(game.get("landed",false)) and not bool(game.get("paid",false)):
			if not preload("res://scripts/fishing_service.gd").commit_cast(self,game):cancel_action();return
		if str(game.get("stage",""))=="bite" and not bool(game.get("biteSound",false)):
			game.biteSound=true;sound_requested.emit("fish")
		fishing_session_changed.emit(fishing_snapshot())
		if bool(game.get("caught",false)) or bool(game.get("missed",false)):
			action_sequence.active.elapsed=float(action_sequence.active.spec.duration)
		else:
			action_sequence.active.elapsed=minf(float(action_sequence.active.spec.duration)-0.2,float(game.time))
			_sync_action_visual();return
	action_sequence.tick(delta,paused)
	_sync_action_visual()
	action_sequence_changed.emit(action_snapshot())

func ground_conditions() -> Dictionary:
	var events: Array = system_catalog.get("environment", {}).get("events", [])
	return ENVIRONMENT_RULES.ground(day, events)

func stop_walking() -> void:
	fishing["queue"]=[]
	cancel_action()
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	building_task.clear()
	walking_target.clear()
	_set_message_silently("停下脚步，可以继续自己的安排。")
	changed.emit()

func toggle_bicycle() -> bool:
	if current_interior != "":
		message = "先走出小屋再骑车。"
		changed.emit()
		return false
	riding = not riding
	_set_message_silently("扶稳车把，沿村道骑行。" if riding else "下车慢慢走。")
	changed.emit()
	_queue_autosave()
	return true

func player_navigation_position() -> Dictionary:
	var point: Dictionary=(player_source_position if current_interior=="" else interior_source_position).duplicate()
	point.direction=player_direction
	return point

func set_player_navigation_position(point: Dictionary) -> void:
	var position: Dictionary={"x":float(point.x),"y":float(point.y)}
	if current_interior=="":player_source_position=position
	else:interior_source_position=position
	player_direction=str(point.get("direction",player_direction))

func player_movement_speed(fast_walk: bool = false) -> float:
	if riding and current_interior == "": return 355.0
	return 265.0 if fast_walk else 195.0

func player_environment_speed() -> float:
	if current_interior!="":return 1.0
	var ground: Dictionary=ground_conditions()
	return 0.92 if float(ground.snow)>0.0 else 0.95 if float(ground.wet)>0.0 else 1.0

func travel_speed_multiplier() -> float:
	return (1.12 if kitchen_active_buff()=="轻快" else 1.0)*player_environment_speed()

func player_movement_rate(fast_walk: bool = false) -> float:
	return player_movement_speed(fast_walk)*(1.12 if kitchen_active_buff()=="轻快" else 1.0)*player_environment_speed()

func _normalize_player_settings() -> void:
	player_settings = PROFILE.settings(player_settings,initial_state.get("settings",{}))

func _normalize_skills(source: Variant = null) -> void:
	var saved: Dictionary = source if source is Dictionary else {}
	var names: Dictionary = content.get("skillNames", {})
	var choices: Dictionary = content.get("skillChoices", {})
	var normalized: Dictionary = {}
	for skill_id in names:
		var row_value: Variant = saved.get(skill_id, {})
		var row: Dictionary = row_value if row_value is Dictionary else {}
		var options: Array = choices.get(skill_id, [])
		var selected: Variant = row.get("choice", null)
		var valid_choice := selected == null
		for option in options:
			if option is Array and not option.is_empty() and selected == option[0]:
				valid_choice = true
				break
		normalized[str(skill_id)] = {
			"xp": clampi(int(row.get("xp", 0)), 0, 99999),
			"choice": selected if valid_choice else null
		}
	skills = normalized

func _normalize_community_projects(source: Variant = null) -> void:
	var saved: Dictionary = source if source is Dictionary else {}
	var normalized: Dictionary = {}
	for project_id in content.get("projects", {}):
		normalized[str(project_id)] = bool(saved.get(project_id, false))
	if bool(flags.get("bridge", false)):
		normalized.bridge = true
	community_projects = normalized

func _normalize_achievements(source: Variant = null) -> void:
	var saved: Array = source if source is Array else []
	var valid: Array[String] = []
	for candidate in content.get("achievements", []):
		var achievement_id := str(candidate.get("id", ""))
		if saved.has(achievement_id) and not valid.has(achievement_id):
			valid.append(achievement_id)
	achievements = valid

func _award_skill_xp(skill_id: String, amount: int = 1) -> void:
	if not skills.has(skill_id) or amount <= 0:
		return
	var row: Dictionary = skills[skill_id]
	row.xp = mini(99999, int(row.get("xp", 0)) + amount)
	skills[skill_id] = row

func choose_skill(skill_id: String, choice_id: String) -> bool:
	var options: Array = content.get("skillChoices", {}).get(skill_id, [])
	var skill: Dictionary = skills.get(skill_id, {})
	var valid_choice := false
	for option in options:
		if option is Array and option.size() >= 2 and str(option[0]) == choice_id:
			valid_choice = true
			break
	if not valid_choice or skill.is_empty():
		message = "熟练度达到 25 后可以选一种做事风格。"
	elif int(skill.get("xp", 0)) < 25:
		message = "熟练度达到 25 后可以选一种做事风格。"
	elif skill.get("choice", null) != null:
		message = "已经有自己的做事风格啦。"
	else:
		skill.choice = choice_id
		skills[skill_id] = skill
		message = "记下了你的选择，基础操作始终都能使用。"
		changed.emit()
		return true
	changed.emit()
	return false

func _record_legacy_event(text: String) -> void:
	var record := {"day": day, "text": text.left(600)}
	player_journal.append(record)
	while player_journal.size() > 200:
		player_journal.pop_front()
	var event_log: Array = legacy_systems.get("eventLog", [])
	event_log.push_front(record.duplicate(true))
	while event_log.size() > 200:
		event_log.pop_back()
	legacy_systems.eventLog = event_log

func _grant_legacy_item(item_id: String, quantity: int) -> void:
	_reconcile_kitchen_lots()
	_add_inventory_count(item_id, quantity)
	if quantity > 0:
		var discovered: Array = legacy_systems.get("discovered", [])
		if not discovered.has(item_id): discovered.append(item_id)
		legacy_systems.discovered = discovered
	_reconcile_kitchen_lots()

func _record_community_log(text: String, track: bool = true) -> void:
	var record := {"day": day, "text": text}
	var rows := journal_entries()
	rows.push_front(record)
	if rows.size() > 60: rows.resize(60)
	player_journal.assign(rows)
	# The browser journal prepends. Preserve that same-day order after saving.
	legacy_archive.journal = rows.duplicate(true)
	if track:
		var events: Array = legacy_systems.get("eventLog", [])
		events.push_front(record.duplicate(true))
		if events.size() > 200: events.resize(200)
		legacy_systems.eventLog = events

func community_project_status(project_id: String) -> Dictionary:
	var project: Dictionary = content.get("projects", {}).get(project_id, {})
	if project.is_empty():
		return {"known": false, "done": false, "ready": false, "reason": "没有这个公共项目。"}
	var done := bool(community_projects.get(project_id, false)) or project_id == "bridge" and bool(flags.get("bridge", false))
	if done:
		return {"known": true, "done": true, "ready": false, "reason": "大家已经完成了这项修缮。"}
	if day < int(project.get("season", 0)) * 28:
		return {"known": true, "done": false, "ready": false, "reason": "%s季起大家准备动工，之后随时可以补做。" % str(content.get("seasons", ["春", "夏", "秋", "冬"])[int(project.get("season", 0))])}
	if project_id == "bridge" and not bool(flags.get("firstDish", false)):
		return {"known": true, "done": false, "ready": false, "reason": "先给林阿婆送一道家常菜。她会把你介绍给一起修河埠的乡亲。"}
	for item_id in project.get("needs", {}):
		var unavailable := int(inventory.get(str(item_id), 0)) < int(project.needs[item_id])
		if project_id != "bridge" and economy.get("locked", []).has(str(item_id)) and int(project.needs[item_id]) > 0: unavailable = true
		if unavailable:
			return {"known": true, "done": false, "ready": false, "reason": "还需要木料 ×8、竹材 ×6。木生叔负责手艺，乡亲们负责其他材料。" if project_id == "bridge" else "材料还没齐。你只需备自己的这一份，其他材料和手艺由乡亲们负责。"}
	return {"known": true, "done": false, "ready": true, "reason": "材料齐了，可以和乡亲们一起动工。"}

func repair_community_bridge() -> bool:
	for item_id in ["wood","bamboo"]:
		if economy.get("locked",[]).has(item_id):
			message = "需要的物品已锁定，请先在背包解除保护。"
			changed.emit()
			return false
	return complete_community_project("bridge")

func complete_community_project(project_id: String) -> bool:
	if not QUESTS.can_commit(self,"project",project_id):
		changed.emit();return false
	var status := community_project_status(project_id)
	if not bool(status.get("ready", false)):
		message = str(status.get("reason", "现在还不能动工。"))
		changed.emit()
		return false
	var project: Dictionary = content.projects[project_id]
	if project_id == "bridge": _reconcile_kitchen_lots()
	for item_id in project.get("needs", {}):
		QUESTS.consume(self,str(item_id),int(project.needs[item_id]))
	_reconcile_kitchen_lots()
	var npc_id := "chen" if project_id == "bridge" else str(project.get("npc", ""))
	var relation: Dictionary = relations[npc_id]
	relation.points = mini(100, int(relation.get("points", 0)) + 20)
	relations[npc_id] = relation
	if project_id == "bridge":
		flags.bridge = true
		_record_community_log("大家修好了河埠，岸边添了长椅和一张小茶桌。", false)
	community_projects[project_id] = true
	if project_id == "bridge" and not archives.has("photo"): archives.append("photo")
	var recipe_id := str(project.get("recipe", ""))
	if recipe_id != "" and not known_recipes.has(recipe_id) and not recipe_data(recipe_id).is_empty():
		known_recipes.append(recipe_id)
		_record_community_log("学会了 %s。" % str(item_catalog[recipe_id].get("name", recipe_id)))
	_award_skill_xp("craft", 12)
	if str(skills.get("craft", {}).get("choice", "")) == "cooperate": _grant_legacy_item("bamboo", 2)
	_record_community_log("共同完成%s。%s" % [str(project.name), str(project.change)])
	message = "%s完成。%s%s" % [str(project.name), str(project.people), str(project.change)]
	changed.emit()
	return true

func complete_neighbor_favor(favor_id: int) -> bool:
	if not QUESTS.can_commit(self,"favor",str(favor_id)):
		changed.emit();return false
	var favor: Dictionary = {}
	for candidate in content.get("favors", []):
		if int(candidate.get("id", -1)) == favor_id:
			favor = candidate
			break
	var event_key := "favor-%d" % favor_id
	if favor.is_empty() or bool(season_events.get(event_key, false)):
		message = "这份帮助已经记下了。"
		changed.emit()
		return false
	if favor_id == 2 and atlas_region_id(player_position) != "town":
		message = "先到集镇，再替许婶照看摊位。"
		changed.emit()
		return false
	for item_id in favor.get("needs", {}):
		if int(inventory.get(str(item_id), 0)) < int(favor.needs[item_id]) or economy.get("locked", []).has(str(item_id)) and int(favor.needs[item_id]) > 0:
			message = "还缺一点材料，可以备好后再来。"
			changed.emit()
			return false
	_reconcile_kitchen_lots()
	for item_id in favor.get("needs", {}): QUESTS.consume(self,str(item_id),int(favor.needs[item_id]))
	_reconcile_kitchen_lots()
	for item_id in favor.get("reward", {}): _grant_legacy_item(str(item_id), int(favor.reward[item_id]))
	var payout := int(favor.get("money", 0))
	money += payout
	player_stats.earned = int(player_stats.get("earned", 0)) + payout
	season_events[event_key] = true
	var npc_id := str(favor.npc)
	var relation: Dictionary = relations[npc_id]
	relation.points = mini(100, int(relation.get("points", 0)) + 8)
	relations[npc_id] = relation
	if favor_id == 2: minutes = minf(1320.0, minutes + 30)
	_award_skill_xp("social", 4)
	_record_community_log("帮邻居完成：%s。" % str(favor.title))
	message = "这点帮助派上用场了，收下回礼和 %d 元。" % payout
	changed.emit()
	return true

func attend_small_gathering(kind: String) -> bool:
	var required_region: String={"tea":"mountain","repair":"town","stage":"town","lost":"river"}.get(kind,"")
	if current_interior!="" or atlas_region_id(player_position)!=required_region:
		message="请先到这场聚会的实际区域，生活手记可以查看路线。";changed.emit();return false
	var event_key := "%s-%d" % [kind, int(day / 7)]
	if bool(season_events.get(event_key, false)):
		message = "这周已经留下了这段小聚，下周再来。"
		changed.emit()
		return false
	var residents := {"tea": "zhou", "repair": "song", "stage": "jiang", "lost": "lan"}
	var stories := {"tea": "围坐喝了一壶茶，聊到今天山路上的风。", "repair": "和宋伯整理了修理摊，也学会了更顺手地握工具。", "stage": "江桂珍唱起小调，你为身边的人轻轻打拍子。", "lost": "小岚在长椅边找到了画本，认真向帮忙的人道谢。"}
	if not residents.has(kind):
		message = "暂时没有这场小聚。"
		changed.emit()
		return false
	if kind == "stage" and not bool(community_projects.get("stage", false)):
		message = "先把旧戏台整理好。"
		changed.emit()
		return false
	season_events[event_key] = true
	var npc_id := str(residents[kind])
	var relation: Dictionary = relations[npc_id]
	relation.points = mini(100, int(relation.get("points", 0)) + 5 + (3 if str(skills.get("social", {}).get("choice", "")) == "together" else 0))
	relations[npc_id] = relation
	_award_skill_xp("social", 3)
	_record_community_log(str(stories[kind]))
	message = str(stories[kind])
	QUESTS.event(self,"gathering")
	changed.emit()
	return true

func record_legacy_chapter(season: int, choice: int) -> bool:
	var chapters: Array = content.get("seasonChapters", [])
	if season < 0 or season >= chapters.size() or choice not in [0, 1]:
		message = "请选择一个回应。"
		changed.emit()
		return false
	var key := "%d-%d" % [int(day / 112) + 1, season]
	if legacy_chapters.has(key):
		message = "这一页已经写好，可以在旧事回看中再次阅读。"
		changed.emit()
		return false
	if posmod(day, 112) < season * 28:
		message = "等这一季来到，故事自然会发生。"
		changed.emit()
		return false
	var chapter: Dictionary = chapters[season]
	QUESTS.complete_record(self,QUESTS.definition(self,"chapter:%d:%d" % [int(day/112)+1,season]))
	legacy_chapters[key] = choice
	_record_community_log("%s：%s" % [str(chapter.title), str(chapter.choices[choice])])
	message = "记下了你的选择。日子没有唯一的标准答案，生活目标都可以延后完成。"
	changed.emit()
	return true

func year_summary() -> Array[String]:
	var harvested := int(player_stats.get("harvested", 0))
	var cooked := int(player_stats.get("cooked", 0))
	var focus := "一方菜地慢慢熟悉了你的脚步" if harvested > cooked * 2 else "许多普通食材变成了与人分享的热饭" if cooked > 10 else "你给散步、相处和慢慢观察留下了时间"
	var repairs := 0
	var projects := 0
	var storytellers := 0
	for done in upgrades.values(): repairs += int(bool(done))
	for done in community_projects.values(): projects += int(bool(done))
	for person in npc_catalog:
		if int(npc_stories.get(str(person.id), {}).get("step", 0)) > 0: storytellers += 1
	var spouse := str(marriage.get("spouse", ""))
	if spouse == "<null>": spouse = ""
	return [
		focus + "。",
		"老院完成 %d 处修缮，乡亲共同完成 %d 项公共事务。" % [repairs, projects],
		"%d 位邻居把自己的故事讲给了你。" % storytellers,
		"和%s组成了家，也保留着各自的工作和朋友。" % npc_name(spouse) if spouse != "" else "有人陪你吃饭，也有独处的晚上；怎样生活都值得认真。",
		"爷爷的旧柜里收好 %d 件生活记录。未做完的事仍能延后，不按钱或全收集给日子评分。" % archives.size()
	]

func journal_entries() -> Array[Dictionary]:
	# Native events append; imported browser events originally prepend.
	# Keep the original order for same-day browser rows without losing newer events.
	var legacy_order: Dictionary = {}
	var legacy_rows: Variant = legacy_archive.get("journal", [])
	if legacy_rows is Array:
		for index in range(legacy_rows.size()):
			if not legacy_rows[index] is Dictionary: continue
			var row: Dictionary = legacy_rows[index]
			legacy_order["%d:%s" % [int(row.get("day", 0)), str(row.get("text", ""))]] = index
	var ordered: Array[Dictionary] = []
	for index in range(player_journal.size()):
		var row := player_journal[index]
		var key := "%d:%s" % [int(row.get("day", 0)), str(row.get("text", ""))]
		ordered.append({"row": row, "index": index, "legacy": int(legacy_order.get(key, -1))})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var day_a := int(a.row.get("day", 0))
		var day_b := int(b.row.get("day", 0))
		if day_a != day_b: return day_a > day_b
		if a.legacy >= 0 and b.legacy >= 0: return a.legacy < b.legacy
		if (a.legacy >= 0) != (b.legacy >= 0): return a.legacy < 0
		return a.index > b.index)
	var result: Array[Dictionary] = []
	for entry in ordered: result.append(entry.row.duplicate(true))
	return result

func record_year_plan(choice: int) -> bool:
	var choices := ["继续照看小院，也常与邻居来往", "把手艺和饭桌分享给更多人", "留一些出门看看的时间，也保留回家的路"]
	if choice not in [0, 1, 2]:
		message = "请选择自己的想法。"
		changed.emit()
		return false
	year_plans[str(int(day / 112))] = choice
	_record_community_log("来年的想法：%s" % str(choices[choice]))
	message = "来年的安排已经写好。可以继续种植、社交、装修，所有未完成故事仍会等你。"
	changed.emit()
	return true

func achievement_status(achievement_id: String) -> Dictionary:
	for achievement in content.get("achievements", []):
		if str(achievement.get("id", "")) == achievement_id:
			var stat_id := str(achievement.get("stat", ""))
			var current := int(player_stats.get(stat_id, 0))
			var target := int(achievement.get("target", 0))
			return {"known": true, "claimed": achievements.has(achievement_id), "current": current, "target": target, "ready": current >= target and not achievements.has(achievement_id)}
	return {"known": false, "claimed": false, "current": 0, "target": 0, "ready": false}

func claim_legacy_achievement(achievement_id: String) -> bool:
	var status := achievement_status(achievement_id)
	if not bool(status.get("ready", false)):
		message = "这页记录还没有完成，或纪念物已经领过。"
		changed.emit()
		return false
	for achievement in content.get("achievements", []):
		if str(achievement.get("id", "")) != achievement_id: continue
		var reward_id := str(achievement.get("reward", ""))
		if not content.get("furniture", {}).has(reward_id):
			message = "这件纪念陈设暂时无法领取。"
			changed.emit()
			return false
		achievements.append(achievement_id)
		furniture[reward_id] = int(furniture.get(reward_id, 0)) + 1
		message = "纪念物：%s。无需全收集，也能迎接年度结尾。" % str(content.furniture[reward_id].get("name", reward_id))
		changed.emit()
		return true
	return false

func _is_ranch_order(order_id: String) -> bool:
	return order_id in ["ranchMilk", "ranchWool", "ranchYogurt"]

func fulfill_legacy_order(order_id: String) -> bool:
	if not QUESTS.can_commit(self,"wish",order_id):
		changed.emit();return false
	var order: Dictionary = {}
	for candidate in content.get("orders", []):
		if str(candidate.get("id", "")) == order_id:
			order = candidate
			break
	for item_id in order.get("needs", {}):
		if economy.get("locked", []).has(str(item_id)):
			message = "需要的物品已锁定，请先在背包解除保护。"
			changed.emit()
			return false
	if _is_ranch_order(order_id) and ranch.get("delivered", []).has(order_id):
		message = "这份牧场心意已经送到了。"
		changed.emit()
		return false
	_reconcile_kitchen_lots()
	if order.is_empty() or bool(flags.get(order_id, false)):
		message = "这份心意已经送到了。"
		changed.emit()
		return false
	for item_id in order.get("needs", {}):
		if int(inventory.get(str(item_id), 0)) < int(order.needs[item_id]):
			message = "料理还没有备齐，慢慢来，没有期限。"
			changed.emit()
			return false
	for item_id in order.get("needs", {}): QUESTS.consume(self,str(item_id),int(order.needs[item_id]))
	_reconcile_kitchen_lots()
	for item_id in order.get("reward", {}): _grant_legacy_item(str(item_id), int(order.reward[item_id]))
	var payout := int(order.get("money", 0))
	money += payout
	player_stats.earned = int(player_stats.get("earned", 0)) + payout
	flags[order_id] = true
	if _is_ranch_order(order_id):
		var delivered: Array = ranch.get("delivered", [])
		delivered.append(order_id)
		ranch.delivered = delivered
	var npc_id := str(order.npc)
	var relation: Dictionary = relations[npc_id]
	relation.points = mini(100, int(relation.get("points", 0)) + 20)
	relations[npc_id] = relation
	_record_community_log("完成邻里心愿：%s。" % str(order.title), false)
	message = "心意送到了！收到 %d 元和一份回礼，邻里关系 +20。" % payout
	changed.emit()
	return true

func _normalize_visual_fx(source: Variant, legacy_feedback: Variant = {}, legacy_settings: Variant = {}) -> Dictionary:
	return PROFILE.visual_fx(source, legacy_feedback, legacy_settings)

func _normalize_ui_art(source: Variant) -> Dictionary:
	return PROFILE.ui_art(source)

func ui_art_set_preference(key: String, value: Variant) -> bool:
	if key == "theme" and str(value) in ["paper", "porcelain", "timber"]:
		ui_art.theme = str(value)
	elif key == "seasonal" and value is bool:
		ui_art.seasonal = value
	else:
		return false
	message = "界面手账已更新。"
	changed.emit()
	return true

func _normalize_appearance(source: Variant) -> Dictionary:
	return PROFILE.appearance(source)

func apply_player_appearance(form: Dictionary) -> bool:
	var next: Dictionary = {}
	for key in APPEARANCE_DEFAULT:
		if not form.has(key): return false
		next[key] = form[key]
	var normalized := _normalize_appearance(next)
	for key in next:
		if normalized[key] != next[key]: return false
	var raw_name := str(form.get("name", player_name))
	var clean_name := (raw_name if raw_name != "" else player_name).strip_edges().left(12)
	if clean_name == "": clean_name = player_name
	player_name = clean_name
	player_gender = str(form.get("gender", player_gender))
	appearance = normalized
	message = "换好了，还是熟悉的你。"
	changed.emit()
	return true

func appearance_set(key: String, value: Variant) -> bool:
	var next := appearance.duplicate(true)
	if key in ["shirt", "hair", "hairColor", "skin"] and (value is int or value is float):
		var limits := {"shirt": 3, "hair": 3, "hairColor": 3, "skin": 2}
		var choice := int(value)
		if choice < 0 or choice > int(limits[key]): return false
		next[key] = choice
	elif key == "outfit" and str(value) in ["field", "apron", "traveler", "festival"]:
		next.outfit = str(value)
	elif key in ["hat", "bag", "weatherDress"] and value is bool:
		next[key] = value
	else:
		return false
	appearance = next
	message = "换好了，还是熟悉的你。"
	changed.emit()
	return true

func _feedback_default() -> Dictionary:
	return PROFILE.feedback_default()

func _normalize_feedback(source: Variant) -> Dictionary:
	return PROFILE.feedback(source, day, item_catalog)

func _feedback_counts(inventory_side: Dictionary, quality_side: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	for id in inventory_side: ids[str(id)] = true
	for id in quality_side: ids[str(id)] = true
	var counts: Dictionary = {}
	for id in ids:
		var grades: Array = quality_side.get(id, [0, 0, 0])
		var quality_total := 0
		var normalized: Array[int] = [0, 0, 0, 0]
		for grade in range(mini(3, grades.size())):
			normalized[grade + 1] = maxi(0, int(grades[grade]))
			quality_total += normalized[grade + 1]
		normalized[0] = maxi(0, int(inventory_side.get(id, 0)) - quality_total)
		counts[id] = normalized
	return counts

func feedback_action_snapshot(point: Dictionary = {}) -> Dictionary:
	# Native beds are stored alongside plots; only the selected target belongs
	# in an action settlement snapshot.
	return preload("res://scripts/feedback_action.gd").snapshot({
		"day": day, "minutes": minutes, "money": money, "stamina": stamina,
		"bag": inventory, "storage": storage, "quality": quality,
		"storageQuality": storage_quality, "farm": {"beds": plots},
		"animals": animals, "relations": relations, "fishing": fishing,
		"kitchen": kitchen, "economy": economy, "building": building,
		"toolkit": toolkit, "neighbors": neighbors
	}, point)

func finish_action_feedback(before: Dictionary,point: Dictionary,spec: Dictionary) -> Variant:
	var catalog := system_catalog.duplicate(false)
	catalog.items = item_catalog
	var names: Dictionary = {}
	for npc in npc_catalog:names[str(npc.id)] = str(npc.name)
	catalog.npc_names = names
	return preload("res://scripts/feedback_action.gd").finish(before,feedback_action_snapshot(point),point,spec,feedback,feedback_action_runtime,catalog,player_navigation_position(),_feedback_note)

func tick_feedback_floats(delta: float) -> void:
	var runtime := feedback_action_runtime
	if runtime.get("room",current_interior) != current_interior:
		runtime.floats=[]
		if runtime.has("stories"):runtime.stories=[]
	runtime.room = current_interior
	runtime.clock += clampf(delta,0.0,0.1)
	runtime.floats = runtime.floats.filter(func(row: Dictionary) -> bool:return float(runtime.clock)-float(row.at)<4.5)
	if runtime.has("stories"):
		runtime.stories = runtime.stories.filter(func(row: Dictionary) -> bool:return float(runtime.clock)-float(row.at)<float(row.duration))

func _feedback_snapshot_state() -> Dictionary:
	var ids: Dictionary = {}
	for id in inventory: ids[str(id)] = true
	for id in storage: ids[str(id)] = true
	for id in quality: ids[str(id)] = true
	for id in storage_quality: ids[str(id)] = true
	var bag_counts := _feedback_counts(inventory, quality)
	var storage_counts := _feedback_counts(storage, storage_quality)
	var items: Dictionary = {}
	for id in ids:
		var counts: Array[int] = [0, 0, 0, 0]
		var bag_row: Array = bag_counts.get(id, [0, 0, 0, 0])
		var storage_row: Array = storage_counts.get(id, [0, 0, 0, 0])
		for grade in range(4):
			counts[grade] = int(bag_row[grade]) + int(storage_row[grade])
		items[id] = counts
	var plot_fields: Array[Dictionary] = []
	for plot in plots:
		plot_fields.append({"moisture": int(plot.get("moisture", 0)), "fertility": int(plot.get("fertility", 0)), "health": int(plot.get("health", 0)), "pests": int(plot.get("pests", 0)), "disease": int(plot.get("disease", 0)), "weeds": int(plot.get("weeds", 0)), "tilled": bool(plot.get("tilled", false)), "crop": str(plot.get("crop", ""))})
	var animal_fields: Array[Dictionary] = []
	for animal in animals:
		animal_fields.append({"id": str(animal.get("id", "")), "name": str(animal.get("name", "伙伴")), "hunger": int(animal.get("hunger", 0)), "mood": int(animal.get("mood", 0)), "clean": int(animal.get("clean", 0)), "health": int(animal.get("health", 0)), "illness": int(animal.get("illness", 0))})
	var relation_points: Dictionary = {}
	for npc_id in relations:
		relation_points[str(npc_id)] = int(relations[npc_id].get("points", 0)) if relations[npc_id] is Dictionary else int(relations[npc_id])
	var casts := 0
	var fish_waters: Dictionary = fishing.get("waters", {}) if fishing.get("waters", {}) is Dictionary else {}
	for water in fish_waters.values():
		if int(water.get("day", -1)) == day: casts += int(water.get("casts", 0))
	var tool_levels: Dictionary = {}
	for tool_id in toolkit.get("tools", {}):
		tool_levels[str(tool_id)] = int(toolkit.tools[tool_id].get("level", 0))
	var neighbor_events: Dictionary = {}
	for npc_id in neighbors.get("people", {}):
		var event: Variant = neighbors.people[npc_id].get("event", null)
		neighbor_events[str(npc_id)] = event.duplicate(true) if event is Dictionary else null
	return {
		"items": items,
		"money": money,
		"stamina": stamina,
		"relations": relation_points,
		"plots": plot_fields,
		"animals": animal_fields,
		"world": {
			"interior": current_interior,
			"forage_finds": forage.get("finds", []).duplicate(true),
			"fish_records": fishing.get("records", {}).duplicate(true) if fishing.get("records", {}) is Dictionary or fishing.get("records", {}) is Array else fishing.get("records", {}),
			"fish_last": fishing.get("last", {}).duplicate(true) if fishing.get("last", {}) is Dictionary else {},
			"fish_casts": casts,
			"kitchen": kitchen.get("jobs", []).duplicate(true),
			"trade": economy.get("jobs", []).duplicate(true),
			"orders": economy.get("claimed", []).duplicate(true),
			"building": building.get("jobs", []).duplicate(true),
			"tools": tool_levels,
			"neighbors": neighbor_events
		}
	}

func _feedback_note(data: Dictionary) -> Dictionary:
	var key: Variant = JS_TEXT.prefix(JS_TEXT.coerce(data.get("key", "feedback/%d" % int(feedback.get("next", 1)))), 140)
	var title: Variant = JS_TEXT.prefix(JS_TEXT.coerce(data.get("title", "手边的事有了结果")), 120)
	var text: Variant = JS_TEXT.prefix(JS_TEXT.coerce(data.get("text", "")), 1800)
	var row_type := str(data.get("type", "提醒"))
	var link := str(data.get("link", "feedback"))
	if not FEEDBACK_TYPES.has(row_type): row_type = "提醒"
	if not FEEDBACK_LINKS.has(link): link = "feedback"
	var rows: Array = feedback.get("rows", [])
	for row in rows:
		if JS_TEXT.equal(row.get("key", ""), key) and int(row.get("day", -1)) == day:
			if bool(data.get("merge", false)):
				row.count = mini(999999, int(row.get("count", 1)) + 1)
				row.minute = floori(minutes)
			if not JS_TEXT.equal(row.get("text", ""), text):
				row.text = text
				row.read = false
			return row
	var priority := clampi(int(data.get("priority", 0)), 0, 2)
	var row := {"id": int(feedback.get("next", 1)), "key": key, "title": title, "text": text, "type": row_type, "priority": priority, "link": link, "day": day, "minute": floori(minutes), "count": 1, "read": priority == 0}
	feedback.next = int(feedback.get("next", 1)) + 1
	rows.append(row)
	if rows.size() > 80:
		var remove_index := -1
		for index in range(rows.size()):
			if bool(rows[index].get("read", false)) and int(rows[index].get("priority", 0)) == 0:
				remove_index = index
				break
		rows.remove_at(remove_index if remove_index >= 0 else 0)
	feedback.rows = rows
	return row

func _set_message_silently(text:String)->void:
	var prior:=_suppress_message_notifications
	_suppress_message_notifications=true
	message=text
	_suppress_message_notifications=prior

func record_notification_error(text:String)->void:
	_feedback_note({"key":JS_TEXT.concat(["error/", JS_TEXT.prefix(text,100)]),"title":"这一步还没完成","text":text,"type":"未完成","priority":1,"merge":true})
	var prior_message:=message
	var prior_suppression:=_suppress_message_notifications
	_suppress_message_notifications=true
	save_game(SAVE_PATH,true)
	message=prior_message
	_suppress_message_notifications=prior_suppression

func feedback_mark_read(row_id: String = "all") -> void:
	for row in feedback.get("rows", []):
		if row_id == "all" or int(row.get("id", -1)) == int(row_id): row.read = true
	changed.emit()

func feedback_set_preference(key: String, value: Variant) -> bool:
	var prefs: Dictionary = feedback.get("prefs", FEEDBACK_PREFS_DEFAULT.duplicate(true))
	if key == "pace" and str(value) in ["normal", "brisk"]:
		prefs.pace = str(value)
	elif key == "motion" and str(value) in ["full", "reduced"]:
		prefs.motion = str(value)
		visual_fx.motion = str(value)
	elif key == "floating" and str(value) in ["normal", "compact", "off"]:
		prefs.floating = str(value)
	elif key == "seconds" and int(value) in [5, 8, 12]:
		prefs.seconds = int(value)
	elif key == "quiet" and value is bool:
		prefs.quiet = value
	else:
		return false
	feedback.prefs = prefs
	changed.emit()
	return true

func _feedback_item_deltas(before_items: Dictionary, after_items: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Dictionary = {}
	for id in before_items: ids[str(id)] = true
	for id in after_items: ids[str(id)] = true
	for id in ids:
		var old: Array = before_items.get(id, [0, 0, 0, 0])
		var current: Array = after_items.get(id, [0, 0, 0, 0])
		for grade in range(4):
			var amount := int(current[grade]) - int(old[grade])
			if amount != 0: result.append({"id": str(id), "grade": grade, "qty": amount})
	return result

func _feedback_sound_events(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var old_world: Dictionary = before.get("world", {})
	var new_world: Dictionary = after.get("world", {})
	var old_fish: Dictionary = old_world.get("fish_records", {})
	var new_fish: Dictionary = new_world.get("fish_records", {})
	for fish_id in new_fish:
		var current: Dictionary = new_fish[fish_id]
		var prior: Dictionary = old_fish.get(fish_id, {})
		if int(current.get("count", 0)) > int(prior.get("count", 0)):
			var spec: Dictionary = system_catalog.get("fishing", {}).get("species", {}).get(str(fish_id), {})
			var last: Dictionary = new_world.get("fish_last", {})
			var fresh := prior.is_empty()
			var best := not prior.is_empty() and float(current.get("best", 0.0)) > float(prior.get("best", 0.0))
			var label := "图鉴新发现 · " if fresh else "体长新纪录 · " if best else "鱼获记录 · "
			result.append({"text": "%s%s %.1f 厘米 · %s%s" % [label, str(spec.get("name", fish_id)), float(last.get("length", 0.0)), ["普通", "优质", "上品", "珍品"][clampi(int(last.get("grade", 0)), 0, 3)], " · 已轻放回水中" if bool(last.get("released", false)) else " · 已收进鱼篓"], "link": "fishing", "priority": 1 if fresh or best else 0, "type": "提醒"})
	var last_fish: Dictionary = new_world.get("fish_last", {})
	if last_fish.get("fish", "not-a-miss") == null and int(new_world.get("fish_casts", 0)) > int(old_world.get("fish_casts", 0)):
		result.append({"text": "这竿没有鱼获：%s；可以改用轻松观漂模式。" % str(last_fish.get("reason", "鱼游开了")), "link": "fishing", "priority": 1, "type": "未完成"})
	for job in new_world.get("kitchen", []):
		if not old_world.get("kitchen", []).any(func(row: Dictionary) -> bool: return int(row.get("key", -1)) == int(job.get("key", -2))):
			var station: Dictionary = system_catalog.get("kitchen", {}).get("stations", {}).get(str(job.get("station", "")), {})
			var item_name := str(item_catalog.get(str(job.get("id", "")), {}).get("name", job.get("id", "成品")))
			result.append({"text": "%s已开始加工 %s ×%d。完成后走近工位手动收取。" % [str(station.get("name", "工位")), item_name, int(job.get("qty", 0))], "link": "processing", "priority": 0, "type": "提醒"})
	for job in new_world.get("trade", []):
		if not old_world.get("trade", []).any(func(row: Dictionary) -> bool: return int(row.get("key", -1)) == int(job.get("key", -2))):
			var item_name := str(item_catalog.get(str(job.get("id", "")), {}).get("name", job.get("id", "物品")))
			result.append({"text": "%s已接收 %s ×%d；待结算 %d 元，领取后才到账。" % ["合作社代销" if str(job.get("channel", "")) == "coop" else "乡间摆摊", item_name, int(job.get("qty", 0)), int(job.get("price", 0))], "link": "economy", "priority": 0, "type": "提醒"})
	for order_id in new_world.get("orders", []):
		if not old_world.get("orders", []).has(order_id): result.append({"text": "供货单 %s 已交付，货款已经计入本次收支。" % str(order_id), "link": "economy", "priority": 1, "type": "提醒"})
	for job in new_world.get("building", []):
		var found: bool = old_world.get("building", []).any(func(row: Dictionary) -> bool: return str(row.get("id", "")) == str(job.get("id", "")) and int(row.get("level", 0)) == int(job.get("level", 0)))
		if not found: result.append({"text": "%s第 %d 阶已开工，预计第 %d 天竣工。" % [str(system_catalog.get("building", {}).get("projects", {}).get(str(job.get("id", "")), {}).get("name", "工程")), int(job.get("level", 0)), int(job.get("readyDay", day)) + 1], "link": "build", "priority": 1, "type": "提醒"})
	for tool_id in new_world.get("tools", {}):
		var level := int(new_world.tools[tool_id])
		if level > int(old_world.get("tools", {}).get(tool_id, 0)):
			result.append({"text": "%s升至第 %d 阶；可在工具手记选择作业方式。" % [str(system_catalog.get("tools", {}).get("defs", {}).get(str(tool_id), {}).get("name", tool_id)), level], "link": "tools", "priority": 1, "type": "提醒"})
	for npc_id in new_world.get("neighbors", {}):
		var event: Variant = new_world.neighbors[npc_id]
		var prior: Variant = old_world.get("neighbors", {}).get(npc_id, null)
		if event is Dictionary and (not prior is Dictionary or str(event.get("status", "")) != str(prior.get("status", ""))):
			var name := str(npc_id)
			for person in npc_catalog:
				if str(person.get("id", "")) == str(npc_id): name = str(person.get("name", npc_id)); break
			var status_text: String = str({"offered": "想找你搭把手", "done": "已经办妥", "accepted": "已答应帮忙", "postponed": "留待下次"}.get(str(event.get("status", "")), "有新进展"))
			result.append({"text": "%s的邻里小事：%s。" % [name, status_text], "link": "neighbors", "priority": 1, "type": "社交"})
	var old_relations: Dictionary = before.get("relations", {})
	for npc_id in after.get("relations", {}):
		var prior_points := int(old_relations.get(npc_id, 0))
		var points := int(after.relations[npc_id])
		var stage_before := _relationship_stage(prior_points)
		var stage_after := _relationship_stage(points)
		if stage_before != stage_after:
			var name := str(npc_id)
			for person in npc_catalog:
				if str(person.get("id", "")) == str(npc_id): name = str(person.get("name", npc_id)); break
			result.append({"text": "%s：%s → %s。" % [name, stage_before, stage_after], "link": "neighbors", "priority": 1, "type": "社交"})
	return result

func _relationship_stage(points: int) -> String:
	return "初识" if points < 10 else "熟悉" if points < 30 else "亲近" if points < 70 else "信任"

func _feedback_sound_kind(old_world: Dictionary, new_world: Dictionary, item_deltas: Array[Dictionary], money_delta: int, relation_deltas: Array[Dictionary], field_changes: Array[String], events: Array[Dictionary]) -> String:
	if not relation_deltas.is_empty(): return "greet"
	for event in events:
		var link := str(event.get("link", ""))
		if link == "fishing": return "fish"
		if link == "processing": return "steam"
		if link == "economy": return "trade"
		if link == "build": return "build"
		if link == "neighbors": return "greet"
	var old_finds: Array = old_world.get("forage_finds", [])
	var new_finds: Array = new_world.get("forage_finds", [])
	if not new_finds.is_empty() and (old_finds.is_empty() or str(old_finds.back().get("id", "")) != str(new_finds.back().get("id", "")) or int(old_finds.back().get("day", -1)) != int(new_finds.back().get("day", -1))): return "gather"
	if item_deltas.is_empty() and money_delta == 0 and field_changes.is_empty() and events.is_empty(): return ""
	var action_text := message
	for match in [["浇水", "water"], ["湿度升", "water"], ["清水浸进", "water"], ["播种", "seed"], ["种下", "seed"], ["松土", "hoe"], ["翻好", "hoe"], ["开垦", "hoe"], ["收获", "harvest"], ["采集", "gather"], ["喂", "feed"], ["堆肥拌进", "feed"], ["清扫", "brush"], ["抚摸", "pet"], ["虫害", "brush"], ["护好叶片", "brush"], ["出售", "trade"], ["摆摊", "trade"], ["收下", "harvest"], ["加工", "steam"], ["投料", "steam"], ["建造", "build"], ["修缮", "build"]]:
		if action_text.contains(str(match[0])): return str(match[1])
	return "good"

func _track_feedback_sounds() -> void:
	var after := _feedback_snapshot_state()
	if _feedback_snapshot.is_empty():
		_feedback_snapshot = after
		return
	var before := _feedback_snapshot
	_feedback_snapshot = after
	var old_world: Dictionary = before.get("world", {})
	var new_world: Dictionary = after.get("world", {})
	if str(old_world.get("interior", "")) != str(new_world.get("interior", "")):
		sound_requested.emit("door")
	var item_deltas := _feedback_item_deltas(before.get("items", {}), after.get("items", {}))
	var money_delta := int(after.get("money", 0)) - int(before.get("money", 0))
	var relation_deltas: Array[Dictionary] = []
	for npc_id in after.get("relations", {}):
		var change := int(after.relations[npc_id]) - int(before.get("relations", {}).get(npc_id, 0))
		if change != 0: relation_deltas.append({"id": str(npc_id), "amount": change})
	var field_changes: Array[String] = []
	for index in range(mini(before.get("plots", []).size(), after.get("plots", []).size())):
		for field in ["moisture", "fertility", "health", "pests", "disease", "weeds"]:
			var old_value := int(before.plots[index].get(field, 0))
			var new_value := int(after.plots[index].get(field, 0))
			if old_value != new_value and field_changes.size() < 6: field_changes.append("田块 %d %s %d→%d" % [index + 1, {"moisture": "水分", "fertility": "肥力", "health": "健康", "pests": "虫害", "disease": "病害", "weeds": "杂草"}[field], old_value, new_value])
		if bool(before.plots[index].get("tilled", false)) != bool(after.plots[index].get("tilled", false)) and field_changes.size() < 6:
			field_changes.append("田块 %d %s" % [index + 1, "开垦完成" if bool(after.plots[index].get("tilled", false)) else "已休耕"])
		if str(before.plots[index].get("crop", "")) != str(after.plots[index].get("crop", "")) and field_changes.size() < 6:
			field_changes.append("田块 %d 作物 %s→%s" % [index + 1, str(before.plots[index].get("crop", "空地")), str(after.plots[index].get("crop", "空地"))])
	for index in range(mini(before.get("animals", []).size(), after.get("animals", []).size())):
		for field in ["hunger", "mood", "clean", "health", "illness"]:
			var old_value := int(before.animals[index].get(field, 0))
			var new_value := int(after.animals[index].get(field, 0))
			if old_value != new_value and field_changes.size() < 6: field_changes.append("%s %s %d→%d" % [str(after.animals[index].get("name", "伙伴")), {"hunger": "饱食", "mood": "心情", "clean": "清洁", "health": "健康", "illness": "病情"}[field], old_value, new_value])
	var events := _feedback_sound_events(before, after)
	var sound_kind := _feedback_sound_kind(old_world, new_world, item_deltas, money_delta, relation_deltas, field_changes, events)
	if sound_kind != "": sound_requested.emit(sound_kind)
	# Presentation sounds retain their existing routing. Journal entries are
	# settled once by _commit_action after the domain operation and page switch.

func _feedback_notice(key:String,title:String,text:String,link:String,priority:int=1,row_type:String="提醒")->bool:
	var hash_value:=0
	for character in key:
		var code:=character.unicode_at(0)
		if code>0xffff:code=0xd800+((code-0x10000)>>10)
		hash_value=(hash_value*31+code)&0xffffffff
	var token:Variant=JS_TEXT.concat([str(day),"/",JS_TEXT.prefix(key,110),"/",str(hash_value)])
	var seen:Array=feedback.get("seen",[])
	if JS_TEXT.includes(seen,token):return false
	seen.append(token);feedback.seen=seen
	var row:=_feedback_note({"key":key,"title":title,"text":text,"link":link,"priority":priority,"type":row_type})
	_feedback_poll_added.append(row)
	return true

func _feedback_poll(present:bool=true) -> bool:
	_feedback_poll_added=[]
	var emitted := false
	var ready_kitchen: Array[String] = []
	for job in kitchen.get("jobs", []):
		if float(job.get("ready", 0)) <= _kitchen_now(): ready_kitchen.append(str(job.get("key", "")))
	if not ready_kitchen.is_empty(): emitted = _feedback_notice("kitchen/" + ",".join(ready_kitchen), "小灶有成品可收", "%d 批加工完成，走到工位收好，保鲜从收取日开始。" % ready_kitchen.size(), "processing") or emitted
	var ready_trades: Array[String] = []
	for job in economy.get("jobs", []):
		if float(job.get("ready", 0)) <= _kitchen_now(): ready_trades.append(str(job.get("key", "")))
	if not ready_trades.is_empty(): emitted = _feedback_notice("trade/" + ",".join(ready_trades), "有货款可以领取", "%d 张货单可以结算，打开物产经营查看。" % ready_trades.size(), "economy") or emitted
	var care_rows: Array[String] = []
	var care_ids:Array[String]=[]
	for animal in animals:
		if int(animal.get("hunger", 100)) < 40 or int(animal.get("illness", 0)) >= 20:
			care_ids.append(str(animal.id))
			care_rows.append("%s：%s" % [str(animal.get("name", "伙伴")), "身体不适" if int(animal.get("illness", 0)) >= 20 else "饲料不足"])
	if not care_rows.is_empty(): emitted = _feedback_notice("animals/" + ",".join(care_ids), "伙伴需要照料", "；".join(care_rows), "ranch", 2) or emitted
	var low_fields := 0
	for index in range(mini(plots.size(), farm.get("beds", []).size())):
		if str(plots[index].get("crop", "")) != "" and (int(farm.beds[index].get("health", 100)) < 35 or int(farm.beds[index].get("moisture", 100)) < 15): low_fields += 1
	if low_fields > 0: emitted = _feedback_notice("fields", "田间照料提醒", "%d 块地需要补水或护苗；打开四时农事查看具体原因。" % low_fields, "farmcare", 2) or emitted
	var tomorrow := weather_profile(day + 1)
	if bool(tomorrow.get("extreme", false)):
		var events: Array = system_catalog.get("environment", {}).get("events", [])
		emitted = _feedback_notice("weather", "明日天气预警", ENVIRONMENT_RULES.warning(day, events), "weather", 2) or emitted
	var promises: Array[String] = []
	for npc_id in neighbors.get("people", {}):
		var event: Dictionary = neighbors.people[npc_id].get("event", {})
		if int(event.get("day", -1)) == day and str(event.get("status", "")) == "offered":
			for person in npc_catalog:
				if str(person.get("id", "")) == str(npc_id): promises.append(str(person.get("name", npc_id))); break
	if not promises.is_empty(): emitted = _feedback_notice("neighbors", "邻居有件小事想找你", "、".join(promises) + " 想找人搭把手，不限日期，顺路再去也可以。", "neighbors", 1) or emitted
	while feedback.seen.size()>80:feedback.seen.pop_front()
	if present:_present_polled_feedback()
	return emitted

func _present_polled_feedback()->void:
	if not _feedback_poll_added.is_empty():
		var best:Dictionary=_feedback_poll_added[0]
		for row in _feedback_poll_added:
			if int(row.priority)>int(best.priority):best=row
		var extra:="（另有 "+str(_feedback_poll_added.size()-1)+" 条，回响里可查看）" if _feedback_poll_added.size()>1 else ""
		feedback_toast_requested.emit(str(best.title)+" · "+str(best.text)+extra,int(best.priority))

func bound_key(action: String, fallback: int) -> int:
	var bindings: Dictionary = player_settings.get("bindings", {})
	var value := str(bindings.get(action, ""))
	return value.to_upper().unicode_at(0) if value.length() == 1 else fallback

var touch_direction := Vector2.ZERO
var mobile_orientation_blocked := false

func simulation_hidden() -> bool:
	return mobile_orientation_blocked or (DisplayServer.get_name() != "headless" and get_tree().root.mode == Window.MODE_MINIMIZED)

func pass_time(delta: float) -> void:
	if delta <= 0.0 or ui_open or action_busy() or simulation_hidden():
		return
	_advance_frame_time(clampf(delta, 0.0, 0.05))

func _advance_frame_time(delta: float) -> void:
	var rate := 1.55 if str(player_settings.get("speed", "relaxed")) == "normal" else 1.04
	minutes = minf(1320.0, minutes + delta * rate)
	_source_update_tick += delta
	if _source_update_tick > 1.0:
		_source_update_tick = 0.0
		clock_changed.emit()
		_periodic_autosave_elapsed += 1.0
		if _periodic_autosave_elapsed >= 15.0:
			_periodic_autosave_elapsed = 0.0
			_queue_autosave()
		if minutes >= 1320 and not action_busy():
			_bedtime_prompted = true
			bedtime_reached.emit()

func _remember_weather() -> void:
	if environment.is_empty():
		environment = {"version": 1, "history": []}
	var history: Array = environment.get("history", [])
	var already_recorded := false
	for entry in history:
		if int(entry.get("day", -1)) == day:
			already_recorded = true
			break
	if not already_recorded:
		history.append({"day": day, "kind": weather_for(day)})
	while history.size() > 14:
		history.pop_front()
	environment.history = history

func _new_inventory(include_starter: bool = true) -> Dictionary:
	var result: Dictionary = {}
	if include_starter:
		var starter_bag: Dictionary = initial_state.get("bag", STARTER_SUPPLIES)
		for item in starter_bag:
			if item_catalog.has(item): result[item] = int(starter_bag[item])
	for item_id in item_catalog:
		if not result.has(item_id): result[item_id] = 0
	return result

func crop_data(crop_id: String) -> Dictionary:
	return crop_catalog.get(crop_id, {})

func crop_days(crop_id: String) -> int:
	return int(crop_data(crop_id).get("days", 3))

func seed_item_id(crop_id: String) -> String:
	return str(crop_data(crop_id).get("seed", ""))

func seed_variant_id(crop_id: String, kind: String = "") -> String:
	var selected_kind := str(farm.get("seedKind", "normal")) if kind == "" else kind
	return seed_item_id(crop_id) if selected_kind == "normal" else "%s_%s" % [crop_id, selected_kind]

func crop_profile(crop_id: String) -> Dictionary:
	return preload("res://scripts/farm_rules.gd").profile(crop_id,crop_data(crop_id))

func farm_neighbor_indices(index: int) -> Array[int]:
	var result: Array[int] = []
	if index < 0 or index >= plots.size():
		return result
	var point := _farm_position(index)
	for other in range(plots.size()):
		if other != index and point.distance_to(_farm_position(other)) < 63.0:
			result.append(other)
	return result

func crop_compatibility(first: String, second: String) -> int:
	if first == second or str(crop_data(first).get("group", "")) == str(crop_data(second).get("group", "")):
		return -1
	var first_group := str(crop_data(first).get("group", ""))
	var second_group := str(crop_data(second).get("group", ""))
	if first_group == "豆类" or second_group == "豆类" or first_group == "叶菜" and second_group == "根菜" or first_group == "根菜" and second_group == "叶菜":
		return 1
	return 0

func crop_relation(index: int) -> int:
	if index < 0 or index >= plots.size() or str(plots[index].get("crop", "")) == "":
		return 0
	var crop_id := str(plots[index].crop)
	var neighbors := 0
	for other in farm_neighbor_indices(index):
		var neighbor_crop := str(plots[other].get("crop", ""))
		if neighbor_crop != "":
			neighbors += crop_compatibility(crop_id, neighbor_crop)
	var companion: Dictionary = plots[index].get("companion", {})
	if not companion.is_empty():
		neighbors += crop_compatibility(crop_id, str(companion.get("crop", "")))
	return clampi(neighbors, -2, 2)

func set_farm_seed_kind(kind: String) -> void:
	if system_catalog.get("farming", {}).get("kinds", {}).has(kind):
		farm.seedKind = kind
		message = "种子类型：%s。" % str(system_catalog.farming.kinds[kind].get("name", kind))
		changed.emit()

func set_farm_density(density: String) -> void:
	if density in ["sparse", "balanced", "dense"]:
		farm.density = density
		message = "株距调整为%s。" % {"sparse": "疏植", "balanced": "标准", "dense": "密植"}[density]
		changed.emit()

func change_plot_soil(index: int, soil_type: String) -> bool:
	var soils: Dictionary = system_catalog.get("farming", {}).get("soils", {})
	if index < 0 or index >= plots.size() or not soils.has(soil_type):
		message = "请选择有效田块与土质。"
	elif not bool(plots[index].get("tilled", false)) or bool(plots[index].get("removed", false)):
		message = "先修复并开垦土地，再调整土质。"
	elif str(plots[index].get("crop", "")) != "" or not plots[index].get("companion", {}).is_empty():
		message = "先收下作物再改土，调整土质不会销毁作物。"
	elif money < 20 or int(inventory.get("compost", 0)) < 2:
		message = "换土需要堆肥 ×2 与 20 金币。"
	elif spend_energy(2, 5):
		money -= 20
		inventory["compost"] -= 2
		plots[index].soil_type = soil_type
		plots[index].soil = float(plots[index].fertility) / 50.0
		message = "换入%s，适种偏好已更新。" % str(soils[soil_type].get("name", soil_type))
		changed.emit()
		return true
	changed.emit()
	return false

func crop_name(crop_id: String) -> String:
	return str(crop_data(crop_id).get("name", crop_id))

func npc_name(npc_id: String) -> String:
	for person in npc_catalog:
		if str(person.get("id", "")) == npc_id:
			return str(person.get("name", npc_id))
	return npc_id

func season_index() -> int:
	return int((day % 112) / 28)

func crop_in_season(crop_id: String) -> bool:
	for candidate in crop_data(crop_id).get("seasons", []):
		if int(candidate) == season_index():
			return true
	return false

func select_toolbar_tool(tool_id: String) -> bool:
	if tool_id not in TOOLBAR_IDS: return false
	selected_tool = tool_id
	_set_message_silently("选中%s。" % str(TOOLBAR_NAMES[tool_id]))
	QUESTS.event(self,"tool")
	changed.emit()
	sound_requested.emit("action")
	return true

func cycle_toolbar_tool(direction: int) -> String:
	var current := TOOLBAR_IDS.find("hand" if selected_tool == "harvest" else selected_tool)
	if current < 0: current = 0
	var next: String = TOOLBAR_IDS[posmod(current + direction, TOOLBAR_IDS.size())]
	select_toolbar_tool(next)
	return next

func choose_normal_seed(crop_id: String, require_season: bool = true) -> bool:
	if not crop_catalog.has(crop_id) or (require_season and not crop_in_season(crop_id)):
		return false
	farm.seedKind = "normal"
	selected_seed = crop_id
	selected_tool = "seed"
	message = "选好了%s种子。点击松好的菜地播种。" % crop_name(crop_id)
	changed.emit()
	return true

func next_seed() -> void:
	var ids := crop_catalog.keys()
	if ids.is_empty():
		return
	var current := ids.find(selected_seed)
	for step in range(1, ids.size() + 1):
		var candidate: String = ids[(current + step) % ids.size()]
		if inventory.get(seed_item_id(candidate), 0) > 0 and crop_in_season(candidate):
			selected_seed = candidate
			message = "当前种子：" + crop_name(candidate)
			return
	message = "背包里没有当前季节可种的其他种子。"

func sell_all_crops() -> void:
	var sold := 0
	var proceeds := 0
	for crop_id in crop_catalog:
		var quantity := int(inventory.get(crop_id, 0))
		if quantity <= 0:
			continue
		var unit_price := int(crop_data(crop_id).get("price", 0))
		if unit_price <= 0:
			continue
		var grades: Array = quality.get(crop_id, [0, 0, 0])
		var weighted_quantity := quantity - int(grades[0]) - int(grades[1]) - int(grades[2])
		proceeds += int(unit_price * (float(weighted_quantity) + float(grades[0]) * 1.2 + float(grades[1]) * 1.4 + float(grades[2]) * 1.7))
		sold += quantity
		inventory[crop_id] = 0
		quality.erase(crop_id)
	if sold == 0:
		message = "菜筐里还没有可以出售的收成。"
	else:
		money += proceeds
		message = "卖出农产 %d 份，收入 %d 金币。" % [sold, proceeds]
	changed.emit()

func _quality_counts(item_id: String) -> Array[int]:
	var ledger: Array = quality.get(item_id, [0, 0, 0])
	var premium := [int(ledger[0]), int(ledger[1]), int(ledger[2])]
	return [maxi(0, int(inventory.get(item_id, 0)) - premium[0] - premium[1] - premium[2]), premium[0], premium[1], premium[2]]

func _consume_item(item_id: String, quantity: int) -> Array[int]:
	if quantity < 1 or int(inventory.get(item_id, 0)) < quantity:
		return []
	var counts := _quality_counts(item_id)
	var taken: Array[int] = [0, 0, 0, 0]
	var remaining := quantity
	for grade in range(4):
		taken[grade] = mini(remaining, counts[grade])
		remaining -= taken[grade]
	if remaining > 0:
		return []
	inventory[item_id] = int(inventory[item_id]) - quantity
	if quality.has(item_id): quality[item_id] = [counts[1] - taken[1], counts[2] - taken[2], counts[3] - taken[3]]
	return taken

func _add_inventory_count(item_id: String, quantity: int) -> void:
	var previous := int(inventory.get(item_id, 0))
	# A new acquisition belongs at the end of the bag, including when the
	# previous stack has been exhausted.
	if previous == 0 and quantity > 0: inventory.erase(item_id)
	inventory[item_id] = previous + quantity

func _restore_item(item_id: String, grades: Array) -> void:
	var quantity := 0
	for count in grades:
		quantity += int(count)
	_add_inventory_count(item_id, quantity)
	var ledger: Array = quality.get(item_id, [0, 0, 0])
	for grade in range(1, 4):
		ledger[grade - 1] = int(ledger[grade - 1]) + int(grades[grade])
	quality[item_id] = ledger

func _storage_quality_counts(item_id: String) -> Array[int]:
	var ledger: Array = storage_quality.get(item_id, [0, 0, 0])
	var premium := [int(ledger[0]), int(ledger[1]), int(ledger[2])]
	return [maxi(0, int(storage.get(item_id, 0)) - premium[0] - premium[1] - premium[2]), premium[0], premium[1], premium[2]]

func transfer_storage(item_id: String, quantity: int, to_storage: bool) -> bool:
	# economy.js supplies the final original C.storageMove implementation.
	return economy_transfer(item_id, quantity, to_storage)

func _transfer_storage(item_id: String, quantity: int, to_storage: bool, notify: bool) -> bool:
	if not item_catalog.has(item_id) or quantity < 1:
		message = "请选择有效的物品和数量。"
		if notify: changed.emit()
		return false
	var source: Dictionary = inventory if to_storage else storage
	if int(source.get(item_id, 0)) < quantity:
		message = "物品数量不足，无法搬动。"
		if notify: changed.emit()
		return false
	_reconcile_kitchen_lots()
	_move_kitchen_lots(item_id, quantity, "bag" if to_storage else "storage", "storage" if to_storage else "bag")
	if to_storage:
		var moved := _consume_item(item_id, quantity)
		storage[item_id] = int(storage.get(item_id, 0)) + quantity
		var ledger: Array = storage_quality.get(item_id, [0, 0, 0])
		for grade in range(1, 4):
			ledger[grade - 1] = int(ledger[grade - 1]) + int(moved[grade])
		storage_quality[item_id] = ledger
	else:
		var counts := _storage_quality_counts(item_id)
		var moved: Array[int] = [0, 0, 0, 0]
		var remaining := quantity
		for grade in range(4):
			moved[grade] = mini(remaining, counts[grade])
			remaining -= moved[grade]
		storage[item_id] = int(storage.get(item_id, 0)) - quantity
		storage_quality[item_id] = [counts[1] - moved[1], counts[2] - moved[2], counts[3] - moved[3]]
		_restore_item(item_id, moved)
	_reconcile_kitchen_lots()
	message = "%s%s ×%d。" % ["存好" if to_storage else "取出", str(item_catalog.get(item_id, {}).get("name", item_id)), quantity]
	if notify: changed.emit()
	return true

func sort_building_storage(category_id: String, withdraw: bool = false) -> bool:
	if building_level("granary") < 1 or not bool(upgrades.get("storage", false)):
		message = "先改良丰收粮仓。"
		changed.emit()
		return false
	if withdraw and (building_level("granary") < 2 or str(building.get("modes", {}).get("granary", "")) != "supply"):
		message = "二阶粮仓选择周转补给后，可以一键取回。"
		changed.emit()
		return false
	var source: Dictionary = storage if withdraw else inventory
	var destination: Dictionary = inventory if withdraw else storage
	var ids: Array = source.keys()
	var moved := 0
	for raw_id in ids:
		var item_id := str(raw_id)
		var kind := str(item_catalog.get(item_id, {}).get("kind", ""))
		var matches := _is_food(item_id) if category_id == "food" else kind == "种子" if category_id == "seed" else kind == "材料" if category_id == "material" else item_id in ["feed", "hay", "grainFeed", "healthFeed", "bedding"]
		if not matches: continue
		var held := int(source.get(item_id, 0))
		var transfer := mini(held, maxi(0, 5 - int(destination.get(item_id, 0)))) if withdraw else maxi(0, held - 5)
		if transfer > 0 and _transfer_storage(item_id, transfer, not withdraw, false):
			moved += transfer
	message = ("取回" if withdraw else "存好") + str(moved) + " 件，随身每类保留 5 份；品质和陈放年龄保留。" if moved > 0 else "已按每类 5 份随身余量整理，无需再搬。"
	changed.emit()
	return moved > 0

func tool_data(tool_id: String) -> Dictionary:
	return toolkit.get("tools", {}).get(tool_id, {})

func tool_definition(tool_id: String) -> Dictionary:
	return system_catalog.get("tools", {}).get("defs", {}).get(tool_id, {})

func tool_quote(tool_id: String) -> Dictionary:
	var definition := tool_definition(tool_id)
	var tool := tool_data(tool_id)
	if definition.is_empty() or tool.is_empty() or int(tool.get("level", 0)) >= 2:
		return {}
	var level := int(tool.get("level", 0))
	var needs: Dictionary = {"wood": 6, "bamboo": 5}
	if level == 0:
		needs = definition.get("needs", {}).duplicate(true)
	elif tool_id == "care":
		needs["wool"] = 2
	return {"money": int(definition.get("cost", 80)) + (100 if level > 0 else 0), "needs": needs, "locked": level == 1 and day < 7 and int(tool.get("xp", 0)) < 8 and building_level("workshop") < 1}

func upgrade_tool(tool_id: String) -> bool:
	var quote := tool_quote(tool_id)
	if quote.is_empty():
		message = "已经完成这件工具的全部改良。"
	elif bool(quote.get("locked", false)):
		message = "进村满一周、这件工具成功使用 8 次，或改良农具间，任一条件即可学习二阶。"
	elif money < int(quote.money) or not _building_has(quote.needs):
		var parts: Array[String] = []
		for item_id in quote.needs: parts.append("%s ×%d" % [str(item_catalog.get(item_id,{}).get("name",item_id)),int(quote.needs[item_id])])
		message = "需要 %d 元及 %s。" % [int(quote.money),"、".join(parts)]
	elif spend_energy(2, 15, "", false):
		money -= int(quote.money)
		_reconcile_kitchen_lots()
		_kitchen_consume(quote.needs, 1)
		var tool := tool_data(tool_id)
		tool.level = int(tool.get("level", 0)) + 1
		toolkit.tools[tool_id] = tool
		if int(tool.level) == 1 and tool_id in ["axe", "sickle"]:
			for paired in ["axe", "sickle"]:
				var shared: Dictionary = tool_data(paired)
				shared.level = maxi(1, int(shared.get("level", 0)))
				toolkit.tools[paired] = shared
		if int(tool.level)==1 and tool_id in ["axe","sickle"]: legacy_systems.toolUpgrades.gather = true
		elif int(tool.level)==1 and tool_id!="care": legacy_systems.toolUpgrades[tool_id] = true
		var name := str(tool_definition(tool_id).get("name", tool_id))
		_record_community_log("%s完成第 %d 阶改良。" % [name,int(tool.level)],false)
		message = name+"改好了。"+("基础动作更省力；适用农具可选一行三格。" if int(tool.level)==1 else "专长可随时切换，原有工具始终可用。")
		changed.emit()
		return true
	else:
		message = "先休息再来改工具。"
	changed.emit()
	return false

func configure_tool(tool_id: String, field: String, value: String) -> bool:
	var definition := tool_definition(tool_id)
	var tool := tool_data(tool_id)
	var ok := false
	if definition.is_empty() or tool.is_empty():
		message = "请选择工具。"
	elif field == "branch":
		if int(tool.get("level",0)) < 2 or value not in ["broad","care"]:
			message = "二阶后可以选择专长。"
		else:
			tool.branch = value
			if value == "care" and str(tool.get("shape","single")) == "cross": tool.shape = "row"
			ok = true
	elif field == "shape":
		if value not in ["single","row","cross"] or tool_id not in ["hoe","water","sickle"] or value != "single" and int(tool.get("level",0)) < 1 or value == "cross" and (int(tool.get("level",0)) < 2 or str(tool.get("branch","broad")) != "broad"):
			message = "一阶开放三格，二阶宽幅方向开放五格。"
		else:
			tool.shape = value
			ok = true
	else:
		message = "未知工具设置。"
	if ok:
		toolkit.tools[tool_id] = tool
		message = "已记住这件工具的用法，随时可以调整。"
	changed.emit()
	return ok

func _award_tool(tool_id: String) -> void:
	var tool := tool_data(tool_id)
	if tool.is_empty():
		return
	tool.xp = mini(99999, int(tool.get("xp", 0)) + 1)
	toolkit.tools[tool_id] = tool

func fishing_energy_cost() -> int:
	return maxi(2, 6 - int(tool_data("rod").get("level", 0)))

func _farm_targets(index: int, tool_id: String) -> Array[int]:
	var result: Array[int] = [index]
	var tool := tool_data(tool_id)
	var shape := str(tool.get("shape", "single"))
	if int(tool.get("level",0)) < 1: shape = "single"
	if shape == "cross" and (int(tool.get("level",0)) < 2 or str(tool.get("branch","broad")) != "broad"): shape = "row"
	if shape == "single":
		return result
	var cols := FARM_LAYOUT.columns(index)
	var first := FARM_LAYOUT.first(index)
	var last := mini(FARM_LAYOUT.end(index),plots.size())
	var row := int((index - first) / cols)
	for offset in [-1, 1]:
		var other: int = index + int(offset)
		if other >= first and other < last and int((other - first) / cols) == row:
			result.append(other)
	if shape == "cross":
		for offset in [-cols, cols]:
			var other: int = index + int(offset)
			if other >= first and other < last:
				result.append(other)
	if result.size() > 1:
		var center: int = result.pop_front()
		result.sort()
		result.push_front(center)
	return result

func farm_facility_definition(type: String) -> Dictionary:
	return system_catalog.get("farming", {}).get("facilities", {}).get(type, {})

func farm_facility_indices(anchor: int, type: String) -> Array[int]:
	var definition := farm_facility_definition(type)
	var result: Array[int] = []
	if definition.is_empty() or anchor < 0 or anchor >= plots.size():
		return result
	var origin := _farm_position(anchor)
	var radius := float(definition.get("radius", 0.0)) * (1.25 if _farm_facility_at(anchor, type).get("level", 0) == 1 else 1.0)
	for index in range(plots.size()):
		if _farm_position(index).distance_to(origin) <= radius:
			result.append(index)
	return result

func _farm_position(index: int) -> Vector2:
	return FARM_LAYOUT.position(index)

func _farm_facility_at(anchor: int, type: String) -> Dictionary:
	for facility in farm.get("facilities", []):
		if int(facility.get("anchor", -1)) == anchor and str(facility.get("type", "")) == type:
			return facility
	return {}

func farm_facility_coverage(index: int, type: String) -> bool:
	if type in ["greenhouse", "trellis", "scarecrow"] and _has_farm_decoration(type):
		return true
	for facility in farm.get("facilities", []):
		if str(facility.get("type", "")) != type or not bool(facility.get("enabled", true)) or float(facility.get("durability", 0.0)) <= 0.0:
			continue
		if farm_facility_indices(int(facility.get("anchor", -1)), type).has(index):
			return true
	return false

func _has_farm_decoration(type: String) -> bool:
	for piece in building.get("layout", []):
		if str(piece.get("type", "")) == type:
			return true
	for piece in legacy_systems.get("layouts", []):
		if str(piece.get("id", "")) == type:
			return true
	return false

func farm_facility_status(facility: Dictionary) -> String:
	if not bool(facility.get("enabled", true)):
		return "暂停"
	if float(facility.get("durability", 0.0)) <= 0.0:
		return "损坏"
	if str(facility.get("type", "")) == "sprinkler" and int(farm.get("water", 0)) <= 0:
		return "缺水"
	return "运行"

func manage_farm_facility(anchor: int, type: String, action: String, target: int = -1) -> void:
	var definitions: Dictionary = system_catalog.get("farming", {}).get("facilities", {})
	var definition: Dictionary = definitions.get(type, {})
	var facilities: Array = farm.get("facilities", [])
	var existing := _farm_facility_at(anchor, type)
	if definition.is_empty() or anchor < 0 or anchor >= plots.size():
		message = "请选择有效田块与设施。"
	elif action == "build":
		var count_at_anchor := 0
		for candidate in facilities:
			if int(candidate.get("anchor", -1)) == anchor:
				count_at_anchor += 1
		if not existing.is_empty():
			message = "这里已经有同类设施。"
		elif count_at_anchor >= 2:
			message = "田埂最多放两座设施，请换一处位置。"
		elif day < int(definition.get("day", 0)):
			message = "小暖棚图纸要到第三季开放。"
		else:
			var stock: Array = farm.get("stock", [])
			var stock_index := -1
			for i in range(stock.size()):
				if str(stock[i].get("type", "")) == type:
					stock_index = i
					break
			var needs: Dictionary = {} if stock_index >= 0 else definition.get("needs", {})
			var cost := 0 if stock_index >= 0 else int(definition.get("cost", 0))
			if money < cost or not _kitchen_has(needs, 1):
				message = "设施需要 %d 金币并备齐建造材料。" % cost
			elif spend_energy(3, 5):
				money -= cost
				_kitchen_consume(needs, 1)
				if stock_index >= 0:
					var stored: Dictionary = stock.pop_at(stock_index)
					stored.anchor = anchor
					facilities.append(stored)
					farm.stock = stock
				else:
					facilities.append({"type": type, "anchor": anchor, "durability": 100.0, "enabled": true, "level": 0})
				message = str(definition.get("name", type)) + "安在田埂上，仅影响覆盖内的地块。"
	elif existing.is_empty():
		message = "没有找到这座设施。"
	elif action == "move":
		var target_count := 0
		for candidate in facilities:
			if int(candidate.get("anchor", -1)) == target:
				target_count += 1
		if target < 0 or target >= plots.size() or target == anchor or target_count >= 2 or not _farm_facility_at(target, type).is_empty():
			message = "目标田埂已满或位置无效。"
		elif spend_energy(2, 5):
			existing.anchor = target
			message = "把设施搬到了 %d 号地旁。" % (target + 1)
	elif action == "repair":
		if float(existing.get("durability", 0.0)) >= 100.0:
			message = "设施完好，无需维修。"
		elif money < 5 or int(inventory.get("wood", 0)) < 1:
			message = "维修需要木材 ×1 与 5 金币。"
		elif spend_energy(2, 5):
			money -= 5
			inventory["wood"] -= 1
			existing.durability = 100.0
			message = "绑紧竹结，设施修好了。"
	elif action == "toggle":
		existing.enabled = not bool(existing.get("enabled", true))
		message = "设施已" + ("启用。" if bool(existing.enabled) else "暂停。")
	elif action == "recover":
		var stock: Array = farm.get("stock", [])
		if stock.size() >= 144:
			message = "先重放一些收起的设施。"
		elif spend_energy(1, 5):
			existing.anchor = -1
			stock.append(existing.duplicate(true))
			facilities.erase(existing)
			farm.stock = stock
			message = "完整收起设施；等级、耐久与开关状态保留。"
	elif action == "upgrade":
		if int(existing.get("level", 0)) >= 1:
			message = "这座设施已经加固。"
		else:
			var needs: Dictionary = {}
			for item_id in definition.get("needs", {}):
				needs[item_id] = maxi(1, ceili(float(definition.needs[item_id]) / 2.0))
			var cost := ceili(float(definition.get("cost", 0)) * 0.65)
			if money < cost or not _kitchen_has(needs, 1):
				message = "加固需要 %d 金币并备齐设施材料的一半。" % cost
			elif spend_energy(2, 10):
				money -= cost
				_kitchen_consume(needs, 1)
				existing.level = 1
				message = "加固竹结、加长支架：覆盖半径增加 25%，耐久损耗减半。"
	changed.emit()

func fill_farm_water() -> bool:
	if int(farm.get("water",0))>=120:
		message="水箱已经装满。"
	elif money<6:
		message="零钱不足，需要 6 元。"
	elif not spend_energy(3,5,"",false):
		message="体力不足，先歇一会儿。"
	else:
		money-=6
		farm.water=120
		message="挑水补满 120 格储水，喷灌每次照料一块消耗 1 格。"
		changed.emit()
		return true
	changed.emit()
	return false

func fill_from_well() -> bool:
	var level := building_level("well")
	if level < 1:
		message = "先修好院落水源，再来提水。"
	elif int(farm.get("water", 0)) >= 120:
		message = "水箱已经装满。"
	else:
		var amount := mini(24 * level, 120 - int(farm.get("water", 0)))
		farm.water = int(farm.get("water", 0)) + amount
		message = "從井里提水，蓄水增加 %d 格。" % amount
		changed.emit()
		return true
	changed.emit()
	return false

func rest_at_home() -> bool:
	stamina = minf(100.0, stamina + 25.0)
	minutes = minf(1320.0, minutes + 45)
	message = "坐了一会儿，听见风穿过树叶。体力恢复 25 点。"
	changed.emit()
	return true

func set_farm_threshold(value: int) -> void:
	farm.threshold = clampi(value, 20, 65)
	changed.emit()

func _normalize_farm() -> void:
	if not farm is Dictionary:
		farm = {}
	var defaults: Dictionary = initial_state.get("farm", {})
	for key in defaults:
		if not farm.has(key):
			farm[key] = defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
	farm.version = 1
	farm.facilities = farm.get("facilities", []).duplicate(true) if farm.get("facilities", []) is Array else []
	farm.stock = farm.get("stock", []).duplicate(true) if farm.get("stock", []) is Array else []
	farm.water = clampf(float(farm.get("water", 0)), 0.0, 120.0)
	farm.threshold = clampf(float(farm.get("threshold", 40)), 20.0, 65.0)
	if not system_catalog.get("farming", {}).get("kinds", {}).has(str(farm.get("seedKind", "normal"))): farm.seedKind = "normal"
	if str(farm.get("density", "balanced")) not in ["sparse", "balanced", "dense"]: farm.density = "balanced"
	var soils: Dictionary = system_catalog.get("farming", {}).get("soils", {})
	if not soils.has(str(farm.get("selectedSoil", "loam"))): farm.selectedSoil = "loam"
	farm.autoSeed = preload("res://scripts/atlas_rules.gd").truthy(farm.get("autoSeed", false))
	farm.overlay = preload("res://scripts/atlas_rules.gd").truthy(farm.get("overlay", false))
	var definitions: Dictionary = system_catalog.get("farming", {}).get("facilities", {})
	var valid: Array = []
	var seen: Dictionary = {}
	for candidate in farm.facilities:
		if not candidate is Dictionary:
			continue
		var type := str(candidate.get("type", ""))
		var anchor := int(candidate.get("anchor", -1))
		var key := "%d:%s" % [anchor, type]
		if not definitions.has(type) or anchor < 0 or anchor >= plots.size() or seen.has(key) or float(candidate.get("durability", -1.0)) < 0.0 or float(candidate.get("durability", 101.0)) > 100.0:
			continue
		seen[key] = true
		candidate.level = clampi(int(candidate.get("level", 0)), 0, 1)
		candidate.enabled = bool(candidate.get("enabled", true))
		valid.append(candidate)
	farm.facilities = valid.slice(0, FARM_LAYOUT.TOTAL * 2)

func _building_default() -> Dictionary:
	var defaults: Dictionary = initial_state.get("building", {})
	return defaults.duplicate(true) if not defaults.is_empty() else {"version": 1, "house": 0, "land": {"orchard": false}, "levels": {"granary": 0, "workshop": 0, "well": 0, "nursery": 0}, "modes": {"granary": "fresh", "workshop": "craft", "well": "rain", "nursery": "soil"}, "jobs": [], "layout": [], "revision": 0, "nextId": 1, "style": "wood", "roomUse": "display", "showcase": null, "claimed": []}

func _normalize_building(saved: Variant = null) -> void:
	building_epoch += 1
	var defaults := _building_default()
	building = saved.duplicate(true) if saved is Dictionary else defaults
	for key in defaults:
		if not building.has(key):
			building[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
	for key in ["land", "levels", "modes"]:
		if not building.get(key) is Dictionary:
			building[key] = defaults[key].duplicate(true)
		for subkey in defaults[key]:
			if not building[key].has(subkey): building[key][subkey] = defaults[key][subkey]
	var projects: Dictionary = system_catalog.get("building", {}).get("projects", {})
	building.house = clampi(int(building.get("house", 0)), 0, 3)
	if building.house == 0 and not (saved is Dictionary and saved.has("house")):
		building.house = 2 if bool(upgrades.get("room", false)) else (1 if bool(upgrades.get("kitchen", false)) else 0)
	building.land.orchard = bool(building.land.get("orchard", false))
	for project_id in ["granary", "workshop", "well", "nursery"]:
		var project: Dictionary = projects.get(project_id, {})
		building.levels[project_id] = clampi(int(building.levels.get(project_id, 0)), 0, int(project.get("max", 2)))
	var valid_modes := {"granary": ["fresh", "supply"], "workshop": ["craft", "tools"], "well": ["rain", "spring"], "nursery": ["soil", "seed"]}
	for project_id in valid_modes:
		if not valid_modes[project_id].has(str(building.modes.get(project_id, ""))): building.modes[project_id] = defaults.modes[project_id]
	var jobs: Array = building.get("jobs", []) if building.get("jobs", []) is Array else []
	var clean_jobs: Array = []
	var seen: Dictionary = {}
	for job in jobs:
		if not job is Dictionary: continue
		var project_id := str(job.get("id", ""))
		var project: Dictionary = projects.get(project_id, {})
		var level := int(job.get("level", 0))
		if project.is_empty() or seen.has(project_id) or level != int(building_level(project_id)) + 1 or level > int(project.get("max", 0)): continue
		seen[project_id] = true
		clean_jobs.append({"id": project_id, "level": level, "readyDay": maxi(day, int(job.get("readyDay", day + 1)))})
	building.jobs = clean_jobs.slice(0, 4)
	var definitions: Dictionary = system_catalog.get("building", {}).get("defs", {})
	var layout: Array = building.get("layout", []) if building.get("layout", []) is Array else []
	var valid_layout: Array = []
	var keys: Dictionary = {}
	for piece in layout:
		if not piece is Dictionary: continue
		var key := int(piece.get("key", 0))
		var type := str(piece.get("type", ""))
		var zone := str(piece.get("zone", ""))
		var zone_data: Dictionary = system_catalog.get("building", {}).get("zones", {}).get(zone, {})
		if key < 1 or keys.has(key) or not definitions.has(type) or zone_data.is_empty(): continue
		var cell := int(piece.get("cell", -1))
		var rotation := posmod(int(piece.get("rotation", 0)), 4)
		if cell < 0 or cell >= int(zone_data.cols) * int(zone_data.rows): continue
		keys[key] = true
		valid_layout.append({"key": key, "type": type, "zone": zone, "cell": cell, "rotation": rotation})
	building.layout = valid_layout.slice(0, 100)
	building.revision = maxi(0, int(building.get("revision", 0)))
	building.nextId = maxi(1, int(building.get("nextId", 1)))
	for piece in building.layout: building.nextId = maxi(int(building.nextId), int(piece.key) + 1)
	if not ["wood", "blue", "plum"].has(str(building.get("style", "wood"))): building.style = "wood"
	if not ["display", "workshop", "nursery", "storage"].has(str(building.get("roomUse", "display"))): building.roomUse = "display"
	building.claimed = building.get("claimed", []) if building.get("claimed", []) is Array else []


func building_task_destination(task: Dictionary) -> Dictionary:
	if str(task.get("op","")).begins_with("economy-"): return economy_task_destination(task)
	var op := str(task.get("op",""))
	var name := "农具间" if op in ["craft","tool"] else str(system_catalog.get("building",{}).get("projects",{}).get(str(task.get("id","")),{}).get("house","爷爷的老屋"))
	for house in world_village.get("houses",[]):
		if str(house.get("name",""))==name:
			var door: Dictionary = house.get("door",{}).duplicate(true)
			door.merge({"id":"building-task","kind":"build-task","name":"木工案" if op=="craft" else name,"building_task":true,"world_click":current_interior=="","click_room":"","auto_interact":true,"room":null},true)
			return door
	return {}

func perform_building_task(task: Dictionary) -> bool:
	if str(task.get("op","")).begins_with("economy-"): return perform_economy_task(task)
	match str(task.get("op","")):
		"project": return start_building_project(str(task.get("id","")),true)
		"legacy": return perform_legacy_upgrade(str(task.get("id","")))
		"craft":
			var count: Variant = task.get("n",1)
			if not (count is int or count is float) or float(count)!=float(int(count)):
				message = "请选择整数家具数量。"
				return false
			return craft_furniture(str(task.get("id","")),int(count) if int(count)!=0 else 1,true)
		"tool": return upgrade_tool(str(task.get("id","")))
	message = "没有这项营造操作。"
	return false

func preview_building_task(task: Dictionary) -> Dictionary:
	var copy = get_script().new()
	for field in get_property_list():
		if int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var value: Variant = get(str(field.name))
		if value is Dictionary or value is Array: value = value.duplicate(true)
		copy.set(str(field.name),value)
	var ok: bool = copy.perform_building_task(task)
	var result := {"ok":ok,"message":str(copy.message)}
	copy.free()
	return result

func queue_building_task(task: Dictionary) -> bool:
	var check := preview_building_task(task)
	if not bool(check.ok):
		message = str(check.message)
		changed.emit()
		return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	cancel_action()
	source_keyboard.clear()
	var world: Node = players[0].get_parent()
	if world.get("hud")!=null: world.get("hud").close_top_panel()
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	walking_target.clear()
	building_task = task.duplicate(true)
	return advance_building_task()

func advance_building_task() -> bool:
	if building_task.is_empty(): return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	var target := building_task_destination(building_task)
	if target.is_empty() or not players[0].walk_to(target):
		building_task.clear()
		return false
	return true

func finish_building_task(target: Dictionary) -> void:
	if building_task.is_empty() or not bool(target.get("building_task",false)): return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var actual := building_task_destination(building_task)
	if current_interior!="" or actual.is_empty() or players[0].global_position.distance_to(Vector2(float(actual.x),float(actual.y)))>=53.0:
		stop_walking()
		return
	if not bool(target.get("_sequence_resolved",false)):
		var point := target.duplicate(true)
		point.op = str(building_task.get("op",""))
		if building_task.has("id"):point.item=building_task.id
		_begin_task_action(point,finish_building_task)
		return
	var task := building_task.duplicate(true)
	building_task.clear()
	confirm_operation(perform_building_task(task))
	changed.emit()

func _building_has(needs: Dictionary) -> bool:
	for id in needs:
		if int(needs[id])>0 and economy.get("locked",[]).has(str(id)): return false
	return _kitchen_has(needs,1)

func perform_legacy_upgrade(id: String) -> bool:
	var definition: Dictionary = content.get("upgrades",{}).get(id,{})
	var needs: Dictionary = definition.get("materials",{})
	if needs.keys().any(func(item_id): return economy.get("locked",[]).has(str(item_id))):
		message = "需要的物品已锁定，请先在背包解除保护。"
	elif id in ["kitchen","room","roof"] and building.get("jobs",[]).any(func(job): return str(job.get("id",""))=="house"):
		message = "老屋正在扩建，明日再安排基础修缮。"
	elif id=="irrigation" and not bool(community_projects.get("canal",false)):
		message = "先和大家疏通旧水渠，再接院内蓄水。"
	elif definition.is_empty() or bool(upgrades.get(id,false)):
		message = "这里已经修好了。"
	elif money<int(definition.cost) or not _building_has(definition.get("materials",{})):
		message = "材料或零钱还没备齐。竹林和野山都有可用的材料。"
	else:
		money -= int(definition.cost)
		_reconcile_kitchen_lots()
		_kitchen_consume(needs,1)
		upgrades[id] = true
		_award_skill_xp("craft",8)
		if id=="yard":
			for item in ["bench","pot","path"]: furniture[item] = int(furniture.get(item,0))+1
		if id=="irrigation":
			legacy_systems.waterReserve = 3
			for index in range(plots.size()):
				if farm.facilities.filter(func(f): return int(f.get("anchor",-1))==index).size()<2 and _farm_facility_at(index,"sprinkler").is_empty():
					farm.facilities.append({"type":"sprinkler","anchor":index,"durability":100,"enabled":true})
					break
			farm.water = 120
		if id=="coop":
			var barn: Dictionary = ranch.barns.poultry
			barn.space = maxi(1,int(barn.get("space",0)))
			barn.autoFeed = true
			barn.autoFeedBuilt = true
		building.house = maxi(int(building.house),2 if bool(upgrades.get("room",false)) else 1 if bool(upgrades.get("kitchen",false)) else 0)
		building.revision = int(building.revision)+1
		_record_community_log("和邻居一起"+str(definition.name)+"。",false)
		message = str(definition.name)+"完成了！院子有了新的变化。"
		if id == "irrigation": message += " 配送一座局部竹管喷灌与满箱储水，可在四时农事中搬动。"
		if id == "coop": message += " 鸡鸭舍新增床位和自动食槽；请在牧场料仓存入饲料。"
		changed.emit()
		return true
	changed.emit()
	return false

func building_level(project_id: String) -> int:
	if project_id == "house": return int(building.get("house", 0))
	if project_id == "orchard": return 1 if bool(building.get("land", {}).get("orchard", false)) else 0
	return int(building.get("levels", {}).get(project_id, 0))

func building_quote(project_id: String) -> Dictionary:
	var project: Dictionary = system_catalog.get("building", {}).get("projects", {}).get(project_id, {})
	var level := building_level(project_id)
	if project.is_empty() or level >= int(project.get("max", 0)): return {}
	return {"money": int(project.cost[level]), "wood": int(project.wood[level]), "bamboo": int(project.bamboo[level]), "level": level + 1}

func start_building_project(project_id: String, at_worksite: bool) -> bool:
	var project: Dictionary = system_catalog.get("building", {}).get("projects", {}).get(project_id, {})
	var quote := building_quote(project_id)
	if project.is_empty() or quote.is_empty(): message = "這項工程已完成，或暫時沒有可用圖紙。"
	elif not at_worksite: message = "請走到「%s」門前再安排施工。" % str(project.get("house", "工坊"))
	elif building.jobs.any(func(job): return str(job.get("id", "")) == project_id): message = "這處正在施工，明日竣工。"
	elif building.jobs.size() >= 4: message = "木生叔正照看四處工程，明日再安排。"
	elif project_id == "orchard" and not bool(upgrades.get("yard", false)): message = "先整理庭院，再拓出西院。"
	elif money < int(quote.money): message = "還需要 %d 金币。" % int(quote.money)
	elif not _building_has({"wood":int(quote.wood),"bamboo":int(quote.bamboo)}): message = "备料不足：需要木材 ×%d、竹材 ×%d。" % [int(quote.wood), int(quote.bamboo)]
	elif not spend_energy(3, 10): return false
	else:
		money -= int(quote.money)
		_kitchen_consume({"wood":int(quote.wood),"bamboo":int(quote.bamboo)},1)
		building.jobs.append({"id": project_id, "level": int(quote.level), "readyDay": day + 1})
		message = "已备好%s第 %d 阶材料，明日竣工。" % [str(project.name), int(quote.level)]
		changed.emit()
		return true
	changed.emit()
	return false

func is_near_building(house_name: String, radius: float = 96.0) -> bool:
	for house in world_village.get("houses", []):
		if str(house.get("name", "")) != house_name: continue
		if current_interior != "" and str(house.get("id", "")) == current_interior: return true
		var door: Dictionary = house.get("door", {})
		var point := Vector2(float(door.get("x", 0)), float(door.get("y", 0)))
		return player_position.distance_to(point) <= radius
	return false

func enter_interior(house_id: String) -> bool:
	if not enter_room_state(house_id):return false
	sound_requested.emit("soft")
	get_tree().change_scene_to_file("res://scenes/interior.tscn")
	return true

func enter_room_state(house_id: String) -> bool:
	if current_interior != "": return false
	for house in world_village.get("houses", []):
		if str(house.get("id", "")) != house_id: continue
		var door: Dictionary = house.get("door", {})
		if _atlas_hypot(float(player_source_position.x)-float(door.x),float(player_source_position.y)-float(door.y))>70.0:return false
		interior_return_source={"x":float(door.x),"y":float(door.y)+12.0,"direction":"down"}
		current_interior = house_id
		walking_target.clear()
		riding = false
		interior_npc_positions.clear()
		interior_position = Vector2(480, 567)
		player_direction = "up"
		return true
	return false

func leave_interior(continue_walk: bool = false) -> void:
	if current_interior == "": return
	if not continue_walk:
		cancel_farm_queue()
		cancel_ranch_queue()
		walking_target.clear()
		kitchen_task.clear()
		museum_task.clear()
		npc_task.clear()
		building_task.clear()
	if not leave_room_state():return
	sound_requested.emit("soft")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func leave_room_state() -> bool:
	if current_interior=="":return false
	if atlas_source_navigation==null:atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
	atlas_source_navigation.refresh(self)
	var origin: Dictionary=interior_return_source if interior_return_source is Dictionary else interior_house().door
	var safe:Dictionary=atlas_source_navigation.safe(self,"",origin)
	player_source_position={"x":float(safe.x),"y":float(safe.y)}
	player_direction=str(safe.get("direction","down"))
	current_interior = ""
	interior_return_source=null
	interior_npc_positions.clear()
	return true


func interior_house() -> Dictionary:
	for house in world_village.get("houses", []):
		if str(house.get("id", "")) == current_interior: return house
	return {}

func inspect_interior_point(point: Dictionary) -> bool:
	var room := interior_house()
	if room.is_empty():
		message = "走进小屋再看看。"
		changed.emit()
		return false
	var point_id := str(point.get("id", ""))
	if point_id == "": return false
	var memories: Dictionary = interior_state.get("memories", {})
	var first_visit := not memories.has(point_id)
	memories[point_id] = day
	interior_state.memories = memories
	# Public buildings have a JSON null owner. Converting null to text would
	# create a phantom "<null>" relationship and break the feedback formatter.
	var owner := str(room.get("owner")) if room.get("owner") != null else ""
	if first_visit:
		var label := str(point.get("name", "")).replace("动手看看 · ", "")
		_record_community_log("在%s发现了%s。" % [str(room.get("name", "")), label], false)
		if owner != "" and relations.has(owner):
			var relation: Dictionary = relations[owner]
			relation.points = mini(100, int(relation.get("points", 0)) + 1)
			relations[owner] = relation
	var profiles: Dictionary = system_catalog.get("interiors", {}).get("profiles", {})
	var profile: Variant = profiles.get(owner, [])
	var text_index := 5 + int(point.get("index", 0)) * 2
	var story := "这里收藏着%s平常却珍贵的一天。" % str(room.get("name", ""))
	if profile is Array and text_index >= 0 and text_index < profile.size(): story = str(profile[text_index])
	var stories: Array = feedback_action_runtime.get("stories", [])
	stories.append({"x": point.get("x", 480), "y": float(point.get("y", 400)) - 55.0, "text": story, "at": feedback_action_runtime.clock, "duration": 4.0})
	feedback_action_runtime.stories = stories
	feedback_action_runtime.room = current_interior
	message = "收下一段屋里的小故事。" if first_visit else "又看见了熟悉的小细节。"
	changed.emit()
	return true

func claim_letter(letter_id: String) -> bool:
	var letter: Dictionary = {}
	for candidate in letters:
		if str(candidate.get("id", "")) == letter_id:
			letter = candidate
			break
	if letter.is_empty():
		message = "没有这封信。"
		changed.emit()
		return false
	if mail_read.has(letter_id):
		message = "这封信已经好好收好了。"
		changed.emit()
		return false
	mail_read.append(letter_id)
	var gifts: Dictionary = letter.get("gift", {}) if letter.get("gift", {}) is Dictionary else {}
	for item_id in gifts:
		var key := str(item_id)
		var quantity := maxi(0, int(gifts[item_id]))
		if quantity <= 0 or not item_catalog.has(key): continue
		_reconcile_kitchen_lots()
		_add_inventory_count(key, quantity)
		var discovered: Array = legacy_systems.get("discovered", [])
		if not discovered.has(key): discovered.append(key)
		legacy_systems.discovered = discovered
		_reconcile_kitchen_lots()
	message = "收好了%s的信%s" % [str(letter.get("from", "寄信人")), "和随信的小礼物。" if letter.get("gift") is Dictionary else "。"]
	changed.emit()
	return true

func _advance_letters() -> void:
	var season := season_index()
	var date := posmod(day, 28) + 1
	var chapters: Array = content.get("seasonChapters", [])
	if date == 1 and season < chapters.size():
		var chapter: Dictionary = chapters[season]
		letters.push_front({"id": "season-%d-%d" % [int(day / 112) + 1, season], "day": day, "from": "禾溪邻里", "title": str(chapter.get("title", "四季来信")), "text": str(chapter.get("goal", "新的一季也可以慢慢来。")) + " 错过也能在生活簿补看补做。", "gift": {"feed": 3}})
	if day % 7 == 0:
		var known: Array[Dictionary] = []
		for person in npc_catalog:
			var npc_id := str(person.get("id", ""))
			if int(relations.get(npc_id, {}).get("points", 0)) >= 30: known.append(person)
		if not known.is_empty():
			var person: Dictionary = known[posmod(int(day / 7), known.size())]
			letters.push_front({"id": "visit-%d" % day, "day": day, "from": str(person.get("name", "邻居")), "title": "有空来坐坐", "text": "这一周有空就来喝茶、吃饭。忙的话晚些来也行。带两份米给你，别忘了吃饭。", "gift": {"rice": 2}})
			if bool(community_projects.get("canal", false)):
				_record_community_log(str(person.get("name", "邻居")) + "顺路帮忙润湿了菜地。")
	while letters.size() > 150: letters.pop_back()

func open_mailbox() -> void:
	var unread := 0
	for letter in letters:
		if not mail_read.has(str(letter.get("id", ""))): unread += 1
	message = "信箱里有 %d 封未读来信。" % unread
	changed.emit()

func perform_interior_chore(point: Dictionary) -> bool:
	var action := str(point.get("action", ""))
	var point_id := str(point.get("id", ""))
	if point_id == "" or action == "": return false
	var chores: Dictionary = interior_state.get("chores", {})
	var repeatable := action in ["wind", "bell", "wash"]
	if not repeatable and int(chores.get(point_id, -1)) == day:
		message = "今天已经照料好了。"
		changed.emit()
		return false
	match action:
		"feed":
			if int(inventory.get("feed", 0)) < 1:
				message = "带一份草谷饲料来补草架吧。"
				changed.emit()
				return false
			inventory.feed -= 1
			for animal in animals: animal.fed = true
			message = "草架添满，伙伴们慢慢围了过来。"
		"brush":
			for animal in animals: animal.bond = mini(100, int(animal.get("bond", 0)) + 2)
			message = "浮毛梳干净，伙伴们舒服地眯起眼。"
		"compost":
			if not spend_energy(3, 8): return false
			_add_inventory_count("compost", 1)
			message = "翻好堆肥，收下一份熟堆肥。"
		"churn":
			if int(inventory.get("milk", 0)) < 1:
				message = "带一份鲜奶来，试试手摇乳桶吧。"
				changed.emit()
				return false
			inventory.milk -= 1
			stamina = minf(100.0, stamina + 15.0)
			message = "摇匀一杯温奶，体力恢复 15。"
		"water":
			for animal in animals: animal.bond = mini(100, int(animal.get("bond", 0)) + 1)
			message = "清水缓缓流进槽里。"
		"wind": message = "风车转起来了，叶片投下一圈圈影子。"
		"bell": message = "叮——铜铃把伙伴们唤了过来。"
		"wash": message = "水珠落下，菜叶亮晶晶。"
		_: message = "轻轻动一动，屋里有了回应。"
	if action in ["feed","brush","water","bell"]:
		gather_ranch_actors(Vector2(float(point.get("x",player_position.x)),float(point.get("y",player_position.y))))
	if not repeatable:
		chores[point_id] = day
		interior_state.chores = chores
	changed.emit()
	return true

func set_building_mode(project_id: String, mode_id: String) -> bool:
	var choices: Array = system_catalog.get("building", {}).get("modes", {}).get(project_id, [])
	if building_level(project_id) >= 1:
		for choice in choices:
			if str(choice[0]) == mode_id:
				building.modes[project_id] = mode_id
				message = "已调整用途，次日起按新安排运作。改换方向不再收费。"
				changed.emit()
				return true
	message = "先完成这处改良，再选用途。"
	changed.emit()
	return false

func upgrade_yard(at_home: bool) -> bool:
	if not at_home:
		message = "请先走到老屋门前。"
		changed.emit()
		return false
	return perform_legacy_upgrade("yard")

func craft_furniture(item_id: String, quantity: int, at_workshop: bool) -> bool:
	var definitions: Dictionary = system_catalog.get("building", {}).get("defs", {})
	var catalog: Dictionary = content.get("furniture", {})
	var definition: Dictionary = definitions.get(item_id, {})
	var item: Dictionary = catalog.get(item_id, {})
	if not at_workshop: message = "请走到竹木工坊门前再制作家具。"
	elif definition.is_empty() or item.is_empty() or quantity < 1 or quantity > 10: message = "请选择有效家具与 1—10 件数量。"
	elif str(definition.get("where", "both")) == "yard" and not bool(upgrades.get("yard", false)): message = "先整理庭院，才能制作这类室外家具。"
	elif item_id == "greenhouse" and day < 56: message = "小温棚图纸在秋季开放。"
	else:
		var needs: Dictionary = item.get("needs", {}).duplicate(true)
		var saving := building_level("workshop") if str(building.get("modes", {}).get("workshop", "craft")) == "craft" else 0
		if int(needs.get("wood", 0)) > 0 and saving > 0: needs.wood = maxi(1, int(needs.wood) - saving)
		for item_name in needs: needs[item_name] = int(needs[item_name]) * quantity
		for item_name in needs:
			if not _building_has({str(item_name):int(needs[item_name])}): message = "材料不足：%s ×%d。" % [str(item_catalog.get(str(item_name), {}).get("name", item_name)), int(needs[item_name])]; changed.emit(); return false
		if not spend_energy(2, 10): return false
		_kitchen_consume(needs,1)
		furniture[item_id] = int(furniture.get(item_id, 0)) + quantity
		_award_skill_xp("craft", quantity * 3)
		if str(skills.get("craft", {}).get("choice", "")) == "reuse" and int(item.get("needs", {}).get("wood", 0)) > 0:
			_add_inventory_count("wood", quantity)
		message = "%s ×%d 已做好，打开布局图布置。" % [str(item.get("name", item_id)), quantity]
		if str(skills.get("craft", {}).get("choice", "")) == "reuse" and int(item.get("needs", {}).get("wood", 0)) > 0:
			message += " 回收边角料，木料返还 ×%d。" % quantity
		changed.emit()
		return true
	changed.emit()
	return false

func building_placement_valid(piece: Dictionary, layout: Array) -> Dictionary:
	return BUILDING_GEOMETRY.placement(self, piece, layout)

func check_building_layout(layout: Array) -> Dictionary:
	return BUILDING_GEOMETRY.check_layout(self, layout)

func apply_building_layout(next_layout: Array, base_revision: int, base_epoch: int = -1) -> bool:
	var result: Dictionary
	if base_epoch >= 0 and base_epoch != building_epoch:
		result = {"ok": false, "message": "场地刚有变化，请重新打开布置图。"}
	else:
		result = BUILDING_GEOMETRY.commit(self, next_layout, base_revision)
	message = str(result.message)
	changed.emit()
	return bool(result.ok)

func _building_layout_accessible(layout: Array, zone_id: String) -> bool:
	return BUILDING_GEOMETRY.accessible(self, layout, zone_id)

func configure_building(field: String, value: Variant) -> bool:
	var valid := false
	if field == "style": valid = value in ["wood", "blue", "plum"]
	elif field == "roomUse": valid = value in ["display", "workshop", "nursery", "storage"] and int(building.get("house",0)) >= 3
	elif field == "showcase": valid = value == null or legacy_systems.get("discovered",[]).has(value)
	if not valid:
		message = "这项装修尚未开放或选择无效。"
		changed.emit()
		return false
	building[field] = value
	building.revision = int(building.get("revision",0)) + 1
	message = "家的新样子已经记下，之后也可以随时更换。"
	changed.emit()
	return true

func set_building_furniture_style(style_id: String) -> bool:
	return configure_building("style",style_id)

func set_building_room_use(room_use: String) -> bool:
	return configure_building("roomUse",room_use)

func set_building_showcase(item_id: String) -> bool:
	return configure_building("showcase",null if item_id == "" else item_id)

func legacy_furniture_slots() -> Array:
	var rows:Array=[]
	for piece in legacy_systems.get("layouts",[]):
		if not piece is Dictionary:continue
		var slot:int=int(piece.get("slot",-1))
		if slot<0 or slot>=24 or not content.get("furniture",{}).has(str(piece.get("id",""))):continue
		rows.append({"id":str(piece.id),"slot":slot,"x":float([536,644,752,1032,1140,1248][slot%6])+1920.0,"y":874.0+floorf(float(slot)/6.0)*52.0+1152.0})
	return rows

func recover_legacy_furniture(slot: int) -> bool:
	var layouts:Array=legacy_systems.get("layouts",[])
	for i in range(layouts.size()):
		if int(layouts[i].get("slot",-1))!=slot:continue
		var id:String=str(layouts[i].id)
		layouts.remove_at(i)
		furniture[id]=int(furniture.get(id,0))+1
		legacy_systems.greenhouse=layouts.any(func(piece:Dictionary)->bool:return str(piece.get("id",""))=="greenhouse")
		building.revision=int(building.get("revision",0))+1
		message="家具已经收好，材料和家具不会损失。"
		changed.emit()
		return true
	message="这一格没有家具。"
	changed.emit()
	return false

func building_milestone_ready(milestone_id: String) -> bool:
	var claimed: Array = building.get("claimed", [])
	if claimed.has(milestone_id): return false
	if milestone_id == "home": return int(building.get("house", 0)) >= 1
	if milestone_id == "garden":
		var count := 0
		for piece in building.get("layout", []):
			if str(piece.get("zone", "")) != "home": count += 1
		return count >= 5
	if milestone_id == "living":
		var count := 0
		for level in building.get("levels", {}).values():
			if int(level) > 0: count += 1
		return count >= 3
	if milestone_id == "collection":
		for piece in building.get("layout", []):
			if int(building.get("house", 0)) >= 3 and str(piece.get("type", "")) == "display": return true
	return false

func claim_building_milestone(milestone_id: String) -> bool:
	var milestone: Dictionary = system_catalog.get("building", {}).get("milestones", {}).get(milestone_id, {})
	if milestone.is_empty() or not building_milestone_ready(milestone_id):
		message = "这份院落纪念尚未完成或已经领取。"
		changed.emit()
		return false
	var reward := str(milestone.reward)
	building.claimed.append(milestone_id)
	furniture[reward] = int(furniture.get(reward, 0)) + 1
	message = "邻里送来" + str(content.furniture[reward].name) + "，谢谢你把小院照料得有生气。"
	changed.emit()
	return true

func _advance_building(previous_day: int) -> void:
	var projects: Dictionary = system_catalog.get("building", {}).get("projects", {})
	var remaining: Array = []
	for job in building.get("jobs", []):
		if int(job.get("readyDay", day + 1)) > day: remaining.append(job); continue
		var project_id := str(job.id)
		var level := int(job.level)
		if project_id == "house":
			building.house = level
			upgrades.roof = true
			upgrades.kitchen = true
			if level >= 2: upgrades.storage = true; upgrades.room = true
		elif project_id == "orchard": building.land.orchard = true
		else:
			building.levels[project_id] = level
			if project_id == "granary": upgrades.storage = true
		building.revision = int(building.revision) + 1
		message = "%s第 %d 阶竣工。" % [str(projects.get(project_id, {}).get("name", "工程")), level]
		_record_community_log(message, false)
	building.jobs = remaining
	var levels: Dictionary = building.get("levels", {})
	if int(levels.get("well", 0)) > 0:
		var well_level := int(levels.well)
		var water_gain := 8 * well_level if str(building.modes.well) == "spring" else 24 * well_level if weather_for(previous_day) in ["雨", "台风"] else 0
		farm.water = mini(120, int(farm.get("water", 0)) + water_gain)
	if int(levels.get("workshop", 0)) > 0 and str(building.modes.workshop) == "tools":
		for facility in farm.get("facilities", []): facility.durability = minf(100.0, float(facility.get("durability", 100.0)) + 2.0 * int(levels.workshop))
	if int(levels.get("nursery", 0)) > 0:
		var nursery_level := int(levels.nursery)
		if str(building.modes.nursery) == "soil":
			for index in range(mini(FARM_LAYOUT.MAIN_COUNT, plots.size())):
				if str(plots[index].get("crop", "")) == "": plots[index].fertility = minf(100, float(plots[index].get("fertility", 50)) + nursery_level)
		elif day % 7 == 0:
			var seasonal_seed := ""
			for crop_id in crop_catalog:
				if crop_in_season(str(crop_id)): seasonal_seed = seed_item_id(str(crop_id)); break
			if seasonal_seed != "":
				_grant_legacy_item(seasonal_seed, 2 * nursery_level)
	if int(levels.get("granary", 0)) >= 2 and str(building.modes.granary) == "fresh":
		for lots in kitchen.get("lots", {}).get("storage",{}).values():
			for lot in lots: lot.age = maxf(0.0, float(lot.get("age", 0.0)) - (0.125 if bool(kitchen.get("cold", false)) else 0.25))

func shop_price(item_id: String) -> int:
	var item: Dictionary = item_catalog.get(item_id, {})
	var raw_cost: Variant = item.get("cost", null)
	var base := int(raw_cost) if raw_cost != null else (24 if item_id == "rice" else 0)
	if base <= 0:
		return 0
	var raw_price: Variant = item.get("price", null)
	return maxi(base, ceili(float(raw_price) * 1.85) if raw_price != null else base)

func daily_offers() -> Array[String]:
	var pool: Array[String] = []
	for item_id in item_catalog:
		var normalized := str(item_id)
		if shop_price(normalized) > 0 and not normalized.ends_with("_heirloom") and not normalized.ends_with("_seasonal"):
			pool.append(normalized)
	var offers: Array[String] = []
	if pool.is_empty():
		return offers
	for n in range(3):
		var item_id := pool[(day * 7 + n * 11) % pool.size()]
		if not offers.has(item_id):
			offers.append(item_id)
	return offers


func economy_task_destination(task: Dictionary) -> Dictionary:
	var job: Dictionary = {}
	for candidate in economy.get("jobs",[]):
		var task_key: Variant = task.get("key",-2)
		if (task_key is int or task_key is float) and float(candidate.get("key",-1))==float(task_key): job = candidate; break
	var coop := str(task.get("op",""))=="economy-order" or (str(task.get("op",""))=="economy-send" and str(task.get("channel",""))=="coop") or str(job.get("channel",""))=="coop"
	var house_name := "禾溪合作社" if coop else "许婶杂货"
	for house in world_village.get("houses",[]):
		if str(house.get("name",""))!=house_name: continue
		var target: Dictionary = house.get("door",{}).duplicate(true)
		target.merge({"id":"building-task","kind":"build-task","building_task":true,"name":"禾溪合作社 · 交接货单" if coop else "老街摊位 · 整理竹匾" if str(task.get("channel",job.get("channel","")))=="stall" else "许婶柜台 · 买卖","room":null,"world_click":current_interior=="","click_room":"","auto_interact":true},true)
		return target
	return {}

func perform_economy_task(task: Dictionary) -> bool:
	var id := str(task.get("id",""))
	var count: Variant = task.get("n",1)
	var grade: Variant = task.get("grade",-1)
	if not (count is int or count is float) or float(count)!=float(int(count)) or not (grade is int or grade is float) or float(grade)!=float(int(grade)):
		message = "交易数量与品质必须为整数。"
		return false
	if str(task.get("op","")) in ["economy-buyback","economy-collect"]:
		var key: Variant = task.get("key",-1)
		if not (key is int or key is float) or float(key)!=float(int(key)):
			message = "这张货签不存在。"
			return false
	match str(task.get("op","")):
		"economy-buy": return buy_item(id,int(count),bool(task.get("special",false)))
		"economy-sell": return sell_item(id,int(count),int(grade))
		"economy-send": return send_economy_goods(id,int(count),int(grade),str(task.get("channel","")),str(task.get("theme","breakfast")))
		"economy-buyback": return buyback_item(int(task.get("key",-1)))
		"economy-collect": return collect_economy_job(int(task.get("key",-1)),bool(task.get("cancel",false)))
		"economy-order": return fulfill_economy_order(id)
		"economy-batch": return sell_economy_batch(task.get("lines",[]))
	message = "请选择有效交易。"
	return false

func sell_economy_batch(lines: Variant) -> bool:
	if not lines is Array or lines.is_empty() or lines.size()>12:
		message = "售货篮可装 1—12 条货签。"
		return false
	var copy = get_script().new()
	for field in get_property_list():
		if int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var value: Variant = get(str(field.name))
		if value is Dictionary or value is Array: value = value.duplicate(true)
		copy.set(str(field.name),value)
	for line in lines:
		if not line is Dictionary or not copy.perform_economy_task({"op":"economy-sell","id":line.get("id",""),"n":line.get("n",0),"grade":line.get("grade",-1)}):
			message = str(copy.message)
			copy.free()
			changed.emit()
			return false
	var income := int(copy.money)-money
	for key in ["money","inventory","quality","kitchen","economy","player_stats","flags","museum_entries","legacy_systems"]:
		var value: Variant = copy.get(key)
		if value is Dictionary or value is Array: value = value.duplicate(true)
		set(key,value)
	copy.free()
	message = "整篮已交柜台，收到 %d 元；各批货签可单独回购。"%income
	changed.emit()
	return true

func _refresh_economy_day(reset_daily: bool = false) -> void:
	if economy.is_empty():
		economy = initial_state.get("economy", {}).duplicate(true)
	economy = preload("res://scripts/economy_lifecycle.gd").normalize(economy,day,reset_daily)

func _record_trade(kind: String, item_id: String, quantity: int, change: int) -> void:
	_urgent_autosave = true
	var ledger: Array = economy.get("ledger", [])
	ledger.push_front({"day": day, "kind": kind, "id": item_id, "qty": quantity, "money": change})
	while ledger.size() > 80:
		ledger.pop_back()
	economy.ledger = ledger

func market_factor(item_id: String) -> float:
	var crop: Dictionary = crop_catalog.get(item_id, {})
	var factor := 1.0
	if not crop.is_empty():
		factor *= 0.96 if crop_in_season(item_id) else 1.08
	factor *= [1.0, 1.04, 0.98][int(day / 112) % 3]
	if day % 7 == 5:
		var crop_ids: Array[String] = []
		for crop_id in crop_catalog: crop_ids.append(str(crop_id))
		if not crop_ids.is_empty() and crop_ids[posmod(int(day / 7), crop_ids.size())] == item_id: factor *= 1.2
	if (day % 28) >= 11 and (day % 28) <= 14 and str(item_catalog.get(item_id, {}).get("kind", "")) == "料理":
		factor *= 1.1
	return minf(1.6, factor)

func _economy_selected_counts(item_id: String, quantity: int, grade: int = -1) -> Array[int]:
	if not item_catalog.has(item_id) or quantity < 1 or grade < -1 or grade > 3:
		return []
	var counts := _quality_counts(item_id)
	var selected: Array[int] = [0, 0, 0, 0]
	var remaining := quantity
	for tier in range(4):
		if grade >= 0 and tier != grade: continue
		selected[tier] = mini(remaining, counts[tier])
		remaining -= selected[tier]
	if remaining>0: selected.clear()
	return selected

func _economy_take_packet(item_id: String, quantity: int, grade: int = -1) -> Dictionary:
	var selected := _economy_selected_counts(item_id, quantity, grade)
	if selected.is_empty(): return {}
	_reconcile_kitchen_lots()
	var counts := _quality_counts(item_id)
	inventory[item_id] = int(inventory.get(item_id, 0)) - quantity
	quality[item_id] = [counts[1] - selected[1], counts[2] - selected[2], counts[3] - selected[3]]
	var lots: Array = []
	if _is_food(item_id):
		var all_lots: Dictionary = kitchen.get("lots", {})
		var bag_lots: Dictionary = all_lots.get("bag", {})
		var source: Array = bag_lots.get(item_id, [])
		var remaining := quantity
		while remaining > 0 and not source.is_empty():
			var first: Dictionary = source[0]
			var taken := mini(remaining, int(first.get("qty", 0)))
			lots.append({"qty": taken, "age": float(first.get("age", 0.0))})
			first.qty = int(first.get("qty", 0)) - taken
			remaining -= taken
			if int(first.qty) <= 0: source.pop_front()
		if source.is_empty(): bag_lots.erase(item_id)
		else: bag_lots[item_id] = source
		all_lots.bag = bag_lots
		kitchen.lots = all_lots
	return {"id": item_id, "qty": quantity, "grades": selected, "lots": lots}

func _economy_restore_packet(packet: Dictionary, elapsed_days: int = 0) -> void:
	var item_id := str(packet.get("id", ""))
	var grades: Array = packet.get("grades", [0, 0, 0, 0])
	if item_id == "" or not item_catalog.has(item_id) or grades.size() != 4: return
	_restore_item(item_id, grades)
	if _is_food(item_id):
		var all_lots: Dictionary = kitchen.get("lots", {"bag": {}, "storage": {}})
		var bag_lots: Dictionary = all_lots.get("bag", {})
		var destination: Array = bag_lots.get(item_id, [])
		for lot in packet.get("lots", []):
			if lot is Dictionary and int(lot.get("qty", 0)) > 0:
				destination.append({"qty": int(lot.qty), "age": minf(3650.0, float(lot.get("age", 0.0)) + float(elapsed_days))})
		destination.sort_custom(func(a, b): return float(a.get("age", 0.0)) > float(b.get("age", 0.0)))
		bag_lots[item_id] = destination
		all_lots.bag = bag_lots
		kitchen.lots = all_lots
	_museum_sync()
	_reconcile_kitchen_lots()

func _economy_theme_matches(item_id: String, theme: String) -> bool:
	var item: Dictionary = item_catalog.get(item_id, {})
	match theme:
		"breakfast": return str(item.get("kind", "")) == "料理" or item_id in ["egg", "milk", "duckEgg"]
		"orchard": return item_id in ["berry", "tea", "dryTea", "berryJam", "summerDrink"]
		"pantry": return str(item.get("kind", "")) == "加工物" or item_id in ["rice", "wheat", "bean", "sesame", "peanut"]
	return false

func economy_quote(item_id: String, quantity: int = 1, grade: int = -1, channel: String = "instant", theme: String = "breakfast") -> Dictionary:
	var selected := _economy_selected_counts(item_id, quantity, grade)
	if selected.is_empty(): return {"available": false, "money": 0, "selected": []}
	var weighted := 0.0
	for tier in range(4): weighted += float(selected[tier]) * [1.0, 1.2, 1.4, 1.7][tier]
	var fresh_ratio := float(food_freshness(item_id, quantity).ratio) if _is_food(item_id) else 1.0
	var multiplier := 1.0
	if channel == "coop": multiplier = 1.08
	elif channel == "stall":
		multiplier = 1.12 if _economy_theme_matches(item_id, theme) else 1.04
	var base_price := float(item_catalog.get(item_id, {}).get("price", 0)) * weighted
	var price := floori(base_price * market_factor(item_id) * (0.7 + 0.3 * fresh_ratio) * multiplier)
	return {"available": true, "money": maxi(0, price), "selected": selected, "freshness": fresh_ratio, "quality": weighted / float(quantity), "multiplier": multiplier}

func sale_quote(item_id: String, quantity: int, grade: int = -1) -> int:
	return int(economy_quote(item_id, quantity, grade).get("money", 0))

func send_economy_goods(item_id: String, quantity: int, grade: int, channel: String, theme: String = "breakfast") -> bool:
	var ok := false
	_refresh_economy_day()
	var theme_ids := ["breakfast", "orchard", "pantry"]
	var maximum := 12 if channel == "stall" else 99
	var jobs: Array = economy.get("jobs", [])
	var job_limit := 8 if int(economy.get("rep", 0)) >= 20 else 4
	if not ["coop", "stall"].has(channel) or not theme_ids.has(theme) or quantity < 1 or quantity > maximum:
		message = "合作社每批最多 99 份，摊位每批最多 12 份。"
	elif economy.get("locked", []).has(item_id):
		message = "物品已锁定。"
	elif jobs.size() >= job_limit:
		message = "货单已满，请先领取或撤回。"
	elif channel == "stall" and jobs.any(func(job): return str(job.get("channel", "")) == "stall"):
		message = "先收好这一摊，再换主题开摊。"
	else:
		var quote := economy_quote(item_id, quantity, grade, channel, theme)
		if not bool(quote.get("available", false)):
			message = "所选品质或数量不足。"
		elif channel == "stall" and not spend_energy(3, 10):
			return ok
		else:
			var packet := _economy_take_packet(item_id, quantity, grade)
			if packet.is_empty():
				message = "物品品质记录与数量不一致，请重新打开交易簿。"
			else:
				var key := int(economy.get("nextId", 1))
				economy.nextId = key + 1
				var ready: float = (day + 1) * 1440 + 390 if channel == "coop" else _kitchen_now() + 90
				packet.merge({"key": key, "day": day, "ready": ready, "channel": channel, "theme": theme, "price": int(quote.money)}, true)
				jobs.append(packet)
				economy.jobs = jobs
				_record_trade("交代销" if channel == "coop" else "摆摊", item_id, quantity, 0)
				ok = true
				if channel == "stall": message = "竹匾摆好，等待 90 游戏分钟后回来收摊；预计 %d 元。" % int(quote.money)
				else: message = "已交合作社锁价代销，明早起可领取 %d 元。" % int(quote.money)
	changed.emit()
	return ok

func collect_economy_job(job_key: int, cancel: bool = false) -> bool:
	var ok := false
	_refresh_economy_day()
	var jobs: Array = economy.get("jobs", [])
	for index in range(jobs.size()):
		var job: Dictionary = jobs[index]
		if int(job.get("key", -1)) != job_key: continue
		if not cancel and _kitchen_now() < float(job.get("ready", 0)):
			message = "货单还在办理，可以先去村里走走。"
		elif cancel and int(inventory.get(str(job.id), 0)) + int(job.qty) > 999999:
			message = "背包这一类已满。"
		elif cancel:
			_economy_restore_packet(job, day - int(job.get("day", day)))
			jobs.remove_at(index)
			economy.jobs = jobs
			_record_trade("撤回", str(job.id), int(job.qty), 0)
			ok = true
			message = "已退回原货，品质和陈放年龄保留。"
		elif money + int(job.price) > 1000000000:
			message = "零钱已满。"
		else:
			money += int(job.price)
			player_stats.earned = int(player_stats.get("earned", 0)) + int(job.price)
			flags.firstSale = true
			if str(job.get("channel", "")) == "coop": economy.rep = mini(99999, int(economy.get("rep", 0)) + 1)
			jobs.remove_at(index)
			economy.jobs = jobs
			_record_trade("结算", str(job.id), int(job.qty), int(job.price))
			ok = true
			message = "货款 %d 元已收好。%s" % [int(job.price), "供货信用 +1。" if str(job.get("channel", "")) == "coop" else ""]
		changed.emit()
		return ok
	message = "这张货单已经处理过。"
	changed.emit()
	return ok

func economy_weekly_orders() -> Array[Dictionary]:
	var week := int(day / 7)
	var crops: Array[String] = []
	for crop_id in crop_catalog:
		var crop: Dictionary = crop_catalog[crop_id]
		if crop_in_season(str(crop_id)): crops.append(str(crop_id))
	if crops.is_empty():
		for crop_id in crop_catalog: crops.append(str(crop_id))
	var crop_id := crops[posmod(week, crops.size())] if not crops.is_empty() else "cabbage"
	var staples: Array[String] = ["egg", "milk", "wool"]
	var pantry_items: Array[String] = ["flour", "driedMushroom", "berryJam"]
	var staple_id: String = staples[posmod(week, staples.size())]
	var pantry_id: String = pantry_items[posmod(week, pantry_items.size())]
	var result: Array[Dictionary] = []
	var ids := [crop_id, staple_id, pantry_id]
	var quantities := [8, 5, 3]
	var grades := [0, 0, 1]
	var titles := ["食堂的时令篮", "邻里早餐桌", "乡味礼盒"]
	var bonuses := [25, 30, 40]
	for index in range(3):
		var id := str(ids[index])
		if not item_catalog.has(id): continue
		result.append({"key": "%d-%d" % [week, index], "id": id, "qty": quantities[index], "grade": grades[index], "title": titles[index], "bonus": bonuses[index]})
	return result

func fulfill_economy_order(order_key: String) -> bool:
	if not QUESTS.can_commit(self,"weekly",order_key):
		changed.emit();return false
	var ok := false
	_refresh_economy_day()
	if economy.get("claimed", []).has(order_key):
		message = "这张供货单已经完成。"
		changed.emit()
		return ok
	var order: Dictionary = QUESTS.accepted_order(self,order_key)
	if order.is_empty():
		message = "这张供货单已经换周了。"
		changed.emit()
		return ok
	var item_id := str(order.id)
	if economy.get("locked", []).has(item_id):
		message = "订单物品已锁定。"
		changed.emit()
		return ok
	var counts: Array = QUESTS.eligible_counts(self,item_id)
	var required := int(order.qty)
	var available := 0
	for grade in range(int(order.grade), 4):
		available += counts[grade]
	if available < required:
		message = "需要普通品质及以上的%s ×%d。" % [item_catalog[item_id].get("name", item_id), required]
		changed.emit()
		return ok
	var selected_weight := 0.0
	var remaining := required
	for grade in range(int(order.grade), 4):
		var taken := mini(remaining, counts[grade])
		selected_weight += float(taken) * [1.0, 1.2, 1.4, 1.7][grade]
		remaining -= taken
		if remaining <= 0: break
	var payout := floori(float(item_catalog[item_id].get("price", 0)) * selected_weight * 1.15) + int(order.bonus)
	if money + payout > 1000000000:
		message = "零钱已满。"
	else:
		remaining = required
		for grade in range(int(order.grade), 4):
			var taken := mini(remaining, counts[grade])
			if taken > 0: QUESTS.consume(self,item_id,taken,grade,true)
			remaining -= taken
			if remaining <= 0: break
		money += payout
		player_stats.earned = int(player_stats.get("earned", 0)) + payout
		flags.firstSale = true
		economy.rep = mini(99999, int(economy.get("rep", 0)) + 3)
		var claimed: Array = economy.get("claimed", [])
		claimed.append(order_key)
		while claimed.size() > 90: claimed.pop_front()
		economy.claimed = claimed
		_record_trade("订单", item_id, required, payout)
		ok = true
		message = "%s已交付，收到 %d 元，供货信用 +3。" % [str(order.title), payout]
	changed.emit()
	return ok

func buy_item(item_id: String, quantity: int = 1, special_offer: bool = false) -> bool:
	var ok := false
	_refresh_economy_day(true)
	var unit_price := shop_price(item_id)
	var heirloom_locked := item_id.ends_with("_heirloom") and day < 14 and int(relations.get("qiao", {}).get("points", 0)) < 20
	var daily: Dictionary = economy.get("daily", {})
	var bought: Dictionary = daily.get("bought", {})
	var is_daily_offer := daily_offers().has(item_id)
	if heirloom_locked:
		message = "春十五或与沈禾熟悉后开放乡传良种。"
	elif unit_price <= 0 or quantity < 1 or quantity > 99:
		message = "这件物品目前不出售。"
	elif special_offer and (not is_daily_offer or int(bought.get(item_id, 0)) + quantity > 5):
		message = "今日货签每种限 5 份，明日换新；普通货架仍可购买。"
	elif int(inventory.get(item_id, 0)) + quantity > 999999:
		message = "背包这一类已满。"
	else:
		if special_offer:
			unit_price = maxi(ceili(float(item_catalog[item_id].get("price", 0)) * 1.85), floori(float(unit_price) * 0.9))
		var total := unit_price * quantity
		if money < total:
			message = "零钱不足，需要 %d 元。" % total
		else:
			money -= total
			_add_inventory_count(item_id, quantity)
			_reconcile_kitchen_lots()
			if special_offer:
				bought[item_id] = int(bought.get(item_id, 0)) + quantity
				daily["bought"] = bought
				economy["daily"] = daily
			_record_trade("买入", item_id, quantity, -total)
			ok = true
			message = "买到%s ×%d，支出 %d 元%s。" % [item_catalog[item_id].get("name", item_id), quantity, total, "（今日特价）" if special_offer else ""]
	changed.emit()
	return ok

func sell_item(item_id: String, quantity: int = 1, grade: int = -1) -> bool:
	var ok := false
	_refresh_economy_day()
	if economy.get("locked", []).has(item_id):
		message = "这件物品已锁定，先解除保护。"
	elif not item_catalog.has(item_id) or quantity < 1 or quantity > 999999 or int(inventory.get(item_id, 0)) < quantity:
		message = "所选物品或数量不足。"
	elif int(item_catalog[item_id].get("price", 0)) <= 0:
		message = "柜台暂不收这件物品。"
	else:
		var quote := economy_quote(item_id, quantity, grade)
		if not bool(quote.get("available", false)):
			message = "所选品质或数量不足。"
			changed.emit()
			return ok
		var price := int(quote.money)
		if money + price > 1000000000:
			message = "零钱已满，先安排一些建设。"
		else:
			var packet := _economy_take_packet(item_id, quantity, grade)
			if packet.is_empty():
				message = "物品品质记录与数量不一致，请重新打开背包。"
				changed.emit()
				return ok
			money += price
			player_stats.earned = int(player_stats.get("earned", 0)) + price
			flags.firstSale = true
			var receipts: Array = economy.get("receipts", []).filter(func(receipt): return day-int(receipt.get("day",day))<=2)
			economy.receipts = receipts
			packet.merge({"key": int(economy.get("nextId", 1)), "day": day, "price": price}, true)
			receipts.push_front(packet)
			while receipts.size() > 30:
				receipts.pop_back()
			economy.nextId = int(economy.get("nextId", 1)) + 1
			_record_trade("现售", item_id, quantity, price)
			ok = true
			message = "售出%s ×%d，收到 %d 元。" % [item_catalog[item_id].get("name", item_id), quantity, price]
	changed.emit()
	return ok

func buyback_item(receipt_key: int) -> bool:
	var ok := false
	_refresh_economy_day()
	var receipts: Array = economy.get("receipts", [])
	for index in range(receipts.size()):
		var receipt: Dictionary = receipts[index]
		if int(receipt.get("key", -1)) != receipt_key:
			continue
		if day-int(receipt.day)>2:
			message = "这张回购货签已到期。"
			changed.emit()
			return false
		var cost := int(receipt.price) + maxi(1, ceili(float(receipt.price) * 0.05))
		if money < cost:
			message = "回购需要 %d 元。" % cost
		elif int(inventory.get(str(receipt.id), 0)) + int(receipt.qty) > 999999:
			message = "背包这一类已满。"
		else:
			money -= cost
			_economy_restore_packet(receipt, day - int(receipt.get("day", day)))
			player_stats.earned = maxi(0, int(player_stats.get("earned", 0)) - int(receipt.price))
			receipts.remove_at(index)
			_record_trade("回购", str(receipt.id), int(receipt.qty), -cost)
			ok = true
			message = "取回原物，品质保留，支出 %d 元。" % cost
		changed.emit()
		return ok
	message = "这张回购货签已经到期。"
	changed.emit()
	return ok

func inventory_sort_value(item_id: String) -> int:
	return sale_quote(item_id,1)

func inventory_item_ids(side: String = "bag", category: String = "全部", search: String = "", order: String = "name") -> Array[String]:
	var holdings: Dictionary = storage if side == "storage" else inventory
	var ids: Array[String] = []
	var values: Dictionary = {}
	var positions: Dictionary = {}
	for raw_id in holdings:
		var id := str(raw_id)
		if not item_catalog.has(id) or int(holdings[id]) <= 0: continue
		var kind := economy_category(id)
		if category != "全部" and kind != category: continue
		if search != "" and not (str(item_catalog[id].name)+kind).contains(search): continue
		positions[id] = ids.size()
		ids.append(id)
		match order:
			"count": values[id] = -int(holdings[id])
			"value": values[id] = -inventory_sort_value(id)
			"fresh":
				var lots: Array = kitchen.get("lots",{}).get(side,{}).get(id,[])
				var ratio := 1.0 - (float(lots[0].get("age",0.0)) if not lots.is_empty() else 0.0) / float(_food_shelf_days(id))
				values[id] = (0.0 if ratio < 0.0 else 1.0 if ratio > 1.0 else ratio) if _is_food(id) else 2.0
			_: values[id] = int(inventory_metadata.get(id,{}).get("rank",999))
	ids.sort_custom(func(a,b):
		if values[a] == values[b]: return int(positions[a]) < int(positions[b])
		return values[a] < values[b])
	return ids

func economy_category(item_id: String) -> String:
	var item: Dictionary = item_catalog.get(item_id, {})
	var kind := str(item.get("kind", ""))
	if kind == "种子": return kind
	if item_id in ["feed","hay","grainFeed","healthFeed","bedding","compost","slowFertilizer","bioCare","plantCare"]: return "农资"
	if kind == "料理" or kind == "材料": return kind
	if item_id in ["milk","egg","duckEgg","fish","shrimp","crab","perch","loach","pork"]: return "鱼蛋奶肉"
	if kind == "加工物": return kind
	return "鲜蔬谷果" if _is_food(item_id) else kind

func economy_transfer(item_id: String, amount: int, to_storage: bool, grade: int = -1, notify: bool = true) -> bool:
	_refresh_economy_day()
	var source: Dictionary = inventory if to_storage else storage
	var destination: Dictionary = storage if to_storage else inventory
	var ok := false
	if not bool(upgrades.get("storage", false)):
		message = "先添置储物柜，之后可存取。"
	elif int(destination.get(item_id, 0)) + amount > 999999:
		message = "目的库存已满。"
	elif not item_catalog.has(item_id) or amount < 1 or amount > 999999 or grade < -1 or grade > 3:
		message = "所选品质或数量不足。"
	else:
		var counts := _quality_counts(item_id) if to_storage else _storage_quality_counts(item_id)
		var selected: Array[int] = [0,0,0,0]
		var left := amount
		for tier in range(4):
			if grade < 0 or grade == tier:
				selected[tier] = mini(left, counts[tier])
				left -= selected[tier]
		if left > 0:
			message = "所选品质或数量不足。"
		else:
			_reconcile_kitchen_lots()
			_move_kitchen_lots(item_id, amount, "bag" if to_storage else "storage", "storage" if to_storage else "bag")
			source[item_id] = int(source.get(item_id, 0)) - amount
			if int(source[item_id]) == 0: source.erase(item_id)
			if to_storage: destination[item_id] = int(destination.get(item_id, 0)) + amount
			else: _add_inventory_count(item_id, amount)
			var from_quality: Dictionary = quality if to_storage else storage_quality
			var to_quality: Dictionary = storage_quality if to_storage else quality
			var target_counts := _storage_quality_counts(item_id) if to_storage else _quality_counts(item_id)
			from_quality[item_id] = [counts[1]-selected[1], counts[2]-selected[2], counts[3]-selected[3]]
			to_quality[item_id] = [target_counts[1]+selected[1], target_counts[2]+selected[2], target_counts[3]+selected[3]]
			if not legacy_systems.discovered.has(item_id): legacy_systems.discovered.append(item_id)
			_reconcile_kitchen_lots()
			message = ("存入" if to_storage else "取回") + str(item_catalog[item_id].name) + " ×" + str(amount) + "；品质与陈放年龄一同保留。"
			ok = true
	if notify: changed.emit()
	return ok

func economy_tidy(category: String = "全部", to_storage: bool = true) -> bool:
	if not bool(upgrades.get("storage", false)):
		message = "先添置储物柜。"
		changed.emit()
		return false
	var source: Dictionary = inventory if to_storage else storage
	var moved := 0
	for raw_id in source.keys():
		var id := str(raw_id)
		if category != "全部" and economy_category(id) != category: continue
		var amount := maxi(0, int(inventory.get(id,0))-5) if to_storage else mini(int(storage.get(id,0)),maxi(0,5-int(inventory.get(id,0))))
		if amount > 0 and economy_transfer(id,amount,to_storage,-1,false): moved += amount
	message = "已周转 " + str(moved) + " 份；每类随身保留或补足 5 份。" if moved > 0 else "当前分类无需整理。"
	changed.emit()
	return moved > 0

func toggle_item_lock(item_id: String) -> bool:
	if not item_catalog.has(item_id):
		message = "物品不存在。"
		changed.emit()
		return false
	_refresh_economy_day()
	var locked: Array = economy.get("locked", [])
	if locked.has(item_id):
		locked.erase(item_id)
		message = "已解除物品锁定。"
	else:
		locked.append(item_id)
		message = "已锁定：不会出售、食用、赠送或作为配方材料。仍可存取。"
	economy.locked = locked
	changed.emit()
	return true

func toggle_item_pin(item_id: String) -> bool:
	_refresh_economy_day()
	if not item_catalog.has(item_id):
		message = "物品不存在。"
		changed.emit()
		return false
	var pinned: Array = economy.get("pinned", [])
	if pinned.has(item_id):
		pinned.erase(item_id)
	elif pinned.size() < 6:
		pinned.append(item_id)
	else:
		message = "常用篮已放六样，先取消一项。"
		changed.emit()
		return false
	economy.pinned = pinned
	message = "常用篮已记住顺序，用完也会保留位置。"
	changed.emit()
	return true

func cycle_recipe(step: int) -> void:
	var recipes: Array = content.get("recipes", [])
	if recipes.is_empty():
		return
	var current := -1
	for i in range(recipes.size()):
		if str(recipes[i].get("id", "")) == selected_recipe:
			current = i
	selected_recipe = str(recipes[posmod(current + step, recipes.size())].get("id", "greens"))
	var item: Dictionary = item_catalog.get(selected_recipe, {})
	message = "菜谱选中：" + str(item.get("name", selected_recipe))
	changed.emit()

func cook_selected_recipe() -> void:
	cook_recipe(selected_recipe)

func recipe_data(recipe_id: String) -> Dictionary:
	for candidate in content.get("recipes", []):
		if str(candidate.get("id", "")) == recipe_id:
			return candidate
	return {}

func kitchen_station_available(id: String) -> bool:
	var station: Dictionary = system_catalog.get("kitchen",{}).get("stations",{}).get(id,{})
	if station.is_empty(): return false
	if station.has("upgrade"): return bool(upgrades.get(str(station.upgrade),false))
	var name := str(station.get("station",""))
	if name == "堆肥箱": return true
	var definition: Dictionary = content.get("stations",{}).get(name,{})
	return bool(definition.get("base",false)) or bool(upgrades.get(str(definition.get("upgrade","")),false))

func kitchen_station_for_recipe(recipe_id: String) -> String:
	var recipe := recipe_data(recipe_id)
	for station in system_catalog.get("kitchen", {}).get("stations", {}):
		if str(system_catalog.kitchen.stations[station].get("station","")) == str(recipe.get("station","灶台")): return str(station)
	return "stove"

func perform_kitchen_task(task: Dictionary) -> bool:
	var id := str(task.get("id",""))
	var count := int(task.get("n",1))
	match str(task.get("op","")):
		"process": return process_recipe(id,count)
		"make","sub","manual": return cook_recipe(id,count,float(task.get("heat",-1.0)),str(task.op) == "sub")
		"collect": return collect_kitchen_job(int(id))
		"clean": return clean_kitchen_station(id)
		"upgrade": return upgrade_kitchen_station(id)
		"experiment": return experiment_recipe(id,str(task.get("second","")))
	message = "没有这项厨房操作。"
	return false

func preview_kitchen_task(task: Dictionary) -> Dictionary:
	# Private node has no tree, audio or autosave signal connections.
	var copy = get_script().new()
	for field in get_property_list():
		if int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var value: Variant = get(str(field.name))
		if value is Dictionary or value is Array: value = value.duplicate(true)
		copy.set(str(field.name),value)
	var ok: bool = copy.perform_kitchen_task(task)
	var result := {"ok":ok,"message":str(copy.message)}
	copy.free()
	return result

func queue_kitchen_task(task: Dictionary) -> bool:
	var check := preview_kitchen_task(task)
	if not bool(check.ok):
		message = str(check.message)
		changed.emit()
		return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	cancel_action()
	source_keyboard.clear()
	building_task.clear()
	var world: Node = players[0].get_parent()
	if world.get("hud") != null: world.get("hud").close_top_panel()
	cancel_farm_queue()
	cancel_ranch_queue()
	walking_target.clear()
	kitchen_task = task.duplicate(true)
	if not kitchen_task.has("station"):
		var op := str(kitchen_task.op)
		kitchen_task.station = str(_processing_recipe(str(kitchen_task.id)).get("stationId","stove")) if op == "process" else str(kitchen_task.id) if op in ["clean","upgrade"] else kitchen_station_for_recipe(str(kitchen_task.id))
		if op == "collect":
			for job in kitchen.get("jobs",[]):
				if int(job.get("key",-1)) == int(kitchen_task.id): kitchen_task.station = str(job.station)
	return advance_kitchen_task()

func advance_kitchen_task() -> bool:
	if kitchen_task.is_empty(): return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	var player: Node = players[0]
	var house: Dictionary = {}
	for candidate in world_village.get("houses",[]):
		if str(candidate.get("name","")) == "禾溪小灶": house = candidate
	if house.is_empty():
		kitchen_task.clear()
		museum_task.clear()
		npc_task.clear()
		building_task.clear()
		return false
	var target: Dictionary
	if current_interior != str(house.id):
		target = house.get("door",{}).duplicate(true)
		target.merge({"id":str(house.id),"house":str(house.id),"kind":"enter","name":"禾溪小灶","kitchen_stage":"door"},true)
	else:
		var station_id := str(kitchen_task.station)
		var station: Dictionary = system_catalog.get("kitchen",{}).get("stations",{}).get(station_id,{})
		target = {"id":"kitchen-"+station_id,"kind":"kitchen-station","name":str(station.get("name",station_id)),"station":station_id,"x":float(station.get("x",240)),"y":float(station.get("y",315)),"world_click":true,"auto_interact":true,"click_room":current_interior,"kitchen_stage":"station"}
		for point in system_catalog.get("interiors",{}).get("layouts",{}).get(str(house.id),{}).get("points",[]):
			if str(point.get("id","")) == str(target.id):
				target.x = float(point.x)
				target.y = float(point.y)
	if not player.walk_to(target):
		kitchen_task.clear()
		museum_task.clear()
		npc_task.clear()
		building_task.clear()
		return false
	return true

func finish_kitchen_task(target: Dictionary) -> void:
	if kitchen_task.is_empty() or str(target.get("kitchen_stage","")) != "station": return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var at := Vector2(float(target.get("x",0)),float(target.get("y",0)))
	if players[0].global_position.distance_to(at) >= 53.0:
		stop_walking()
		return
	if not bool(target.get("_sequence_resolved",false)):
		var point := target.duplicate(true)
		point.kind = "kitchen-task"
		point.op = str(kitchen_task.get("op",""))
		_begin_task_action(point,finish_kitchen_task)
		return
	var task := kitchen_task.duplicate(true)
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	building_task.clear()
	if str(task.get("op","")) == "manual":
		players[0].get_parent().get("hud").show_kitchen_heat(task)
	else:
		confirm_operation(perform_kitchen_task(task))

func _kitchen_now() -> float:
	return day * 1440 + minutes

func _is_food(item_id: String) -> bool:
	var item: Dictionary = item_catalog.get(item_id, {})
	return str(item.get("kind", "")) in ["食材", "料理"] or item_id in ["flour", "oil", "driedMushroom", "driedFish", "dryTea", "cream", "yogurt", "cheese", "riceWine", "berryJam"]

func _food_shelf_days(item_id: String) -> int:
	if system_catalog.get("fishing",{}).get("species",{}).has(item_id):return 5
	if item_id in ["riceWine", "berryJam", "pickles", "radishPickle", "driedMushroom", "driedFish", "dryTea", "oil"]:
		return 28
	if item_id in ["rice", "wheat", "peanut", "sesame", "flour", "bean"]:
		return 21
	if item_id in ["milk", "goatMilk", "cream", "fish", "shrimp", "crab", "perch", "loach"]:
		return 5
	if str(item_catalog.get(item_id, {}).get("kind", "")) == "料理" or item_id in ["yogurt", "cheese", "goatCheese"]:
		return 7
	return 12

func _reconcile_kitchen_lots() -> void:
	var all_lots: Dictionary = kitchen.get("lots", {"bag": {}, "storage": {}})
	for side in ["bag", "storage"]:
		var holdings: Dictionary = inventory if side == "bag" else storage
		var side_lots: Dictionary = all_lots.get(side, {})
		for item_id in holdings:
			if not _is_food(str(item_id)):
				continue
			var lots: Array = side_lots.get(item_id, [])
			var total := 0
			for lot in lots:
				total += int(lot.get("qty", 0))
			var holding_count := maxi(0, int(holdings[item_id]))
			if total < holding_count:
				lots.append({"qty": holding_count - total, "age": 0.0})
			elif total > holding_count:
				var excess := total - holding_count
				while excess > 0 and not lots.is_empty():
					var first: Dictionary = lots[0]
					var taken := mini(excess, int(first.get("qty", 0)))
					first.qty = int(first.qty) - taken
					excess -= taken
					if int(first.qty) <= 0:
						lots.pop_front()
			if lots.is_empty():
				side_lots.erase(item_id)
			else:
				side_lots[item_id] = lots
		all_lots[side] = side_lots
	kitchen.lots = all_lots

func food_freshness(item_id: String, quantity: int = 1, side: String = "bag") -> Dictionary:
	_reconcile_kitchen_lots()
	var side_lots: Dictionary = kitchen.get("lots", {}).get(side, {})
	var lots: Array = side_lots.get(item_id, [])
	var remaining := maxi(1, quantity)
	var age_total := 0.0
	var counted := 0
	for lot in lots:
		var take := mini(remaining, int(lot.get("qty", 0)))
		age_total += float(lot.get("age", 0.0)) * float(take)
		counted += take
		remaining -= take
		if remaining <= 0:
			break
	var age := age_total / float(maxi(1, counted))
	var ratio := clampf(1.0 - age / float(_food_shelf_days(item_id)), 0.0, 1.0)
	return {"ratio": ratio, "age": age, "days": maxi(0, ceili(float(_food_shelf_days(item_id)) - age)), "label": "新鲜" if ratio > 0.55 else "尚可" if ratio > 0.2 else "宜先用" if ratio > 0.0 else "陈放"}

func _move_kitchen_lots(item_id: String, quantity: int, from_side: String, to_side: String) -> void:
	if not _is_food(item_id):
		return
	var all_lots: Dictionary = kitchen.get("lots", {})
	var source: Dictionary = all_lots.get(from_side, {})
	var destination: Dictionary = all_lots.get(to_side, {})
	var source_lots: Array = source.get(item_id, [])
	var moved: Array = []
	var remaining := quantity
	while remaining > 0 and not source_lots.is_empty():
		var first: Dictionary = source_lots[0]
		var taken := mini(remaining, int(first.get("qty", 0)))
		moved.append({"qty": taken, "age": float(first.get("age", 0.0))})
		first.qty = int(first.qty) - taken
		remaining -= taken
		if int(first.qty) <= 0:
			source_lots.pop_front()
	if source_lots.is_empty():
		source.erase(item_id)
	else:
		source[item_id] = source_lots
	var destination_lots: Array = destination.get(item_id, [])
	destination_lots.append_array(moved)
	destination_lots.sort_custom(func(a, b): return float(a.get("age", 0.0)) > float(b.get("age", 0.0)))
	destination[item_id] = destination_lots
	all_lots[from_side] = source
	all_lots[to_side] = destination
	kitchen.lots = all_lots

func _kitchen_grade(recipe_id: String, needs: Dictionary, quantity: int, station_id: String, manual_bonus: int = 0) -> int:
	var grade_sum := 0.0
	var ingredient_count := 0
	var freshness := 1.0
	for item_id in needs:
		var count := int(needs[item_id]) * quantity
		ingredient_count += count
		var counts := _quality_counts(str(item_id))
		var remaining := maxi(0, count - counts[0])
		for level in range(1, 4):
			var taken := mini(remaining, counts[level])
			grade_sum += float(taken * level)
			remaining -= taken
		if _is_food(str(item_id)):
			freshness = minf(freshness, float(food_freshness(str(item_id), count).ratio))
	var equipment: Dictionary = kitchen.get("equipment", {}).get(station_id, {"level": 0, "clean": 100})
	var mastery := int(kitchen.get("mastery", {}).get(recipe_id, 0))
	var recipe := recipe_data(recipe_id)
	var season_bonus := 0.5 if recipe.has("season") and int(recipe.season) == season_index() else 0.0
	var grade := floori(grade_sum / float(maxi(1, ingredient_count)) * 0.7 + (1.0 if freshness > 0.55 else 0.0) + float(manual_bonus) + minf(0.75, float(mastery) * 0.1) + float(equipment.get("level", 0)) * 0.25 + season_bonus)
	if freshness <= 0.0 or int(equipment.get("clean", 100)) < 30:
		grade = mini(grade, 1)
	return clampi(grade, 0, 3)

func kitchen_recipe_needs(recipe: Dictionary, allow_substitutes: bool, quantity: int = 1) -> Dictionary:
	var result: Dictionary = recipe.get("ingredients", {}).duplicate(true)
	if not allow_substitutes or quantity < 1:
		return result
	var groups: Dictionary = {
		"cabbage": ["spinach", "lettuce", "bokchoy", "mustard", "wildHerb"],
		"egg": ["duckEgg"],
		"fish": ["perch", "loach"],
		"mushroom": ["driedMushroom"],
		"rice": ["corn"],
		"bean": ["pea", "broadbean"]
	}
	groups["fish"]=system_catalog.fishing.species.keys().filter(func(id: String):return str(system_catalog.fishing.species[id].get("foodGroup",""))=="fish" and id!="fish")
	for raw_item_id in result.keys():
		var item_id := str(raw_item_id)
		var required := int(result[item_id])
		if int(inventory.get(item_id, 0)) >= required * quantity or not groups.has(item_id):
			continue
		for alternate_value in groups[item_id]:
			var alternate := str(alternate_value)
			var alternate_needed := (int(result.get(alternate, 0)) + required) * quantity
			if int(inventory.get(alternate, 0)) >= alternate_needed and not economy.get("locked", []).has(alternate):
				result.erase(item_id)
				result[alternate] = int(result.get(alternate, 0)) + required
				break
	return result

func _kitchen_has(needs: Dictionary, quantity: int) -> bool:
	for item_id in needs:
		if int(inventory.get(item_id, 0)) < int(needs[item_id]) * quantity:
			return false
	return true

func _kitchen_consume(needs: Dictionary, quantity: int) -> void:
	for item_id in needs:
		_consume_item(str(item_id), int(needs[item_id]) * quantity)
	_reconcile_kitchen_lots()

func _kitchen_record(item_id: String, quantity: int, grade: int, recipe_id: String) -> void:
	_grant_legacy_item(item_id, quantity)
	if grade > 0:
		var ledger: Array = quality.get(item_id, [0, 0, 0])
		ledger[grade - 1] = int(ledger[grade - 1]) + quantity
		quality[item_id] = ledger
	var mastery: Dictionary = kitchen.get("mastery", {})
	mastery[recipe_id] = mini(9999, int(mastery.get(recipe_id, 0)) + 1)
	kitchen.mastery = mastery
	_reconcile_kitchen_lots()

func cook_recipe(recipe_id: String, quantity: Variant = 1, heat: float = -1.0, allow_substitutes: bool = false) -> bool:
	var recipe := recipe_data(recipe_id)
	if recipe.is_empty():
		message = "这道菜还没学会，先请教乡亲或试配。"
		changed.emit()
		return false
	if not known_recipes.has(recipe_id):
		message = "这道菜还没学会，先请教乡亲或试配。"
		changed.emit()
		return false
	if typeof(quantity) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(quantity)) or float(quantity) != floorf(float(quantity)) or quantity < 1 or quantity > 20:
		message = "一次做 1—20 份。"
		changed.emit()
		return false
	quantity = int(quantity)
	if recipe.has("upgrade") and not bool(upgrades.get(str(recipe.get("upgrade")), false)):
		message = "先在修缮小院整理%s。" % str(recipe.get("station","灶台"))
		changed.emit()
		return false
	var kitchen_catalog: Dictionary = system_catalog.get("kitchen", {})
	var station_id := "stove"
	for candidate_id in kitchen_catalog.get("stations", {}):
		if str(kitchen_catalog.stations[candidate_id].get("station", "")) == str(recipe.get("station", "灶台")):
			station_id = str(candidate_id)
			break
	if not kitchen_station_available(station_id):
		message = "先在修缮小院整理%s。" % str(recipe.get("station","灶台"))
		changed.emit()
		return false
	if recipe.has("season") and int(recipe.season) != season_index() and int(kitchen.get("equipment", {}).get("stove", {}).get("level", 0)) < 2:
		message = "这是%s季做法；灶台升至 2 级可全年制作。" % str(["春","夏","秋","冬"][int(recipe.season)])
		changed.emit()
		return false
	var ingredients: Dictionary = kitchen_recipe_needs(recipe, allow_substitutes, quantity)
	if ingredients.keys().any(func(item_id): return economy.get("locked",[]).has(str(item_id))) or not _kitchen_has(ingredients,quantity):
		message = "食材还没备齐，替代搭配也按整批用量检查。"
		changed.emit()
		return false
	if station_id in ["pickle", "dry"]:
		return _enqueue_kitchen({"id": recipe_id, "out": recipe_id, "qty": 1, "minutes": 1440, "needs": ingredients}, station_id, quantity, true)
	if is_nan(heat) or is_inf(heat) or heat > 100 or heat < -1 or (heat > -1 and heat < 0):
		message = "火候读数无效。"
		changed.emit()
		return false
	if not spend_energy(2 + int(quantity / 5), 10, "", false):
		message = "体力不足，歇一歇再做饭。"
		changed.emit()
		return false
	var grade := _kitchen_grade(recipe_id, ingredients, quantity, station_id, 1 if heat >= 35 and heat <= 75 else 0)
	_kitchen_consume(ingredients, quantity)
	_kitchen_record(recipe_id, quantity, grade, recipe_id)
	var equipment: Dictionary = kitchen.get("equipment", {}).get(station_id, {"level": 0, "clean": 100})
	equipment.clean = maxi(0, int(equipment.get("clean", 100)) - 3)
	kitchen.equipment[station_id] = equipment
	flags.firstCook = true
	_kitchen_cook_completed(quantity, true)
	_award_skill_xp("cooking", 3 * quantity)
	var heat_note := " · 家常快做" if heat < 0 else " · 火候恰好" if heat >= 35 and heat <= 75 else " · 火候稍偏，仍是一顿热饭"
	message = "%s ×%d 出锅 · %s%s。" % [str(item_catalog.get(recipe_id, {}).get("name", recipe_id)), quantity, ["普通", "优质", "上品", "珍品"][grade], heat_note]
	changed.emit()
	return true

func _kitchen_cook_completed(quantity: int, unlock_experiments: bool = false) -> void:
	player_stats.cooked = int(player_stats.get("cooked", 0)) + quantity
	if unlock_experiments and int(player_stats.cooked) >= 5:
		for recipe in content.get("recipes", []):
			if str(recipe.get("source", "")) == "experiment" and not known_recipes.has(str(recipe.get("id", ""))):
				var learned_id := str(recipe.get("id", ""))
				known_recipes.append(learned_id)
				_record_community_log("学会了 %s。" % str(item_catalog.get(learned_id, {}).get("name", learned_id)))

func _processing_recipe(recipe_id: String) -> Dictionary:
	for candidate in system_catalog.get("kitchen", {}).get("processing", []):
		if str(candidate.get("id", "")) == recipe_id:
			return candidate
	return {}

func _drying_ready(start: float, duration: int, level: int) -> int:
	var at := float(start)
	var left := float(duration)
	for _step in range(1000):
		if left <= 0.000001:
			break
		var drying_day := floori(at / 1440.0)
		var weather := weather_profile(drying_day)
		var rate := 1.0 if level >= 2 else 0.6 if int(weather.rain) > 0 else 1.15 if float(weather.sunlight) >= 0.9 else 0.8 if bool(weather.snow) else 1.0
		var span := minf(float((drying_day + 1) * 1440) - at, left / rate)
		at += span
		left -= span * rate
	return ceili(at)

func process_recipe(recipe_id: String, batch: Variant = 1) -> bool:
	var recipe := _processing_recipe(recipe_id)
	if recipe.is_empty():
		message = "没有这份加工配方。"
		changed.emit()
		return false
	var station_id := str(recipe.get("stationId", "stove"))
	return _enqueue_kitchen(recipe, station_id, batch, false)

func _enqueue_kitchen(recipe: Dictionary, station_id: String, batch: Variant, cooking: bool) -> bool:
	_reconcile_kitchen_lots()
	var recipe_id := str(recipe.get("id", ""))
	var station: Dictionary = system_catalog.get("kitchen", {}).get("stations", {}).get(station_id, {})
	if not kitchen_station_available(station_id):
		message = "先在修缮小院添置对应设备：%s。" % str(station.get("name", "加工工位"))
		changed.emit()
		return false
	var equipment: Dictionary = kitchen.get("equipment", {}).get(station_id, {"level": 0, "clean": 100})
	var capacity := 5 + int(equipment.get("level", 0)) * 5
	if typeof(batch) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(batch)) or float(batch) != floorf(float(batch)) or batch < 1 or batch > capacity:
		message = "这台设备每批可做 1—%d 份。" % capacity
		changed.emit()
		return false
	batch = int(batch)
	var jobs: Array = kitchen.get("jobs", [])
	var station_jobs: Array = []
	for job in jobs:
		if str(job.get("station", "")) == station_id:
			station_jobs.append(job)
	if station_jobs.size() >= 2 + int(equipment.get("level", 0)):
		message = "工位已满，先收取成品或升级容量。"
		changed.emit()
		return false
	var needs: Dictionary = recipe.get("needs", {})
	if needs.keys().any(func(item_id): return economy.get("locked",[]).has(str(item_id))) or not _kitchen_has(needs, batch):
		message = "原料还没备齐。"
		changed.emit()
		return false
	var grade := _kitchen_grade(recipe_id, needs, batch, station_id)
	if not spend_energy(2, 5, "", false):
		message = "体力不足，歇一歇再投料。"
		changed.emit()
		return false
	_kitchen_consume(needs, batch)
	var start := _kitchen_now()
	for job in station_jobs:
		start = maxf(start, float(job.get("ready", start)))
	var duration := ceili(float(recipe.get("minutes", 20)) * (1.0 - float(equipment.get("level", 0)) * 0.15))
	var ready: float = _drying_ready(start, duration, int(equipment.get("level", 0))) if station_id == "dry" else start + duration
	var next_id := int(kitchen.get("nextId", 1))
	jobs.append({"key": next_id, "recipe": recipe_id, "id": str(recipe.get("out", recipe_id)), "qty": int(recipe.get("qty", 1)) * batch, "station": station_id, "start": start, "ready": ready, "grade": grade, "cooking": cooking, "weatherDelay": 0})
	kitchen.jobs = jobs
	kitchen.nextId = next_id + 1
	equipment.clean = maxi(0, int(equipment.get("clean", 100)) - 8 * batch)
	kitchen.equipment[station_id] = equipment
	flags.firstCook = bool(flags.get("firstCook",false)) or cooking
	_award_skill_xp("cooking" if cooking else "craft", batch * 2)
	message = "已在%s投料，%d 份原料合为一批，完成后走近收取。" % [str(station.get("name", "工位")), batch]
	changed.emit()
	return true

func collect_kitchen_job(job_key: int) -> bool:
	var jobs: Array = kitchen.get("jobs", [])
	for index in range(jobs.size()):
		var job: Dictionary = jobs[index]
		if int(job.get("key", -1)) != job_key:
			continue
		if float(job.get("ready", 0)) > _kitchen_now():
			message = "还在慢慢加工，稍后再来。"
			changed.emit()
			return false
		var item_id := str(job.get("id", ""))
		_kitchen_record(item_id, int(job.get("qty", 0)), int(job.get("grade", 0)), item_id)
		QUESTS.event(self,"process")
		if bool(job.get("cooking", false)):
			_kitchen_cook_completed(int(job.get("qty", 0)))
		jobs.remove_at(index)
		kitchen.jobs = jobs
		message = "收好%s ×%d · %s。保鲜从收取日开始。" % [str(item_catalog.get(item_id, {}).get("name", item_id)), int(job.get("qty", 0)), ["普通", "优质", "上品", "珍品"][clampi(int(job.get("grade", 0)), 0, 3)]]
		changed.emit()
		return true
	message = "这份成品已经收过了。"
	changed.emit()
	return false

func clean_kitchen_station(station_id: String) -> bool:
	_reconcile_kitchen_lots()
	var equipment: Dictionary = kitchen.get("equipment", {}).get(station_id, {})
	var succeeded := false
	if equipment.is_empty():
		message = "没有这个工位。"
	elif not kitchen_station_available(station_id):
		message = "先添置这台设备。"
	elif int(equipment.get("clean", 100)) == 100:
		message = "工位已经干净。"
	elif not spend_energy(2, 5, "", false):
		message = "体力不足。"
	else:
		succeeded = true
		equipment.clean = 100
		kitchen.equipment[station_id] = equipment
		message = "擦洗锅台、晾干器具，工位恢复干净。"
	changed.emit()
	return succeeded

func upgrade_kitchen_station(station_id: String) -> bool:
	_reconcile_kitchen_lots()
	var station: Dictionary = system_catalog.get("kitchen", {}).get("stations", {}).get(station_id, {})
	var equipment: Dictionary = kitchen.get("equipment", {}).get(station_id, {})
	var succeeded := false
	if equipment.is_empty():
		message = "没有这个工位。"
	elif not kitchen_station_available(station_id):
		message = "先添置这台设备。"
	elif int(equipment.get("level", 0)) >= 2:
		message = "设备已达到最高等级。"
	else:
		var level := int(equipment.get("level", 0))
		var cost := 90 + level * 110
		var wood := 6 + level * 4
		if money < cost or economy.get("locked", []).has("wood") or economy.get("locked", []).has("bamboo") or not _kitchen_has({"wood": wood, "bamboo": 4}, 1):
			message = "升级需要 %d 元、木料 %d、竹材 4。" % [cost, wood]
		else:
			succeeded = true
			money -= cost
			_kitchen_consume({"wood": wood, "bamboo": 4}, 1)
			equipment.level = level + 1
			kitchen.equipment[station_id] = equipment
			message = "%s升级：容量增加，后续加工加快，品质更稳定。" % str(station.get("name", "工位"))
	changed.emit()
	return succeeded

func build_cold_pantry() -> bool:
	_reconcile_kitchen_lots()
	var succeeded := false
	if bool(kitchen.get("cold", false)):
		message = "阴凉储藏已备好。"
	elif money < 150 or economy.get("locked", []).has("bamboo") or not _kitchen_has({"bamboo": 6}, 1):
		message = "需要 150 元与竹材 6。"
	else:
		succeeded = true
		money -= 150
		_kitchen_consume({"bamboo": 6}, 1)
		kitchen.cold = true
		upgrades.storage = true
		message = "添好阴凉食橱。储物柜食材按四分之一速度陈放，原有食材年龄保留。"
	changed.emit()
	return succeeded

func kitchen_active_buff() -> String:
	var buff: Variant = kitchen.get("buff", null)
	if buff is Dictionary and float(buff.get("until", 0)) > _kitchen_now():
		return str(buff.get("kind", ""))
	return ""

func begin_eating(item_id: String,label: String,restore: Callable) -> bool:
	if action_busy():return false
	var starting_day:=day
	var starting_room:=current_interior
	var position:=player_position if current_interior=="" else interior_position
	var target:Dictionary={"kind":"ui","id":item_id,"x":position.x,"y":position.y}
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	building_task.clear()
	museum_task.clear()
	npc_task.clear()
	walking_target.clear()
	var resume:=func():
		if day==starting_day and current_interior==starting_room and restore.is_valid():restore.call()
	var commit:=func():
		if day!=starting_day or current_interior!=starting_room:return
		confirm_operation(eat_item(item_id))
		resume.call()
	return begin_action(ACTION_RULES.spec("eat",label,item_id),target,commit,resume)

func eat_item(item_id: String) -> bool:
	if economy.get("locked", []).has(item_id):
		message = "需要的物品已锁定，请先在背包解除保护。"
		changed.emit()
		return false
	var item: Dictionary = item_catalog.get(item_id, {})
	if int(item.get("energy", 0)) <= 0 or int(inventory.get(item_id, 0)) <= 0:
		message = "这件物品不能直接食用。"
		changed.emit()
		return false
	if stamina >= 100:
		message = "现在精神很好，留着待会儿吃吧。"
		changed.emit()
		return false
	var fresh := float(food_freshness(item_id).ratio) if _is_food(item_id) else 1.0
	var counts := _quality_counts(item_id)
	var grade := 0
	for level in range(4):
		if counts[level] > 0:
			grade = level
			break
	var before := stamina
	_consume_item(item_id, 1)
	_reconcile_kitchen_lots()
	var home_bonus:=8 if str(item.get("kind",""))=="料理" and str(skills.get("cooking",{}).get("choice",""))=="home" else 0
	stamina=minf(100.0,before+floorf((float(item.energy)+home_bonus)*(0.65+0.35*fresh)+0.5)+grade*3)
	var buff_kind := "轻快" if item_id in ["summerDrink", "cucumberSalad"] else "暖胃" if item_id in ["winterMilk", "milkPudding", "laba"] else "饱足" if str(recipe_data(item_id).get("category", "")) == "田间便当" else ""
	message="吃了%s，体力回复 %s 点。" % [str(item.get("name",item_id)),preload("res://scripts/js_number.gd").text(stamina-before)]
	if buff_kind!="":
		legacy_systems.buffs.laborDay=-1
		kitchen.buff={"kind":buff_kind,"until":_kitchen_now()+180}
		message+=" "+buff_kind+"持续 180 游戏分钟，新料理增益替换旧增益。"
	message+=" 新鲜度与品质已计入回复。"
	changed.emit()
	return true

func experiment_recipe(first_id: String, second_id: String) -> bool:
	_reconcile_kitchen_lots()
	var first: Dictionary = item_catalog.get(first_id, {})
	var second: Dictionary = item_catalog.get(second_id, {})
	if not _is_food(first_id) or not _is_food(second_id) or str(first.get("kind", "")) == "料理" or str(second.get("kind", "")) == "料理":
		message = "选两样食材或加工原料。"
		changed.emit()
		return false
	var needs: Dictionary = {first_id: 1}
	needs[second_id] = int(needs.get(second_id, 0)) + 1
	if needs.keys().any(func(item_id): return economy.get("locked", []).has(str(item_id))) or not _kitchen_has(needs, 1):
		message = "所选材料不足；相同材料需要两份。"
		changed.emit()
		return false
	for recipe in content.get("recipes", []):
		var ingredients: Dictionary = recipe.get("ingredients", {})
		var matches := true
		for ingredient_id in ingredients:
			if str(ingredient_id) != first_id and str(ingredient_id) != second_id:
				matches = false
		for ingredient_id in needs:
			if not ingredients.has(ingredient_id):
				matches = false
		if matches:
			var recipe_id := str(recipe.get("id", ""))
			if not known_recipes.has(recipe_id):
				known_recipes.append(recipe_id)
				_record_community_log("学会了 %s。" % str(item_catalog.get(recipe_id, {}).get("name", recipe_id)))
			message = "闻到%s与%s，领会了%s！配比已记入菜谱，原料保留。" % [_kitchen_flavor(first_id), _kitchen_flavor(second_id), str(item_catalog.get(recipe_id, {}).get("name", recipe_id))]
			changed.emit()
			return true
	if not spend_energy(2, 8, "", false):
		message = "体力不足。"
		changed.emit()
		return false
	var grade := _kitchen_grade("gardenSoup", needs, 1, "stove")
	_kitchen_consume(needs, 1)
	_kitchen_record("gardenSoup", 1, grade, "gardenSoup")
	_kitchen_cook_completed(1)
	flags.firstCook = true
	var ids := [first_id, second_id]
	ids.sort()
	var signature := "+".join(ids)
	var experiments: Array = kitchen.get("experiments", [])
	if not experiments.has(signature):
		experiments.append(signature)
	while experiments.size() > 40:
		experiments.pop_front()
	kitchen.experiments = experiments
	message = "做成一碗%s·%s田园汤，回复 18 体力。搭配已记下，可以再次制作。" % [_kitchen_flavor(first_id), _kitchen_flavor(second_id)]
	changed.emit()
	return true

func _kitchen_flavor(item_id: String) -> String:
	if system_catalog.get("fishing",{}).get("species",{}).has(item_id):return "鲜香"
	if item_id in ["milk", "cream", "yogurt", "cheese"]: return "奶香"
	if item_id in ["rice", "wheat", "flour", "corn", "taro"]: return "谷香"
	if item_id in ["berry", "watermelon", "pumpkin", "sweetpotato"]: return "甘甜"
	if item_id in ["fish", "shrimp", "crab", "egg", "duckEgg", "mushroom", "truffle"]: return "鲜香"
	if item_id in ["tea", "wildHerb", "shoot", "dryTea"]: return "清香"
	return "田园"

func _advance_kitchen(previous_day: int) -> void:
	_reconcile_kitchen_lots()
	kitchen.lots = preload("res://scripts/kitchen_lifecycle.gd").age_lots(kitchen.get("lots",{"bag":{},"storage":{}}),bool(kitchen.get("cold",false)),int(weather_profile(previous_day).mean_temperature))

func _advance_legacy_processing(previous_day: int) -> void:
	if legacy_processing.is_empty(): return
	var remaining: Array[Dictionary] = []
	var yesterday_weather := str(weather_profile(previous_day).kind)
	for job in legacy_processing:
		if int(job.get("readyDay", day)) > day:
			remaining.append(job)
			continue
		if str(job.get("station", "")) == "晾晒架" and yesterday_weather in ["雨", "台风"]:
			job.readyDay = day + 1
			remaining.append(job)
			continue
		var item_id := str(job.get("id", ""))
		var quantity := int(job.get("qty", 0))
		_grant_legacy_item(item_id, quantity)
		var grade := int(job.get("farmGrade", 0))
		if grade > 0:
			var ledger: Array = quality.get(item_id, [0,0,0])
			ledger[grade - 1] = int(ledger[grade - 1]) + quantity
			quality[item_id] = ledger
		if bool(job.get("cooking", true)):
			player_stats.cooked = int(player_stats.get("cooked", 0)) + quantity
		QUESTS.event(self,"process")
		_record_community_log("%s加工完成，已放入背包。" % str(item_catalog.get(item_id, {}).get("name", item_id)))
	legacy_processing = remaining

func _reset_plots() -> void:
	plots.clear()
	var initial_plots: Array = initial_state.get("plots", [])
	var initial_beds: Array = initial_state.get("farm", {}).get("beds", [])
	for i in range(FARM_LAYOUT.TOTAL):
		var bed: Dictionary = initial_beds[i] if i < initial_beds.size() else {}
		if i < initial_plots.size():
			var source: Dictionary = initial_plots[i]
			var fertility := clampi(int(source.get("soil", 2)) * 50, 0, 100)
			plots.append({"tilled": bool(source.get("tilled", false)), "crop": "" if source.get("crop") == null else str(source.get("crop", "")), "growth": float(source.get("growth", 0)), "watered": bool(source.get("watered", false)), "soil": int(source.get("soil", 2)), "soil_type": str(bed.get("type", "loam")), "last_group": str(source.get("lastGroup", "")), "repeats": int(source.get("repeats", 0)), "fertility": int(bed.get("fertility", fertility)), "moisture": int(bed.get("moisture", 65 if bool(source.get("watered", false)) else 45)), "health": int(bed.get("health", 100)), "pests": int(bed.get("pests", 20 if bool(source.get("pest", false)) else 0)), "disease": int(bed.get("disease", 0)), "weeds": int(bed.get("weeds", 0)), "slow": int(bed.get("slow", 0)), "fertilized": int(bed.get("fertilized", -1)), "treated": int(bed.get("treated", -1)), "compacted": int(bed.get("compacted", 0)), "condition": float(bed.get("condition", 75.0)), "penalty": float(bed.get("penalty", 0.0)), "ripe_days": int(bed.get("ripeDays", 0)), "ticks": int(bed.get("ticks", 0)), "seed_kind": str(bed.get("kind", "normal")), "density": str(bed.get("density", "balanced")), "fallow": bool(bed.get("fallow", false)), "removed": bool(bed.get("removed", false)), "companion": bed.get("companion", {}).duplicate(true) if bed.get("companion") is Dictionary else {}})
		else:
			var blank := _new_plot()
			if not bed.is_empty():
				blank.soil_type = str(bed.get("type", "loam"))
				blank.fertility = int(bed.get("fertility", 100))
				blank.moisture = int(bed.get("moisture", 45))
				blank.health = int(bed.get("health", 100))
				blank.seed_kind = str(bed.get("kind", "normal"))
				blank.density = str(bed.get("density", "balanced"))
			plots.append(blank)

func _new_plot() -> Dictionary:
	return {"tilled": false, "crop": "", "growth": 0.0, "watered": false, "soil": 2, "soil_type": "loam", "last_group": "", "repeats": 0, "fertility": 100, "moisture": 45, "health": 100, "pests": 0, "disease": 0, "weeds": 0, "slow": 0, "fertilized": -1, "treated": -1, "stress": 0, "irrigated": -1, "regrow_days": 0, "harvest_count": 0, "compacted": 0, "condition": 75.0, "penalty": 0.0, "ripe_days": 0, "ticks": 0, "seed_kind": "normal", "density": "balanced", "fallow": false, "removed": false, "companion": {}}

func _normalize_plots() -> void:
	var saved_beds: Array = farm.get("beds", []) if farm is Dictionary and farm.get("beds", []) is Array else []
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		var defaults := _new_plot()
		var bed: Dictionary = saved_beds[i] if i < saved_beds.size() and saved_beds[i] is Dictionary else {}
		var bed_fields := {"regrow_days": bed.get("regrowDays", 0), "harvest_count": bed.get("harvestCount", 0), "soil_type": bed.get("type", "loam"), "fertility": bed.get("fertility", 100), "moisture": bed.get("moisture", 45), "health": bed.get("health", 100), "pests": bed.get("pests", 0), "disease": bed.get("disease", 0), "weeds": bed.get("weeds", 0), "slow": bed.get("slow", 0), "fertilized": bed.get("fertilized", -1), "treated": bed.get("treated", -1), "stress": bed.get("stress", 0), "irrigated": bed.get("irrigated", -1), "compacted": bed.get("compacted", 0), "condition": bed.get("condition", 75.0), "penalty": bed.get("penalty", 0.0), "ripe_days": bed.get("ripeDays", 0), "ticks": bed.get("ticks", 0), "seed_kind": bed.get("kind", "normal"), "density": bed.get("density", "balanced"), "fallow": bed.get("fallow", false), "removed": bed.get("removed", false), "companion": bed.get("companion", {})}
		for key in defaults:
			if not plot.has(key):
				if bed_fields.has(key):
					plot[key] = bed_fields[key].duplicate(true) if bed_fields[key] is Dictionary or bed_fields[key] is Array else bed_fields[key]
				elif key == "fertility":
					plot[key] = clampi(int(plot.get("soil", 2)) * 50, 0, 100)
				elif key == "moisture":
					plot[key] = 65 if bool(plot.get("watered", false)) else 45
				else:
					plot[key] = defaults[key]
		var soils: Dictionary = system_catalog.get("farming", {}).get("soils", {})
		var kinds: Dictionary = system_catalog.get("farming", {}).get("kinds", {})
		if not soils.has(str(plot.get("soil_type", "loam"))): plot.soil_type = "loam"
		if not kinds.has(str(plot.get("seed_kind", "normal"))): plot.seed_kind = "normal"
		if str(plot.get("density", "balanced")) not in ["sparse", "balanced", "dense"]: plot.density = "balanced"
		if not plot.get("companion", {}) is Dictionary: plot.companion = {}
		plot.regrow_days = clampi(int(plot.get("regrow_days",0)),0,int(preload("res://scripts/farm_insights.gd").REGROW.get(str(plot.get("crop","")),0)))
		plot.harvest_count = clampi(int(plot.get("harvest_count",0)),0,100000)
		if not plot.companion.is_empty() and not crop_catalog.has(str(plot.companion.get("crop",""))): plot.companion = {}
		if not crop_data(str(plot.get("crop", ""))).is_empty():
			plot.fertility = clampf(float(plot.fertility), 0.0, 100.0)
			plot.moisture = clampf(float(plot.moisture), 0.0, 100.0)
			plot.health = clampf(float(plot.health), 0.0, 100.0)
		plots[i] = plot

func _sync_farm_beds_from_plots() -> void:
	if not farm is Dictionary:
		farm = {}
	var beds: Array = []
	for plot in plots:
		beds.append({"type": plot.get("soil_type", "loam"), "fertility": plot.get("fertility", 100), "moisture": plot.get("moisture", 45), "health": plot.get("health", 100), "pests": plot.get("pests", 0), "disease": plot.get("disease", 0), "weeds": plot.get("weeds", 0), "slow": plot.get("slow", 0), "fertilized": plot.get("fertilized", -1), "treated": plot.get("treated", -1), "stress": plot.get("stress", 0), "ripeDays": plot.get("ripe_days", 0), "kind": plot.get("seed_kind", "normal"), "density": plot.get("density", "balanced"), "compacted": plot.get("compacted", 0), "fallow": plot.get("fallow", false), "removed": plot.get("removed", false), "condition": plot.get("condition", 75.0), "ticks": plot.get("ticks", 0), "penalty": plot.get("penalty", 0.0), "companion": plot.get("companion", {}).duplicate(true) if plot.get("companion", {}) is Dictionary and not plot.get("companion", {}).is_empty() else null, "irrigated": plot.get("irrigated", -1)})
		if int(plot.get("regrow_days",0)) > 0:
			beds[-1].regrowDays = int(plot.regrow_days)
			beds[-1].harvestCount = int(plot.get("harvest_count",0))
	farm.beds = beds

func cancel_ranch_queue() -> void:
	var held_id := str(ranch_active_task.get("animalId",""))
	if held_id != "": ranch_holds.erase(held_id)
	if str(action_sequence.snapshot().get("targetKind",""))=="ranch-task": cancel_action()
	ranch_queue.clear()
	ranch_active_task.clear()
	ranch_queue_generation += 1

func ranch_animal_index(id: String) -> int:
	for index in range(animals.size()):
		if str(animals[index].get("id","")) == id: return index
	return -1

func ranch_filtered_ids(filter: String = "all") -> Array:
	var ids: Array = []
	for a in animals:
		if filter == "all" or str(a.get("type","")) == filter or filter == "ready" and (int(a.ready)>0 or int(a.feathers)>0) or filter == "care" and (int(a.hunger)<40 or int(a.illness)>=20 or int(a.clean)<45 or bool(a.lost)):
			ids.append(str(a.id))
	return ids

func ranch_batch_plan(ids: Array, action: String) -> Array:
	var tasks: Array = []
	for id in ids:
		var index := ranch_animal_index(str(id))
		if index < 0: continue
		var a: Dictionary = animals[index]
		var care: Dictionary = a.get("care",{})
		var eligible := true
		match action:
			"feed": eligible = preload("res://scripts/ranch_care.gd").needed(self,a,day)>0 and float(a.hunger)<70
			"collect": eligible = int(a.ready) > 0 or int(a.feathers) > 0
			"clean": eligible = int(a.clean) < 95 and int(care.get("clean",-1)) != day
			"treat": eligible = int(a.illness) > 0 and int(care.get("treat",-1)) != day
		if eligible: tasks.append({"animalId":str(id),"action":action,"arg":str(ranch.get("feed","feed"))})
	return tasks

func advance_ranch_movement(delta: float) -> void:
	if ui_open or ranch.is_empty() or system_catalog.is_empty(): return
	if ranch_movement == null: ranch_movement = RANCH_MOVEMENT_SCRIPT.new()
	ranch_actor_clock += delta
	ranch_movement.advance(self,delta)
	ranch_positions_changed.emit()

func gather_ranch_actors(at: Vector2) -> void:
	ranch_actor_focus = {"x":at.x,"y":at.y,"until":npc_movement.clock+24.0}

func hold_ranch_actor(id: String) -> void:
	ranch_holds[id] = ranch_actor_clock+35.0

func ranch_actor_held(id: String) -> bool:
	if str(ranch_active_task.get("animalId","")) == id: return true
	for task: Dictionary in ranch_queue:
		if str(task.get("animalId","")) == id: return true
	return ranch_actor_clock < float(ranch_holds.get(id,0.0))

func house_data(id: String) -> Dictionary:
	for building in world_village.get("houses",[]):
		if str(building.get("id","")) == id: return building
	return {}

func ranch_actor_destination(id: String) -> Dictionary:
	var index:=ranch_animal_index(id)
	if index<0:return {}
	var animal: Dictionary=animals[index]
	var position: Dictionary=animal.position
	var room: String="" if position.get("room")==null else str(position.room)
	if room!="" and room!=current_interior:
		var species: Dictionary=system_catalog.ranch.species[str(animal.type)]
		var house: Dictionary=house_data(str(system_catalog.ranch.barns[str(species.home)].house))
		var point: Dictionary=house.door.duplicate()
		point.merge({"id":str(house.id),"house":str(house.id),"kind":"enter","name":str(house.name)},true)
		return point
	var point: Dictionary=(position.inside if room!="" else position).duplicate()
	point.merge({"kind":"animal","id":id,"name":str(animal.name),"room":position.get("room")},true)
	return point

func ranch_task_destination(task: Dictionary) -> Dictionary:
	var at := Vector2.ZERO
	var room := ""
	var label := "畜舍"
	var stage := "action"
	var house := ""
	if task.has("animalId"):
		var index := ranch_animal_index(str(task.animalId))
		if index < 0: return {}
		var a: Dictionary = animals[index]
		var position_data: Dictionary = a.get("position",{})
		room = str(position_data.room) if position_data.get("room") != null else ""
		label = str(a.get("name","伙伴"))
		var position_point: Dictionary = position_data.get("inside",{}) if room != "" else position_data
		at = Vector2(float(position_point.get("x",480)),float(position_point.get("y",490)))
		if str(task.get("action","")) == "collect":
			for product: Dictionary in ranch.get("products",[]):
				if str(product.animalId) != str(a.id) or str(product.location) not in ["nest","ground"]: continue
				room = "" if product.get("room") == null else str(product.room)
				at = Vector2(float(product.x),float(product.y))
				break
		if room != "" and current_interior != room:
			house = room
			var definition := house_data(room)
			if definition.is_empty(): return {}
			var door: Dictionary = definition.get("door",{})
			at = Vector2(float(door.get("x",0)),float(door.get("y",0)))
			room = ""
			stage = "enter"
	elif bool(task.get("pet",false)):
		var position_data: Dictionary = ranch.get("pet",{}).get("position",{})
		at = Vector2(float(position_data.get("x",2775)),float(position_data.get("y",1690)))
		label = str(pet_state.get("name","小团"))
	else:
		var barn_id := str(task.get("barnId","cattle"))
		var definition: Dictionary = system_catalog.get("ranch",{}).get("barns",{}).get(barn_id,{})
		if definition.is_empty(): return {}
		var building := house_data(str(definition.get("house","")))
		if building.is_empty(): return {}
		label = str(definition.get("name",barn_id))
		if str(task.get("action",""))=="craft" and str(task.get("arg",""))=="compost":
			var corner:Dictionary=system_catalog.ranch.compostCorner
			at=Vector2(float(corner.x),float(corner.y));label="猪圈旁堆肥加工角"
		elif current_interior == str(building.id):
			room = current_interior
			at = Vector2(730,492) if str(task.get("action",""))=="claimBox" else _ranch_workstation_position(room)
		else:
			var door: Dictionary = building.get("door",{})
			at = Vector2(float(door.get("x",0)),float(door.get("y",0)))
			if str(task.get("action",""))=="claimBox":
				house=str(building.id);stage="enter"
	return {"id":"ranch-task","kind":"ranch-task","name":"牧场照料 · "+label,"x":at.x,"y":at.y,
		"ranch_task":true,"ranch_stage":stage,"house":house,"world_click":current_interior == room,
		"click_room":room,"auto_interact":true}

func _ranch_workstation_position(room: String) -> Vector2:
	# Original (480,495) fallback overlaps furniture in three barns. Keep all
	# collision geometry and choose nearby reachable ground for this workpoint only.
	var authored := Vector2(480,490)
	if atlas_source_navigation == null:
		atlas_source_navigation = preload("res://scripts/npc_navigation.gd").new()
	atlas_source_navigation.refresh(self)
	if not atlas_source_navigation.blocked(self,room,authored.x,authored.y+5.0):
		return authored
	var origin: Dictionary = player_navigation_position()
	for candidate: Vector2 in [Vector2(480,522),Vector2(480,528),Vector2(456,522),Vector2(504,522)]:
		var stand := {"x":candidate.x,"y":candidate.y+5.0}
		if not atlas_source_navigation.blocked(self,room,stand.x,stand.y) and not atlas_source_navigation.route(self,room,origin,stand).is_empty():
			return candidate
	return authored

func queue_ranch_tasks(tasks: Array) -> bool:
	if tasks.is_empty():
		message = "暂无需要这项照料的伙伴。"
		changed.emit()
		return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	cancel_action()
	source_keyboard.clear()
	players[0].get_parent().get("hud").close_top_panel()
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	building_task.clear()
	walking_target.clear()
	ranch_queue = tasks.duplicate(true)
	ranch_completed = 0
	return advance_ranch_task()

func advance_ranch_task() -> bool:
	if ranch_active_task.is_empty():
		if ranch_queue.is_empty(): return false
		ranch_active_task = ranch_queue.pop_front()
	if ranch_active_task.has("animalId"): hold_ranch_actor(str(ranch_active_task.animalId))
	elif bool(ranch_active_task.get("pet",false)): hold_ranch_actor("pet")
	var target := ranch_task_destination(ranch_active_task)
	var players := get_tree().get_nodes_in_group("player")
	if target.is_empty() or players.is_empty():
		cancel_ranch_queue()
		message = "伙伴已不在牧场，本批停止。"
		changed.emit()
		return false
	if not players[0].walk_to(target):
		cancel_ranch_queue()
		message = "这条照料路线暂时走不过去，本批停止。"
		changed.emit()
		return false
	return true

func perform_ranch_task(task: Dictionary) -> bool:
	var ok := _perform_ranch_task_operation(task)
	if ok:
		var id := str(task.get("animalId","pet"))
		ranch_holds[id] = ranch_actor_clock+2.2
		if task.has("animalId"):
			ranch_actor_poses[id] = {"action":str(task.get("action","")),"until":ranch_actor_clock+2.2}
			var index := ranch_animal_index(id)
			if index >= 0: ranch_actor_action = {"id":id,"kind":str(task.get("action","")),"at":ranch_actor_clock,"room":animals[index].position.get("room")}
	return ok

func _perform_ranch_task_operation(task: Dictionary) -> bool:
	var action := str(task.get("action",""))
	var arg: Variant = task.get("arg","")
	if task.has("animalId"):
		if action == "retire": return ranch_retire_animal(str(task.animalId))
		return ranch_tend(ranch_animal_index(str(task.animalId)),action,str(arg))
	if bool(task.get("pet",false)): return ranch_pet_action(action)
	match action:
		"claimBox": return ranch_fixture_action("ranch-box",str(task.get("barnId","")))
		"craft": return ranch_craft(str(arg),task.get("quantity",1))
		"purchase":
			if arg is Array and arg.size() == 4: return ranch_buy_animal(str(arg[0]),str(arg[1]),str(arg[2]),bool(arg[3]))
		"breed":
			if arg is Array and arg.size() == 2: return ranch_breed(str(arg[0]),str(arg[1]))
		"incubate": return ranch_incubate(str(arg))
		_: return ranch_barn_action(str(task.get("barnId","cattle")),action)
	return false

func finish_ranch_task(target: Dictionary) -> void:
	if ranch_active_task.is_empty(): return
	var actual := ranch_task_destination(ranch_active_task)
	var players := get_tree().get_nodes_in_group("player")
	if actual.is_empty():
		cancel_ranch_queue()
		message = "伙伴已不在牧场，本批停止。"
		changed.emit()
		return
	var at := Vector2(float(actual.x),float(actual.y))
	if players.is_empty(): return
	if str(actual.ranch_stage) != str(target.ranch_stage) or str(actual.house) != str(target.house) or players[0].global_position.distance_to(at) > (70.0 if ranch_active_task.has("animalId") and str(actual.ranch_stage) == "action" else 53.0):
		advance_ranch_task()
		return
	if str(actual.ranch_stage) == "enter":
		if not bool(target.get("_door_resolved",false)):
			var point:=actual.duplicate(true)
			point.kind="enter"
			var resolved:=target.duplicate(true)
			resolved["_door_resolved"]=true
			begin_point_action(point,finish_ranch_task.bind(resolved))
			return
		if not enter_interior(str(actual.house)): cancel_ranch_queue()
		return
	if not bool(target.get("_sequence_resolved",false)):
		var point := target.duplicate(true)
		point.action = str(ranch_active_task.get("action",""))
		if ranch_active_task.has("animalId"):point.animalId=ranch_active_task.animalId
		if ranch_active_task.has("animalId") and str(point.action)=="collect":
			var animal_index := ranch_animal_index(str(ranch_active_task.animalId))
			if animal_index>=0:point.harvestVerb=system_catalog.ranch.species[str(animals[animal_index].type)].get("harvestVerb","收取")
		_begin_task_action(point,finish_ranch_task)
		return
	var task := ranch_active_task.duplicate(true)
	ranch_active_task.clear()
	var ok := confirm_operation(perform_ranch_task(task),"good",false)
	ranch_next_at = source_frame_time + 1.1
	if not ok:
		cancel_ranch_queue()
		message += " 本批停止，已完成 %d 次。" % ranch_completed
		changed.emit()
		return
	ranch_completed += 1
	var world: Node = players[0].get_parent()
	if world.has_method("_emit_world_effect"):
		world.call("_emit_world_effect","harvest" if str(task.action) == "collect" else "feed" if str(task.action) == "feed" else "brush" if str(task.action) == "clean" else "pet",at,false)
	if ranch_queue.is_empty():
		changed.emit()

func cancel_farm_queue() -> void:
	if str(action_sequence.snapshot().get("targetKind",""))=="farm-task": cancel_action()
	farm_queue.clear()
	farm_active_task.clear()
	farm_queue_generation += 1

func farm_filtered_indices(filter: String = "all", region: String = "all", crop: String = "all") -> Array[int]:
	var result: Array[int] = []
	for index in range(plots.size()):
		var p: Dictionary = plots[index]
		var id := str(p.crop)
		if region != "all" and (index < FARM_LAYOUT.MAIN_COUNT) != (region == "home"): continue
		if crop != "all" and id != crop: continue
		var profile := crop_profile(id) if id != "" else {"low":35,"high":85}
		var matches := filter == "all" or filter == "ready" and id != "" and float(p.growth) >= crop_days(id) or filter == "dry" and id != "" and bool(p.tilled) and float(p.moisture) < float(profile.low) or filter == "risk" and (float(p.pests) >= 15 or float(p.disease) >= 15 or id != "" and float(p.health) < 40 or bool(p.tilled) and float(p.moisture) > float(profile.high)) or filter == "empty" and bool(p.tilled) and id == "" and not bool(p.get("removed",false))
		if matches: result.append(index)
	return result

func farm_batch_plan(indices: Array, action: String) -> Array:
	var tasks: Array = []
	var seen: Array[int] = []
	for value in indices:
		var index := int(value)
		if index < 0 or index >= plots.size() or seen.has(index): continue
		seen.append(index)
		var p: Dictionary = plots[index]
		var id := str(p.crop)
		if action == "care":
			if not bool(p.tilled) or bool(p.get("removed",false)) or id == "": continue
			var profile := crop_profile(id)
			if float(p.moisture) < float(profile.low): tasks.append({"index":index,"action":"water"})
			elif float(p.moisture) > float(profile.high) and float(p.moisture) > 60: tasks.append({"index":index,"action":"drain"})
			if int(p.get("treated",-1)) != day:
				if float(p.disease) >= 15: tasks.append({"index":index,"action":"bio"})
				elif float(p.pests) >= 15: tasks.append({"index":index,"action":"manual"})
			if float(p.weeds) > 35: tasks.append({"index":index,"action":"weed"})
			continue
		if action == "sow" and not preload("res://scripts/farm_insights.gd").sow_reason(self,index,selected_seed,str(farm.get("seedKind","normal")),str(farm.get("density","balanced"))).is_empty(): continue
		if action == "companionHarvest":
			var companion: Dictionary = p.get("companion",{})
			if not companion.is_empty() and float(companion.get("growth",0)) >= crop_days(str(companion.get("crop",""))): tasks.append({"index":index,"action":action})
			continue
		var usable: bool = action == "harvest" and id != "" and float(p.growth) >= crop_days(id) or action == "sow" and bool(p.tilled) and id == "" and not bool(p.get("removed",false)) or action == "water" and id != "" and bool(p.tilled) and not bool(p.get("removed",false)) and float(p.moisture) < float(crop_profile(id).low) or action == "fertilize" and bool(p.tilled) and float(p.fertility) < 70 and int(p.get("fertilized",-1)) != day
		if not usable: continue
		var task := {"index":index,"action":action}
		if action == "sow": task.arg = {"crop":selected_seed,"kind":str(farm.get("seedKind","normal")),"density":str(farm.get("density","balanced"))}
		tasks.append(task)
	return tasks

func farm_tool_plan(index: int, id: String) -> Array:
	if index < 0 or index >= plots.size() or id not in ["hoe","water","sickle"]: return []
	var tasks: Array = []
	var tool := tool_data(id)
	for i in _farm_targets(index,id):
		var p: Dictionary = plots[i]
		var crop := str(p.crop)
		var removed := bool(p.get("removed",false))
		var care := int(tool.get("level",0)) == 2 and str(tool.get("branch","broad")) == "care"
		var usable: bool = bool(p.tilled) and not removed and float(p.moisture) < (float(crop_profile(crop).low) if crop != "" else 35.0) if id == "water" else crop != "" and float(p.growth) >= crop_days(crop) if id == "sickle" else crop == "" and p.get("companion",{}).is_empty() and (not bool(p.tilled) or removed or care and (float(p.compacted) > 0 or float(p.fertility) < 95))
		if usable: tasks.append({"index":i,"action":"water" if id == "water" else "harvest" if id == "sickle" else "restore" if not bool(p.tilled) or removed else "deep" if care else "hoe"})
	return tasks

func queue_farm_tasks(tasks: Array) -> bool:
	if tasks.is_empty():
		message = "范围内暂无适用田块。"
		changed.emit()
		return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	cancel_action()
	source_keyboard.clear()
	players[0].get_parent().get("hud").close_top_panel()
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	building_task.clear()
	walking_target.clear()
	farm_queue = tasks.duplicate(true)
	farm_completed = 0
	return advance_farm_task()

func advance_farm_task() -> bool:
	if farm_active_task.is_empty():
		if farm_queue.is_empty(): return false
		farm_active_task = farm_queue.pop_front()
	var index := int(farm_active_task.get("index",-1))
	if index < 0 or index >= plots.size():
		cancel_farm_queue()
		cancel_ranch_queue()
		return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return false
	var at := _farm_position(index)
	var target := {"id":"farm-task-"+str(index),"kind":"farm-task","name":"农事 · "+str(index+1)+" 号田","index":index,"x":at.x,"y":at.y,"farm_task":true,"world_click":current_interior == "","click_room":"","auto_interact":true}
	if not players[0].walk_to(target):
		cancel_farm_queue()
		cancel_ranch_queue()
		message = "这块地暂时无法到达，本批已停止。"
		changed.emit()
		return false
	return true

func perform_farm_task(task: Dictionary) -> bool:
	var index := int(task.get("index",-1))
	if index < 0 or index >= plots.size(): return false
	var action := str(task.get("action",""))
	var task_arg: Variant = task.get("arg",{})
	var choices: Dictionary = task_arg if task_arg is Dictionary else {}
	var basic := {"hoe":"hoe","restore":"hoe","sow":"seed","water":"water","harvest":"hand","fertilize":"fertilizer"}
	if basic.has(action):
		var ok := _farm_plot_action_single(index,str(basic[action]),choices)
		if ok:
			if action in ["hoe","restore","water","harvest"]: _award_tool("sickle" if action == "harvest" else "hoe" if action == "restore" else action)
			_award_skill_xp("farming",1)
			changed.emit()
		return ok
	var ok := farm_special_action(index,action,task_arg)
	if ok:
		_award_skill_xp("farming",1)
		if action in ["deep","drain","weed","seedSave"]: _award_tool("hoe" if action == "deep" else "water" if action == "drain" else "sickle")
		changed.emit()
	return ok

func finish_farm_task(target: Dictionary) -> void:
	if farm_active_task.is_empty(): return
	var players := get_tree().get_nodes_in_group("player")
	var at := Vector2(float(target.x),float(target.y))
	if players.is_empty() or players[0].global_position.distance_to(at) >= 53:
		stop_walking()
		return
	if not bool(target.get("_sequence_resolved",false)):
		var point := target.duplicate(true)
		point.action = str(farm_active_task.get("action",""))
		_begin_task_action(point,finish_farm_task)
		return
	var task := farm_active_task.duplicate(true)
	farm_active_task.clear()
	var ok := confirm_operation(perform_farm_task(task),"good",false)
	farm_next_at = source_frame_time + 0.85
	if not ok:
		cancel_farm_queue()
		cancel_ranch_queue()
		message += " 已完成 %d 块，本批停止。" % farm_completed
		changed.emit()
		return
	farm_completed += 1
	var world: Node = players[0].get_parent()
	if world.has_method("_emit_world_effect"):
		world.call("_emit_world_effect","harvest" if str(task.action) in ["harvest","seedSave","companionHarvest"] else "water" if str(task.action) == "water" else "seed" if str(task.action) in ["sow","companion"] else "hoe",at,false)
	if farm_queue.is_empty():
		message = "农事完成 · %d 次。%s" % [farm_completed,message]
		changed.emit()

func farm_plot_action(index: int) -> bool:
	var tool_id: String = {"hoe": "hoe", "water": "water", "harvest": "sickle", "sickle": "sickle"}.get(selected_tool, "")
	if tool_id == "":
		var before := stamina
		var success := _farm_plot_action_single(index)
		if stamina < before:
			if selected_tool == "hand": _award_tool("sickle")
			_award_skill_xp("farming", 3 if selected_tool == "hand" else 1)
		return success
	var targets := _farm_targets(index, tool_id)
	var successes := 0
	for target in targets:
		var before := stamina
		_farm_plot_action_single(target)
		if stamina < before:
			successes += 1
			_award_tool(tool_id)
			_award_skill_xp("farming", 3 if selected_tool in ["harvest", "sickle"] else 1)
	if successes > 1:
		message += " 共完成 %d 块田。" % successes
	changed.emit()
	return successes > 0

func _farm_plot_action_single(index: int, action_tool: String = "", seed_choices: Dictionary = {}) -> bool:
	var success := false
	var tool_id := selected_tool if action_tool == "" else action_tool
	if index < 0 or index >= plots.size():
		return false
	var plot: Dictionary = plots[index]
	if tool_id != "hoe" and (not bool(plot.tilled) or bool(plot.get("removed",false))):
		message = "先挥锄开垦或修复这块地。"
		changed.emit()
		return false
	match tool_id:
		"hoe":
			if str(plot.crop) != "":
				message = "先收下作物再松土。"
			elif bool(plot.tilled) and not bool(plot.get("removed",false)) and not bool(plot.get("fallow",false)):
				message = "土已经松好了，换种子播种吧。"
			elif spend_energy(3, 5, "hoe"):
				success = true
				# Legacy light-handle hoe upgrade keeps its matching labor discount.
				plot.tilled = true
				plot.removed = false
				plot.fallow = false
				plot.compacted = maxi(0, int(plot.get("compacted", 0)) - 25)
				if int(tool_data("hoe").get("level", 0)) >= 2 and str(tool_data("hoe").get("branch", "broad")) == "care":
					plot.compacted = maxi(0, int(plot.compacted) - 15)
				message = "翻好了第 %d 块地，可重新耕种。" % (index + 1)
		"seed":
			var seed_kind := str(seed_choices.get("kind",farm.get("seedKind", "normal")))
			var crop_id := str(seed_choices.get("crop",selected_seed))
			var density := str(seed_choices.get("density",farm.get("density", "balanced")))
			var seed_key := seed_variant_id(crop_id, seed_kind)
			var blocked := preload("res://scripts/farm_insights.gd").sow_reason(self,index,crop_id,seed_kind,density)
			if not blocked.is_empty():
				message = blocked
			elif int(inventory.get(seed_key, 0)) < (2 if density == "dense" else 1):
				message = "这种种子用完了。按 Q 可以切换种子。"
			elif not crop_in_season(crop_id) and not (seed_kind != "seasonal" and farm_facility_coverage(index, "greenhouse")):
				message = crop_name(crop_id) + "不适合当前季节；普通种与乡传良种可在小暖棚内反季播种。"
			elif spend_energy(2, 5):
				success = true
				inventory[seed_key] -= 2 if density == "dense" else 1
				plot.crop = crop_id
				plot.growth = 0.0
				plot.health = 100
				plot.condition = 75.0
				plot.penalty = 0.0
				plot.ticks = 0
				plot.ripe_days = 0
				plot.seed_kind = seed_kind
				plot.regrow_days = int(preload("res://scripts/farm_insights.gd").REGROW.get(crop_id,0))
				plot.harvest_count = 0
				plot.density = density
				plot.fallow = false
				message = "种下%s·%s（%s）。" % [crop_name(str(plot.crop)), str(system_catalog.get("farming", {}).get("kinds", {}).get(seed_kind, {}).get("name", seed_kind)), {"sparse": "疏植", "balanced": "标准株距", "dense": "密植"}.get(density, "标准株距")]
				onboarding_mark("sow")
		"water":
			var profile := crop_profile(str(plot.crop)) if str(plot.crop) != "" else {"low": 35, "high": 85}
			if not plot.tilled or int(plot.moisture) >= 95:
				message = "这块地的土壤湿润度足够。"
			elif spend_energy(2, 5, "water"):
				success = true
				var gentle_water := int(tool_data("water").get("level", 0)) >= 2 and str(tool_data("water").get("branch", "broad")) == "care"
				var target := int(profile.high) - 10 if str(plot.crop) != "" else 65
				plot.moisture = maxi(int(plot.moisture), mini(target, int(plot.moisture) + 40)) if gentle_water else mini(100, int(plot.moisture) + 30)
				plot.watered = int(plot.moisture) >= 35
				if int(plot.moisture) >= int(profile.low) and int(plot.moisture) <= int(profile.high):
					plot.health = mini(100, int(plot.health) + 8)
				if gentle_water:
					plot.health = mini(100, int(plot.health) + 3)
				message = "清水浸进了土里，湿度升到 %d。" % int(plot.moisture)
		"harvest", "hand", "sickle":
			if str(plot.crop) == "" or float(plot.growth) < crop_days(str(plot.crop)):
				message = "作物还没成熟。"
			elif spend_energy(1 if int(tool_data("sickle").get("level", 0)) >= 1 else 2, 5):
				success = true
				_harvest_plot(index)
		"fertilizer":
			if str(plot.crop) == "" and not plot.tilled:
				message = "先开垦一块地再施肥。"
			elif int(plot.get("fertilized", -1)) == day:
				message = "今天已经施过肥了，留些空间让地力慢慢吸收。"
			elif int(plot.fertility) >= 95:
				message = "这块地已经很肥沃。"
			elif int(inventory.get("compost", 0)) <= 0:
				message = "缺少堆肥。"
			elif spend_energy(2, 5):
				success = true
				inventory["compost"] -= 1
				plot.fertility = mini(100, int(plot.fertility) + 25)
				plot.compacted = maxi(0, int(plot.compacted) - 10)
				plot.fertilized = day
				message = "把堆肥拌进土里，肥力提高了。"
		"care":
			if int(plot.pests) <= 0 and int(plot.disease) <= 0 and int(plot.weeds) <= 0:
				message = "田里暂时没有需要处理的病虫草害。"
			elif spend_energy(2, 5):
				success = true
				plot.pests = maxi(0, int(plot.pests) - 35)
				plot.disease = maxi(0, int(plot.disease) - 20)
				plot.weeds = maxi(0, int(plot.weeds) - 40)
				message = "仔细检查并清理了田里的虫害与杂草。"
		"soil":
			success = change_plot_soil(index, str(farm.get("selectedSoil", "loam")))
		_:
			message = "这件工具不适合田地，可换锄头、水壶或镰刀。"
	if success:QUESTS.event(self,{"seed":"sow","water":"water","fertilizer":"fertilize"}.get(tool_id,"farmAction"))
	changed.emit()
	return success

func farm_special_action(index: int, action: String, arg: Variant = {}) -> bool:
	if index < 0 or index >= plots.size():
		message = "请选择有效田块。"
		changed.emit()
		return false
	var plot: Dictionary = plots[index]
	if not bool(plot.get("tilled", false)) or bool(plot.get("removed", false)):
		message = "先修复并开垦田地。"
		changed.emit()
		return false
	if action == "soil":
		return change_plot_soil(index, str(arg) if arg is String else str(farm.get("selectedSoil", "loam")))
	if action == "seedSave":
		var crop_id := str(plot.get("crop", ""))
		if crop_id == "" or float(plot.get("growth", 0.0)) < crop_days(crop_id):
			message = "主作物成熟后才能留种。"
		elif spend_energy(2, 5):
			var preview := preload("res://scripts/farm_insights.gd").harvest(self,plot)
			var grade := int(preview.grade)
			var seed_kind := "heirloom" if int(plot.get("health", 0)) >= 75 and grade >= 2 else str(plot.get("seed_kind", "normal"))
			var amount := (2 if int(plot.get("health", 0)) >= 60 else 1) + (1 if int(plot.get("health", 0)) >= 75 and int(plot.get("ripe_days", 0)) >= 4 and int(plot.get("ripe_days", 0)) <= 8 else 0)
			var seed_id := seed_variant_id(crop_id, seed_kind)
			_add_inventory_count(seed_id, amount)
			var group := str(crop_data(crop_id).get("group", ""))
			if int(plot.get("harvest_count",0)) == 0:
				plot.repeats = int(plot.repeats) + 1 if str(plot.get("last_group", "")) == group else 1
				plot.last_group = group
				plot.fertility = clampi(int(plot.fertility) + (14 if group == "豆类" else -5), 0, 100)
			_finish_farm_crop(plot)
			message = "留出%s种子 ×%d；主作物已收种。" % [str(system_catalog.get("farming", {}).get("kinds", {}).get(seed_kind, {}).get("name", seed_kind)), amount]
			if str(plot.get("crop", "")) != "":
				message += " 套种作物接替了田垄。"
			changed.emit()
			return true
		changed.emit()
		return false
	if action == "companion":
		var choices: Dictionary = arg if arg is Dictionary else {}
		var crop_id := str(choices.get("crop", selected_seed))
		var kind := str(choices.get("kind", farm.get("seedKind", "normal")))
		var density := str(choices.get("density", farm.get("density", "balanced")))
		var seed_id := seed_variant_id(crop_id, kind)
		if str(plot.get("crop", "")) == "" or not plot.get("companion", {}).is_empty():
			message = "先种好主作物；一块地只能套种一株。"
		elif not crop_catalog.has(crop_id) or not system_catalog.get("farming",{}).get("kinds",{}).has(kind) or density not in ["sparse","balanced","dense"] or crop_compatibility(str(plot.crop), crop_id) < 0:
			message = "同科作物会争肥，试试豆类或叶菜搭配根菜。"
		elif not crop_in_season(crop_id) and not (farm_facility_coverage(index, "greenhouse") and kind != "seasonal"):
			message = "套种作物当前不适季，暖棚可为普通种和乡传良种延季。"
		elif int(inventory.get(seed_id, 0)) < 1:
			message = "套种需要一份%s。" % str(item_catalog.get(seed_id, {}).get("name", seed_id))
		elif spend_energy(2, 5):
			inventory[seed_id] = int(inventory[seed_id]) - 1
			plot.companion = {"crop": crop_id, "growth": 0.0, "kind": kind, "density": density}
			message = "在田垄旁套种%s，成熟后可单独收下。" % crop_name(crop_id)
			changed.emit()
			return true
		changed.emit()
		return false
	if action == "companionHarvest":
		var companion: Dictionary = plot.get("companion", {})
		var companion_crop := str(companion.get("crop", ""))
		if companion.is_empty() or not crop_catalog.has(companion_crop) or float(companion.get("growth", 0.0)) < crop_days(companion_crop):
			message = "套种作物还没成熟。"
		elif spend_energy(2, 5):
			var source := plot.duplicate(true)
			source.condition = float(companion.get("condition",plot.get("condition",75)))
			source.ripe_days = int(companion.get("ripe_days",0))
			var preview := preload("res://scripts/farm_insights.gd").harvest(self,source,companion_crop,str(companion.get("kind","normal")))
			var grade := int(preview.grade)
			_grant_quality(companion_crop, 1, grade)
			player_stats.harvested = int(player_stats.get("harvested",0))+1
			plot.companion = {}
			message = "摘下垄旁的%s ×1 · %s。" % [crop_name(companion_crop), ["普通", "优质", "上品", "珍品"][grade]]
			_museum_record("item:" + companion_crop, true, true, false, grade)
			changed.emit()
			return true
		changed.emit()
		return false
	if action == "drain":
		if int(plot.get("moisture", 45)) <= 60: message = "这块地暂时不需要排水。"
		elif spend_energy(2, 5, "water"):
			plot.moisture = maxi(55, int(plot.moisture) - 30)
			plot.health = mini(100, int(plot.health) + 5)
			message = "疏通小沟，积水缓缓流走。"
			changed.emit()
			return true
		changed.emit()
		return false
	if action in ["deep", "fallow", "remove", "soil"] and (str(plot.get("crop", "")) != "" or not plot.get("companion", {}).is_empty()):
		message = "先收下作物；土地调整不会替你销毁作物。"
		changed.emit()
		return false
	if action == "deep":
		if spend_energy(4, 5, "hoe"):
			plot.compacted = 0
			plot.fertility = mini(100, int(plot.get("fertility", 50)) + (8 if int(tool_data("hoe").get("level",0)) == 2 and str(tool_data("hoe").get("branch","broad")) == "care" else 5))
			message = "深翻晒土，板结松开了。"
			changed.emit()
			return true
	if action == "fallow":
		if spend_energy(2, 5):
			plot.fallow = not bool(plot.get("fallow", false))
			message = "铺好草屑，让土地休息。" if bool(plot.fallow) else "结束休耕，可以重新播种。"
			changed.emit()
			return true
	if action == "remove":
		if spend_energy(2, 5):
			plot.removed = true
			plot.tilled = false
			message = "撤去田垄，土壤仍留在原处；挥锄可修复。"
			changed.emit()
			return true
	if action == "weed":
		if int(plot.get("weeds", 0)) < 10: message = "田垄很干净。"
		elif spend_energy(2, 5):
			plot.weeds = 0
			message = "拔掉杂草，作物根须有了空间。"
			changed.emit()
			return true
		changed.emit()
		return false
	if action in ["manual", "bio", "agent"]:
		if int(plot.get("pests", 0)) < 1 and int(plot.get("disease", 0)) < 1: message = "暂时没有病虫害，不必处理。"
		elif int(plot.get("treated", -1)) == day: message = "今天已经处理过，明早再观察。"
		elif action == "manual" and int(plot.get("pests", 0)) < 1: message = "人工捉虫不能消除叶斑，请用护苗液。"
		elif action == "bio" and int(inventory.get("bioCare", 0)) < 1: message = "缺少草本护苗液。"
		elif action == "agent" and int(inventory.get("plantCare", 0)) < 1: message = "缺少速效护苗剂。"
		elif spend_energy(3 if action == "manual" else 2, 5):
			if action == "bio": inventory.bioCare = int(inventory.get("bioCare", 0)) - 1
			if action == "agent": inventory.plantCare = int(inventory.get("plantCare", 0)) - 1
			plot.pests = clampi(int(plot.pests) - (45 if action == "manual" else 35 if action == "bio" else 80), 0, 100)
			if action != "manual": plot.disease = clampi(int(plot.disease) - (40 if action == "bio" else 80), 0, 100)
			plot.health = mini(100, int(plot.get("health", 0)) + 15)
			plot.treated = day
			if action == "agent": plot.penalty = minf(100.0, float(plot.get("penalty", 0.0)) + 8.0)
			message = "病叶与虫害得到控制；速效护苗剂会轻微影响本茬品质。" if action == "agent" else "仔细护好叶片，明天再看长势。"
			changed.emit()
			return true
		changed.emit()
		return false
	if action in ["fertilizer", "slow", "green"]:
		if int(plot.get("fertilized", -1)) == day or action == "slow" and int(plot.get("slow", 0)) > 0: message = "今天已有肥效，不必重复施肥。"
		elif action == "green" and str(plot.get("crop", "")) != "": message = "绿肥翻埋需要空地。"
		elif int(plot.get("fertility", 0)) >= 95: message = "土壤肥沃，暂时不需要追肥。"
		elif action == "fertilizer" and int(inventory.get("compost", 0)) < 1: message = "缺少堆肥。"
		elif action == "slow" and int(inventory.get("slowFertilizer", 0)) < 1: message = "缺少草木缓释肥。"
		elif action == "green" and int(inventory.get("beanSeed", 0)) < 1: message = "缺少豆种。"
		elif spend_energy(2, 5):
			if action == "fertilizer": inventory.compost = int(inventory.get("compost", 0)) - 1; plot.fertility = mini(100, int(plot.fertility) + 25)
			elif action == "slow": inventory.slowFertilizer = int(inventory.get("slowFertilizer", 0)) - 1; plot.slow = 5; plot.fertility = mini(100, int(plot.fertility) + 8)
			else: inventory.beanSeed = int(inventory.get("beanSeed", 0)) - 1; plot.fertility = mini(100, int(plot.fertility) + 18)
			plot.fertilized = day
			plot.compacted = maxi(0, int(plot.get("compacted", 0)) - 10)
			message = "把堆肥拌进土里，肥力提高了。" if action == "fertilizer" else "缓释肥将在五天内慢慢养地。" if action == "slow" else "把豆科绿肥轻轻拌进土里。"
			changed.emit()
			return true
		changed.emit()
		return false
	message = "请选择有效的田间管理动作。"
	changed.emit()
	return false

func _finish_farm_crop(plot: Dictionary) -> void:
	var companion: Dictionary = plot.get("companion", {})
	plot.crop = ""
	plot.growth = 0.0
	plot.ripe_days = 0
	plot.ticks = 0
	plot.regrow_days = 0
	plot.harvest_count = 0
	if not companion.is_empty() and crop_catalog.has(str(companion.get("crop", ""))):
		plot.crop = str(companion.crop)
		plot.growth = float(companion.get("growth", 0.0))
		plot.seed_kind = str(companion.get("kind", "normal"))
		plot.density = "sparse"
		plot.condition = float(companion.get("condition",75))
		plot.ticks = int(companion.get("ticks",0))
		plot.ripe_days = int(companion.get("ripe_days",0))
		plot.companion = {}
		message += " 套种的%s接替了田垄。" % crop_name(str(plot.crop))

func _harvest_plot(index: int) -> void:
	var plot: Dictionary = plots[index]
	onboarding_mark("harvest")
	var crop_id := str(plot.crop)
	var profile := crop_profile(crop_id)
	var preview := preload("res://scripts/farm_insights.gd").harvest(self,plot)
	var score := float(preview.score)
	var grade := int(preview.grade)
	var amount := int(preview.qty)
	_add_inventory_count(crop_id, amount)
	player_stats.harvested = int(player_stats.get("harvested", 0)) + amount
	var ledger: Array = quality.get(crop_id, [0, 0, 0])
	if grade > 0:
		ledger[grade - 1] = int(ledger[grade - 1]) + amount
	quality[crop_id] = ledger
	if int(tool_data("sickle").get("level", 0)) >= 2 and str(tool_data("sickle").get("branch", "broad")) == "care" and not bool(farm.get("autoSeed", false)) and int(plot.get("harvest_count",0)) == 0:
		var seed_id := seed_variant_id(crop_id, str(plot.get("seed_kind", "normal")))
		if inventory.has(seed_id):
			_add_inventory_count(seed_id, 1)
	var first_harvest := int(plot.get("harvest_count",0)) == 0
	var category := str(crop_data(crop_id).get("group", ""))
	if first_harvest:
		plot.repeats = int(plot.repeats) + 1 if str(plot.get("last_group", "")) == category else 1
		plot.last_group = category
	plot.fertility = clampi(int(plot.fertility) + (14 if category == "豆类" and first_harvest else -5), 0, 100)
	if bool(farm.get("autoSeed", false)) and first_harvest:
		_add_inventory_count(seed_variant_id(crop_id, str(plot.get("seed_kind", "normal"))), 1)
	message = "收获了%s ×%d · %s品质（田间评分 %d）。" % [crop_name(crop_id), amount, ["普通", "优质", "上品", "珍品"][grade], roundi(score)]
	var regrow := int(plot.get("regrow_days",0))
	if regrow > 0:
		plot.harvest_count = mini(100000,int(plot.get("harvest_count",0))+1)
		plot.growth = maxf(0.0,float(crop_days(crop_id)-regrow))
		plot.ripe_days = 0
		plot.ticks = 0
		plot.condition = 75.0
		message += " 根株保留，约 %d 个生长日后再收；成熟时可留种腾地。" % regrow
	else:
		_finish_farm_crop(plot)
	_museum_record("item:" + crop_id, true, true, false, grade)

func _reset_animals() -> void:
	animals.clear()
	var initial_animals: Array = initial_state.get("animals", STARTER_ANIMALS)
	for animal in initial_animals:
		animals.append(animal.duplicate(true))
	ranch = initial_state.get("ranch", {}).duplicate(true)
	_normalize_animals()

func _normalize_animals() -> void:
	var source_animals: Array = initial_state.get("animals", STARTER_ANIMALS)
	for i in range(animals.size()):
		var animal: Dictionary = animals[i]
		var legacy_ready := clampi(int(animal.get("ready", 0)), 0, 99)
		var raw_quality_stock: Variant = animal.get("qualityStock", null)
		var has_quality_stock: bool = raw_quality_stock is Array and raw_quality_stock.size() >= 4
		var type_id := str(animal.get("type", animal.get("id", "hen")))
		var type_catalog: Dictionary = system_catalog.get("ranch", {}).get("species", {})
		if not type_catalog.has(type_id):
			for candidate in type_catalog:
				if str(type_catalog[candidate].get("name", "")) == str(animal.get("species", "")):
					type_id = str(candidate)
					break
		if not type_catalog.has(type_id): type_id = "hen"
		animal.type = type_id
		var defaults: Dictionary = {}
		for source in source_animals:
			if str(source.get("type", source.get("id", ""))) == type_id:
				defaults = source.duplicate(true)
				break
		if defaults.is_empty():
			var species: Dictionary = type_catalog.get(type_id, {})
			defaults = {"species": species.get("name", "鸡"), "product": species.get("product", "egg"), "sex": "female", "breed": "local", "trait": "friendly", "age": 0, "bond": 0, "hunger": 65, "health": 100, "mood": 80, "clean": 90, "stress": 0, "illness": 0, "warning": 0, "progress": 0.0, "qualityStock": [0, 0, 0, 0], "feedQuality": 0, "feathers": 0, "retired": false, "rest": false, "lost": false, "care": {"feed": -1, "pet": -1, "clean": -1, "treat": -1, "breed": -20}, "generation": 0, "parents": []}
		for key in defaults:
			if not animal.has(key):
				animal[key] = defaults[key]
		var stock: Array = raw_quality_stock.duplicate(true) if has_quality_stock else [legacy_ready, 0, 0, 0]
		while stock.size() < 4:
			stock.append(0)
		for grade in range(4):
			stock[grade] = clampi(int(stock[grade]), 0, 99)
		animal.qualityStock = stock
		animal.ready = int(stock[0]) + int(stock[1]) + int(stock[2]) + int(stock[3])
		animal.name = str(animal.get("name", str(animal.species) + str(i + 1))).strip_edges().left(12)
		if not animal.get("care", {}) is Dictionary: animal.care = {}
		for care_key in ["feed", "pet", "clean", "treat", "breed"]:
			if not animal.care.has(care_key): animal.care[care_key] = -20 if care_key == "breed" else -1
		if not animal.get("position", {}) is Dictionary: animal.position = {}
		var anchor := _ranch_animal_anchor(type_id)
		animal.position.x = float(animal.position.get("x", anchor.x + (i % 4) * 17.0))
		animal.position.y = float(animal.position.get("y", anchor.y + (i % 3) * 14.0))
		animal.position.room = animal.position.get("room", null)
		if not animal.position.get("inside", {}) is Dictionary: animal.position.inside = {"x": 420 + (i % 6) * 35, "y": 490}
		animals[i] = animal
	if ranch.is_empty():
		ranch = initial_state.get("ranch", {}).duplicate(true)
	_normalize_ranch()

func _normalize_ranch() -> void:
	var defaults: Dictionary = initial_state.get("ranch", {})
	for key in defaults:
		if not ranch.has(key): ranch[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
	var ranch_catalog: Dictionary = system_catalog.get("ranch", {})
	var catalog_barns: Dictionary = ranch_catalog.get("barns", {})
	if not ranch.get("barns", {}) is Dictionary: ranch.barns = {}
	for barn_id in catalog_barns:
		if not ranch.barns.has(barn_id):
			ranch.barns[barn_id] = {"built": false, "space": 0, "comfort": 0, "protection": 0, "efficiency": 0, "autoFeed": false, "autoClean": false, "autoCollect": false, "durability": 100, "clean": 90, "waste": 0, "lastClean": -1}
		var barn: Dictionary = ranch.barns[barn_id]
		if not barn.has("trough"): barn.trough = {}
		for field in ["space", "comfort", "protection", "efficiency"]:
			barn[field] = clampi(int(barn.get(field, 0)), 0, 3)
		for field in ["autoFeed", "autoClean", "autoCollect"]:
			barn[field] = bool(barn.get(field, false))
		for field in ["autoFeedBuilt", "autoCleanBuilt", "autoCollectBuilt"]:
			if barn.has(field): barn[field] = bool(barn[field])
		for field in ["durability", "clean"]: barn[field] = clampf(float(barn.get(field, 100)), 0.0, 100.0)
		barn.waste = clampi(int(barn.get("waste", 0)), 0, 99)
	if not ranch.get("stores", {}) is Dictionary: ranch.stores = {}
	for item_id in ["feed", "hay", "grainFeed", "healthFeed", "bedding"]: ranch.stores[item_id] = clampi(int(ranch.stores.get(item_id, 0)), 0, 9999)
	if not ranch.get("births", []) is Array: ranch.births = []
	if not ranch.get("rehomed", []) is Array: ranch.rehomed = []
	if not ranch.get("notices", []) is Array: ranch.notices = []
	if not ranch.get("collection", {}) is Dictionary: ranch.collection = {}
	if not ranch.get("pet", {}) is Dictionary: ranch.pet = {}
	var pet_defaults: Dictionary = defaults.get("pet", {})
	for key in pet_defaults:
		if not ranch.pet.has(key): ranch.pet[key] = pet_defaults[key].duplicate(true) if pet_defaults[key] is Dictionary or pet_defaults[key] is Array else pet_defaults[key]
	for key in ["hunger", "energy", "training"]: ranch.pet[key] = clampf(float(ranch.pet.get(key, 0)), 0.0, 100.0)
	if str(ranch.pet.get("mode", "home")) not in ["home", "follow", "patrol"]: ranch.pet.mode = "home"
	if ranch.has("jobs") and not ranch.jobs is Array: ranch.jobs = []
	if not ranch.has("policy") or str(ranch.policy) not in ["safe", "day", "inside"]: ranch.policy = "safe"
	if not ranch.has("grass") or not ranch.grass is Array or ranch.grass.size() != 2: ranch.grass = [100, 100]
	ranch.grass = [clampf(float(ranch.grass[0]), 0.0, 100.0), clampf(float(ranch.grass[1]), 0.0, 100.0)]
	ranch.nextId = maxi(1, int(ranch.get("nextId", 1)))
	preload("res://scripts/ranch_products.gd").initialize(self)

func _ranch_animal_anchor(type_id: String) -> Vector2:
	var species: Dictionary = system_catalog.get("ranch", {}).get("species", {}).get(type_id, {})
	var home := str(species.get("home", "poultry"))
	var barn: Dictionary = system_catalog.get("ranch", {}).get("barns", {}).get(home, {})
	var house_id := str(barn.get("house", ""))
	for prop in world_village.get("allProps", []):
		if str(prop.get("id", "")) == house_id:
			var door: Dictionary = prop.get("door", {})
			return Vector2(float(door.get("x", prop.get("x", 3000))), float(door.get("y", prop.get("y", 3000))) + 42.0)
	var zone: Array = system_catalog.get("ranch", {}).get("zones", [])
	var zone_index := 0 if home == "poultry" else 1
	if zone_index < zone.size(): return Vector2(float(zone[zone_index].get("x", 3000)), float(zone[zone_index].get("y", 3000)))
	return Vector2(3070, 3082)

func ranch_barn_capacity(barn_id: String) -> int:
	var definition: Dictionary = system_catalog.get("ranch", {}).get("barns", {}).get(barn_id, {})
	var barn: Dictionary = ranch.get("barns", {}).get(barn_id, {})
	if definition.is_empty() or not bool(barn.get("built", false)): return 0
	return int(definition.get("base", 0)) + int(barn.get("space", 0)) * 2

func ranch_animal_count(type_id: String = "") -> int:
	var species: Dictionary = system_catalog.get("ranch", {}).get("species", {})
	var home := str(species.get(type_id, {}).get("home", ""))
	var count := 0
	for animal in animals:
		if type_id != "" and str(animal.get("type", "")) != type_id: continue
		if type_id == "" or str(species.get(str(animal.get("type", "")), {}).get("home", "")) == home: count += 1
	return count

func _ranch_space_for(type_id: String) -> bool:
	var species: Dictionary = system_catalog.get("ranch", {}).get("species", {})
	var definition: Dictionary = species.get(type_id, {})
	if definition.is_empty(): return false
	var home := str(definition.get("home", ""))
	var occupants := 0
	for animal in animals:
		if str(species.get(str(animal.get("type", "")), {}).get("home", "")) == home: occupants += 1
	var reserved := 0
	for birth in ranch.get("births", []):
		if str(species.get(str(birth.get("type", "")), {}).get("home", "")) == home: reserved += 1
	return animals.size() + ranch.get("births", []).size() < 32 and occupants + reserved < ranch_barn_capacity(home)

func _ranch_charge(energy: int, needs: Dictionary = {}, cost: int = 0, time_cost: int = 5) -> bool:
	if not _building_has(needs):
		var parts: Array[String] = []
		for item_id in needs: parts.append(str(item_catalog.get(str(item_id), {}).get("name", item_id)) + " ×" + str(needs[item_id]))
		message = "材料不足：" + "、".join(parts)
		changed.emit()
		return false
	if money < cost:
		message = "需要 %d 元。" % cost
		changed.emit()
		return false
	if not spend_energy(energy, time_cost, "", false):
		message = "有些累，先休息或吃点东西。"
		changed.emit()
		return false
	_reconcile_kitchen_lots()
	_kitchen_consume(needs, 1)
	money -= cost
	return true

func _ranch_new_animal(type_id: String, sex: String, breed_id: String, age: int = 0, parents: Array = []) -> Dictionary:
	var catalog: Dictionary = system_catalog.get("ranch", {})
	var spec: Dictionary = catalog.get("species", {}).get(type_id, {})
	var breed: Dictionary = catalog.get("breeds", {}).get(breed_id, {})
	if spec.is_empty(): return {}
	ranch.nextId = int(ranch.get("nextId", 1)) + 1
	var id := "livestock-%d" % (int(ranch.nextId) - 1)
	var names := ["团团", "麦麦", "阿栗", "豆花", "小穗", "糯米"]
	var position: Dictionary = {}
	var home := str(catalog.barns[str(spec.home)].house)
	for house in world_village.get("houses", []):
		if str(house.get("id", "")) == home:
			var door: Dictionary = house.door
			var spawn_x := float(door.x) + 24.0 + float(ranch.nextId) * 8.0
			var spawn_y := float(door.y) + 25.0
			position = {"x": spawn_x, "y": spawn_y}
			var movement = load("res://scripts/ranch_movement.gd").new()
			if not movement.clear(self, "", Vector2(spawn_x, spawn_y)):
				var found := false
				for radius in range(12, 800, 12):
					for angle in range(24):
						var x := spawn_x + cos(float(angle) * PI / 12.0) * float(radius)
						var y := spawn_y + sin(float(angle) * PI / 12.0) * float(radius)
						if movement.clear(self, "", Vector2(x, y)):
							position = {"x": x, "y": y, "direction": "down"}
							found = true
							break
					if found: break
				if not found: position = {"x": 2831, "y": 1652, "direction": "down"}
			break
	position.direction = "down"
	position.room = home
	position.inside = {"x": 360 + int(ranch.nextId) % 6 * 55, "y": 490 + int(ranch.nextId) % 2 * 34}
	var traits: Dictionary = catalog.get("traits", {})
	var trait_ids: Array = traits.keys()
	var trait_id := str(trait_ids[posmod(int(ranch.nextId) + day, maxi(1, trait_ids.size()))]) if not trait_ids.is_empty() else "friendly"
	var generation := 0
	for parent_id in parents:
		for parent in animals:
			if str(parent.get("id", "")) == str(parent_id): generation = maxi(generation, int(parent.get("generation", 0)) + 1)
	var animal := {
		"id": id, "type": type_id, "species": str(spec.get("name", type_id)), "product": str(spec.get("product", "egg")),
		"name": "%s%d" % [names[int(ranch.nextId) % names.size()], int(ranch.nextId)], "personality": str(traits.get(trait_id, "")),
		"sex": sex, "breed": breed_id, "trait": trait_id, "age": age, "generation": generation, "parents": parents.duplicate(),
		"bond": 0, "hunger": 65, "health": 100, "mood": 80, "clean": 90, "stress": 0, "illness": 0, "warning": 0,
		"progress": 0.0, "qualityStock": [0, 0, 0, 0], "ready": 0, "feedQuality": 0, "fed": true, "feathers": 0,
		"retired": false, "rest": false, "lost": false,
		"care": {"feed": -1, "pet": -1, "clean": -1, "treat": -1, "breed": -20},
		"position": position
	}
	if breed.is_empty(): animal.breed = "local"
	animals.append(animal)
	return animal

func ranch_buy_animal(type_id: String, sex: String, breed_id: String, young: bool) -> bool:
	var catalog: Dictionary = system_catalog.get("ranch", {})
	var spec: Dictionary = catalog.get("species", {}).get(type_id, {})
	var breed: Dictionary = catalog.get("breeds", {}).get(breed_id, {})
	var home := str(spec.get("home", ""))
	if spec.is_empty() or breed.is_empty() or sex not in ["female", "male"]:
		message = "请选择有效种类与品种。"
	elif not bool(ranch.get("barns", {}).get(home, {}).get("built", false)):
		message = "畜舍尚未修好或没有空位；孕育中的幼崽也预留床位。"
	elif not _ranch_space_for(type_id):
		message = "畜舍尚未修好或没有空位；孕育中的幼崽也预留床位。"
	else:
		var price := roundi(float(spec.get("cost", 0)) * float(breed.get("cost", 1.0)) * (0.7 if young else 1.0))
		if _ranch_charge(2, {}, price, 5):
			var animal := _ranch_new_animal(type_id, sex, breed_id, 0 if young else int(spec.get("adult", 6)))
			message = "迎来%s“%s”，已安置在%s。" % [str(spec.get("name", type_id)), str(animal.get("name", "新伙伴")), str(catalog.get("barns", {}).get(home, {}).get("name", "畜舍"))]
			changed.emit()
			return true
	changed.emit()
	return false

func ranch_breed(mother_id: String, father_id: String) -> bool:
	var mother: Dictionary = {}
	var father: Dictionary = {}
	for animal in animals:
		if str(animal.id) == mother_id: mother = animal
		if str(animal.id) == father_id: father = animal
	var spec: Dictionary = system_catalog.ranch.species.get(str(mother.get("type", "")), {})
	if mother.is_empty() or father.is_empty() or mother_id == father_id or str(mother.type) != str(father.type) or str(mother.sex) != "female" or str(father.sex) != "male":
		message = "需要同种成年母畜与公畜配对。"
	elif mother_id in father.get("parents",[]) or father_id in mother.get("parents",[]) or mother.get("parents",[]).any(func(id):return id in father.get("parents",[])):
		message = "这两位伙伴有近亲关系，请安排不同家系。"
	elif [mother, father].any(func(animal: Dictionary) -> bool: return int(animal.age) < int(spec.adult) or bool(animal.retired) or float(animal.health) < 70 or float(animal.hunger) < 55 or float(animal.mood) < 50 or float(animal.illness) > 10 or bool(animal.lost)):
		message = "先让双方成年、吃饱、恢复健康与心情，再安排繁殖。"
	elif ranch.births.any(func(birth: Dictionary) -> bool: return birth.mother != null and str(birth.mother) == mother_id) or day - int(mother.care.breed) < 12:
		message = "刚生产的母畜需要休养，或已有孕育安排。"
	elif not _ranch_space_for(str(mother.type)):
		message = "先给未来幼崽预留一个床位。"
	elif float(ranch.barns[str(spec.home)].clean) < 50:
		message = "先清理畜舍，再迎接新生命。"
	elif _ranch_charge(3, {"grainFeed": 2}, 20):
		var birth_id := "birth-%d" % int(ranch.nextId)
		ranch.nextId = int(ranch.nextId) + 1
		var breed_id := str(mother.breed) if str(mother.breed) == str(father.breed) or int(ranch.nextId) % 2 == 1 else str(father.breed)
		var gestation := int(spec.gestation)
		ranch.births.append({"id": birth_id, "type": str(mother.type), "mother": mother_id, "father": father_id, "breed": breed_id, "remaining": gestation, "total": gestation})
		mother.care.breed = day
		message = "安排好了，约 %d 个舒适日后迎来幼崽；床位已经预留。" % gestation
		changed.emit()
		return true
	changed.emit()
	return false

func ranch_incubate(type_id: String) -> bool:
	var barn: Dictionary = ranch.get("barns", {}).get("poultry", {})
	var egg_id := "fertileHenEgg" if type_id == "hen" else "fertileDuckEgg"
	var spec: Dictionary = system_catalog.get("ranch", {}).get("species", {}).get(type_id, {})
	if type_id not in ["hen", "duck"]:
		message = "孵化区只接收受精鸡鸭蛋。"
	elif int(barn.get("comfort", 0)) < 1:
		message = "先给鸡鸭舍添置舒适巢箱。"
	elif not _ranch_space_for(type_id):
		message = "孵化也需要预留床位。"
	elif _ranch_charge(2, {egg_id: 1}, 0, 5):
		var gestation := int(spec.get("gestation", 4))
		ranch.births.append({"id": "birth-%d" % int(ranch.nextId), "type": type_id, "mother": null, "father": null, "breed": "local", "remaining": gestation, "total": gestation})
		ranch.nextId = int(ranch.nextId) + 1
		message = "把受精蛋放进温暖巢箱，普通食用蛋不会误拿去孵化。"
		changed.emit()
		return true
	changed.emit()
	return false

func ranch_barn_action(barn_id: String, action: String) -> bool:
	var catalog: Dictionary = system_catalog.get("ranch", {})
	var definition: Dictionary = catalog.get("barns", {}).get(barn_id, {})
	var barn: Dictionary = ranch.get("barns", {}).get(barn_id, {})
	if definition.is_empty() or barn.is_empty():
		message = "请选择畜舍。"
		changed.emit()
		return false
	if action == "build":
		if bool(barn.get("built", false)):
			message = "畜舍已经可以使用。"
		elif _ranch_charge(4, {"wood": int(definition.get("wood", 6)), "bamboo": 4}, int(definition.get("cost", 100))):
			barn.built = true
			message = "%s修好了，门内有了干净床位。" % str(definition.get("name", barn_id))
			changed.emit()
			return true
		changed.emit()
		return false
	if not bool(barn.get("built", false)):
		message = "先修好这座畜舍。"
		changed.emit()
		return false
	if action in ["space", "comfort", "protection", "efficiency"]:
		var level := int(barn.get(action, 0))
		if level >= 3:
			message = "这一项已升至三级。"
		elif _ranch_charge(3, {"wood": 4 + level * 2, "bamboo": 3}, 60 + level * 50):
			barn[action] = level + 1
			var names := {"space": "空间", "comfort": "舒适巢床", "protection": "通风排水与围护", "efficiency": "收集工位"}
			message = "%s的%s升级到 %d 级。" % [str(definition.get("name", barn_id)), names[action], level + 1]
			changed.emit()
			return true
		changed.emit()
		return false
	if action in ["autoFeed", "autoClean", "autoCollect"]:
		if bool(barn.get(action, false)):
			barn[action] = false
			message = "已暂停自动照料。"
			changed.emit()
			return true
		var built_key := action + "Built"
		if not bool(barn.get(built_key, false)):
			if not _ranch_charge(3, {"wood": 5, "bamboo": 4}, 100):
				changed.emit()
				return false
			barn[built_key] = true
		barn[action] = true
		message = "已启用%s，材料取自牧场料仓。" % str({"autoFeed": "食槽自动添料", "autoClean": "自动更换垫草", "autoCollect": "自动收集"}.get(action, action))
		changed.emit()
		return true
	if action == "clean":
		if int(barn.get("lastClean", -1)) == day or float(barn.get("clean", 90)) >= 95 and int(barn.get("waste", 0)) == 0:
			message = "畜舍干净，今天不用重复清扫。"
		elif _ranch_charge(3):
			var manure: int = preload("res://scripts/ranch_care.gd").clean_barn(self,barn_id,false,day)
			message = "清扫%s，收下圈肥原料 ×%d，可熟化后养田。" % [str(definition.get("name", barn_id)), manure]
			changed.emit()
			return true
		changed.emit()
		return false
	if action == "bedding":
		if float(barn.get("clean", 90)) >= 95:
			message = "垫草还很清爽。"
		elif _ranch_charge(2, {"bedding": 1}):
			barn.clean = clampf(float(barn.clean) + 35, 0.0, 100.0)
			for animal in animals:
				if _ranch_home_for(str(animal.get("type", ""))) == barn_id:
					animal.clean = clampf(float(animal.get("clean", 0)) + 10, 0.0, 100.0)
					animal.mood = clampf(float(animal.get("mood", 0)) + 6, 0.0, 100.0)
			message = "铺开干草垫料，屋里暖和干爽了。"
			changed.emit()
			return true
		changed.emit()
		return false
	if action == "repair":
		if float(barn.get("durability", 100)) >= 100:
			message = "屋舍完好。"
		elif _ranch_charge(3, {"wood": 2}, 10):
			barn.durability = 100
			message = "补好屋顶、扎紧篱门，防护恢复了。"
			changed.emit()
			return true
		changed.emit()
		return false
	message = "请选择升级或照料方式。"
	changed.emit()
	return false

func _ranch_home_for(type_id: String) -> String:
	return str(system_catalog.get("ranch", {}).get("species", {}).get(type_id, {}).get("home", ""))

func ranch_store(item_id: String, amount: Variant, withdraw: bool) -> bool:
	if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)) or float(amount) < 1 or float(amount) > 100 or not ranch.stores.has(item_id):
		message = "请选择有效物品与数量。"
		changed.emit()
		return false
	var count := int(amount)
	if withdraw and int(ranch.stores[item_id]) < count:
		message = "料仓数量不足。"
	elif not withdraw and not _building_has({item_id: count}):
		message = "背包数量不足。"
	elif not withdraw and int(ranch.stores[item_id]) + count > 9999:
		message = "料仓这一格已满。"
	else:
		if withdraw:
			ranch.stores[item_id] = int(ranch.stores[item_id]) - count
			_grant_legacy_item(item_id, count)
		else:
			_reconcile_kitchen_lots()
			_kitchen_consume({item_id: count}, 1)
			ranch.stores[item_id] = int(ranch.stores[item_id]) + count
		message = "%s%s ×%d。" % ["取回" if withdraw else "存入", str(item_catalog[item_id].name), count]
		changed.emit()
		return true
	changed.emit()
	return false

func ranch_craft(recipe_id: String, quantity: Variant) -> bool:
	if recipe_id in ["cream", "yogurt"]: return process_recipe(recipe_id, quantity)
	var recipe: Dictionary = system_catalog.get("ranch", {}).get("recipes", {}).get(recipe_id, {})
	if recipe.is_empty() or not (quantity is int or quantity is float) or not is_finite(float(quantity)) or float(quantity) != floor(float(quantity)) or float(quantity) < 1 or float(quantity) > 20:
		message = "选择 1—20 批。"
		changed.emit()
		return false
	var count := int(quantity)
	var needs: Dictionary = {}
	var premium := true
	for item_id in recipe.needs:
		needs[item_id] = int(recipe.needs[item_id]) * count
		var grades := _quality_counts(str(item_id))
		if int(inventory.get(item_id, 0)) != grades[1] + grades[2] + grades[3] or int(inventory.get(item_id, 0)) < int(needs[item_id]): premium = false
	if not _ranch_charge(2, needs): return false
	var output := str(recipe.out)
	var qty := int(recipe.qty) * count
	if int(recipe.get("days", 0)) > 0:
		var job: Dictionary = {"id": output, "qty": qty, "readyDay": day + int(recipe.days), "station": str(recipe.station), "cooking": output == "yogurt"}
		if premium: job.farmGrade = 1
		legacy_processing.append(job)
	else:
		_grant_legacy_item(output, qty)
		if premium:
			var ledger: Array = quality.get(output, [0, 0, 0])
			ledger[0] = int(ledger[0]) + qty
			quality[output] = ledger
	message = str(recipe.name) + " ×" + str(count) + ("，明早完成。" if int(recipe.get("days", 0)) > 0 else "，已经收好。")
	changed.emit()
	return true

func ranch_rehome(animal_id: String, confirm: bool = false) -> bool:
	var animal_index := ranch_animal_index(animal_id)
	if animal_index < 0:
		message = "没有这位伙伴。"
	elif not confirm:
		message = "请在游戏中确认送养。"
	else:
		var animal: Dictionary = animals[animal_index]
		var reserved := false
		for birth in ranch.births:
			if str(birth.get("mother", "")) == animal_id or str(birth.get("father", "")) == animal_id: reserved = true
		if reserved:
			message = "它正参与孕育，请等幼崽出生后再安排。"
		elif int(animal.get("ready", 0)) > 0 or int(animal.get("feathers", 0)) > 0:
			message = "先收好它的产物再办理送养。"
		elif ranch.rehomed.size() >= 32:
			message = "送养记录已满，请先接回伙伴。"
		else:
			var spec: Dictionary = system_catalog.get("ranch", {}).get("species", {}).get(str(animal.get("type", "hen")), {})
			var fee := roundi(float(spec.get("cost", 0)) * 0.4)
			ranch.rehomed.append({"animal": animal.duplicate(true), "fee": fee, "day": day})
			animals.remove_at(animal_index)
			money += fee
			message = "%s搬去邻村牧场，收到 %d 元照料补贴；有空位时可按同价接回。" % [str(animal.get("name", "伙伴")), fee]
			changed.emit()
			return true
	changed.emit()
	return false

func ranch_adopt(animal_id: String) -> bool:
	for i in range(ranch.rehomed.size()):
		var record: Dictionary = ranch.rehomed[i]
		var animal: Dictionary = record.get("animal", {})
		if str(animal.get("id", "")) != animal_id: continue
		if not _ranch_space_for(str(animal.get("type", "hen"))):
			message = "没有记录或畜舍没有空位。"
		elif not _ranch_charge(2, {}, int(record.get("fee", 0))):
			changed.emit()
			return false
		else:
			animal = animal.duplicate(true)
			animal.lost = false
			var home := _ranch_home_for(str(animal.get("type", "hen")))
			animal.position.room = str(system_catalog.ranch.barns[home].house)
			animal.position.inside = {"x": 480, "y": 500}
			animals.append(animal)
			ranch.rehomed.remove_at(i)
			message = "把%s接回来了，名字、亲近与品种都还在。" % str(animal.get("name", "伙伴"))
			changed.emit()
			return true
		changed.emit()
		return false
	message = "没有记录或畜舍没有空位。"
	changed.emit()
	return false

func ranch_pet_action(action: String) -> bool:
	var pet: Dictionary = ranch.get("pet", {})
	var type_id := str(pet_state.get("type", "cat"))
	if action == "feed":
		if int(pet.get("fed", -1)) == day or float(pet.get("hunger", 0)) >= 95:
			message = "它今天已经吃饱。"
		elif _ranch_charge(1, {"feed": 1}, 0, 5):
			pet.hunger = clampf(float(pet.hunger) + 50, 0.0, 100.0)
			pet.energy = clampf(float(pet.energy) + 15, 0.0, 100.0)
			pet.fed = day
			pet_visual_action = {"kind":"feed", "at":ranch_actor_clock, "until":ranch_actor_clock + 2.8}
			pet_state.bond = mini(100, int(pet_state.get("bond", 0)) + 3)
			message = "给%s添好一小碗饭。" % str(pet_state.get("name", "小团"))
			changed.emit()
			return true
		changed.emit()
		return false
	if action == "train":
		if int(pet.get("trained", -1)) == day: message = "今天练过啦，明天再来。"
		elif float(pet.get("energy", 0)) < 15: message = "它有些累，先休息。"
		elif _ranch_charge(2, {}, 0, 5):
			pet.training = clampf(float(pet.get("training", 0)) + 10, 0.0, 100.0)
			pet.energy = float(pet.get("energy", 0)) - 15
			pet.trained = day
			pet_visual_action = {"kind":"train", "at":ranch_actor_clock, "until":ranch_actor_clock + 2.8}
			pet_state.bond = mini(100, int(pet_state.get("bond", 0)) + 4)
			message = "练习听铃与召回；训练达到 20 后能协助看护。" if type_id == "dog" else "练习回家与巡粮仓；训练达到 20 后减少粮耗。"
			changed.emit()
			return true
		changed.emit()
		return false
	if action in ["home", "follow", "patrol"]:
		pet.mode = action
		message = str({"home": "让它回小院休息。", "follow": "它会沿路跟在身后，进屋时在门外等你。", "patrol": "它会在牧场巡看，照料和训练越好，帮忙越稳妥。"}.get(action, ""))
		changed.emit()
		return true
	if action == "switch_pet":
		pet_visual_action.clear()
		pet_state.type = "dog" if type_id == "cat" else "cat"
		pet_state.name = "阿福" if str(pet_state.type) == "dog" else "小团"
		pet.mode = "home"
		message = "牧场伙伴现在是%s「%s」。" % ["小狗" if str(pet_state.type) == "dog" else "小猫", str(pet_state.name)]
		changed.emit()
		return true
	var already_patted := int(pet_state.get("patted", -1)) == day
	pat_companion()
	return not already_patted

func cycle_animal_action() -> void:
	var index := ANIMAL_ACTIONS.find(selected_animal_action)
	selected_animal_action = ANIMAL_ACTIONS[(index + 1) % ANIMAL_ACTIONS.size()]
	message = "畜牧动作：" + str(ANIMAL_ACTION_NAMES[selected_animal_action]) + "。靠近动物按 E 执行。"
	changed.emit()

func ranch_default_action(index: int) -> String:
	if index < 0 or index >= animals.size(): return ""
	var a: Dictionary = animals[index]
	if bool(a.lost): return "rescue"
	if float(a.illness)>=20 or float(a.health)<50: return "treat"
	if int(a.ready)>0 or int(a.feathers)>0: return "collect"
	return "feed" if preload("res://scripts/ranch_care.gd").needed(self,a,day)>0 and float(a.hunger)<70 else "pet"

func ranch_tend(index: int, action: String, food: String = "") -> bool:
	if index < 0 or index >= animals.size():
		message = "这位伙伴不在牧场里。"
		changed.emit()
		return false
	var previous_action := selected_animal_action
	selected_animal_action = action
	var ok := tend_animal(index, food)
	selected_animal_action = previous_action
	return ok

func ranch_rename_animal(animal_id: String, new_name: Variant) -> bool:
	var index := ranch_animal_index(animal_id)
	if index < 0:
		message = "这位伙伴不在牧场里。"
	elif not new_name is String or new_name.strip_edges().is_empty():
		message = "请写一个名字。"
	else:
		animals[index].name = str(new_name).strip_edges().left(12)
		message = "记住了它的名字。"
		changed.emit()
		return true
	changed.emit()
	return false

func ranch_retire_animal(animal_id: String) -> bool:
	var index := ranch_animal_index(animal_id)
	if index < 0:
		message = "这位伙伴不在牧场里。"
	else:
		var animal: Dictionary = animals[index]
		var spec: Dictionary = system_catalog.ranch.species[str(animal.type)]
		if int(animal.age) < int(spec.adult):
			message = "幼崽还在长大。"
		else:
			animal.retired = not bool(animal.retired)
			message = "留在牧场安心颐养，不再安排产出。" if bool(animal.retired) else "恢复生产安排，仍按健康状况慢慢来。"
			changed.emit()
			return true
	changed.emit()
	return false

func ranch_set_schedule(policy: String, zone: int, food: String) -> bool:
	if policy not in ["safe", "day", "inside"] or zone not in [0, 1] or not system_catalog.ranch.feedKinds.has(food):
		message = "请选择有效的牧场照料安排。"
		changed.emit()
		return false
	ranch.policy = policy
	ranch.zone = zone
	ranch.feed = food
	legacy_systems.freeRange = policy != "inside"
	message = "已记住，伙伴会按作息沿路活动。"
	changed.emit()
	return true

func ranch_set_policy(policy: String) -> void:
	if policy in ["safe", "day", "inside"]:
		ranch.policy = policy
		legacy_systems.freeRange = policy != "inside"
		message = "放牧策略：%s。" % str({"safe": "避雨稳妥", "day": "白日散养", "inside": "全天留舍"}.get(policy, policy))
		changed.emit()

func ranch_set_zone(zone: int) -> void:
	ranch.zone = clampi(zone, 0, 1)
	var zones: Array = system_catalog.get("ranch", {}).get("zones", [])
	message = "轮牧草圈：%s。" % str(zones[int(ranch.zone)].get("name", "草圈"))
	changed.emit()

func ranch_set_feed(food: String) -> void:
	if system_catalog.get("ranch", {}).get("feedKinds", {}).has(food):
		ranch.feed = food
		message = "自动添料偏好：%s。" % str(system_catalog.get("ranch", {}).get("feedKinds", {})[food].get("name", food))
		changed.emit()

func cycle_animal_feed() -> void:
	var choices := ["feed", "hay", "grainFeed", "healthFeed"]
	var current := choices.find(str(ranch.get("feed", "feed")))
	ranch.feed = choices[(current + 1) % choices.size()]
	message = "畜牧饲料：%s（背包 %d）。" % [item_catalog.get(str(ranch.feed), {}).get("name", str(ranch.feed)), int(inventory.get(str(ranch.feed), 0))]
	changed.emit()

func rename_companion(companion_name: String, type_id: String) -> bool:
	if type_id not in ["cat","dog"]:
		message = "请选择猫或狗。"
		changed.emit()
		return false
	var cleaned := companion_name.strip_edges().left(12)
	pet_state.name = "小团" if cleaned=="" else cleaned
	pet_state.type = type_id
	message = "记住了这个名字。"
	changed.emit()
	return true

func pat_companion() -> bool:
	if int(pet_state.get("patted", -1)) == day:
		message = "%s正在打盹，今天已经陪它玩过了。" % str(pet_state.get("name", "小团"))
		changed.emit()
		return false
	pet_state.patted = day
	pet_visual_action = {"kind":"pet", "at":ranch_actor_clock, "until":ranch_actor_clock + 2.2}
	pet_state.bond = mini(100, int(pet_state.get("bond", 0)) + 3)
	ranch.pet.energy = clampf(float(ranch.get("pet", {}).get("energy", 100)) + 5, 0.0, 100.0)
	message = "%s靠过来蹭了蹭你。窗外的声音慢了下来。" % str(pet_state.get("name", "小团"))
	_museum_sync()
	changed.emit()
	return true

func festival_status(target_season: int = -1) -> Dictionary:
	var target := season_index() if target_season < 0 else target_season
	if target < 0 or target > 3: return {"valid": false, "message": "请选择春、夏、秋或冬。"}
	var year := int(day / 112) + 1
	var key := "%d-%d" % [year, target]
	var details: Array = content.get("festivalDetails", [])
	var definition: Dictionary = details[target] if target < details.size() else {}
	var open_day := (year - 1) * 112 + target * 28 + 13
	return {"valid": true, "season": target, "year": year, "key": key, "name": str(content.get("festivals", [])[target]), "open": day >= open_day, "done": festivals.has(key), "prepare": str(definition.get("prepare", "")), "activity": str(definition.get("activity", "")), "choices": definition.get("choices", []), "recipe": str(definition.get("recipe", "")), "after": str(definition.get("after", ""))}

func attend_festival(dish_id: String, choice: int, target_season: int = -1) -> bool:
	var target:=season_index() if target_season==-1 else target_season
	var status:=festival_status(target)
	if target<0 or target>3:
		message="请选择季节。"
	elif bool(status.get("done",false)):
		message="这一季的故事已经记下了，来年还能参加。"
	elif not bool(status.get("open",false)):
		message="该季第 14 天起可以开席。"
	elif str(item_catalog.get(dish_id,{}).get("kind",""))!="料理" or int(inventory.get(dish_id,0))<1:
		message="带一道料理来吧。"
	elif choice not in [0,1]:
		message="选一种参与方式。"
	else:
		_consume_item(dish_id,1)
		_reconcile_kitchen_lots()
		festivals.append(str(status.key))
		season_events["festival-"+str(status.key)]=choice
		for relation in relations.values():relation.points=mini(100,int(relation.points)+10)
		_add_inventory_count("rice", 3)
		_reconcile_kitchen_lots()
		for recipe in content.get("recipes",[]):
			var id:=str(recipe.id)
			if str(recipe.get("source",""))=="festival"+str(target) and not known_recipes.has(id):
				known_recipes.append(id)
				_record_legacy_event("学会了 "+str(item_catalog[id].name)+"。")
		_award_skill_xp("social",8)
		_record_legacy_event("参加"+str(status.name)+"："+str(status.choices[choice])+"。"+str(status.after))
		message=str(status.after)+"〔节令配方已记入菜谱，收到稻米 ×3〕"
		_museum_sync()
		changed.emit()
		return true
	changed.emit()
	return false

func _grant_quality(item_id: String, amount: int, grade: int) -> void:
	_add_inventory_count(item_id, amount)
	if grade > 0:
		var ledger: Array = quality.get(item_id, [0, 0, 0])
		ledger[grade - 1] = int(ledger[grade - 1]) + amount
		quality[item_id] = ledger
	_museum_sync()

func _animal_quality(animal: Dictionary, barn: Dictionary) -> int:
	return preload("res://scripts/ranch_rules.gd").quality(animal,barn,system_catalog.get("ranch",{}).get("breeds",{}))

func tend_animal(index: int, food_choice: String = "") -> bool:
	if index < 0 or index >= animals.size():
		message = "这位伙伴不在牧场里。"
		changed.emit()
		return false
	var animal: Dictionary = animals[index]
	var species: Dictionary = system_catalog.ranch.species[str(animal.type)]
	var action := selected_animal_action
	if action == "auto": action = ranch_default_action(index)
	var care: Dictionary = animal.care
	var applies := action in ["collect", "clean"]
	var care_tool := tool_data("care")
	var care_level := int(care_tool.get("level", 0))
	var broad := applies and care_level == 2 and str(care_tool.get("branch", "broad")) == "broad"
	var energy_reduction := (1 if applies and care_level > 0 else 0) + (1 if broad else 0)
	var handling_time := 3 if broad else 5
	var ok := false
	match action:
		"collect":
			if int(animal.ready) == 0 and int(animal.feathers) == 0:
				message = "还没有可以收下的产物。"
			elif spend_energy((1 if int(ranch.barns[str(species.home)].efficiency)>0 else 2)-energy_reduction,handling_time,"",false):
				var count: int = preload("res://scripts/ranch_products.gd").collect_near(self,animal)
				message = "%s：%s的产物 ×%d。" % [str(species.get("harvestVerb","收取")),str(animal.name),count]
				ok = count > 0
		"feed":
			var food := food_choice if food_choice != "" else str(ranch.feed)
			var care_rules = preload("res://scripts/ranch_care.gd")
			var needed: int = care_rules.needed(self,animal,day)
			if needed == 0:
				message = "今天已经吃饱，不用重复喂食。"
			elif not care_rules.accepts(self,animal,food):
				message = "这种饲料不适合它，请换基础饲料或谷物精料。"
			elif _ranch_charge(2,{food:needed}):
				var barn: Dictionary = ranch.barns[str(species.home)]
				barn.trough[food] = int(barn.trough.get(food,0))+needed
				care_rules.from_trough(self,animal,barn,day)
				animal.bond = minf(100,float(animal.bond)+2)
				message = "添入%s，%s在料槽边吃饱了。" % [str(item_catalog[food].name),str(animal.name)]
				ok = true
		"pet":
			if int(care.pet) == day:
				message = "今天已经陪过它，可以放心做别的事。"
			elif _ranch_charge(1):
				animal.bond = clampf(float(animal.bond) + (7 if str(animal.trait) == "friendly" else 4), 0.0, 100.0)
				animal.mood = clampf(float(animal.mood) + 12, 0.0, 100.0)
				animal.stress = clampf(float(animal.stress) - 15, 0.0, 100.0)
				care.pet = day
				message = str(animal.name) + "靠过来，舒服地眯起眼。"
				ok = true
		"clean":
			if float(animal.clean) >= 95 or int(care.clean) == day:
				message = "皮毛已经很干净。"
			elif _ranch_charge(2 - energy_reduction, {}, 0, handling_time):
				animal.clean = 100
				animal.mood = clampf(float(animal.mood) + 6, 0.0, 100.0)
				care.clean = day
				message = "轻轻梳洗" + str(animal.name) + "，皮毛清爽了。"
				ok = true
		"treat", "vet":
			if float(animal.health) >= 95 and float(animal.illness) < 1:
				message = "它很健康，暂时不必治疗。"
			elif int(care.treat) == day:
				message = "今天已护理过，先让它歇一歇。"
			elif _ranch_charge(2, {"animalMedicine": 1} if action == "treat" else {}, 35 if action == "vet" else 0):
				animal.health = clampf(float(animal.health) + (45 if action == "vet" else 30), 0.0, 100.0)
				animal.illness = clampf(float(animal.illness) - (70 if action == "vet" else 45), 0.0, 100.0)
				animal.stress = clampf(float(animal.stress) - 15, 0.0, 100.0)
				care.treat = day
				animal.rest = true
				message = "处理好不适，安排" + str(animal.name) + "回舍休养；状态改善后可恢复放牧。"
				ok = true
		"rest":
			animal.rest = not bool(animal.rest)
			message = "安排留舍休养。" if bool(animal.rest) else "允许按牧场策略活动。"
			ok = true
		"rescue":
			if not bool(animal.lost):
				message = "它正在牧场附近。"
			elif _ranch_charge(2):
				animal.lost = false
				animal.rest = true
				animal.mood = clampf(float(animal.mood) + 15, 0.0, 100.0)
				animal.stress = clampf(float(animal.stress) - 20, 0.0, 100.0)
				message = "认出你的脚步，" + str(animal.name) + "愿意跟你回舍休息。"
				ok = true
		_:
			message = "请选择照料动作。"
	if ok and applies:
		_award_tool("care")
		if care_level == 2 and str(care_tool.get("branch", "broad")) == "care":
			animal.mood = clampf(float(animal.mood) + 4, 0.0, 100.0)
			animal.bond = clampf(float(animal.bond) + 1, 0.0, 100.0)
			message += " 温柔照料，让它更安心。"
	_museum_sync()
	changed.emit()
	return ok

func talk_to_npc(npc_id: String, topic: String = "auto") -> bool:
	var person:Dictionary={}
	for candidate in npc_catalog:
		if str(candidate.id)==npc_id:person=candidate;break
	if person.is_empty() or topic not in ["auto","daily","advice","memory"]:
		message="请选择想聊的话题。"
		changed.emit()
		return false
	onboarding_mark("neighbor")
	ensure_neighbor_events()
	var candidate:=_npc_dialogue_for_topic(person,int(relations[npc_id].points),topic)
	var relation:Dictionary=relations[npc_id]
	var first:=int(relation.get("talked",-1))!=day
	if first:
		relation.points=mini(100,int(relation.points)+5)
		relation.talked=day
	message=str(candidate.text)
	if int(relation.points)>=25 and not bool(relation.get("returnGift",false)):
		relation.returnGift=true
		_add_inventory_count("rice", 2)
		_reconcile_kitchen_lots()
		player_journal.append({"day":day,"text":str(person.name)+"送来了新米。"})
		while player_journal.size()>200:player_journal.pop_front()
		message+="〔收到对方回赠的稻米 ×2〕"
	if first:
		_award_skill_xp("social",2)
		if str(skills.get("social",{}).get("choice",""))=="listener":relation.points=mini(100,int(relation.points)+2)
		if int(relation.points)>=10:
			var learned:=0
			for recipe in content.get("recipes",[]):
				var id:=str(recipe.id)
				if str(recipe.get("source",""))==npc_id and not known_recipes.has(id):
					known_recipes.append(id)
					_record_legacy_event("学会了 "+str(item_catalog.get(id,{}).get("name",id))+"。")
					learned+=1
			if learned>0:message+="〔学会 "+str(learned)+" 道家常菜，已记入菜谱〕"
	neighbors.people[npc_id].introduced=true
	_remember_npc_dialogue(npc_id,str(candidate.key),message,str(candidate.category),str(candidate.emotion))
	_museum_sync()
	changed.emit()
	return true

func npc_dialogue_activity(person: Dictionary) -> Dictionary:
	return NPC_SCHEDULE_RULES.from_state(self, person)

func _dialogue_row(key: String,text: String,category: String="日常",emotion: String="calm") -> Dictionary:
	return {"key":key,"text":text,"category":category,"emotion":emotion}

func npc_dialogue_candidates(person: Dictionary,topic: String="auto") -> Array[Dictionary]:
	var id:=str(person.id)
	var profile:Dictionary=system_catalog.npc.profiles[id]
	var resident:Dictionary=neighbors.people[id]
	var relation:Dictionary=relations[id]
	var plan:=npc_dialogue_activity(person)
	var list:Array[Dictionary]=[]
	var event:Dictionary=resident.get("event",{})
	var story:Dictionary=npc_stories.get(id,{})
	var arc:Array=content.get("arcs",{}).get(id,[])
	var step:=int(story.get("step",0))
	if topic=="advice":return [_dialogue_row("advice",str(profile.advice),"线索","focus")]
	if topic=="memory":
		if str(event.get("status",""))=="done":
			list.append(_dialogue_row("help-memory-"+str(int(event.day)),"上回"+str(profile.request)+"，你"+("把材料送来了" if str(event.method)=="supply" else "留下来一起做完了")+"。那一点照应，我记着呢。","回忆","happy"))
		if step>0 and step<=arc.size():
			var choices:Array=story.get("choices",[])
			if choices.size()>=step:list.append(_dialogue_row("story-memory-"+str(step),str(arc[step-1].choices[int(choices[-1])].reply),"回忆","happy"))
		var gifted:=int(relation.get("gifted",-1))
		if gifted>=0 and gifted<=day and day-gifted<=7:list.append(_dialogue_row("gift-memory-"+str(gifted),"前些天你带来的那份心意，我收好了。空手来聊聊天，也一样欢迎。","回忆","happy"))
		if list.is_empty():list.append(_dialogue_row("new-memory","咱们还可以慢慢熟悉。今天遇见，说几句话，就是一件新记忆。","回忆"))
		return list
	if topic=="auto":
		if bool(npc_story_readiness(id).get("ok",false)):list.append(_dialogue_row("story-"+str(step),"我有件近况想和你商量：“"+str(arc[step].title)+"”。你愿意听时，我们再慢慢聊。","故事","thought"))
		if int(person.birthday)==posmod(day,112)+1:list.append(_dialogue_row("birthday-"+str(day),"今天是我的生日。你路过停下来，我就觉得是个好日子，不用特意备贵重东西。","节庆","happy"))
		var date:=posmod(day,28)+1
		var season:=season_index()
		if date>=13 and date<=15:
			var festival:=str(content.festivals[season])
			var text:="明天是"+festival+"，我想把"+str(profile.work)+"先安排好，留点时间给饭桌。" if date==13 else "今天的"+festival+"，来了就坐一会儿。自己的活没忙完，改天补聚也一样。" if date==14 else "昨天饭桌上的热闹还记得。今天把日常的事慢慢接上。" if festivals.has(str(int(day/112)+1)+"-"+str(season)) else "昨天没聚上也别着急，节令饭桌还等着你。"
			list.append(_dialogue_row("festival-%d-%d"%[date,season],text,"节庆","happy"))
		if not event.is_empty() and str(event.status)!="done":
			var text:="你答应帮我"+str(profile.request)+"。不赶日子，备好材料或者有空一起做都行。" if str(event.status)=="accepted" else "上次那件"+str(profile.request)+"的小事还在，改天再说也行，不用觉得欠着什么。" if str(event.status)=="postponed" else "最近想"+str(profile.request)+"。带两份"+str(item_catalog[str(profile.item)].name)+"，或者留一会儿一起做，都能帮上忙。"
			list.append(_dialogue_row("event-%d-%s"%[int(event.day),str(event.status)],text,"邻里小事","thought"))
		var fish_value:Variant=fishing.get("last",{})
		var fish:Dictionary=fish_value if fish_value is Dictionary else {}
		if fish.get("fish",null)!=null and day-int(fish.get("day",-99))<=2 and id in ["yu","ning","mei"]:
			list.append(_dialogue_row("fish-"+str(int(fish.day)),"你记下的"+str(item_catalog[str(fish.fish)].name)+"有 "+(str(int(fish.length)) if float(fish.length)==float(int(fish.length)) else str(fish.length))+" 厘米。"+("放回水里也留下了一次观察。" if bool(fish.get("released",false)) else "鲜鱼及时做菜，吃不完也能晾成鱼干。"),"生活","happy"))
		var finds:Array=forage.get("finds",[])
		if not finds.is_empty() and id in ["zhou","luo","granny"]:
			var found:Dictionary=finds[-1]
			if day-int(found.day)<=2:list.append(_dialogue_row("forage-"+str(int(found.day)),"最近采回的"+str(item_catalog[str(found.item)].name)+"正是山野的馈赠。留下根和老叶，下次走过还能看见新芽。","生活","happy"))
		if bool(legacy_systems.get("projects",{}).get("bridge",false)) or bool(flags.get("bridge",false)):list.append(_dialogue_row("bridge","新河埠能好好坐下歇脚了。做成一件大家用得上的事，路也走得亲近。","村庄","happy"))
		if int(building.get("house",0))>0 and id in ["chen","he"]:list.append(_dialogue_row("house-"+str(int(building.house)),"你家的老屋修得更妥帖了。添进去的每件东西，都能讲讲为什么放在那里。","村庄","happy"))
		if str(marriage.get("spouse",""))==id:list.append(_dialogue_row("partner",str(profile.trust)+" 等各自忙完，再把今天讲给彼此听。","关系","happy"))
		elif int(relation.points)>=60:list.append(_dialogue_row("trust",str(profile.trust),"关系","happy"))
		elif int(relation.points)>=25:list.append(_dialogue_row("familiar","现在见到你，我就想起"+str(profile.goal)+"。不必给我答案，听我说说也好。","关系"))
		var weather:=weather_for(day)
		if weather!="晴":list.append(_dialogue_row("weather-"+weather,"今天"+weather+"，"+("我在屋里"+str(profile.work)+"。你先站稳，擦擦手再坐。" if bool(plan.indoors) else "沿路慢一点，手边的事不用急着赶完。"),"天气","thought"))
		list.append(_dialogue_row("season-"+str(season),str(["春天东西长得快，做事倒可以慢一点，给嫩芽留点空。","夏日午后先找片阴凉，等暑气过去再做细活。","秋天收好的东西多，记得把能分给邻居的也留一份。","冬天屋里有热水，路过进来暖暖手再走。"][season]),"时令"))
	if not bool(resident.get("introduced",false)):list.append(_dialogue_row("intro",str(person.greeting),"初识","happy"))
	list.append(_dialogue_row("work-"+str(plan.key),"我这会儿在"+str(plan.label)+"。"+str(profile.daily[0]),"日常","focus"))
	for i in range(profile.daily.size()):list.append(_dialogue_row("daily-"+str(i),str(profile.daily[i])))
	return list

func _npc_dialogue_for_topic(person: Dictionary,_points: int,topic: String) -> Dictionary:
	var list:=npc_dialogue_candidates(person,topic)
	var recent:Array=neighbors.people[str(person.id)].get("recent",[])
	for row in list:
		if not recent.has(row.key):return row
	var selected:Dictionary=list[0]
	for row in list:
		if recent.find(row.key)<recent.find(selected.key):selected=row
	return selected

func _npc_dialogue(person: Dictionary,points: int) -> Dictionary:
	return _npc_dialogue_for_topic(person,points,"auto")

func _normalize_npc_social(saved_stories: Variant = {}, saved_partners: Variant = {}, saved_marriage: Variant = {}) -> void:
	var normalized := preload("res://scripts/npc_social_profile.gd").normalize(saved_stories,saved_partners,saved_marriage,day,npc_catalog,content)
	npc_stories = normalized.stories
	partners = normalized.partners
	marriage = normalized.marriage

func _npc_story_scene(person: Dictionary) -> String:
	return npc_scene_region(str(person.get("id", "")))

func npc_story_readiness(npc_id: String) -> Dictionary:
	var arc: Array = content.get("arcs", {}).get(npc_id, [])
	var state: Dictionary = npc_stories.get(npc_id, {})
	if arc.is_empty() or state.is_empty(): return {"ok":false,"message":"暂无故事。"}
	var step := int(state.get("step",0))
	if step >= arc.size(): return {"ok":false,"message":"这段故事已经留下了完整记录。"}
	var event: Dictionary = arc[step]
	if str(event.get("kind","")) == "married" and str(marriage.get("spouse","")) != npc_id: return {"ok":false,"message":"这一章是共同生活故事，结婚后再来聊。"}
	if int(state.get("lastDay",-1)) == day: return {"ok":false,"message":"今天聊到这里，明天再来继续。"}
	var needed_points := int(event.get("points",0))
	if int(relations.get(npc_id,{}).get("points",0)) < needed_points: return {"ok":false,"message":"关系达到 %d 后继续；聊聊天、一起做饭或完成委托都可以。"%needed_points}
	var needs: Dictionary = event.get("needs",{}) if event.get("needs",{}) is Dictionary else {}
	if not _building_has(needs):
		var descriptions: Array[String] = []
		for item_id in needs: descriptions.append("%s ×%d"%[str(item_catalog.get(str(item_id),{}).get("name",item_id)),int(needs[item_id])])
		return {"ok":false,"message":"这次合作需要 %s，随时备好再来。"%("、".join(descriptions))}
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.id) == npc_id: person = candidate;break
	var scene_id := _npc_story_scene(person)
	return {"ok":true,"message":"此刻在%s，可以继续聊“%s”。"%[str(content.get("scenes",{}).get(scene_id,{}).get("name","")),str(event.get("title","近况"))],"event":event,"step":step}

func choose_npc_story(npc_id: String, choice: int) -> bool:
	if not npc_is_near(npc_id):
		message = "面对面聊完这一段故事吧，先沿路找到对方。"
		changed.emit()
		return false
	var readiness := npc_story_readiness(npc_id)
	if not bool(readiness.get("ok", false)):
		message = str(readiness.get("message", "暂时无法继续这段故事。"))
		changed.emit()
		return false
	if choice not in [0, 1]:
		message = "请选择一个回应。"
		changed.emit()
		return false
	var state: Dictionary = npc_stories[npc_id]
	var quest_definition: Dictionary=QUESTS.definition(self,"story:"+npc_id+":"+str(int(state.step)))
	var event: Dictionary = readiness.event
	var choices: Array = event.get("choices", [])
	if choice >= choices.size():
		message = "这段故事没有可选的回应。"
		changed.emit()
		return false
	var needs_value: Variant = event.get("needs", {})
	var needs: Dictionary = needs_value if needs_value is Dictionary else {}
	_reconcile_kitchen_lots()
	for item_id in needs:
		_consume_item(str(item_id), int(needs[item_id]))
	_reconcile_kitchen_lots()
	var selected: Dictionary = choices[choice]
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.get("id", "")) == npc_id:
			person = candidate
			break
	if str(event.get("kind", "")) == "confirmation":
		if str(person.get("tier", "")) != "romance" or int(person.get("age", 0)) < 18:
			message = "只有成年候选人才有关系确认。"
			changed.emit()
			return false
		partners[npc_id] = "dating" if choice == 0 else "friend"
	var arc: Array = content.get("arcs", {}).get(npc_id, [])
	state.choices.append(choice)
	state.step = int(state.get("step", 0)) + 1
	state.lastDay = day
	npc_stories[npc_id] = state
	if int(state.step) == 2:
		for link in content.get("links", []):
			if link is Array and link.size() >= 2 and str(link[0]) == npc_id and relations.has(str(link[1])):
				var friend_relation: Dictionary = relations[str(link[1])]
				friend_relation.points = mini(100, int(friend_relation.get("points", 0)) + 2)
				relations[str(link[1])] = friend_relation
	var relation: Dictionary = relations.get(npc_id, {"points": 0})
	relation.points = mini(100, int(relation.get("points", 0)) + 10)
	_award_skill_xp("social", 5)
	relations[npc_id] = relation
	for recipe in content.get("recipes", []):
		if str(recipe.get("source", "")) == npc_id and not known_recipes.has(str(recipe.get("id", ""))):
			known_recipes.append(str(recipe.get("id", "")))
			_record_community_log("学会了 %s。" % str(item_catalog.get(str(recipe.get("id","")),{}).get("name","")))
	var reply := str(selected.get("reply", ""))
	var narrative := str(event.get("text", "")) + "\n" + reply
	_record_community_log("%s · %s：%s" % [npc_name(npc_id),str(event.get("title","")),reply])
	_remember_npc_dialogue(npc_id, "story-choice-%d" % int(state.step), narrative, "故事", "happy", str(selected.get("label", "")))
	message = reply
	if int(state.step) == arc.size():
		var archive_by_npc := {"granny": "recipe", "chen": "ruler", "zhouSenior": "teaBook", "he": "album"}
		var archive_id := str(archive_by_npc.get(npc_id, ""))
		if archive_id != "" and not archives.has(archive_id):
			archives.append(archive_id)
		_grant_legacy_item("rice", 2)
	if quest_definition.is_empty():quest_definition={"id":"story:"+npc_id+":"+str(int(state.step)-1),"kind":"story","category":"人物","title":npc_name(npc_id)+" · "+str(event.title),"text":"已听完这段个人故事，可在人物簿回看。","npc":npc_id,"ref":npc_id,"step":int(state.step)-1,"source":"npc:"+npc_id,"page":"stories"}
	QUESTS.complete_record(self,quest_definition)
	_museum_sync()
	changed.emit()
	return true

func upgrade_home_room() -> bool:
	return perform_legacy_upgrade("room")

func date_npc(npc_id: String) -> bool:
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.get("id", "")) == npc_id:
			person = candidate
			break
	if str(person.get("tier", "")) != "romance" or int(person.get("age", 0)) < 18 or int(npc_stories.get(npc_id, {}).get("step", 0)) < 4:
		message = "先走过对方的关系确认故事。"
		changed.emit()
		return false
	partners[npc_id] = "dating"
	_record_community_log("与%s再次确认了心意。" % npc_name(npc_id))
	message = "把心意说开了。对方愿意和你慢慢走下去。"
	changed.emit()
	return true

func marry_npc(npc_id: String) -> bool:
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.get("id", "")) == npc_id:
			person = candidate
			break
	var relation: Dictionary = relations.get(npc_id, {})
	if person.is_empty() or str(person.get("tier", "")) != "romance" or int(person.get("age", 0)) < 18 or str(partners.get(npc_id, "")) != "dating" or int(npc_stories.get(npc_id, {}).get("step", 0)) < 4 or int(relation.get("points", 0)) < 70:
		message = "需要双方确认心意、走完前四章，并达到信任。"
		changed.emit()
		return false
	if str(marriage.get("spouse", "")) != "":
		message = "已有共同生活的伴侣，可先好好商量未来安排。"
		changed.emit()
		return false
	if not bool(upgrades.get("room", false)):
		message = "先整理厢房，让两个人都有自己的空间。"
		changed.emit()
		return false
	marriage = {"spouse": npc_id, "day": day, "weekly": {}, "memories": []}
	_record_community_log("在乡亲们的饭桌祝福里，和%s结为伴侣。" % npc_name(npc_id))
	message = "院里摆开一张长桌。大家带菜来，祝你们各自有喜欢的事，也有愿意一起回来的家。"
	changed.emit()
	return true

func separate_from_partner() -> bool:
	var spouse := str(marriage.get("spouse", ""))
	if spouse == "":
		message = "目前没有伴侣。"
		changed.emit()
		return false
	partners[spouse] = "friend"
	marriage = {"spouse": "", "day": -1, "weekly": {}, "memories": []}
	_record_community_log("和%s平静地商量，各自生活，仍是邻里。" % npc_name(spouse))
	message = "各自的工作、友谊和已发生的故事都保留。"
	changed.emit()
	return true

func _museum_default() -> Dictionary:
	return {"version": 1, "entries": {}, "observations": {}, "donated": {}, "claimed": [], "badges": [], "level": 0, "featured": {}, "tracked": null}

func _museum_entry(key: String) -> Dictionary:
	return museum_entries.get(key, {})

func _museum_donation(key: String) -> Dictionary:
	return system_catalog.get("museum", {}).get("donationMap", {}).get(key, {})

func _museum_bundle(bundle_id: String) -> Dictionary:
	for bundle in system_catalog.get("museum", {}).get("bundles", []):
		if str(bundle.get("id", "")) == bundle_id:
			return bundle
	return {}

func _museum_record(key: String, acquired: bool = false, researched: bool = false, legacy: bool = false, best: int = 0) -> Dictionary:
	if _museum_entry(key).is_empty():
		return {}
	var entries: Dictionary = collection.get("entries", {})
	var row: Dictionary = entries.get(key, {"first": -1 if legacy else day, "acquired": false, "researched": false, "best": 0})
	row.acquired = bool(row.get("acquired", false)) or acquired
	row.researched = bool(row.get("researched", false)) or researched
	row.best = maxi(int(row.get("best", 0)), clampi(best, 0, 3))
	entries[key] = row
	collection.entries = entries
	return row

func _museum_normalize(saved: Variant = null) -> void:
	var clean := _museum_default()
	var source: Dictionary = saved if saved is Dictionary else {}
	var known_entries: Dictionary = {}
	for entry in system_catalog.get("museum", {}).get("entries", []):
		known_entries[str(entry.get("key", ""))] = true
	var saved_entries: Variant = source.get("entries", {})
	if saved_entries is Dictionary:
		for key in saved_entries:
			if not known_entries.has(str(key)) or not saved_entries[key] is Dictionary:
				continue
			var row: Dictionary = saved_entries[key]
			clean.entries[str(key)] = {"first": clampi(int(row.get("first", -1)), -1, day), "acquired": bool(row.get("acquired", false)), "researched": bool(row.get("researched", false)), "best": clampi(int(row.get("best", 0)), 0, 3)}
	var wildlife_ids: Dictionary = {}
	for wildlife in system_catalog.get("museum", {}).get("wildlife", []):
		wildlife_ids[str(wildlife.get("id", ""))] = true
	var saved_observations: Variant = source.get("observations", {})
	if saved_observations is Dictionary:
		for wildlife_id in saved_observations:
			if not wildlife_ids.has(str(wildlife_id)) or not saved_observations[wildlife_id] is Array:
				continue
			var days: Array[int] = []
			for value in saved_observations[wildlife_id]:
				var observed_day := int(value)
				if observed_day >= 0 and observed_day <= day and not days.has(observed_day) and days.size() < 2:
					days.append(observed_day)
			clean.observations[str(wildlife_id)] = days
	var donations: Dictionary = system_catalog.get("museum", {}).get("donationMap", {})
	var saved_donated: Variant = source.get("donated", {})
	if saved_donated is Dictionary:
		for key in saved_donated:
			var definition: Dictionary = donations.get(str(key), {})
			var row_value: Variant = saved_donated[key]
			if definition.is_empty() or not known_entries.has(str(key)) or not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			var mode := str(row.get("mode", ""))
			if not definition.get("modes", []).has(mode):
				continue
			clean.donated[str(key)] = {"day": clampi(int(row.get("day", 0)), 0, day), "mode": mode, "grade": clampi(int(row.get("grade", 0)), 0, 3)}
	var saved_claimed: Variant = source.get("claimed", [])
	for bundle in system_catalog.get("museum", {}).get("bundles", []):
		var bundle_id := str(bundle.get("id", ""))
		if saved_claimed is Array and saved_claimed.has(bundle_id):
			var complete := true
			for key in bundle.get("keys", []):
				if not clean.donated.has(str(key)):
					complete = false
			if complete: clean.claimed.append(bundle_id)
	var saved_badges: Variant = source.get("badges", [])
	for badge_id in ["observer", "researcher"]:
		if saved_badges is Array and saved_badges.has(badge_id):
			clean.badges.append(badge_id)
	clean.level = clampi(int(source.get("level", 0)), 0, 3)
	var saved_featured: Variant = source.get("featured", {})
	if saved_featured is Dictionary:
		for group in saved_featured:
			var key := str(saved_featured[group])
			if clean.donated.has(key) and str(donations.get(key, {}).get("group", "")) == str(group):
				clean.featured[str(group)] = key
	var tracked := str(source.get("tracked", ""))
	clean.tracked = tracked if not _museum_bundle(tracked).is_empty() else null
	collection = clean

func _museum_sync(legacy: bool = false) -> void:
	if collection.is_empty():
		collection = _museum_default()
	var item_best: Dictionary = {}
	for item_id in inventory:
		if int(inventory[item_id]) > 0:
			var best := 0
			var ledger: Array = quality.get(item_id, [0, 0, 0])
			for grade in range(mini(3, ledger.size())):
				if int(ledger[grade]) > 0:
					best = grade + 1
			item_best[str(item_id)] = best
			_museum_record("item:" + str(item_id), true, false, legacy, best)
	for item_id in storage:
		if int(storage[item_id]) > 0:
			_museum_record("item:" + str(item_id), true, false, legacy, int(item_best.get(str(item_id), 0)))
	for plot in plots:
		if str(plot.get("crop", "")) != "":
			_museum_record("item:" + str(plot.crop), false, false, legacy)
	for item_id in kitchen.get("mastery", {}):
		if int(kitchen.mastery[item_id]) > 0:
			_museum_record("item:" + str(item_id), true, true, legacy)
	var fish_records: Dictionary = fishing.get("records", {}) if fishing.get("records", {}) is Dictionary else {}
	for fish_id in fish_records:
		var record: Dictionary = fish_records[fish_id]
		if int(record.get("count", 0)) > 0:
			_museum_record("item:" + str(fish_id), true, int(record.count) >= 3, legacy, int(record.get("grade", 0)))
	for animal in animals:
		_museum_record("animal:" + str(animal.get("type", animal.get("id", ""))), true, int(animal.get("bond", 0)) >= 20, legacy, 0)
	var pet_type := str(pet_state.get("type", "cat"))
	_museum_record("pet:" + pet_type, true, int(pet_state.get("bond", 0)) >= 15, legacy)
	var story_ids: Dictionary = {}
	for npc_id in npc_stories:
		story_ids[str(npc_id)] = true
	for npc_id in relations:
		if int(relations[npc_id].get("talked", -1)) >= 0:
			story_ids[str(npc_id)] = true
	for npc_id in story_ids:
		var state: Dictionary = npc_stories.get(npc_id, {})
		var resident: Dictionary = neighbors.get("people", {}).get(npc_id, {})
		if bool(resident.get("introduced", false)) or int(state.get("step", 0)) > 0 or int(relations.get(npc_id, {}).get("talked", -1)) >= 0:
			_museum_record("npc:" + npc_id, false, int(state.get("step", 0)) > 0, legacy)
	# Story rewards belong to the successful final choice, not catalog synchronization.
	for archive_id in archives:
		_museum_record("archive:" + archive_id, true, true, legacy)
	for festival_key in festivals:
		var parts := festival_key.split("-")
		if parts.size() == 2:
			var festival_season := int(parts[1])
			if festival_season >= 0 and festival_season < 4:
				_museum_record("festival:" + str(festival_season), true, true, legacy)

func museum_record_region(position: Vector2) -> void:
	var column := 1 if position.x >= 1920.0 else 0
	var row := clampi(floori(position.y / 1152.0), 0, 2)
	var ids := [["mountain", "bamboo", "river"], ["town", "farm", "pasture"]]
	var region_id := str(ids[column][row])
	var visited: Array = atlas.get("visited", [])
	if not visited.has(region_id):
		visited.append(region_id)
		atlas["visited"] = visited
	if region_id == seen_world_region:
		return
	seen_world_region = region_id
	_museum_record("region:" + region_id)

func _atlas_default() -> Dictionary:
	return {"version": 1, "visited": [], "pins": [], "nextId": 1, "tracking": null, "layer": "all", "minimap": false}

func _atlas_normalize(saved: Variant = null) -> void:
	# Validate before loading. Preserve valid fields, fractional coordinates and extras.
	var rules = preload("res://scripts/atlas_rules.gd")
	atlas = saved.duplicate(true) if rules.truthy(saved) and saved is Dictionary else _atlas_default()

func atlas_scope() -> Dictionary:
	var house := house_data(current_interior)
	if not house.is_empty():
		return {"id":str(house.id),"name":str(house.name),"region":str(house.region),"bounds":{"width":960,"height":672,"interior":true},"door":house.door.duplicate(true)}
	var region := atlas_region_id(player_position)
	return {"id":"world","name":str(world_village.get("offsets",{}).get(region,{}).get("name","")),"region":region,"bounds":{"width":3840,"height":3840}}

func atlas_visit() -> void:
	var region: String = str(atlas_scope().region)
	if not atlas.visited.has(region): atlas.visited.append(region)

func atlas_set_dynamic_obstacles(rectangles: Array[Rect2]) -> void:
	if atlas_navigation != null:
		atlas_navigation.call("set_dynamic_obstacles", rectangles)

func atlas_route(from: Vector2, to: Vector2) -> Dictionary:
	if atlas_navigation == null:
		atlas_navigation = VILLAGE_NAVIGATION_SCRIPT.new(world_village)
	return atlas_navigation.call("route", from, to)

func atlas_region_id(position: Vector2) -> String:
	return atlas_region_point(float(position.x), float(position.y))

func atlas_region_bounds(region_id: String) -> Rect2:
	var region: Dictionary = world_village.get("offsets", {}).get(region_id, {})
	if region.is_empty(): return Rect2()
	return Rect2(float(region.x), float(region.y), 1920.0, 1536.0 if float(region.y) == 2304.0 else 1152.0)

func atlas_region_point(x: float, y: float) -> String:
	for region_id in world_village.get("offsets", {}):
		var region: Dictionary = world_village.offsets[region_id]
		var height := 1536.0 if float(region.get("y", 0)) == 2304.0 else 1152.0
		if x >= float(region.x) and x < float(region.x) + 1920.0 and y >= float(region.y) and y < float(region.y) + height:
			return str(region_id)
	return "farm"

func npc_location(npc_id: String) -> Dictionary:
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.get("id", "")) == npc_id: person = candidate; break
	var p: Dictionary = npc_residents.get(npc_id, {})
	if person.is_empty() or p.is_empty(): return {}
	var place := str(world_village.get("offsets", {}).get(atlas_region_point(float(p.x),float(p.y)), {}).get("name", ""))
	if p.get("room") != null:
		# The original neighbor journal names this person's own home even during a museum visit.
		for house in world_village.get("houses", []):
			if str(house.get("owner", "")) == npc_id: place = str(house.get("name", "")); break
	var plan: Dictionary = npc_dialogue_activity(person)
	var walking: bool = npc_movement != null and bool(npc_movement.actors.get(npc_id, {}).get("walking", false))
	return {"place": place, "activity": ("沿路前往 · " if walking else "") + str(plan.label), "reason": str(plan.reason), "plan": plan}

func npc_scene_region(npc_id: String) -> String:
	var p: Dictionary = npc_residents.get(npc_id, {})
	var region := "farm"
	if not p.is_empty():
		region = atlas_region_point(float(p.x),float(p.y))
		if p.get("room") != null:
			for house in world_village.get("houses", []):
				if str(house.get("owner", "")) == npc_id: region = str(house.get("region", "farm")); break
	return "farm" if region == "pasture" else region

func farm_plot_position(index: int) -> Vector2:
	return FARM_LAYOUT.position(index)

func _atlas_npc_house(person: Dictionary) -> Dictionary:
	var p: Dictionary = npc_residents.get(str(person.get("id", "")), {})
	return house_data(str(p.room)) if p.get("room") != null else {}

func npc_destination(npc_id: String) -> Dictionary:
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.get("id", "")) == npc_id: person = candidate; break
	var resident: Dictionary = npc_residents.get(npc_id, {})
	if person.is_empty() or resident.is_empty(): return {}
	if resident.get("room") != null:
		for house in world_village.get("houses", []):
			if str(house.get("owner", "")) != npc_id: continue
			var door: Dictionary = house.get("door", {}).duplicate()
			door.merge({"id":str(house.id),"house":str(house.id),"kind":"enter","name":str(person.name)+"家"},true)
			return door
		return {}
	var target := {"id":npc_id,"kind":"npc","npc":person,"name":str(person.name)+" · "+str(npc_dialogue_activity(person).label)}
	target.merge(resident,true)
	return target

func find_npc(npc_id: String) -> bool:
	var destination := npc_destination(npc_id)
	# Legacy "find" always leaves the current room before starting an outdoor destination.
	if current_interior != "" and not destination.is_empty(): destination.leave_before_find = true
	var players := get_tree().get_nodes_in_group("player")
	if destination.is_empty() or players.is_empty(): return false
	var player: Node = players[0]
	var hud: Node = player.get_parent().get("hud")
	if hud != null: hud.close_top_panel()
	source_keyboard.clear()
	return bool(player.walk_to(destination))

func atlas_npc_target(person: Dictionary) -> Dictionary:
	var id := str(person.get("id", ""))
	var resident: Dictionary = npc_residents.get(id, {})
	if resident.is_empty(): return {}
	var house := _atlas_npc_house(person)
	var row: Dictionary = resident.duplicate() if house.is_empty() else house.get("door", {}).duplicate()
	var location := npc_location(id)
	row.merge({"id": "neighbor-" + id, "type": "neighbors", "kind": "enter" if not house.is_empty() else "walk", "name": str(person.get("name", id)) + (" · 在家" if not house.is_empty() else " · 在村里"), "region": str(house.get("region", "")) if not house.is_empty() else atlas_region_point(float(row.x),float(row.y)), "detail": str(location.get("activity", "")) + " · " + str(location.get("reason", ""))}, true)
	if not house.is_empty(): row.house = str(house.id)
	return row

func atlas_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for house in world_village.get("houses", []):
		var owner := str(house.get("owner", "")) if house.get("owner") != null else ""
		var row: Dictionary = house.get("door", {}).duplicate(true)
		var profile: Array = world_village.get("profiles", {}).get(owner, [])
		row.merge({"id":str(house.id),"type":"homes" if owner != "" else "services","name":str(house.name),"detail":str(profile[2]) if profile.size()>2 else "进屋可使用服务与查看旧物","region":str(house.region),"kind":"enter","house":str(house.id)},true)
		result.append(row)
	for person in npc_catalog:
		var target := atlas_npc_target(person)
		if not target.is_empty(): result.append(target)
	for region in atlas_catalog.get("regions", []): result.append(region.duplicate(true))
	for index in range(plots.size()):
		var plot: Dictionary = plots[index]
		var crop_id := str(plot.get("crop", ""))
		if crop_id == "" or crop_data(crop_id).is_empty(): continue
		var at := farm_plot_position(index)
		var base := {"x":float(at.x),"y":float(at.y),"region":atlas_region_point(float(at.x),float(at.y)),"kind":"walk"}
		if float(plot.get("growth",0)) >= float(crop_data(crop_id).get("days",1)):
			var row := base.duplicate()
			row.merge({"id":"harvest-"+str(index),"type":"harvest","name":str(index+1)+" 号田 · "+str(item_catalog.get(crop_id,{}).get("name",crop_id))+"成熟","detail":"到田边后选工具照料"},true)
			result.append(row)
		if float(plot.get("moisture",45)) < 40.0:
			var row := base.duplicate()
			row.merge({"id":"water-"+str(index),"type":"water","name":str(index+1)+" 号田 · 待补水","detail":"水分 "+str(floori(float(plot.get("moisture",45))+0.5))+" · 带好水壶"},true)
			result.append(row)
	for animal in animals:
		var position_data: Dictionary = animal.get("position", {})
		var room := str(position_data.get("room", "")) if position_data.get("room") != null else ""
		var house := house_data(room) if room != "" else {}
		# Ranch.point uses the player's current room; a valid barn still contributes its door.
		if house.is_empty() and room != current_interior: continue
		var row: Dictionary = house.get("door", {}).duplicate(true) if not house.is_empty() else position_data.get("inside",{}).duplicate(true) if room != "" else position_data.duplicate(true)
		if house.is_empty(): row.room=position_data.get("room",null)
		var status := "可收产" if float(animal.get("ready",0)) != 0 or float(animal.get("feathers",0)) != 0 else "饿了" if float(animal.get("hunger",100)) < 40 else "需护理" if float(animal.get("illness",0)) >= 20 else "在舍内" if not house.is_empty() else "散步中"
		row.merge({"id":"animal-"+str(animal.id),"animalId":str(animal.id),"kind":"enter" if not house.is_empty() else "walk","type":"animals","region":"pasture","name":str(animal.get("name","伙伴"))+" · "+status,"detail":str(house.name) if not house.is_empty() else ranch_life_stage(animal)},true)
		if not house.is_empty(): row.house=str(house.id)
		result.append(row)
	for point in atlas_catalog.get("foragePoints", []):
		if not forage.get("discovered",[]).has(str(point.id)): continue
		if not bool(forage_status(str(point.id),str(point.item),str(point.get("event",""))).ready): continue
		var row: Dictionary = point.duplicate(true)
		var detail := forage_description(str(point.id),str(point.item),str(point.get("event","")))
		row.merge({"id":"resource-"+str(point.id),"kind":"walk","type":"resources","region":atlas_region_point(float(point.x),float(point.y)),"name":str(system_catalog.get("forage",{}).get("defs",{}).get(str(point.item),{}).get("name",""))+" · "+detail,"detail":detail},true)
		result.append(row)
	for spot in system_catalog.get("fishing", {}).get("spots", []):
		var row: Dictionary = spot.duplicate(true)
		row.merge({"type":"services","kind":"walk","region":atlas_region_point(float(spot.x),float(spot.y)),"detail":str(system_catalog.get("fishing",{}).get("waters",{}).get(str(spot.water),{}).get("tip",""))},true)
		result.append(row)
	for pin in atlas.get("pins", []):
		var row: Dictionary = pin.duplicate(true)
		row.merge({"name":pin.label,"kind":"walk","type":"pins","region":atlas_region_point(float(pin.x),float(pin.y)),"detail":"自己记下的地点"},true)
		result.append(row)
	for scenery in atlas_catalog.get("sceneryPoints", []):
		var row: Dictionary = scenery.duplicate(true)
		row.merge({"type":"services","kind":"walk","detail":str(scenery.story)},true)
		result.append(row)
	return result

func ranch_life_stage(animal: Dictionary) -> String:
	var spec: Dictionary = system_catalog.get("ranch",{}).get("species",{}).get(str(animal.get("type","")),{})
	var age := float(animal.get("age",0))
	return "颐养" if bool(animal.get("retired",false)) else "幼崽" if age < float(spec.get("adult",6))*0.45 else "成长" if age < float(spec.get("adult",6)) else "年长" if age >= float(spec.get("elder",999999)) else "成年"

func atlas_resolve(target: Variant) -> Dictionary:
	if not target is Dictionary or target.is_empty(): return {}
	var id: Variant=target.get("id",null)
	for row in atlas_targets():
		if preload("res://scripts/js_string.gd").equal(row.get("id"),id): return row
	if not preload("res://scripts/atlas_rules.gd").truthy(id) and (target.get("x") is float or target.get("x") is int) and (target.get("y") is float or target.get("y") is int):
		if is_finite(float(target.x)) and is_finite(float(target.y)):
			var row:Dictionary=target.duplicate(true)
			row.kind="walk"
			if not preload("res://scripts/atlas_rules.gd").truthy(row.get("name")):row.name="地图落点"
			return row
	return {}

func atlas_click_point(x: float, y: float, layer: String="all") -> Dictionary:
	var closest: Dictionary = {}
	var distance := 90.0
	for row in atlas_targets():
		if layer != "all" and str(row.get("type","")) != layer: continue
		var d := sqrt(pow(float(row.x)-x,2)+pow(float(row.y)-y,2))
		if d < distance: distance=d;closest=row
	return closest if not closest.is_empty() else {"x":x,"y":y,"kind":"walk","name":"地图落点"}

func atlas_pin_current(label: String = "") -> bool:
	if current_interior != "":
		message = "先走到室外，再把当前位置记在地图上。"
		changed.emit()
		return false
	return atlas_pin_point(player_position, label)

func atlas_pin_point(position: Vector2, label: Variant = "") -> bool:
	return bool(atlas_pin_coordinates(float(position.x),float(position.y),label).ok)

func atlas_pin_coordinates(x: Variant,y: Variant,label: Variant = "") -> Dictionary:
	var result: Dictionary
	if atlas.get("pins",[]).size()>=12:
		result={"ok":false,"msg":"手绘标记最多十二个，先擦去不需要的标记。"}
	elif not preload("res://scripts/atlas_rules.gd").number(x) or not preload("res://scripts/atlas_rules.gd").number(y):
		result={"ok":false,"msg":"请把标记落在能走到的空地上。"}
	else:
		var navigation = npc_movement.navigation if npc_movement!=null else preload("res://scripts/npc_navigation.gd").new()
		navigation.refresh(self)
		if navigation.blocked(self,"",x,y):
			result={"ok":false,"msg":"请把标记落在能走到的空地上。"}
		else:
			var rules = preload("res://scripts/atlas_rules.gd")
			var js = preload("res://scripts/js_string.gd")
			var title: Variant=js.prefix(js.trim(js.coerce(label if rules.truthy(label) else "我的标记")),18)
			if js.length(title)==0: title="我的标记"
			var pin:Dictionary={"id":"pin-"+str(int(atlas.nextId)),"x":floori(x+0.5),"y":floori(y+0.5),"label":title}
			atlas.nextId=int(atlas.nextId)+1
			atlas.pins.append(pin)
			result={"ok":true,"msg":"这处地点已记进手绘地图。","pin":pin}
	message=str(result.msg)
	changed.emit()
	return result

func atlas_remove_pin(pin_id: Variant) -> void:
	var js = preload("res://scripts/js_string.gd")
	atlas.pins=atlas.get("pins",[]).filter(func(pin:Dictionary)->bool:return not js.equal(pin.get("id"),pin_id))
	var tracking:Variant=atlas.get("tracking")
	if tracking is Dictionary and ((tracking.get("id")==null and pin_id==null) or js.equal(tracking.get("id"),pin_id)): atlas.tracking=null
	changed.emit()

func _atlas_hypot(dx: float,dy: float) -> float:
	var scale:=maxf(absf(dx),absf(dy))
	if scale==0.0:return 0.0
	var x:=absf(dx)/scale
	var y:=absf(dy)/scale
	return sqrt(x*x+y*y)*scale

func interaction_route(target: Dictionary, source_position: Dictionary = {}, room: String = "", use_approach: bool = true) -> Dictionary:
	if atlas_source_navigation==null:atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
	var navigation=atlas_source_navigation
	navigation.refresh(self)
	var position:=source_position
	if position.is_empty():
		position=(interior_source_position if room!="" else player_source_position).duplicate()
	var stand:Dictionary=preload("res://scripts/interaction_navigation.gd").approach(navigation,self,room,position,target) if use_approach else {"x":float(target.x),"y":float(target.y)}
	var path:Array=navigation.route(self,room,position,stand)
	var points:Array=[]
	var distance:=0.0
	var last:Dictionary=position
	for point in path:
		points.append(Vector2(float(point.x),float(point.y)))
		distance+=_atlas_hypot(float(point.x)-float(last.x),float(point.y)-float(last.y))
		last=point
	return {"stand":stand,"path":path,"points":points,"distance":distance,"reachable":not path.is_empty(),"local_walk":true,"seconds":maxi(1,ceili(distance/player_movement_speed())) if not path.is_empty() else 0}

func atlas_preview(target: Variant, source_position: Dictionary = {}) -> Dictionary:
	var resolved := atlas_resolve(target)
	if resolved.is_empty(): return {"ok":false,"reachable":false,"msg":"这个目标已经完成或不在原处，请刷新地图。","path":[],"points":[]}
	var room := current_interior
	var position := source_position
	if position.is_empty():
		position=(interior_source_position if room!="" else player_source_position).duplicate()
	if room!="" and str(resolved.get("house",""))==room:
		return {"ok":true,"reachable":true,"msg":"已经在这间屋里。","path":[],"points":[],"roomPath":[],"room_points":[],"distance":0.0,"seconds":0,"target":resolved,"here":true}
	if atlas_source_navigation==null:atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
	var navigation=atlas_source_navigation
	navigation.refresh(self)
	var origin:Dictionary=house_data(room).door.duplicate() if room!="" else position.duplicate()
	var room_path:Array=[]
	if room!="":
		var exit={"x":480.0,"y":595.0}
		for point in system_catalog.get("interiors",{}).get("layouts",{}).get(room,{}).get("points",[]):
			if str(point.get("kind",""))=="exit":
				exit={"x":float(point.x),"y":float(point.y)+5.0}
				break
		room_path=navigation.route(self,room,position,exit)
	var path:Array=navigation.route(self,"",origin,{"x":float(resolved.x),"y":float(resolved.y)+5.0})
	if path.is_empty() or room!="" and room_path.is_empty():
		return {"ok":false,"reachable":false,"msg":"当前布局无法通行，请调整障碍或换一个落点。","path":[],"points":[],"target":resolved}
	var distance:=0.0
	for part in [{"path":path,"from":origin},{"path":room_path,"from":position}]:
		var last:Dictionary=part.from
		var part_distance:=0.0
		for point in part.path:
			part_distance+=_atlas_hypot(float(point.x)-float(last.x),float(point.y)-float(last.y))
			last=point
		distance+=part_distance
	var points:Array=[]
	for point in path: points.append(Vector2(float(point.x),float(point.y)))
	var room_points:Array=[]
	for point in room_path:room_points.append(Vector2(float(point.x),float(point.y)))
	return {"ok":true,"reachable":true,"path":path,"points":points,"next":points[0],"roomPath":room_path,"room_points":room_points,"from":origin,"distance":distance,"seconds":maxi(1,ceili(distance/(355.0 if riding and room=="" else 195.0))),"target":resolved,"msg":"先由原门出屋，再沿村道前往。" if room!="" else "沿连通村道步行前往。"}

func atlas_track(target: Dictionary) -> bool:
	var resolved := atlas_resolve(target)
	if resolved.is_empty():
		message = "目标已失效。"
		changed.emit()
		return false
	var player := get_tree().get_first_node_in_group("player")
	var preview: Dictionary
	if player != null: preview=player.preview_walk(resolved)
	else: preview=atlas_preview(resolved)
	if not bool(preview.get("reachable",false)):
		message="当前布局无法通行，请调整障碍或换一个落点。"
		changed.emit()
		return false
	atlas.tracking = {"id":resolved.get("id",null),"name":resolved.name,"x":float(resolved.x),"y":float(resolved.y)}
	message = "已记住目标，重载后可从地图继续带路。"
	changed.emit()
	return true

func atlas_clear_tracking() -> void:
	atlas.tracking = null
	message = "已清除地图方向指引。"
	changed.emit()

func museum_progress(category: String = "全部") -> Dictionary:
	_museum_sync()
	var total := 0
	var seen := 0
	var acquired := 0
	var researched := 0
	for entry in system_catalog.get("museum", {}).get("entries", []):
		if category != "全部" and str(entry.get("category", "")) != category:
			continue
		total += 1
		var row: Dictionary = collection.get("entries", {}).get(str(entry.key), {})
		if not row.is_empty(): seen += 1
		if bool(row.get("acquired", false)): acquired += 1
		if bool(row.get("researched", false)): researched += 1
	return {"total": total, "seen": seen, "acquired": acquired, "researched": researched}

func museum_research_reason(key: String) -> String:
	var entry := _museum_entry(key)
	var row: Dictionary = collection.get("entries", {}).get(key, {})
	if entry.is_empty() or row.is_empty(): return "先在村里发现这个条目。"
	if bool(row.get("researched", false)): return "已经研究完成。"
	var entry_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	if entry_type == "item" and crop_catalog.has(item_id): return "亲手收获一次，补上种植记录。"
	if entry_type == "item" and system_catalog.get("fishing", {}).get("species", {}).has(item_id): return "记录 3 次鱼获，放流也计入。"
	if entry_type == "wild": return "在两个不同的日子观察它。"
	if entry_type == "npc": return "听完对方的一章个人故事。"
	if entry_type == "animal": return "持续照料伙伴，好感达到 20。"
	if entry_type == "pet": return "与家中的伙伴相处，好感达到 15。"
	if entry_type == "item" and not bool(row.get("acquired", false)): return "实际获得后再整理用途笔记。"
	return ""

func museum_research(key: String) -> bool:
	if not museum_near():
		message="请到村史馆登记桌前整理研究笔记。";changed.emit();return false
	_museum_sync()
	var reason := museum_research_reason(key)
	if reason != "":
		message = reason
		changed.emit()
		return false
	_museum_record(key, true, true)
	QUESTS.event(self,"research")
	message = "已补齐%s的用途与生活笔记。" % str(_museum_entry(key).get("name", key))
	changed.emit()
	return true

func museum_near() -> bool:
	var catalog:Dictionary=system_catalog.get("museum",{})
	if current_interior!=str(catalog.get("house",{}).get("id","building-river-10")):return false
	var registry:Dictionary=catalog.get("registry",{"x":480,"y":510})
	return interior_position.distance_to(Vector2(float(registry.x),float(registry.y)))<=90.0

func npc_task_action(task: Dictionary) -> Dictionary:
	var profile:Dictionary=system_catalog.get("npc",{}).get("profiles",{}).get(str(task.get("npcId",task.get("id",""))),{})
	var operation:=str(task.get("op",""))
	if profile.is_empty() or operation not in ["talk","story","accept","later","supply","join"]:return {}
	var kind:=str(profile.get("helpKind","read")) if operation=="join" else "trade" if operation=="supply" else "read" if operation=="story" else "greet"
	var label:=str(profile.get("helpAction","")) if operation=="join" else "点好材料，交到邻居手中" if operation=="supply" else "停下脚步，面对面回应"
	var spec:=ACTION_RULES.spec(kind,label)
	spec.duration=2.8 if operation=="join" else 1.15
	spec.item=profile.get("item",null) if operation=="supply" else null
	return spec

func queue_npc_task(npc_id: String,operation: String,data: Dictionary={}) -> bool:
	if action_busy():return false
	var spec:=npc_task_action({"npcId":npc_id,"op":operation})
	if spec.is_empty():return false
	var players:=get_tree().get_nodes_in_group("player")
	if players.is_empty():return false
	var player:Node=players[0]
	var hud:Node=player.get_parent().get("hud")
	if not npc_is_near(npc_id):
		find_npc(npc_id)
		message="先沿路找到对方，再选择话题或一起做事。"
		changed.emit()
		return false
	var point:Vector2=interior_npc_positions[npc_id] if current_interior!="" else npc_positions[npc_id]
	hud.close_top_panel()
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	building_task.clear()
	museum_task.clear()
	npc_task.clear()
	walking_target.clear()
	npc_task_serial+=1
	npc_task={"kind":"npc-task","id":npc_id,"npcId":npc_id,"op":operation,"x":point.x,"y":point.y,"token":npc_task_serial}
	npc_task.merge(data,true)
	return begin_action(spec,npc_task,finish_npc_task.bind(npc_task.duplicate(true)))

func finish_npc_task(target: Dictionary) -> void:
	if npc_task.is_empty() or int(target.get("token",-1))!=int(npc_task.get("token",-2)):return
	var npc_id:=str(target.npcId)
	npc_task.clear()
	if not npc_is_near(npc_id):
		message="对方走开了，先靠近再聊。"
		changed.emit()
		return
	match str(target.op):
		"talk":confirm_operation(talk_to_npc(npc_id,str(target.get("topic","auto"))))
		"story":confirm_operation(choose_npc_story(npc_id,int(target.get("choice",-1))))
		_:confirm_operation(resolve_npc_event(npc_id,str(target.op),int(target.get("day",-1))))
	var players:=get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var hud=players[0].get_parent().get("hud")
		if str(target.op)=="story":
			hud.show_npc_story(npc_id)
		else:hud.show_npc_dialogue(npc_id)

func museum_task_action(task: Dictionary) -> Dictionary:
	var operation:=str(task.get("op",""))
	if operation not in ["donate","claim","upgrade","feature"]:return {}
	var sample:=str(task.get("mode",""))=="sample"
	var kind:="build" if operation=="upgrade" else "trade" if sample else "read"
	var label:="整理展架，擦净展柜" if operation=="upgrade" else "签名领取，收好纪念陈设" if operation=="claim" else "布置展品，摆正铭牌" if operation=="feature" else "点验物产，装盒登记" if sample else "摊开资料，誊写入册"
	var spec:=ACTION_RULES.spec(kind,label)
	spec.duration=2.8 if operation=="upgrade" else 1.6
	var parts:PackedStringArray=str(task.get("id","")).split(":")
	spec.item=parts[1] if sample and parts.size()>1 else null
	return spec

func queue_museum_task(operation: String,id: String="",mode: String="",grade: int=0) -> bool:
	if operation not in ["donate","claim","upgrade","feature"] or action_busy():return false
	var players:=get_tree().get_nodes_in_group("player")
	if players.is_empty():return false
	var player:Node=players[0]
	var world:Node=player.get_parent()
	var catalog:Dictionary=system_catalog.get("museum",{})
	var house:Dictionary=catalog.get("house",{})
	world.get("hud").close_top_panel()
	source_keyboard.clear()
	if current_interior!=str(house.get("id","building-river-10")):
		var door:Dictionary=house.get("door",{})
		return player.walk_to({"id":house.id,"house":house.id,"kind":"enter","name":"禾溪村史馆","x":door.x,"y":door.y})
	stop_walking()
	var registry:Dictionary=catalog.get("registry",{"x":480,"y":510})
	museum_task_serial+=1
	museum_task={"kind":"museum-task","id":id,"op":operation,"mode":mode,"grade":grade,"name":"村史馆登记桌","x":registry.x,"y":registry.y,"token":museum_task_serial,"museum_task":true,"world_click":true,"click_room":current_interior,"auto_interact":true}
	if not player.walk_to(museum_task.duplicate(true)):
		museum_task.clear()
		npc_task.clear()
		return false
	return true

func finish_museum_task(target: Dictionary) -> void:
	if museum_task.is_empty() or int(target.get("token",-1))!=int(museum_task.get("token",-2)):return
	var players:=get_tree().get_nodes_in_group("player")
	if players.is_empty():
		museum_task.clear()
		npc_task.clear()
		return
	if interior_position!=players[0].global_position:interior_position=players[0].global_position
	if not museum_near():
		museum_task.clear()
		npc_task.clear()
		message="请到村史馆登记桌前再提交。"
		changed.emit()
		return
	if not bool(target.get("_sequence_resolved",false)):
		var resolved:=target.duplicate(true)
		resolved._sequence_resolved=true
		begin_action(museum_task_action(target),target,finish_museum_task.bind(resolved))
		return
	museum_task.clear()
	npc_task.clear()
	match str(target.op):
		"donate":confirm_operation(museum_donate(str(target.id),str(target.mode),int(target.grade)))
		"claim":confirm_operation(museum_claim(str(target.id)))
		"upgrade":confirm_operation(museum_upgrade())
		"feature":confirm_operation(museum_feature(str(target.id)))
	players[0].get_parent().get("hud").show_museum("donate" if str(target.op) in ["donate","feature"] else "bundles" if str(target.op)=="claim" else "history")

func _museum_note(title: String,text: String) -> void:
	message=text
	_feedback_note({"key":"museum/%s/%d/%d/%d/%s"%[title,day,collection.get("claimed",[]).size(),collection.get("donated",{}).size(),text.left(30)],"title":title,"text":text,"type":"提醒","priority":1})


func _museum_quality_count(item_id: String, grade: int) -> int:
	var total := int(inventory.get(item_id, 0))
	var ledger: Array = quality.get(item_id, [0, 0, 0])
	if grade == 0:
		var higher := 0
		for count in ledger: higher += int(count)
		return maxi(0, total - higher)
	return int(ledger[grade - 1]) if grade - 1 < ledger.size() else 0

func museum_donation_reason(key: String, mode: String, grade: int = 0) -> String:
	var definition := _museum_donation(key)
	var entry := _museum_entry(key)
	if definition.is_empty() or entry.is_empty() or not definition.get("modes", []).has(mode): return "这不是馆内可登记的藏品。"
	if collection.get("donated", {}).has(key): return "这份藏品已经登记，不能重复提交。"
	if not collection.get("entries", {}).has(key): return "先亲自发现这份物产或记录。"
	if mode == "sample":
		if economy.get("locked", []).has(str(entry.id)): return "物品已锁定，请先在背包中解除保护。"
		if grade < 0 or grade > 3 or _museum_quality_count(str(entry.id), grade) < 1: return "所选品质的随身物品不足。"
	elif mode == "copy" and not archives.has(str(entry.id)):
		return "先取得这件旧物，再制作副本。"
	elif str(entry.type) == "item" and int((fishing.get("records", {}) if fishing.get("records", {}) is Dictionary else {}).get(str(entry.id), {}).get("count", 0)) <= 0:
		return "需要真实鱼获记录，放流同样有效。"
	elif str(entry.type) == "wild" and collection.get("observations", {}).get(str(entry.id), []).is_empty():
		return "先在野外观察一次。"
	elif str(entry.type) == "npc" and int(npc_stories.get(str(entry.id), {}).get("step", 0)) <= 0:
		return "先听完对方的一章故事，取得口述资料。"
	return ""

func museum_donate(key: String, mode: String, grade: int = 0) -> bool:
	_museum_sync()
	if not museum_near():
		message = "请到村史馆登记桌前再提交。"
		changed.emit()
		return false
	var reason := museum_donation_reason(key, mode, grade)
	if reason != "":
		message = reason
		changed.emit()
		return false
	var entry := _museum_entry(key)
	if mode == "sample":
		var item_id := str(entry.id)
		inventory[item_id] = int(inventory.get(item_id, 0)) - 1
		if grade > 0:
			var ledger: Array = quality.get(item_id, [0, 0, 0])
			ledger[grade - 1] = maxi(0, int(ledger[grade - 1]) - 1)
			quality[item_id] = ledger
		_reconcile_kitchen_lots()
	var donated: Dictionary = collection.get("donated", {})
	donated[key] = {"day": day, "mode": mode, "grade": grade if mode == "sample" else 0}
	collection.donated = donated
	var group := str(_museum_donation(key).get("group", ""))
	var featured: Dictionary = collection.get("featured", {})
	if not featured.has(group): featured[group] = key
	collection.featured = featured
	_museum_sync()
	_museum_note("馆藏已登记",str(entry.get("name",key))+(" ×1 已交由馆内保存。" if mode=="sample" else "的"+("副本" if mode=="copy" else "观察 / 口述记录")+"已入馆，原件与活物都不被收走。"))
	changed.emit()
	return true

func museum_bundle_complete(bundle_id: String) -> bool:
	var bundle := _museum_bundle(bundle_id)
	if bundle.is_empty(): return false
	for key in bundle.get("keys", []):
		if not collection.get("donated", {}).has(str(key)): return false
	return true

func museum_claim(bundle_id: String) -> bool:
	if not museum_near(): message = "请到登记桌前领取纪念陈设。"
	elif _museum_bundle(bundle_id).is_empty() or not museum_bundle_complete(bundle_id) or collection.get("claimed", []).has(bundle_id): message = "收集包尚未完成，或纪念陈设已经领取。"
	else:
		var bundle := _museum_bundle(bundle_id)
		var reward := str(bundle.get("reward", ""))
		if int(furniture.get(reward, 0)) >= 999:
			message = "这种陈设已存得很多，布置一些后再来。"
			changed.emit()
			return false
		collection.claimed.append(bundle_id)
		furniture[reward] = int(furniture.get(reward, 0)) + 1
		_museum_note("收集包完成","%s已归档，收到%s ×1，可在庭院布置中使用。"%[str(bundle.name),str(bundle.get("rewardName",reward))])
		changed.emit()
		return true
	changed.emit()
	return false

func museum_upgrade_reason() -> String:
	var levels: Array = system_catalog.get("museum", {}).get("levels", [])
	var level := int(collection.get("level", 0))
	if level + 1 >= levels.size(): return "村史馆已完成全部修缮。"
	var next: Dictionary = levels[level + 1]
	var groups: Dictionary = {}
	for key in collection.get("donated", {}):
		groups[str(_museum_donation(str(key)).get("group", ""))] = true
	return "" if collection.donated.size() >= int(next.get("need", 0)) and groups.size() >= int(next.get("groups", 0)) else "需要登记 %d 类藏品，涵盖 %d 个分类。" % [int(next.need), int(next.groups)]

func museum_upgrade() -> bool:
	var reason := museum_upgrade_reason()
	if not museum_near(): reason = "请到馆内登记桌旁协助布展。"
	if reason != "":
		message = reason
		changed.emit()
		return false
	collection.level = int(collection.level) + 1
	var level: Dictionary = system_catalog.get("museum", {}).get("levels", [])[int(collection.level)]
	_museum_note("村史馆焕新","%s已开放。%s"%[str(level.name),str(level.desc)])
	changed.emit()
	return true

func museum_feature(key: String) -> bool:
	var donation := _museum_donation(key)
	if not museum_near() or donation.is_empty() or not collection.get("donated", {}).has(key):
		message = "请到登记桌安排常设展品。" if not museum_near() else "先登记这件藏品。"
		changed.emit()
		return false
	collection.featured[str(donation.group)] = key
	_museum_note("常设展更新","%s已摆进%s展柜。"%[str(_museum_entry(key).get("name",key)),str(donation.group)])
	changed.emit()
	return true

func museum_badge(badge_id: String) -> bool:
	_museum_sync()
	var progress := museum_progress()
	var needed := int(progress.seen) >= 15 if badge_id == "observer" else int(progress.researched) >= 10 if badge_id == "researcher" else false
	if not needed or collection.get("badges", []).has(badge_id):
		message = "记录尚不足，或这枚纪念章已经收好。"
		changed.emit()
		return false
	collection.badges.append(badge_id)
	message = "获得“%s”纪念章。" % ("禾溪观察者" if badge_id == "observer" else "四时研习者")
	changed.emit()
	return true

func observe_wildlife(wildlife_id: String) -> bool:
	var definition: Dictionary = {}
	for candidate in system_catalog.get("museum", {}).get("wildlife", []):
		if str(candidate.get("id", "")) == wildlife_id: definition = candidate
	if definition.is_empty() or minutes < 420 or minutes >= 1080 or int(weather_profile().get("rain", 0)) > 0 or bool(weather_profile().get("extreme", false)) or wildlife_id == "butterfly" and season_index() >= 2 or player_position.distance_to(Vector2(float(definition.get("x", 0)), float(definition.get("y", 0)))) > 75.0:
		message = "请在合适天气走近观察点，保持一点距离。"
		changed.emit()
		return false
	var observations: Dictionary = collection.get("observations", {})
	var days: Array = observations.get(wildlife_id, [])
	if days.size() >= 2:
		message = "这份观察已研究完成，仍可在田边看它活动。"
		changed.emit()
		return false
	if days.has(day):
		message = "今天已经留下观察记录，改天再来看看它的新习惯。"
		changed.emit()
		return false
	days.append(day)
	observations[wildlife_id] = days
	collection.observations = observations
	_museum_record("wild:" + wildlife_id, false, days.size() >= 2)
	message = "%s的活动记入图鉴。%s" % [str(definition.get("name", wildlife_id)), str(definition.get("text", ""))]
	changed.emit()
	return true

func share_life(activity: String, dish_id: String = "") -> bool:
	var spouse := str(marriage.get("spouse", ""))
	if spouse == "":
		message = "有共同生活的伴侣后再来安排。"
		changed.emit()
		return false
	if activity not in ["meal", "visit", "objects", "plan"]:
		message = "请选择一种共同安排。"
		changed.emit()
		return false
	var weekly: Dictionary = marriage.get("weekly", {})
	var key := "%d-%s" % [int(day / 7), activity]
	if bool(weekly.get(key, false)):
		message = "这一周已经安排过了，留点时间做自己的事吧。"
		changed.emit()
		return false
	if activity == "meal":
		if str(item_catalog.get(dish_id, {}).get("kind", "")) != "料理" or int(inventory.get(dish_id, 0)) < 1 or economy.get("locked",[]).has(dish_id):
			message = "共餐需要一道料理。"
			changed.emit()
			return false
		_reconcile_kitchen_lots()
		_consume_item(dish_id, 1)
		_reconcile_kitchen_lots()
	weekly[key] = true
	var memories: Array = marriage.get("memories", [])
	memories.append({"day": day, "activity": activity})
	marriage.weekly = weekly
	marriage.memories = memories.slice(maxi(0, memories.size() - 80))
	var relation: Dictionary = relations.get(spouse, {"points": 0})
	relation.points = mini(100, int(relation.get("points", 0)) + 5)
	relations[spouse] = relation
	var lines := {"meal": "你们坐下来共餐，轮流讲今天的见闻。", "visit": "各自安排好工作，和伴侣一起去看望亲友。", "objects": "旧柜里的物件被擦拭干净，你们添上一张属于现在的便条。", "plan": "你们写下各自来年的愿望，也留下愿意一起做的事。"}
	message = str(lines[activity])
	_record_community_log(message)
	changed.emit()
	return true

func host_meal_location_allowed() -> bool:
	var region := str(interior_house().get("region", "")) if current_interior != "" else atlas_region_id(player_position)
	# The browser village maps pasture to its farm scene, including interiors.
	return region in ["farm", "pasture"]

func host_meal(npc_id: String, dish_id: String) -> bool:
	if not bool(upgrades.get("room", false)):
		message = "先整理厢房，摆好共餐桌。"
	elif not host_meal_location_allowed():
		message = "先回到小院，再安排家宴。"
	elif not relations.has(npc_id) or npc_name(npc_id) == npc_id:
		message = "先选一位邻居。"
	else:
		var event_key := "meal-%d-%s" % [int(day / 7), npc_id]
		if bool(season_events.get(event_key, false)):
			message = "这周已经邀请过对方，下周再约。"
		elif str(item_catalog.get(dish_id, {}).get("kind", "")) != "料理" or int(inventory.get(dish_id, 0)) < 1 or economy.get("locked",[]).has(dish_id):
			message = "需要备好一道料理。"
		else:
			var person: Dictionary = {}
			for candidate in npc_catalog:
				if str(candidate.get("id", "")) == npc_id: person = candidate; break
			_reconcile_kitchen_lots()
			_consume_item(dish_id, 1)
			_reconcile_kitchen_lots()
			season_events[event_key] = true
			var relation: Dictionary = relations[npc_id]
			relation.points = mini(100, int(relation.get("points", 0)) + 10 + (3 if str(skills.get("cooking", {}).get("choice", "")) == "host" else 0))
			relations[npc_id] = relation
			_award_skill_xp("social", 3)
			for recipe in content.get("recipes", []):
				if str(recipe.get("source", "")) == npc_id and not known_recipes.has(str(recipe.get("id", ""))):
					known_recipes.append(str(recipe.get("id", "")))
					_record_community_log("学会了 %s。" % str(item_catalog.get(str(recipe.get("id", "")), {}).get("name", "")))
			var event_text := "请%s来小院吃%s，聊了聊%s的日常。" % [str(person.get("name", npc_id)), str(item_catalog.get(dish_id, {}).get("name", dish_id)), str(person.get("role", "生活"))]
			_record_community_log(event_text)
			message = "对方说起近来的工作，也认真听你讲菜地里的新变化。下周再约。"
			changed.emit()
			return true
	changed.emit()
	return false

func _normalize_neighbors(saved: Dictionary = {}) -> void:
	var ids: Array[String] = []
	for person in npc_catalog:
		ids.append(str(person.get("id", "")))
	var saved_people: Variant = saved.get("people", {})
	var people: Dictionary = saved_people if saved_people is Dictionary else {}
	var normalized: Dictionary = {}
	for npc_id in ids:
		var saved_resident: Variant = people.get(npc_id, {})
		var resident: Dictionary = saved_resident if saved_resident is Dictionary else {}
		var saved_recent: Variant = resident.get("recent", [])
		var recent: Array = saved_recent if saved_recent is Array else []
		var clean_recent: Array = []
		for key in recent:
			if preload("res://scripts/js_string.gd").is_string(key) and preload("res://scripts/js_string.gd").length(key) <= 100:
				clean_recent.append(key)
		var saved_last: Variant = resident.get("last", {})
		var saved_event: Variant = resident.get("event", {})
		var clean_event: Dictionary = {}
		if saved_event is Dictionary and not saved_event.is_empty():
			var raw_event_day: Variant = saved_event.get("day", -1)
			var event_day := int(raw_event_day) if preload("res://scripts/source_save_validation.gd").number(raw_event_day,-1000000,1000000) else -1
			var event_status := str(saved_event.get("status", ""))
			var event_method: Variant = saved_event.get("method", null)
			var completed_day: Variant = saved_event.get("completed", null)
			var event_valid := event_day >= 0 and event_day <= day and event_status in ["offered", "accepted", "postponed", "done"]
			if event_status == "done":
				var completed_is_integer := completed_day is int or completed_day is float and is_equal_approx(float(completed_day), roundf(float(completed_day)))
				event_valid = event_valid and event_method in ["join", "supply"] and completed_is_integer and int(completed_day) >= event_day and int(completed_day) <= day
			else:
				event_valid = event_valid and event_method == null and completed_day == null
			if event_valid:
				clean_event = {"day": event_day, "status": event_status, "method": event_method, "completed": completed_day}
		normalized[npc_id] = {
			"introduced": bool(resident.get("introduced", false)),
			"recent": clean_recent.slice(maxi(0, clean_recent.size() - 12)),
			"last": saved_last.duplicate(true) if saved_last is Dictionary else {},
			"event": clean_event
		}
	var saved_history: Variant = saved.get("history", [])
	var history: Array = saved_history if saved_history is Array else []
	var clean_history: Array[Dictionary] = []
	for row in history:
		if row is Dictionary and ids.has(str(row.get("id", ""))) and preload("res://scripts/js_string.gd").is_string(row.get("text")) and preload("res://scripts/js_string.gd").length(row.text) <= 2200 and preload("res://scripts/js_string.gd").is_string(row.get("key")) and preload("res://scripts/js_string.gd").length(row.key) <= 100:
			var record: Dictionary = row.duplicate(true)
			if not preload("res://scripts/source_save_validation.gd").number(record.get("day",0),-1000000,1000000) or not preload("res://scripts/source_save_validation.gd").number(record.get("minute",390),-1000000,1000000): continue
			record["day"] = clampi(int(record.get("day", 0)), 0, day)
			record["minute"] = clampf(float(record.get("minute", 390)), 0.0, 1320.0)
			clean_history.append(record)
		if clean_history.size() >= 160:
			break
	var raw_neighbor_day: Variant = saved.get("day", -1)
	var neighbor_day := int(raw_neighbor_day) if preload("res://scripts/source_save_validation.gd").number(raw_neighbor_day,-1000000,1000000) else -1
	neighbors = {"version": 1, "day": clampi(neighbor_day, -1, day), "people": normalized, "history": clean_history}
	ensure_neighbor_events()

func ensure_neighbor_events() -> void:
	if neighbors.is_empty():
		_normalize_neighbors()
	preload("res://scripts/social_lifecycle.gd").ensure_events(neighbors,npc_catalog,day)

func npc_is_near(npc_id: String) -> bool:
	if current_interior != "":
		var indoor_position: Variant = interior_npc_positions.get(npc_id, null)
		return indoor_position is Vector2 and interior_position.distance_to(indoor_position) <= 80.0
	var position: Variant = npc_positions.get(npc_id, null)
	return position is Vector2 and player_position.distance_to(position) <= 80.0

func resolve_npc_event(npc_id: String, operation: String, event_day: int) -> bool:
	ensure_neighbor_events()
	if not npc_is_near(npc_id):
		message = "请先走到这位邻居身边。"
		changed.emit()
		return false
	var resident: Dictionary = neighbors.people.get(npc_id, {})
	var event: Dictionary = resident.get("event", {})
	if event.is_empty() or int(event.get("day", -1)) != event_day or str(event.get("status", "")) == "done":
		message = "这件小事的状态已经变化，重新看看近况吧。"
		changed.emit()
		return false
	var profile: Dictionary = system_catalog.get("npc", {}).get("profiles", {}).get(npc_id, {})
	var item_id := str(profile.get("item", ""))
	var item_name := str(item_catalog.get(item_id, {}).get("name", item_id))
	var request := str(profile.get("request", "整理手边的小事"))
	var choice := ""
	match operation:
		"accept":
			if str(event.get("status", "")) == "accepted":
				message = "已经记下这份约定。"
				changed.emit()
				return false
			event.status = "accepted"
			choice = "答应帮忙，材料或共同劳动均可"
			message = "好呀，%s就等咱们有空来做。没有截止日期。" % request
		"later":
			if str(event.get("status", "")) == "postponed":
				message = "已经约好以后再说。"
				changed.emit()
				return false
			event.status = "postponed"
			choice = "说明改天再来，不扣关系"
			message = "你先忙自己的，哪天顺路再说。"
		"supply", "join":
			if str(event.get("status", "")) != "accepted":
				message = "先把愿意怎么帮忙说清楚，再一起动手。"
				changed.emit()
				return false
			if operation == "supply":
				if int(inventory.get(item_id, 0)) < 2:
					message = "还需要 %s ×2，也可以选择一起劳动。" % item_name
					changed.emit()
					return false
			else:
				if not spend_energy(3, 20):
					message="先歇歇，再来一起做这件小事。"
					changed.emit()
					return false
			if operation == "supply":
				_consume_item(item_id, 2)
			event.status = "done"
			event.method = operation
			event.completed = day
			if not relations.has(npc_id):
				relations[npc_id] = {"points": 0, "talked": -1, "gifted": -1, "returnGift": false}
			var relation: Dictionary = relations[npc_id]
			relation.points = mini(100, int(relation.get("points", 0)) + 6)
			relations[npc_id] = relation
			choice = "一起动手 · 20 分钟 / 3 体力" if operation == "join" else "送来 %s ×2" % item_name
			message = "“%s”完成了。%s〔关系 +6〕" % [request, "两个人分着做，原来零碎的活也轻快起来。" if operation == "join" else "材料整齐放好，对方可以接着完成手边的活。"]
		_: 
			message = "请选择一种回应。"
			changed.emit()
			return false
	resident.event = event
	neighbors.people[npc_id] = resident
	_remember_npc_dialogue(npc_id, "event-%d-%s" % [event_day, operation], message, "邻里小事", "calm" if operation == "later" else "happy", choice)
	_record_legacy_event(npc_name(npc_id)+"："+message)
	changed.emit()
	return true

func gift_npc(npc_id: String, item_id: String) -> bool:
	ensure_neighbor_events()
	if not npc_is_near(npc_id):
		message="先走近对方，再把心意交到手中。"
		changed.emit()
		return false
	var person: Dictionary = {}
	for candidate in npc_catalog:
		if str(candidate.get("id", "")) == npc_id:
			person = candidate
			break
	if person.is_empty() or not item_catalog.has(item_id) or int(inventory.get(item_id, 0)) < 1:
		message = "背包里没有这份礼物。"
		changed.emit()
		return false
	if not npc_is_near(npc_id):
		message = "先走近对方，再把心意交到手中。"
		changed.emit()
		return false
	if not relations.has(npc_id):
		relations[npc_id] = {"points": 0, "talked": -1, "gifted": -1, "returnGift": false}
	var relation: Dictionary = relations[npc_id]
	if int(relation.get("gifted", -1)) == day:
		message = "今天的心意已经收到啦，留一点给自己吧。"
		changed.emit()
		return false
	var consumed := _consume_item(item_id, 1)
	if consumed.is_empty():
		message = "背包里没有这份礼物。"
		changed.emit()
		return false
	var liked_items: Array = person.get("likes", [])
	var liked := liked_items.has(item_id)
	var item: Dictionary = item_catalog.get(item_id, {})
	var gain := 15 if liked else 10 if str(item.get("kind", "")) == "料理" else 5
	var before_points:=int(relation.points)
	relation.points=mini(100,before_points+gain)
	if str(last_gifts.get(npc_id,""))==item_id:
		relation.points=before_points+ceili(float(int(relation.points)-before_points)/2.0)
	_award_skill_xp("social", 3)
	relation.gifted = day
	if int(person.get("birthday", -1)) == posmod(day, 112) + 1:
		relation.points = mini(100, int(relation.points) + 3)
	relations[npc_id] = relation
	last_gifts[npc_id] = item_id
	player_journal.append({"day":day,"text":"把"+str(item.get("name",item_id))+"送给了"+str(person.name)+"。"})
	while player_journal.size()>200:player_journal.pop_front()
	_reconcile_kitchen_lots()
	player_stats.gifts = int(player_stats.get("gifts", 0)) + 1
	message = "“正是我喜欢的味道，谢谢你想着我。” 关系 +%d" % gain if liked else "“谢谢你，改天来家里吃饭。” 关系 +%d" % gain
	message += " 换着聊天、合作、送菜，会有更多新的回应。"
	_remember_npc_dialogue(npc_id, "gift-%d" % day, "你送来了%s。%s" % [str(item.get("name", item_id)), message], "回忆", "happy", "送上 %s" % str(item.get("name", item_id)))
	_museum_sync()
	changed.emit()
	return true

func _remember_npc_dialogue(npc_id: String, key: String, text: String, category: String, emotion: String, choice: String = "") -> void:
	var resident: Dictionary = neighbors.people.get(npc_id, {})
	var record := {"id": npc_id, "key": key, "day": day, "minute": minutes, "text": text, "category": category, "emotion": emotion, "choice": choice}
	resident.last = record
	var recent: Array = resident.get("recent", [])
	recent.erase(key)
	recent.append(key)
	while recent.size() > 12:
		recent.pop_front()
	resident.recent = recent
	neighbors.people[npc_id] = resident
	var history: Array = neighbors.get("history", [])
	var duplicate := false
	for previous in history:
		if str(previous.get("id", "")) == npc_id and int(previous.get("day", -1)) == day and str(previous.get("key", "")) == key and str(previous.get("choice", "")) == choice:
			duplicate = true
			break
	if not duplicate:
		history.append(record)
	while history.size() > 160:
		history.pop_front()
	neighbors.history = history

func npc_history(npc_id: String) -> Array:
	var result: Array = []
	for record in neighbors.get("history", []):
		if str(record.get("id", "")) == npc_id:
			result.append(record)
	return result

func gathered_today(node_id: String) -> bool:
	return int(gathered.get(node_id, -1)) == day

func forage_status(node_id: String, item_id: String, event: String = "") -> Dictionary:
	var definition: Dictionary = system_catalog.get("forage", {}).get("defs", {}).get(item_id, {})
	var point := {"id": node_id, "item": item_id, "event": event}
	var axe:=tool_data("axe")
	var tool_bonus:=1 if item_id in ["wood","bamboo"] and int(axe.get("level",0))==2 and str(axe.get("branch","broad"))=="broad" else 0
	return FORAGE_RULES.status(point, definition, forage, day, season_index(), weather_for(day), weather_for(maxi(0, day - 1)), gathered_today(node_id), tool_bonus)

func forage_description(node_id: String, item_id: String, event: String = "") -> String:
	var definition: Dictionary = system_catalog.get("forage", {}).get("defs", {}).get(item_id, {})
	return FORAGE_RULES.describe({"id": node_id, "item": item_id, "event": event}, definition, forage_status(node_id, item_id, event))

func discover_forage(node_id: String) -> void:
	var discovered: Array = forage.get("discovered", [])
	if not discovered.has(node_id):
		discovered.append(node_id)
		forage.discovered = discovered

func register_forage_point(point: Dictionary) -> void:
	forage_points.append(point)

func toggle_forage_mode() -> void:
	forage.mode = "full" if str(forage.get("mode", "gentle")) == "gentle" else "gentle"
	message = "采集方式：%s。" % ("多采（多一份，恢复更久）" if forage.mode == "full" else "轻采（留根留种）")
	changed.emit()

func care_forage(node_id: String, item_id: String, event: String = "") -> bool:
	var success := false
	var patches: Dictionary = forage.get("patches", {})
	var patch: Dictionary = patches.get(node_id, {})
	var state := forage_status(node_id, item_id, event)
	if patch.is_empty() or int(state.wait) <= 1:
		message = "这里即将恢复，不必再覆土。"
	elif int(patch.get("lastCare", -1)) == day:
		message = "今天已经覆土照料过，给根系一点时间。"
	elif int(inventory.get("compost", 0)) < 1:
		message = "带一份熟堆肥，轻轻覆在根边。"
	elif spend_energy(2, 8):
		success = true
		_consume_item("compost", 1)
		patch.readyDay = maxi(day + 1, int(patch.readyDay) - 1)
		patch.pressure = maxi(0, int(state.pressure) - 2)
		patch.lastCare = day
		patches[node_id] = patch
		forage.patches = patches
		message = "薄薄覆土护根，这处提前一天恢复。"
	changed.emit()
	return success

func gather_node(node_id: String, item_id: String, event: String = "") -> bool:
	if not inventory.has(item_id):
		message = "这个采集物不在物品目录里。"
		changed.emit()
		return false
	var definition: Dictionary = system_catalog.get("forage", {}).get("defs", {}).get(item_id, {})
	if definition.is_empty():
		message = "这处资源还没有采集规则。"
		changed.emit()
		return false
	discover_forage(node_id)
	var state := forage_status(node_id, item_id, event)
	if not bool(state.ready):
		message = forage_description(node_id, item_id, event) + "，先让这一处歇一歇。"
		changed.emit()
		return false
	var energy_cost := maxi(1, (4 if str(forage.mode) == "full" else 3) - (1 if int(forage.xp) >= 20 else 0))
	var tool_id := "axe" if item_id in ["wood", "bamboo"] else "sickle"
	var tool := tool_data(tool_id)
	var minutes_cost := 5 if tool_id == "axe" and int(tool.get("level", 0)) >= 2 and str(tool.get("branch", "broad")) == "care" else 10
	if not spend_energy(energy_cost, minutes_cost, "gather"):
		return false
	gathered[node_id] = day
	var amount := int(state.quantity)
	var region_id := atlas_region_id(player_position)
	if region_id == "": region_id = "unknown"
	var pressure_map: Dictionary = legacy_systems.get("resourcePressure", {})
	var regional_pressure: Dictionary = pressure_map.get(region_id, {"day": day, "count": 0})
	if int(regional_pressure.get("day", -1)) != day: regional_pressure = {"day": day, "count": 0}
	regional_pressure.count = int(regional_pressure.get("count", 0)) + 1
	var conservation_limit := item_id not in ["wood", "bamboo"] and int(regional_pressure.count) > 3
	if conservation_limit: amount = maxi(0, amount - 1)
	pressure_map[region_id] = regional_pressure
	legacy_systems.resourcePressure = pressure_map
	_award_tool(tool_id)
	_add_inventory_count(item_id, amount)
	player_stats.gathered = int(player_stats.get("gathered", 0)) + amount
	if int(state.grade) > 0:
		var ledger: Array = quality.get(item_id, [0, 0, 0])
		ledger[0] = int(ledger[0]) + amount
		quality[item_id] = ledger
	var patches: Dictionary = forage.get("patches", {})
	patches[node_id] = {"lastDay": day, "readyDay": day + int(state.days), "pressure": mini(8, int(state.pressure) + (3 if forage.mode == "full" else 1))}
	forage.patches = patches
	forage.xp = mini(1000000, int(forage.xp) + 1)
	if item_id != "wildHerb":
		_award_skill_xp("craft", 1)
	var finds: Array = forage.get("finds", [])
	finds.append({"id": node_id, "item": item_id, "day": day, "qty": amount, "grade": int(state.grade), "weather": weather_for(day)})
	while finds.size() > 14:
		finds.pop_front()
	forage.finds = finds
	_museum_sync()
	message = "收下%s ×%d。%s。%d 天后再生。%s" % [item_catalog.get(item_id, {}).get("name", item_id), amount, "多取一份，这处多休养两天" if forage.mode == "full" else str(definition.get("method", "留根留种")), int(state.days), "顺着天气，多了一份收获。" if int(state.bonus) > 0 else ""]
	if conservation_limit: message += " 这一片今天采得多了，少取一份，明天会恢复。"
	changed.emit()
	return true

func fishing_plan(water_id: String) -> Dictionary:
	return preload("res://scripts/fishing_service.gd").plan(self,water_id)

func fishing_has_bait(bait_id: String) -> bool:
	return preload("res://scripts/fishing_service.gd").has_bait(self,bait_id)

func set_fishing_option(key: String, value: Variant) -> void:
	if fishing_active():return
	if key=="mode" and str(value) in ["relaxed","standard"]:fishing.mode=str(value);player_settings.fishAssist=str(value)=="relaxed"
	elif key=="bait" and system_catalog.fishing.baits.has(str(value)):fishing.bait=str(value)
	elif key=="inputStyle" and str(value) in ["hold","toggle"]:fishing.inputStyle=str(value)
	elif key=="depth":fishing.depth=clampi(int(value),0,2)
	changed.emit()

func fishing_active() -> bool:return not fishing_session.game.is_empty()
func fishing_snapshot() -> Dictionary:return fishing_session.snapshot()
func fishing_phase() -> String:return fishing_session.phase()
func fishing_input(command: String) -> void:
	fishing_session.command(command)
	fishing_session_changed.emit(fishing_snapshot())
func toggle_fishing_reel() -> void:fishing_input("toggle")
func fishing_resolve(released: bool) -> bool:return preload("res://scripts/fishing_service.gd").resolve(self,released)
func fishing_craft(id: String) -> bool:return preload("res://scripts/fishing_service.gd").craft(self,id)
func fishing_equip(id: String) -> bool:return preload("res://scripts/fishing_service.gd").equip(self,id)
func queue_fishing_tasks(tasks: Array) -> bool:return preload("res://scripts/fishing_service.gd").queue(self,tasks)
func finish_fishing_task(target: Dictionary) -> void:preload("res://scripts/fishing_service.gd").finish_task(self,target)

func begin_fishing(spot_id: String) -> bool:
	if action_busy() or fishing_active():return false
	if not fishing.get("pending",{}).is_empty():message="先决定上一尾鱼留下还是放流。";changed.emit();return false
	var point: Dictionary={}
	for candidate: Dictionary in system_catalog.fishing.spots:
		if str(candidate.id)==spot_id:point=candidate.duplicate(true);break
	if current_interior!="" or point.is_empty() or player_position.distance_to(Vector2(float(point.x),float(point.y)))>75:
		message="先沿路走到这处水岸。";changed.emit();return false
	var plan:=fishing_plan(str(point.water))
	if plan.is_empty():message="这个时段没有适合垂钓的鱼，翻翻水畔手记吧。";changed.emit();return false
	if not fishing_has_bait(str(plan.bait)) or stamina<fishing_energy_cost():message="鱼饵或体力不足，可先换免费素饵或休息。";changed.emit();return false
	if preload("res://scripts/fishing_rules.gd").hotspot(system_catalog.fishing,day)==spot_id:plan.wait=float(plan.wait)*0.65
	fishing_session.start(plan,point)
	var spec: Dictionary={"kind":"fish","label":"蓄力 · 等漂 · 追踪鱼影","duration":45.0,"waterX":point.waterX,"waterY":point.waterY,"item":plan.fish}
	if not begin_action(spec,point,_finish_fishing_session,_cancel_fishing_session):_cancel_fishing_session();return false
	set_player_direction_from_vector(Vector2(float(point.waterX),float(point.waterY))-player_position)
	fishing_session_changed.emit(fishing_snapshot());return true

func _cancel_fishing_session() -> void:
	if fishing_active() and bool(fishing_session.game.get("paid",false)):
		fishing.settled=maxi(int(fishing.get("settled",0)),int(fishing_session.game.plan.id))
	fishing_session.cancel();fishing_session_changed.emit({})

func _finish_fishing_session() -> void:
	var game:=fishing_snapshot()
	preload("res://scripts/fishing_service.gd").finish(self,game)
	_cancel_fishing_session()

func finish_fishing(plan: Dictionary, caught: bool, safe_time: float, total_time: float, reason: String="") -> bool:
	# Compatibility facade: only a committed current session may settle.
	if int(plan.get("id",0))<=int(fishing.get("settled",0)) or int(plan.get("id",0))>=int(fishing.get("nextId",1)):return false
	preload("res://scripts/fishing_service.gd").finish(self,{"plan":plan,"paid":true,"caught":caught,"safe":safe_time,"total":total_time,"reason":reason})
	return true

func season_name() -> String:
	return str(content.get("seasons", ["春", "夏", "秋", "冬"])[season_index()])

func date_text() -> String:
	var day_of_year := day % 112
	return "第 %d 年 · %s %d 日" % [int(day / 112) + 1, season_name(), day_of_year % 28 + 1]

func time_text() -> String:
	return "%02d:%02d" % [int(minutes / 60), int(minutes) % 60]

func player_direction_vector() -> Vector2:
	return {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(player_direction, Vector2.DOWN)

func set_player_direction_from_vector(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	player_direction = "right" if absf(direction.x) > absf(direction.y) and direction.x > 0.0 else "left" if absf(direction.x) > absf(direction.y) else "down" if direction.y > 0.0 else "up"

func spend_energy(amount: float, minutes_cost: float = 8.0, labor_tool: String = "", notify_failure: bool = true) -> bool:
	var reduction := (1 if str(skills.get("farming", {}).get("choice", "")) == "gentle" else 0) + (1 if kitchen_active_buff() in ["暖胃", "饱足"] else 0) + (1 if int(legacy_systems.get("buffs", {}).get("laborDay", -1)) == day else 0) + (1 if labor_tool != "" and bool(legacy_systems.get("toolUpgrades", {}).get(labor_tool, false)) else 0)
	var actual_cost := maxf(1.0, amount - reduction)
	if stamina < actual_cost:
		if notify_failure:
			message = "有点累了，回屋休息或到自己的床边睡到明天吧。"
			changed.emit()
		return false
	stamina -= actual_cost
	minutes = minf(1320.0, minutes + minutes_cost)
	return true

func advance_day() -> void:
	fishing["queue"]=[]
	var previous_minutes := minutes
	var buildings_before: Array = building.get("jobs", []).duplicate(true)
	_remember_weather()
	_advance_kitchen(day)
	day += 1
	_advance_legacy_processing(day - 1)
	ensure_neighbor_events()
	minutes = 390
	_reset_npc_morning()
	ranch_actor_focus.clear()
	_bedtime_prompted = false
	stamina = 100
	riding = false
	cancel_farm_queue()
	cancel_ranch_queue()
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	building_task.clear()
	walking_target.clear()
	interior_npc_positions.clear()
	cancel_action()

	_refresh_economy_day()
	preload("res://scripts/fishing_service.gd").advance(self,day)
	_advance_farm(day - 1)
	_advance_ranch(day - 1, weather_for(day - 1), previous_minutes)
	_advance_letters()
	if day % 112 == 0:
		flags.yearReview = true
		year_review_pending = true
		_record_community_log("走过完整四季，来年继续过自己的日子。")
	_advance_building(day - 1)
	_remember_weather()
	for job in buildings_before:
		var still_running := false
		for active_job in building.get("jobs", []):
			if str(active_job.get("id", "")) == str(job.get("id", "")) and int(active_job.get("level", 0)) == int(job.get("level", 0)):
				still_running = true
				break
		if not still_running:
			var project: Dictionary = system_catalog.get("building", {}).get("projects", {}).get(str(job.get("id", "")), {})
			_feedback_note({"key": "building/" + str(job.get("id", "")) + "/" + str(job.get("level", 0)), "title": "修缮工程竣工", "text": "%s第 %d 阶已完成。" % [str(project.get("name", "工程")), int(job.get("level", 0))], "priority": 1, "link": "build"})
	message = "早安，%s。今天%s。%s" % [player_name, str(weather_profile().kind), str(weather_profile().tip)]
	_feedback_snapshot = _feedback_snapshot_state()
	changed.emit()
	save_game(SAVE_PATH,true)
	if year_review_pending:year_review_requested.emit()

func _sync_legacy_plot_view(plot: Dictionary) -> void:
	plot.soil = float(plot.fertility) / 50.0
	plot.watered = float(plot.moisture) >= 35.0
	plot.pest = float(plot.pests) >= 15.0 or float(plot.disease) >= 15.0

func _advance_farm(previous_day: int) -> void:
	var yesterday := weather_profile(previous_day)
	var weather := str(yesterday.kind)
	var rain := weather in ["雨", "台风"]
	var previous_season := int(posmod(previous_day, 112) / 28)
	var auto_water := bool(upgrades.get("irrigation", false)) and (weather not in ["高温", "台风"] or int(legacy_systems.get("waterReserve", 0)) > 0)
	if auto_water and weather in ["高温", "台风"]:
		legacy_systems.waterReserve = maxi(0, int(legacy_systems.get("waterReserve", 0)) - 1)
	var soils: Dictionary = system_catalog.get("farming", {}).get("soils", {})
	var prior: Array = []
	for plot in plots: prior.append({"pests": plot.pests, "disease": plot.disease})
	var canal_help := bool(community_projects.get("canal", false)) and day % 7 == 0 and npc_catalog.any(func(npc): return int(relations.get(str(npc.id), {}).get("points", 0)) >= 30)
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		if not bool(plot.tilled) or bool(plot.get("removed", false)):
			plot.fertility = clampf(float(plot.fertility) + 1.0, 0.0, 100.0)
			_sync_legacy_plot_view(plot)
			continue
		var shade := farm_facility_coverage(i, "shade")
		var greenhouse := farm_facility_coverage(i, "greenhouse")
		var soil: Dictionary = soils.get(str(plot.soil_type), {})
		plot.moisture = clampf(float(plot.moisture) + float(yesterday.rain) - float(soil.get("evap",15)) * float(yesterday.evaporation) * (0.65 if shade else 1.0), 0.0, 100.0)
		if farm_facility_coverage(i, "drain") and float(plot.moisture) > 80.0: plot.moisture = 75.0
		var water_profile := crop_profile(str(plot.crop)) if str(plot.crop) != "" else {"low":35,"high":85}
		var water_target := minf(float(water_profile.high)-5.0,maxf(65.0,float(water_profile.low)+20.0))
		if auto_water and str(plot.crop) != "": plot.moisture = maxf(float(plot.moisture),water_target)
		if str(plot.crop) != "" and farm_facility_coverage(i, "sprinkler") and float(plot.moisture) < maxf(float(farm.get("threshold",40)),float(water_profile.low)) and int(farm.get("water",0)) > 0:
			farm.water = int(farm.water) - 1
			plot.moisture = water_target
			plot.irrigated = day
		if canal_help: plot.moisture = maxf(55.0,float(plot.moisture))
		if int(plot.slow) > 0:
			plot.fertility = clampf(float(plot.fertility)+5.0,0.0,100.0)
			plot.slow = int(plot.slow)-1
		if str(plot.crop) == "":
			plot.fertility = clampf(float(plot.fertility)+(9.0 if bool(plot.fallow) else 3.0),0.0,100.0)
			plot.compacted = clampf(float(plot.compacted)-3.0,0.0,100.0)
			plot.pests = clampf(float(plot.pests)-8.0,0.0,100.0)
			plot.disease = clampf(float(plot.disease)-8.0,0.0,100.0)
			if bool(plot.fallow):
				plot.repeats = maxi(0,int(plot.repeats)-1)
				plot.weeds = 0.0
			_sync_legacy_plot_view(plot)
			continue
		var crop_id := str(plot.crop)
		var crop := crop_data(crop_id)
		var profile := crop_profile(crop_id)
		var relation := crop_relation(i)
		var dry := float(plot.moisture) < float(profile.low)
		var wet := float(plot.moisture) > float(profile.high)
		var off: bool = not crop.get("seasons",[]).any(func(value): return int(value) == previous_season) and not greenhouse
		var cold := weather == "寒潮" and not greenhouse
		var heat := weather == "高温" and not shade
		var same_species := 0
		for neighbor in farm_neighbor_indices(i):
			if str(plots[neighbor].crop) == crop_id: same_species += 1
		var kind: Dictionary = system_catalog.get("farming",{}).get("kinds",{}).get(str(plot.seed_kind),{})
		var risk := clampf(2.0+float(plot.repeats)*2.0+same_species*2.0+(7.0 if str(plot.density)=="dense" else 0.0)+(9.0 if wet else 0.0)+(5.0 if heat else 0.0)+(5.0 if float(plot.fertility)<30.0 else 0.0)-float(kind.get("resist",0))-(4.0 if relation>0 else 0.0),0.0,35.0)
		var roll := ((previous_day+1)*1103515245+(i+17)*12345)&0xffffffff
		if previous_day>6 and roll%100<risk: plot.pests=clampf(float(plot.pests)+14.0,0.0,100.0)
		if previous_day>6 and wet and (roll>>8)%100<risk: plot.disease=clampf(float(plot.disease)+12.0,0.0,100.0)
		if wet or str(plot.density)=="dense":
			for neighbor in farm_neighbor_indices(i):
				if float(prior[neighbor].pests)>=60.0: plot.pests=clampf(float(plot.pests)+2.0,0.0,100.0)
				if float(prior[neighbor].disease)>=60.0: plot.disease=clampf(float(plot.disease)+2.0,0.0,100.0)
		plot.weeds=clampf(float(plot.weeds)+(5.0 if rain else 2.0),0.0,100.0)
		plot.compacted=clampf(float(plot.compacted)+(3.0 if wet else 1.0),0.0,100.0)
		var pressure := (12.0 if dry or wet else 0.0)+(7.0 if cold or heat or off else 0.0)+(float(plot.pests)+float(plot.disease))*0.12+(5.0 if float(plot.weeds)>60.0 else 0.0)
		plot.health=clampf(float(plot.health)+(-minf(15.0,pressure-8.0) if pressure>12.0 else 8.0),10.0,100.0)
		plot.stress=mini(999,int(plot.get("stress",0))+1) if pressure>12.0 else 0
		var condition:=clampf(100.0-(28.0 if dry or wet else 0.0)-(15.0 if off or cold or heat else 0.0)-(float(plot.pests)+float(plot.disease))*0.25-(20.0 if float(plot.fertility)<40.0 else 0.0)-(10.0 if float(plot.weeds)>40.0 else 0.0)+(3.0 if relation>0 else 0.0),0.0,100.0)
		plot.condition=(float(plot.condition)*float(plot.ticks)+condition)/(float(plot.ticks)+1.0)
		plot.ticks=mini(100000,int(plot.ticks)+1)
		var rate:float=(0.55 if dry or wet else 1.0)*(0.65 if off else 1.0)*(0.7 if cold else 1.0)*(0.25 if float(plot.health)<22.0 else 1.0)*(1.0-(float(plot.pests)+float(plot.disease))/400.0)*float(kind.get("rate",1))
		rate*=1.08 if str(plot.soil_type)==str(profile.preferred) else 1.0
		rate*=0.94 if str(plot.density)=="dense" else 1.05 if str(plot.density)=="sparse" else 1.0
		rate*=1.05 if relation>0 else 0.95 if relation<0 else 1.0
		if float(plot.compacted)>55.0: rate*=0.85
		if float(plot.fertility)<25.0: rate*=0.85
		if farm_facility_coverage(i,"trellis") and bool(profile.climber): rate*=1.15
		if farm_facility_coverage(i,"trellis") and str(crop.get("group",""))=="叶菜" and heat: rate*=1.1
		if shade and weather=="晴": rate*=0.95
		var growth_days:=float(crop_days(crop_id))
		if i>=FARM_LAYOUT.MAIN_COUNT and not farm_facility_coverage(i,"fence") and previous_day%17==i%17 and float(plot.growth)<growth_days*0.5: plot.health=clampf(float(plot.health)-6.0,10.0,100.0)
		if not farm_facility_coverage(i,"scarecrow") and float(plot.growth)>=growth_days and previous_day%13==i%13: plot.penalty=clampf(float(plot.penalty)+3.0,0.0,100.0)
		if float(plot.growth)>=growth_days: plot.ripe_days=mini(100000,int(plot.ripe_days)+1)
		else:
			plot.growth=minf(growth_days,float(plot.growth)+maxf(0.08,rate))
			plot.fertility=clampf(float(plot.fertility)-float(profile.feed)*(1.25 if str(plot.density)=="dense" else 1.0),0.0,100.0)
		var companion:Dictionary=plot.get("companion",{})
		if not companion.is_empty():
			var companion_id := str(companion.crop)
			var companion_profile := crop_profile(companion_id)
			var companion_kind: Dictionary = system_catalog.get("farming",{}).get("kinds",{}).get(str(companion.get("kind","normal")),{})
			var companion_dry := float(plot.moisture) < float(companion_profile.low) or float(plot.moisture) > float(companion_profile.high)
			var companion_off: bool = not crop_data(companion_id).get("seasons",[]).any(func(value): return int(value) == previous_season) and not greenhouse
			var companion_rate := (0.55 if companion_dry else 1.0)*(0.65 if companion_off else 1.0)*(0.7 if cold else 1.0)*(0.25 if float(plot.health)<22 else 1.0)*(1.0-(float(plot.pests)+float(plot.disease))/400.0)*float(companion_kind.get("rate",1.0))*0.9
			if str(plot.soil_type) == str(companion_profile.preferred): companion_rate *= 1.08
			if farm_facility_coverage(i,"trellis") and bool(companion_profile.climber): companion_rate *= 1.15
			var companion_condition := clampf(100.0-(28.0 if companion_dry else 0.0)-(15.0 if companion_off or cold or heat else 0.0)-(float(plot.pests)+float(plot.disease))*0.25-(20.0 if float(plot.fertility)<40 else 0.0)-(10.0 if float(plot.weeds)>40 else 0.0),0.0,100.0)
			var companion_ticks := int(companion.get("ticks",0))
			companion.condition = (float(companion.get("condition",75))*companion_ticks+companion_condition)/(companion_ticks+1.0)
			companion.ticks = mini(100000,companion_ticks+1)
			if float(companion.growth) >= crop_days(companion_id): companion.ripe_days = mini(100000,int(companion.get("ripe_days",0))+1)
			else: companion.growth = minf(float(crop_days(companion_id)),float(companion.growth)+maxf(0.08,companion_rate))
		_sync_legacy_plot_view(plot)
	for facility in farm.get("facilities",[]):
		facility.durability=clampf(float(facility.durability)-(7.0 if weather=="台风" else 1.0)*(0.5 if int(facility.get("level",0))==1 else 1.0),0.0,100.0)

func _advance_ranch(previous_day: int, weather: String, previous_minutes: float = 1050.0) -> void:
	preload("res://scripts/ranch_lifecycle.gd").advance(self,previous_day,weather,previous_minutes)

func _ranch_notice(text: String) -> void:
	var notices: Array = ranch.get("notices", [])
	notices.push_front({"day": day, "text": text})
	while notices.size() > 24: notices.pop_back()
	ranch.notices = notices

func _new_game_snapshot() -> Dictionary:
	var fresh = get_script().new()
	fresh._load_content()
	fresh._load_initial_state()
	fresh.inventory = fresh._new_inventory()
	fresh.storage = fresh.initial_state.get("storage", {}).duplicate(true)
	fresh.storage_quality = fresh.initial_state.get("storageQuality", {}).duplicate(true)
	fresh.building = fresh._building_default()
	fresh._reset_plots()
	fresh._reset_animals()
	fresh._merge_legacy_animal_care()
	fresh._normalize_neighbors()
	fresh.ensure_neighbor_events()
	fresh._museum_sync()
	fresh.museum_record_region(fresh.player_position)
	fresh._remember_weather()
	var snapshot: Dictionary = fresh._make_save_data().duplicate(true)
	fresh.free()
	return snapshot

func start_new_game() -> bool:
	return _start_new_game_to_paths(SAVE_PATH, "user://zhenrizhi_godot_backup.json")

func _start_new_game_to_paths(save_path: String, backup_path: String) -> bool:
	var previous := _make_save_data().duplicate(true)
	var fresh := _new_game_snapshot()
	if not _write_json_atomically(backup_path, previous):
		message = "当前进度的备份没有写好，新生活尚未开始。"
		changed.emit()
		return false
	# Persist the replacement before changing live state. A disk failure leaves
	# the paused world and its navigation target intact.
	if not _write_json_atomically(save_path, fresh):
		message = "新生活存档写入失败，当前日子和备份仍保留。"
		changed.emit()
		return false
	if not load_game_data(fresh):
		_write_json_atomically(save_path, previous)
		message = "新生活数据无法读取，已恢复原有存档。"
		changed.emit()
		return false
	if is_instance_valid(_movement_autosave_timer): _movement_autosave_timer.stop()
	_bedtime_prompted = false
	npc_positions.clear()
	seen_world_region = ""
	message = "重新推开院门，欢迎回到禾溪村。上一段生活保存在备份，手动档仍可读取。"
	changed.emit()
	return true

func save_game(path: String = SAVE_PATH, silent: bool = false) -> bool:
	if _writing_save:
		return false
	_writing_save = true
	if path == SAVE_PATH:
		_autosave_queued = false
		if is_instance_valid(_autosave_timer): _autosave_timer.stop()
	var data := _make_save_data()
	if not _write_json_atomically(path, data):
		message = "存档写入失败，原有存档仍保留。"
		changed.emit()
		_writing_save = false
		return false
	if not silent:
		message = "已保存到本机存档。"
		changed.emit()
	_writing_save = false
	return true

func _save_path_absolute(path: String) -> String:
	return preload("res://scripts/save_repository.gd").absolute(path)

func _write_json_atomically(path: String, data: Dictionary) -> bool:
	var restored := _save_path_absolute(path) == _recovered_save_path
	var ok: bool = preload("res://scripts/save_repository.gd").write(path,data,restored)
	if ok and restored: _recovered_save_path = ""
	return ok

func _queue_autosave() -> void:
	if _writing_save: return
	if _urgent_autosave:
		_urgent_autosave = false
		_flush_autosave()
		return
	if _autosave_queued:
		return
	_autosave_queued = true
	if is_instance_valid(_autosave_timer): _autosave_timer.start()
	else: call_deferred("_flush_autosave")

func _schedule_position_autosave(_position: Vector2) -> void:
	if is_instance_valid(_movement_autosave_timer):
		_movement_autosave_timer.start()

func _flush_autosave() -> void:
	_autosave_queued = false
	save_game(SAVE_PATH,true)

func _make_save_data() -> Dictionary:
	return preload("res://scripts/native_save_snapshot.gd").capture(self)

func weather_for(target_day: int) -> String:
	return str(weather_profile(target_day).kind)

func load_game(path: String = SAVE_PATH) -> bool:
	var absolute_path := _save_path_absolute(path)
	var primary_data: Variant = _read_save_json(absolute_path)
	if primary_data is Dictionary and load_game_data(primary_data):
		_recovered_save_path = ""
		return true
	var backup_path := absolute_path + ".bak"
	var backup_data: Variant = _read_save_json(backup_path)
	if backup_data is Dictionary and load_game_data(backup_data):
		_recovered_save_path = absolute_path
		message = "主存档无法读取，已从最近一次有效存档恢复。"
		return true
	return false

func _read_save_json(path: String) -> Variant:
	return preload("res://scripts/save_repository.gd").read(path)

func load_game_data(parsed: Variant) -> bool:
	if not preload("res://scripts/native_save_schema.gd").safe_tree(parsed): return false
	if parsed is Dictionary:
		parsed = parsed.duplicate(true)
		if parsed.has("_float64_roundtrip"):
			parsed = load("res://scripts/save_json.gd").decode(parsed)
	var original_ranch_input:Dictionary={"day":parsed.get("day",0),"ranch":parsed.get("ranch"),"animals":parsed.get("animals")} if parsed is Dictionary else {}
	original_ranch_input=original_ranch_input.duplicate(true)
	var validation_error := preload("res://scripts/native_save_rules.gd").error(parsed,initial_state,world_village.get("offsets",{}))
	if not validation_error.is_empty():
		message = validation_error
		return false
	var saved_ranch: Variant = parsed.get("ranch", {})
	var saved_delivered: Variant = saved_ranch.get("delivered", []) if saved_ranch is Dictionary else []
	if not preload("res://scripts/atlas_rules.gd").truthy(saved_delivered): saved_delivered = []
	year_review_pending = false
	quest_action.clear();quest_action_serial+=1
	quests = parsed.get("quests",QUESTS.defaults()).duplicate(true)
	day = maxi(0, int(parsed.get("day", 0)))
	legacy_systems = _normalize_legacy_systems(parsed)
	player_name = str(parsed.get("player_name", parsed.get("name", "小满"))).strip_edges().left(12)
	if player_name == "": player_name = "小满"
	player_gender = str(parsed.get("player_gender", parsed.get("gender", "不设定")))
	if player_gender not in ["不设定", "女", "男"]: player_gender = "不设定"
	player_settings = parsed.get("player_settings", parsed.get("settings", {})).duplicate(true) if parsed.get("player_settings", parsed.get("settings", {})) is Dictionary else {}
	_normalize_player_settings()
	visual_fx = _normalize_visual_fx(parsed.get("visual_fx", parsed.get("visualFx", initial_state.get("visualFx", {}))), parsed.get("feedback", initial_state.get("feedback", {})), parsed.get("settings", {}))
	ui_art = _normalize_ui_art(parsed.get("ui_art", parsed.get("uiArt", {})))
	appearance = _normalize_appearance(parsed.get("appearance", initial_state.get("appearance", {})))
	feedback = _normalize_feedback(parsed.get("feedback", initial_state.get("feedback", {})))
	feedback.prefs.motion = str(visual_fx.motion)
	player_stats = parsed.get("player_stats", parsed.get("stats", {})).duplicate(true) if parsed.get("player_stats", parsed.get("stats", {})) is Dictionary else {}
	player_journal.clear()
	var saved_journal: Variant = parsed.get("player_journal", parsed.get("journal", []))
	if saved_journal is Array:
		for entry in saved_journal:
			if entry is Dictionary and player_journal.size() < 200:
				player_journal.append(entry.duplicate(true))
	letters.clear()
	var saved_letters: Variant = parsed.get("letters", initial_state.get("letters", []))
	if saved_letters is Array:
		for letter in saved_letters:
			if letter is Dictionary and letters.size() < 150 and str(letter.get("id", "")).length() <= 80 and str(letter.get("title", "")).length() < 2000 and str(letter.get("text", "")).length() < 2000:
				letters.append(letter.duplicate(true))
	mail_read.clear()
	var saved_mail_read: Variant = parsed.get("mail_read", parsed.get("mailRead", initial_state.get("mailRead", [])))
	if saved_mail_read is Array:
		for letter_id in saved_mail_read:
			var normalized_letter_id := str(letter_id)
			if normalized_letter_id.length() <= 80 and not mail_read.has(normalized_letter_id): mail_read.append(normalized_letter_id)
	legacy_archive = parsed.get("legacy_archive", {}).duplicate(true) if parsed.get("legacy_archive", {}) is Dictionary else {}
	day = maxi(0, int(parsed.get("day", 0)))
	minutes = clampf(float(parsed.get("minutes", 390)), 360.0, 1320.0)
	_bedtime_prompted = false
	stamina = float(parsed.get("stamina", 100))
	money = clampi(int(parsed.get("money", 180)), 0, 1000000000)
	var saved_player: Dictionary = parsed.get("player", {})
	player_direction = str(saved_player.get("direction", "down")) if str(saved_player.get("direction", "down")) in ["up", "down", "left", "right"] else "down"
	if saved_player.has("x") and saved_player.has("y"):
		var loaded_position := Vector2(float(saved_player.x), float(saved_player.y))
		if loaded_position.x >= 24 and loaded_position.x <= 3816 and loaded_position.y >= 38 and loaded_position.y <= 3816:
			player_source_position={"x":float(saved_player.x),"y":float(saved_player.y)}
	current_interior = str(parsed.get("interior", ""))
	# Discard before clearing queues: their cancellation must not invoke old callbacks.
	source_keyboard.clear()
	_feedback_state_generation += 1
	feedback_action_runtime = {"floats": [], "clock": 0.0, "serial": 0}
	cancel_action(false)
	# Session state belongs to the replaced save, not the persistent fishing data.
	# Discard it explicitly without invoking the old action cancellation callback.
	_cancel_fishing_session()
	cancel_farm_queue()
	cancel_ranch_queue()
	ranch_holds.clear()
	ranch_actor_clock = 0.0
	pet_visual_action.clear()
	ranch_actor_focus.clear()
	ranch_actor_poses.clear()
	ranch_actor_action.clear()
	ranch_movement = null
	kitchen_task.clear()
	museum_task.clear()
	npc_task.clear()
	building_task.clear()
	walking_target.clear()
	interior_npc_positions.clear()
	if current_interior != "" and interior_house().is_empty(): current_interior = ""
	var saved_riding: Variant = parsed.get("riding", false)
	riding = saved_riding if saved_riding is bool and current_interior == "" else false
	var saved_interior_state: Variant = parsed.get("interior_state", {})
	if saved_interior_state is Dictionary:
		interior_state = {
			"memories": saved_interior_state.get("memories", {}).duplicate(true) if saved_interior_state.get("memories", {}) is Dictionary else {},
			"chores": saved_interior_state.get("chores", {}).duplicate(true) if saved_interior_state.get("chores", {}) is Dictionary else {}
		}
	else:
		interior_state = {"memories": {}, "chores": {}}
	var saved_interior_position: Variant = parsed.get("interior_position", {})
	if saved_interior_position is Dictionary:
		var candidate_interior := Vector2(float(saved_interior_position.get("x", 480)), float(saved_interior_position.get("y", 567)))
		if candidate_interior.x >= 113 and candidate_interior.x <= 847 and candidate_interior.y >= 205 and candidate_interior.y <= 602:
			interior_source_position={"x":float(saved_interior_position.get("x",480)),"y":float(saved_interior_position.get("y",567))}
	interior_return_source=null
	var saved_return_position: Variant=parsed.get("interior_return_position")
	if saved_return_position is Dictionary and saved_return_position.has("x") and saved_return_position.has("y"):
		var rx:=float(saved_return_position.x)
		var ry:=float(saved_return_position.y)
		if is_finite(rx) and is_finite(ry) and rx>=24.0 and rx<=3816.0 and ry>=38.0 and ry<=3816.0:
			interior_return_source={"x":rx,"y":ry}
			if saved_return_position.has("direction"):interior_return_source.direction=saved_return_position.direction

	selected_tool = str(parsed.get("selected_tool", "hoe"))
	selected_seed = str(parsed.get("selected_seed", "cabbage"))
	selected_recipe = str(parsed.get("selected_recipe", "greens"))
	if not crop_catalog.has(selected_seed): selected_seed = "cabbage"
	var recipe_exists := false
	for recipe in content.get("recipes", []):
		if str(recipe.get("id", "")) == selected_recipe:
			recipe_exists = true
			break
	if not recipe_exists: selected_recipe = "greens"
	inventory = {}
	var saved_inventory: Dictionary = parsed.get("inventory", {})
	for item_id in saved_inventory:
		var normalized_id := str(item_id)
		if normalized_id == "cabbage_seed": normalized_id = "cabbageSeed"
		if normalized_id == "radish_seed": normalized_id = "radishSeed"
		if item_catalog.has(normalized_id):
			inventory[normalized_id] = int(saved_inventory[item_id])
	for item_id in item_catalog:
		if not inventory.has(item_id): inventory[item_id] = 0
	quality = parsed.get("quality", parsed.get("crop_grades", {})).duplicate(true)
	storage = parsed.get("storage", initial_state.get("storage", {})).duplicate(true)
	storage_quality = parsed.get("storage_quality", initial_state.get("storageQuality", {})).duplicate(true)
	economy = parsed.get("economy", initial_state.get("economy", {})).duplicate(true)
	environment = parsed.get("environment", initial_state.get("environment", {"version": 1, "history": []})).duplicate(true)
	forage = parsed.get("forage", initial_state.get("forage", {"version": 1, "mode": "gentle", "xp": 0, "patches": {}, "discovered": [], "finds": []})).duplicate(true)
	if not forage is Dictionary or str(forage.get("mode", "gentle")) not in ["gentle", "full"]:
		forage = {"version": 1, "mode": "gentle", "xp": 0, "patches": {}, "discovered": [], "finds": []}
	fishing = parsed.get("fishing", initial_state.get("fishing", {"version": 1, "mode": "relaxed", "bait": "plain", "release": false, "waters": {}, "records": {}, "last": null})).duplicate(true)
	preload("res://scripts/fishing_service.gd").initialize_current(self)
	kitchen = parsed.get("kitchen", initial_state.get("kitchen", {"version": 1, "jobs": [], "nextId": 1, "equipment": {}, "lots": {"bag": {}, "storage": {}}, "cold": false, "mastery": {}, "experiments": [], "buff": null})).duplicate(true)
	var archived_source: Variant = parsed.get("legacy_archive", {})
	var archived_processing: Variant = archived_source.get("processing", []) if archived_source is Dictionary else []
	var raw_legacy_processing: Variant = parsed.get("legacy_processing", parsed.get("processing", archived_processing if not archived_processing.is_empty() else initial_state.get("processing", [])))
	legacy_processing = _normalize_legacy_processing(raw_legacy_processing)
	toolkit = parsed.get("toolkit", initial_state.get("toolkit", {"version": 1, "tools": {}})).duplicate(true)
	_normalize_skills(parsed.get("skills", initial_state.get("skills", {})))
	farm = parsed.get("farm", initial_state.get("farm", {})).duplicate(true)
	known_recipes.clear()
	for recipe_id in parsed.get("known_recipes", initial_state.get("knownRecipes", [])):
		known_recipes.append(str(recipe_id))
	festivals.clear()
	var saved_festivals: Variant = parsed.get("festivals", initial_state.get("festivals", []))
	if saved_festivals is Array:
		for festival_key in saved_festivals:
			var parts := str(festival_key).split("-")
			if parts.size() != 2: continue
			var festival_year := int(parts[0])
			var festival_season := int(parts[1])
			var festival_day := (festival_year - 1) * 112 + festival_season * 28 + 13
			if festival_year >= 1 and festival_season >= 0 and festival_season < 4 and festival_day <= day and not festivals.has(str(festival_key)):
				festivals.append(str(festival_key))
	season_events = parsed.get("season_events", initial_state.get("seasonEvents", {})).duplicate(true)
	_reconcile_kitchen_lots()
	_refresh_economy_day()
	selected_animal_action = str(parsed.get("selected_animal_action", "auto"))
	if not ANIMAL_ACTIONS.has(selected_animal_action):
		selected_animal_action = "auto"
	plots.clear()
	var saved_plots: Array = parsed.get("plots", [])
	for candidate in saved_plots:
		if candidate is Dictionary:
			plots.append(candidate)
	if plots.size() != FARM_LAYOUT.TOTAL:
		_reset_plots()
	_normalize_plots()
	_normalize_farm()
	animals.clear()
	var saved_animals: Array = parsed.get("animals", [])
	for candidate in saved_animals:
		if candidate is Dictionary:
			animals.append(candidate)
	if not parsed.has("animals"):
		_reset_animals()
	var saved_neighbors: Variant = parsed.get("neighbors", {})
	_normalize_neighbors(saved_neighbors if saved_neighbors is Dictionary else {})
	ranch = parsed.get("ranch", initial_state.get("ranch", {})).duplicate(true)
	_normalize_animals()
	upgrades = parsed.get("upgrades", {})
	_normalize_building(parsed.get("building", initial_state.get("building", {})))
	relations = parsed.get("relations", initial_state.get("relations", {})).duplicate(true)
	last_gifts = {}
	var saved_last_gifts: Variant = parsed.get("last_gifts", {})
	if saved_last_gifts is Dictionary:
		for npc_id in saved_last_gifts:
			var item_id := str(saved_last_gifts[npc_id])
			var known_npc := false
			for person in npc_catalog:
				if str(person.get("id", "")) == str(npc_id):
					known_npc = true
					break
			if relations.has(str(npc_id)) and known_npc and item_catalog.has(item_id):
				last_gifts[str(npc_id)] = item_id
	flags = parsed.get("flags", initial_state.get("flags", {})).duplicate(true)
	if saved_ranch is Dictionary and saved_ranch.has("delivered"):
		ranch.delivered = []
		for order_id in saved_delivered:
			if not ranch.delivered.has(order_id): ranch.delivered.append(order_id)
			flags[order_id] = true
	_normalize_community_projects(parsed.get("community_projects", parsed.get("projects", initial_state.get("projects", {}))))
	legacy_chapters = {}
	var saved_chapters: Variant = parsed.get("legacy_chapters", parsed.get("chapters", initial_state.get("chapters", {})))
	if saved_chapters is Dictionary:
		for chapter_key in saved_chapters:
			var chapter_parts := str(chapter_key).split("-")
			var chapter_choice := int(saved_chapters[chapter_key])
			if chapter_parts.size() == 2 and int(chapter_parts[0]) >= 0 and int(chapter_parts[0]) <= 100000 and int(chapter_parts[1]) in [0, 1, 2, 3] and chapter_choice in [0, 1]:
				legacy_chapters["%d-%d" % [int(chapter_parts[0]), int(chapter_parts[1])]] = chapter_choice
	year_plans = {}
	var saved_year_plans: Variant = parsed.get("year_plans", parsed.get("yearPlans", initial_state.get("yearPlans", {})))
	if saved_year_plans is Dictionary:
		for year_key in saved_year_plans:
			var year := int(year_key)
			var plan_choice := int(saved_year_plans[year_key])
			if year >= 0 and year <= 100000 and plan_choice in [0, 1, 2]: year_plans[str(year)] = plan_choice
	_normalize_achievements(parsed.get("achievements", initial_state.get("achievements", [])))
	_normalize_onboarding(false)
	_normalize_npc_social(parsed.get("npc_stories", {}), parsed.get("partners", {}), parsed.get("marriage", {}))
	archives.clear()
	var saved_archives: Variant = parsed.get("archives", initial_state.get("archives", ["key"]))
	if saved_archives is Array:
		for archive_id in saved_archives:
			var valid_archive := false
			for candidate in content.get("archives", []):
				if str(candidate.get("id", "")) == str(archive_id): valid_archive = true
			if valid_archive and not archives.has(str(archive_id)):
				archives.append(str(archive_id))
	if not archives.has("key"):
		archives.append("key")
	furniture = parsed.get("furniture", initial_state.get("furniture", {})).duplicate(true)
	_merge_legacy_animal_care()
	_migrate_legacy_layouts(legacy_systems.get("layouts", []))
	var saved_pet: Variant = parsed.get("pet", initial_state.get("pet", {"type": "cat", "name": "小团", "bond": 0, "patted": -1}))
	if saved_pet is Dictionary and str(saved_pet.get("type", "cat")) in ["cat", "dog"]:
		pet_state = {"type": str(saved_pet.get("type", "cat")), "name": str(saved_pet.get("name", "小团")).strip_edges().left(12), "bond": clampi(int(saved_pet.get("bond", 0)), 0, 100), "patted": clampi(int(saved_pet.get("patted", -1)), -1, day)}
	else:
		pet_state = {"type": "cat", "name": "小团", "bond": 0, "patted": -1}
	_museum_normalize(parsed.get("collection", null))
	_import_legacy_discoveries()
	_atlas_normalize(parsed.get("atlas"))
	# The source environment load wrapper hides the minimap after every load.
	atlas.minimap = false
	gathered = parsed.get("gathered", {}).duplicate(true)
	if not parsed.has("forage"):
		var old_patches: Dictionary = {}
		for node_id in gathered:
			old_patches[node_id] = {"lastDay": int(gathered[node_id]), "readyDay": int(gathered[node_id]) + 2, "pressure": 1}
		forage.patches = old_patches
	fish_caught = maxi(0, int(parsed.get("fish_caught", 0)))
	_museum_sync(not parsed.has("collection"))
	seen_world_region = ""
	_feedback_snapshot = _feedback_snapshot_state()
	_normalize_npc_residents(parsed.get("npc_residents", {}))
	if bool(parsed.get("_restore_source_player",false)):
		if atlas_source_navigation==null:atlas_source_navigation=preload("res://scripts/npc_navigation.gd").new()
		atlas_source_navigation.refresh(self)
		set_player_navigation_position(atlas_source_navigation.safe(self,current_interior,player_navigation_position()))
	var canonical:Variant=parsed.get("_source_ranch_bundle")
	if canonical is Dictionary:
		ranch=canonical.ranch.duplicate(true);animals.assign(canonical.animals.duplicate(true))
	elif original_ranch_input.get("ranch") is Dictionary and original_ranch_input.get("animals") is Array:
		var source_extra:Script=load("res://scripts/source_save_extra.gd")
		var raw_ranch:Dictionary=original_ranch_input
		if source_extra.ranch_error(raw_ranch,item_catalog,system_catalog,world_village)=="":
			# Native saves already contain runtime positions and care state.
			# Only browser imports above use the source loader normalization.
			ranch=raw_ranch.ranch.duplicate(true)
			animals.assign(raw_ranch.animals.duplicate(true))
	preload("res://scripts/ranch_products.gd").initialize(self)
	_remember_weather()
	if atlas.get("tracking") is Dictionary and atlas_resolve(atlas.tracking).is_empty(): atlas.tracking=null
	atlas_visit()
	if is_inside_tree(): preload("res://scripts/performance_policy.gd").configure(get_tree().root)
	return true

func convert_external_save(source: Dictionary) -> Dictionary:
	if not preload("res://scripts/native_save_schema.gd").safe_tree(source): return {}
	# Native JSON also reaches this entry; reject containers before int(version).
	if not preload("res://scripts/source_save_validation.gd").integer(source.get("version"),1,33): return {}
	if source.has("bag") and not source.has("inventory"):
		if int(source.get("version", 0)) not in [1, 2, 3] or not source.get("bag") is Dictionary or not source.get("plots") is Array:
			return {}
		var original_browser_archive: Dictionary = source.duplicate(true)
		var old_alias: bool = source.get("worldRevision") == 1
		for old_id in source.bag:
			if str(old_id).ends_with("_seed"): old_alias = true
		if int(source.version) < 3 and not old_alias:
			# The original life loader ignores v3 additions in genuine v1/v2 saves.
			source = source.duplicate(true)
			var old_life: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_old_life_defaults.json"))
			var old_appearance: Dictionary = source.get("appearance", {}).duplicate(true) if source.get("appearance") is Dictionary else {}
			for life_key in old_life.fields:
				var life_value: Variant = old_life.fields[life_key]
				source[life_key] = life_value.duplicate(true) if life_value is Dictionary or life_value is Array else life_value
			source.projects.bridge = bool(source.get("flags", {}).get("bridge", false))
			for letter in source.letters: letter.day = source.day
			old_appearance.merge(source.appearance, true)
			source.appearance = old_appearance
			var old_settings: Dictionary = source.get("settings", {}).duplicate(true) if source.get("settings") is Dictionary else {}
			old_settings.merge(old_life.settings, true)
			source.settings = old_settings
			for old_plot in source.plots:
				old_plot.care = 0
				old_plot.pest = false
		var converted: Dictionary = {
			"version": 31,
			"_restore_source_player": true,
			"legacy_systems": _normalize_legacy_systems(source),
			"player_name": source.get("name", "小满"),
			"player_gender": source.get("gender", "不设定"),
			"day": source.get("day", 0),
			"minutes": source.get("minutes", 390),
			"stamina": source.get("stamina", 100),
			"money": source.get("money", 180),
			"player": _convert_legacy_player(source),
			"interior": str(source.get("village", {}).get("interior", "")) if source.get("village", {}) is Dictionary else "",
			"npc_residents": source.get("village", {}).get("npc", {}).duplicate(true) if source.get("village", {}) is Dictionary and source.get("village", {}).get("npc", {}) is Dictionary else {},
			"riding": bool(source.get("village", {}).get("riding", false)) if source.get("village", {}) is Dictionary else false,
			"interior_state": {
				"memories": load("res://scripts/source_save_extra.gd").village_history(source.village.get("memories"),float(source.get("day",0))) if source.get("village") is Dictionary else {},
				"chores": load("res://scripts/source_save_extra.gd").village_history(source.village.get("chores"),float(source.get("day",0))) if source.get("village") is Dictionary else {}
			},
			"letters": source.get("letters", []).duplicate(true) if source.get("letters", []) is Array else [],
			"mail_read": source.get("mailRead", []).duplicate(true) if source.get("mailRead", []) is Array else [],
			"selected_tool": str(source.get("toolkit", {}).get("selected", "hoe")) if source.get("toolkit", {}) is Dictionary else "hoe",
			"selected_seed": source.get("seed", "cabbage"),
			"selected_recipe": source.get("selectedRecipe", "greens"),
			"inventory": source.get("bag", {}).duplicate(true),
			"storage": source.get("storage", {}).duplicate(true) if source.get("storage", {}) is Dictionary else {},
			"quality": source.get("quality", {}).duplicate(true) if source.get("quality", {}) is Dictionary else {},
			"storage_quality": source.get("storageQuality", {}).duplicate(true) if source.get("storageQuality", {}) is Dictionary else {},
			"economy": source.get("economy", initial_state.get("economy", {})).duplicate(true) if source.get("economy", initial_state.get("economy", {})) is Dictionary else {},
			"environment": source.get("environment", initial_state.get("environment", {})).duplicate(true) if source.get("environment", initial_state.get("environment", {})) is Dictionary else {},
			"forage": source.get("forage", initial_state.get("forage", {})).duplicate(true) if source.get("forage", initial_state.get("forage", {})) is Dictionary else {},
			"fishing": source.get("fishing", initial_state.get("fishing", {})).duplicate(true) if source.get("fishing", initial_state.get("fishing", {})) is Dictionary else {},
			"kitchen": source.get("kitchen", initial_state.get("kitchen", {})).duplicate(true) if source.get("kitchen", initial_state.get("kitchen", {})) is Dictionary else {},
			"legacy_processing": source.get("processing", []).duplicate(true) if source.get("processing", []) is Array else [],
			"toolkit": source.get("toolkit", initial_state.get("toolkit", {})).duplicate(true) if source.get("toolkit", initial_state.get("toolkit", {})) is Dictionary else {},
			"skills": source.get("skills", initial_state.get("skills", {})).duplicate(true) if source.get("skills", initial_state.get("skills", {})) is Dictionary else {},
			"community_projects": source.get("projects", {}).duplicate(true) if source.get("projects", {}) is Dictionary else {},
			"legacy_chapters": source.get("chapters", {}).duplicate(true) if source.get("chapters", {}) is Dictionary else {},
			"year_plans": source.get("yearPlans", {}).duplicate(true) if source.get("yearPlans", {}) is Dictionary else {},
			"achievements": source.get("achievements", []).duplicate(true) if source.get("achievements", []) is Array else [],
			"farm": source.get("farm", initial_state.get("farm", {})).duplicate(true) if source.get("farm", initial_state.get("farm", {})) is Dictionary else {},
			"building": source.get("building", initial_state.get("building", {})).duplicate(true) if source.get("building", initial_state.get("building", {})) is Dictionary else {},
			"known_recipes": source.get("knownRecipes", []).duplicate(true) if source.get("knownRecipes", []) is Array else [],
			"ranch": source.get("ranch", initial_state.get("ranch", {})).duplicate(true) if source.get("ranch", initial_state.get("ranch", {})) is Dictionary else {},
			"selected_animal_action": "auto",
			"animals": source.get("animals", []).duplicate(true) if source.get("animals", []) is Array else [],
			"upgrades": source.get("upgrades", {}).duplicate(true) if source.get("upgrades", {}) is Dictionary else {},
			"relations": source.get("relations", {}).duplicate(true) if source.get("relations", {}) is Dictionary else {},
			"neighbors": source.get("neighbors", initial_state.get("neighbors", {})).duplicate(true) if source.get("neighbors", initial_state.get("neighbors", {})) is Dictionary else {},
			"last_gifts": source.get("lastGifts", {}).duplicate(true) if source.get("lastGifts", {}) is Dictionary else {},
			"npc_stories": source.get("stories", {}).duplicate(true) if source.get("stories", {}) is Dictionary else {},
			"partners": source.get("partners", {}).duplicate(true) if source.get("partners", {}) is Dictionary else {},
			"marriage": source.get("marriage", {}).duplicate(true) if source.get("marriage", {}) is Dictionary else {},
			"collection": source.get("collection", {}).duplicate(true) if source.get("collection", {}) is Dictionary else {},
			"atlas": source.get("atlas").duplicate(true) if source.get("atlas") is Dictionary or source.get("atlas") is Array else source.get("atlas"),
			"archives": source.get("archives", []).duplicate(true) if source.get("archives", []) is Array else [],
			"furniture": source.get("furniture", {}).duplicate(true) if source.get("furniture", {}) is Dictionary else {},
			"pet": source.get("pet", {}).duplicate(true) if source.get("pet", {}) is Dictionary else {},
			"festivals": source.get("festivals", []).duplicate(true) if source.get("festivals", []) is Array else [],
			"season_events": source.get("seasonEvents", {}).duplicate(true) if source.get("seasonEvents", {}) is Dictionary else {},
			"flags": source.get("flags", {}).duplicate(true) if source.get("flags", {}) is Dictionary else {},
			"gathered": source.get("collected", {}).duplicate(true) if source.get("collected", {}) is Dictionary else {},
			"fish_caught": int(source.get("stats", {}).get("fish", 0)) if source.get("stats", {}) is Dictionary else 0,
			"player_settings": source.get("settings", {}).duplicate(true) if source.get("settings", {}) is Dictionary else {},
			"visual_fx": source.get("visualFx", {}).duplicate(true) if source.get("visualFx", {}) is Dictionary else {},
			"ui_art": _normalize_ui_art(source.get("uiArt", {})),
			"appearance": _normalize_appearance(source.get("appearance", {})),
			"feedback": source.get("feedback", {}).duplicate(true) if source.get("feedback", {}) is Dictionary else {},
			"player_stats": source.get("stats", {}).duplicate(true) if source.get("stats", {}) is Dictionary else {},
			"player_journal": source.get("journal", []).duplicate(true) if source.get("journal", []) is Array else [],
			"legacy_archive": original_browser_archive
		}
		# Source ensure treats absent and JavaScript-falsy optional systems alike.
		for system_id in ["kitchen", "economy"]:
			if not preload("res://scripts/atlas_rules.gd").truthy(source.get(system_id)):
				converted[system_id] = initial_state.get(system_id, {}).duplicate(true)
				if system_id == "kitchen": converted.kitchen.lots = {"bag": {}, "storage": {}}
		if not preload("res://scripts/atlas_rules.gd").truthy(source.get("toolkit")):
			converted.toolkit = initial_state.get("toolkit", {}).duplicate(true)
			for tool_id in converted.toolkit.get("tools", {}):
				var upgrade_id: String = "gather" if tool_id in ["axe", "sickle"] else tool_id
				converted.toolkit.tools[tool_id].level = 1 if bool(converted.legacy_systems.get("toolUpgrades", {}).get(upgrade_id, false)) else 0
		if not preload("res://scripts/atlas_rules.gd").truthy(source.get("building")):
			converted.building = initial_state.get("building", {}).duplicate(true)
			converted.building.house = 2 if bool(converted.upgrades.get("room", false)) else (1 if bool(converted.upgrades.get("kitchen", false)) else 0)
		if preload("res://scripts/atlas_rules.gd").truthy(source.get("building")):
			converted.legacy_systems.layoutMigrationComplete = true
		# Source load defaults and duplicate discovery normalization.
		if not preload("res://scripts/atlas_rules.gd").truthy(source.get("environment")):
			converted.environment = {"version":1,"history":[]}
		if converted.forage.get("finds")==null: converted.forage.finds=[]
		var unique_discovered:Array=[]
		for resource_id in converted.forage.get("discovered",[]):
			if not unique_discovered.has(resource_id):unique_discovered.append(resource_id)
		converted.forage.discovered=unique_discovered
		if not source.has("ranch"): converted.ranch["delivered"] = []
		# Browser load reconstructs these flags only from delivered records.
		for order_id in ["ranchMilk", "ranchWool", "ranchYogurt"]: converted.flags.erase(order_id)
		var converted_plots: Array = []
		for old_plot in source.get("plots", []):
			if not old_plot is Dictionary: return {}
			var plot: Dictionary = old_plot.duplicate(true)
			plot["crop"] = "" if old_plot.get("crop", null) == null else str(old_plot.get("crop", ""))
			plot["last_group"] = "" if old_plot.get("lastGroup", null) == null else str(old_plot.get("lastGroup", ""))
			plot["repeats"] = int(old_plot.get("repeats", 0))
			converted_plots.append(plot)
		converted["plots"] = converted_plots
		var village: Dictionary=source.get("village",{}) if source.get("village") is Dictionary else {}
		var room: String=str(village.get("interior")) if village.get("interior") is String else ""
		converted.interior=room
		if room!="":
			converted.interior_position=converted.player.duplicate()
		var back: Variant=village.get("returnPoint")
		converted.interior_return_position=null
		if back is Dictionary and back.has("x") and back.has("y"):
			var bx:=float(back.x)
			var by:=float(back.y)
			if is_finite(bx) and is_finite(by) and bx>=24.0 and bx<=3816.0 and by>=38.0 and by<=3816.0:
				converted.interior_return_position={"x":bx,"y":by,"direction":"down"}
		if room!="" and converted.interior_return_position==null:
			converted.interior_return_position=house_data(room).get("door",{}).duplicate()
		if int(source.get("version", 0)) in [1, 2, 3] and not old_alias:
			var source_extra:Script=load("res://scripts/source_save_extra.gd")
			var migrated:Dictionary=source_extra.migrate(source)
			if source_extra.ranch_error(migrated,item_catalog,system_catalog,world_village)=="":
				converted["_source_ranch_bundle"]=source_extra.normalize_ranch(migrated,initial_state,system_catalog,world_village)
		return converted
	if int(source.get("version", 0)) in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33] and source.has("inventory"):
		var native: Variant = load("res://scripts/save_json.gd").decode(source.duplicate(true))
		return native if native is Dictionary and preload("res://scripts/native_save_rules.gd").error(native,initial_state,world_village.get("offsets",{})).is_empty() else {}
	return {}

func _convert_legacy_player(source: Dictionary) -> Dictionary:
	var raw_player: Variant = source.get("player", {})
	if not raw_player is Dictionary:
		return initial_state.get("player", {"x": 2831, "y": 1652, "direction": "down"}).duplicate(true)
	var player: Dictionary = raw_player
	var direction := str(player.get("direction", "down"))
	if direction not in ["up", "down", "left", "right"]: direction = "down"
	var x := float(player.get("x", 2831.0))
	var y := float(player.get("y", 1652.0))
	var revision := int(source.get("worldRevision", 1))
	var scene := str(source.get("scene", "farm"))
	if scene not in ["mountain", "town", "river", "bamboo", "farm", "pasture"]: scene = "farm"
	var target_offsets := {
		"mountain": Vector2(0, 0), "town": Vector2(1920, 0), "river": Vector2(0, 2304),
		"bamboo": Vector2(0, 1152), "farm": Vector2(1920, 1152), "pasture": Vector2(1920, 2304)
	}
	if revision < 3:
		# v1 used the compact 944x556 farm map; the old core expanded it before
		# the village layer placed the scene in the continuous world.
		if revision < 2:
			x += 480.0
			y += 288.0
		var local_position := Vector2(x, y)
		var offset: Vector2 = target_offsets.get(scene, target_offsets.farm)
		local_position.x = clampf(local_position.x, 24.0, 1896.0)
		local_position.y = clampf(local_position.y, 38.0, 1128.0)
		local_position += offset
		x = local_position.x
		y = local_position.y
	elif revision == 3:
		# v3 stored the six regions in a 3-column grid. Rebase the local point
		# into the current 2-column world layout while preserving its scene.
		var old_region := "farm"
		var column := clampi(int(floor(x / 1920.0)), 0, 2)
		var row := 1 if y >= 1152.0 else 0
		var old_regions := [["mountain", "town", "river"], ["bamboo", "farm", "pasture"]]
		old_region = old_regions[row][column]
		# The old UI represented the pasture as the farm scene; its coordinates
		# still identify the pasture column unambiguously.
		var old_offset := Vector2(column * 1920.0, row * 1152.0)
		var local_position := Vector2(x, y) - old_offset
		local_position.x = clampf(local_position.x, 24.0, 1896.0)
		local_position.y = clampf(local_position.y, 38.0, 1128.0)
		var new_offset: Vector2 = target_offsets.get(old_region, target_offsets.get(scene, target_offsets.farm))
		local_position += new_offset
		x = local_position.x
		y = local_position.y
	return {"x": x, "y": y, "direction": direction}

func import_external_save(source: Dictionary) -> bool:
	return _import_external_save_to_paths(source, SAVE_PATH, "user://zhenrizhi_godot_recovery.json", "user://zhenrizhi_godot_backup.json")

func _import_external_save_to_paths(source: Dictionary, save_path: String, recovery_path: String, backup_path: String) -> bool:
	var old_alias_save:=false
	if preload("res://scripts/source_save_validation.gd").integer(source.get("version"),1,2) and source.get("bag") is Dictionary:
		old_alias_save=source.get("worldRevision")==1
		for key in source.bag:
			if key is String and key.ends_with("_seed") and item_catalog.has(key.trim_suffix("_seed")+"Seed"):old_alias_save=true
	if source.has("bag") and not source.has("inventory") and not old_alias_save:
		var validation_error: String = preload("res://scripts/source_save_validation.gd").error(source, item_catalog, crop_catalog, content.get("scenes", {}), content, system_catalog, world_village)
		if validation_error != "":
			message = validation_error
			changed.emit()
			return false
	var converted := convert_external_save(source)
	if converted.is_empty():
		message = "这不是兼容的《种日子》浏览器存档或 Godot 存档。原有进度未改动。"
		changed.emit()
		return false
	if not _write_snapshot(recovery_path) or not _write_snapshot(backup_path):
		message = "导入前的回退存档没有写好，暂时没有替换当前进度。"
		changed.emit()
		return false
	var previous_state := _make_save_data().duplicate(true)
	if not load_game_data(converted):
		message = "存档结构无法识别，当前进度仍可从回退档恢复。"
		changed.emit()
		return false
	if not save_game(save_path):
		load_game_data(previous_state)
		message = "新存档写入失败，内存中的当前进度已恢复；可从导入前回退档恢复磁盘存档。"
		changed.emit()
		return false
	message = "浏览器存档已导入 Godot，原版档案副本也保留在存档里。"
	changed.emit()
	return true

func save_game_to_recovery() -> bool:
	return _write_snapshot("user://zhenrizhi_godot_recovery.json")

func save_game_to_backup() -> bool:
	return _write_snapshot("user://zhenrizhi_godot_backup.json")

func _write_snapshot(path: String) -> bool:
	return _write_json_atomically(path, _make_save_data())

func _normalize_npc_residents(source: Variant) -> void:
	npc_residents.clear()
	npc_movement = load("res://scripts/npc_movement.gd").new()
	for person in npc_catalog:
		var id := str(person.id)
		var home: Dictionary = {}
		for house in world_village.get("houses", []):
			if str(house.get("owner", "")) == id: home = house; break
		if home.is_empty(): continue
		var raw: Variant = source.get(id) if source is Dictionary else null
		var valid: bool = raw is Dictionary and (raw.get("x") is float or raw.get("x") is int) and (raw.get("y") is float or raw.get("y") is int)
		if valid: valid = is_finite(float(raw.x)) and is_finite(float(raw.y)) and float(raw.x)>=24 and float(raw.x)<=3816 and float(raw.y)>=38 and float(raw.y)<=3816
		var p: Dictionary
		if valid:
			p = {"x":float(raw.x),"y":float(raw.y),"direction":str(raw.get("direction","down")) if str(raw.get("direction","down")) in ["up","down","left","right"] else "down","room":str(home.id) if raw.get("room") is String and raw.get("room")==home.id else null}
			if p.room == null: p.merge(npc_movement.navigation.safe(self,"",p,true),true)
		else:
			var safe: Dictionary = npc_movement.navigation.safe(self,"",home.door,true)
			p = {"x":float(safe.x),"y":float(safe.y),"direction":"down","room":str(home.id) if minutes<420 or minutes>=1170 else null}
		npc_residents[id] = p
	npc_movement.publish(self)

func _reset_npc_morning() -> void:
	npc_residents.clear()
	npc_movement = load("res://scripts/npc_movement.gd").new()
	for person in npc_catalog:
		for house in world_village.get("houses", []):
			if str(house.get("owner", "")) == str(person.id):
				var p: Dictionary = house.door.duplicate()
				p.direction = "down"; p.room = str(house.id)
				npc_residents[str(person.id)] = p
				break
	npc_movement.publish(self)

func advance_npc_movement(delta: float) -> void:
	if npc_movement == null: _normalize_npc_residents(npc_residents.duplicate(true))
	npc_movement.advance(self,delta)
	npc_movement.publish(self)

func confirm_operation(success: bool, kind: String="good", vibrate: bool=true) -> bool:
	if success:
		sound_requested.emit(kind)
		if vibrate and bool(player_settings.get("vibration",false)):
			vibration_requested.emit()
		# Original app.apply persists successful operations before returning to UI.
		save_game(SAVE_PATH, true)
	return success

func inspect_point_with_sound(point: Dictionary) -> bool:
	var musical := false
	for word in ["声","琴","铃","曲","录音"]:
		if str(point.get("name","")).contains(word):musical=true;break
	return confirm_operation(inspect_interior_point(point),"music" if musical else "good",false)

func ranch_fixture_action(kind: String, identity: String) -> bool:
	if kind == "ranch-trough": return ranch_fill_trough(identity)
	var count: int = preload("res://scripts/ranch_products.gd").take(self,"box" if kind == "ranch-box" else "product",identity)
	message = "收下产物 ×%d，品质与生产日期已保留。" % count if count>0 else "这里暂时没有待领产物。"
	changed.emit()
	return count>0

func ranch_fill_trough(home: String) -> bool:
	if not ranch.barns.has(home) or not bool(ranch.barns[home].built): return false
	var food := str(ranch.feed)
	var amount := 0
	for a: Dictionary in animals:
		if _ranch_home_for(str(a.type)) == home and preload("res://scripts/ranch_care.gd").accepts(self,a,food): amount += preload("res://scripts/ranch_care.gd").needed(self,a,day)
	amount = maxi(0,amount-int(ranch.barns[home].trough.get(food,0)))
	if amount == 0: message = "料槽已有足够饲料。"; changed.emit(); return false
	if not _ranch_charge(2,{food:amount}): return false
	ranch.barns[home].trough[food] = int(ranch.barns[home].trough.get(food,0))+amount
	message = "往料槽添入%s ×%d，伙伴会自行来吃。" % [str(item_catalog[food].name),amount]
	changed.emit()
	return true


func _refresh_quests() -> void:
	QUESTS.sync(self)
func quest_event(key: String, token: String="", amount: int=1) -> bool:
	return QUESTS.event(self,key,token,amount)
func quest_snapshot(filters: Dictionary={}) -> Array:
	return QUESTS.rows(self,filters)
func quest_accept(id: String) -> bool:return QUESTS.accept(self,id)
func quest_claim(id: String) -> bool:return QUESTS.claim(self,id)
func quest_pin(id: String) -> bool:return QUESTS.pin(self,id)
func quest_abandon(id: String) -> bool:return QUESTS.abandon(self,id)
func quest_track(id: String) -> Dictionary:return QUESTS.track(self,id)
func quest_submit(id: String) -> bool:
	var d: Dictionary=QUESTS.definition(self,id)
	if d.is_empty() or str(QUESTS.snapshot(self,d).status)!="ready" or not QUESTS.near(self,d):
		message="请备齐材料并到实际交付地点，手记可查看路线。";changed.emit();return false
	if action_busy():return false
	var spec: Dictionary=ACTION_RULES.spec("trade" if str(d.kind)!="project" else "build","当面交接 · "+str(d.title))
	spec.duration=1.2 if str(d.kind)!="project" else 2.8
	var at: Vector2=player_position if current_interior=="" else interior_position
	quest_action_serial+=1
	quest_action={"id":id,"serial":quest_action_serial,"day":day,"room":current_interior}
	var record:=quest_action.duplicate(true)
	var started:=begin_action(spec,{"kind":"quest","id":id,"x":at.x,"y":at.y},_finish_quest_submission.bind(record),func():
		if int(quest_action.get("serial",-1))==int(record.serial):quest_action.clear())
	if not started:quest_action.clear()
	return started
func _finish_quest_submission(record: Dictionary) -> void:
	if quest_action.is_empty() or int(quest_action.get("serial",-1))!=int(record.get("serial",-2)):return
	quest_action.clear()
	if day!=int(record.day) or current_interior!=str(record.room):return
	QUESTS.submit(self,str(record.id))
