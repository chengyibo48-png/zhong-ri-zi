extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(title)
func put(data: Variant, path: Array, value: Variant) -> void:
	var parent: Variant = data
	for index: int in range(path.size() - 1):
		var key: Variant = path[index]
		if parent is Array:
			while parent.size() <= int(key): parent.append({})
		elif not parent.has(key): parent[key] = [] if path[index + 1] is int else {}
		parent = parent[key]
	if parent is Array:
		while parent.size() <= int(path[-1]): parent.append({})
	parent[path[-1]] = value
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("Deep native save timeout");quit(1))
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
	var state := root.get_node("GameState")
	state.set_process(false)
	var baseline: Dictionary = state._make_save_data().duplicate(true)
	check(state.load_game_data(baseline),"Current complete save remains readable")
	baseline = state._make_save_data().duplicate(true)
	check(state.save_game("user://deep-valid.json",true),"Write canonical save")
	var before_disk := FileAccess.get_file_as_string("user://deep-valid.json")
	var paths := [
		["quality"],["storage_quality"],["storage","wood"],["economy","daily","bought","wood"],
		["economy","daily","day"],["economy","ledger",0,"day"],["farm","water"],
		["farm","facilities",0,"anchor"],["farm","stock",0,"qty"],["farm","beds",0,"fertility"],
		["plots",0,"companion","growth"],["animals",0,"health"],["animals",0,"care","pet"],
		["animals",0,"position","inside","x"],["ranch","barns","poultry","durability"],
		["ranch","pet","position","x"],["ranch","grass",0],["ranch","births",0,"remaining"],
		["kitchen","jobs",0,"progress"],["kitchen","lots","bag","rice",0,"qty"],
		["kitchen","equipment","stove","level"],["kitchen","mastery","greens"],
		["forage","patches","bamboo","readyDay"],["forage","xp"],
		["fishing","records","fish","best"],["fishing","waters","pond","casts"],
		["environment","history",0,"day"],["building","levels","granary"],
		["building","jobs",0,"level"],["building","layout",0,"key"],
		["toolkit","tools","hoe","condition"],["skills","farming","xp"],
		["relations","granny","points"],["npc_stories","granny","step"],
		["marriage","day"],["marriage","memories",0,"day"],["pet","bond"],
		["feedback","rows",0,"count"],["feedback","days",0,"income"],
		["feedback","prefs","seconds"],["collection","entries","item:wood","first"],
		["collection","donated","item:wood","grade"],["player_stats","gathered"],
		["player_settings","effects"],["interior_return_position"]
	]
	for path: Array in paths:
		var broken := baseline.duplicate(true)
		put(broken,path,"broken")
		check(not state.load_game_data(broken),"Reject before load: "+str(path))
		check(state._make_save_data() == baseline,"No persistent mutation: "+str(path))
		check(state.convert_external_save(broken).is_empty(),"Reject before import backups: "+str(path))
		check(FileAccess.get_file_as_string("user://deep-valid.json") == before_disk,"Preserve disk: "+str(path))
	var partial := {"version":1,"plots":baseline.plots.slice(0,24),"inventory":{}}
	check(state.load_game_data(partial),"Sparse old native save retains defaults")
	check(state.plots.size() == 72,"Old 24 plot native save expands")
	check(state.load_game_data(baseline),"Restore canonical state")
	var detached: Node = load("res://scripts/game_state.gd").new()
	detached._load_content();detached._load_initial_state()
	check(detached.load_game_data(baseline),"Detached state instances can load without a window")
	detached.free()
	var old_maps := baseline.duplicate(true);old_maps.fishing.waters=true;old_maps.fishing.records=1
	check(state.load_game_data(old_maps),"Old scalar fishing maps retain load compatibility")
	var water_id := str(state.system_catalog.fishing.waters.keys()[0])
	check(not state.fishing_plan(water_id).is_empty(),"Old scalar fishing maps remain safe to inspect")
	check(state.load_game_data(baseline),"Restore after old fishing representation")
	for path: Array in [["kitchen","jobs",0,"grade"],["fishing","records","fish","grade"]]:
		var invalid_grade := baseline.duplicate(true);put(invalid_grade,path,99)
		check(not state.load_game_data(invalid_grade),"Reject out of range quality index: "+str(path))
	var many: Array = []
	many.resize(preload("res://scripts/save_json.gd").MAX_FLOAT_ENTRIES+1)
	var drift := 0.0
	for i: int in range(400):
		var candidate := absf(sin(float(i)*0.17)*2.0)
		if JSON.parse_string(JSON.stringify({"v":candidate},"",false,true)).v != candidate:
			drift=candidate;break
	check(drift>0.0,"Construct actual decimal round trip drift")
	many.fill(drift)
	check(preload("res://scripts/save_json.gd").encode({"values":many}).is_empty(),"Do not encode metadata beyond the reader limit")
	var schema := preload("res://scripts/native_save_schema.gd")
	for number: float in [NAN,INF,-INF]:
		var invalid := baseline.duplicate(true); invalid.legacy_archive = {"nested":{"value":number}}
		check(not state.load_game_data(invalid),"Reject non-finite nested data")
	var cycle: Dictionary = {};cycle["self"] = cycle
	check(not schema.safe_tree(cycle),"Reject cycles before duplicating state")
	cycle.erase("self")
	var object := Node.new()
	check(not schema.safe_tree({"object":object}),"Reject scene objects")
	object.free()
	var deep: Dictionary = {};var current: Dictionary = deep
	for i: int in range(70): current["child"]={};current=current.child
	check(not schema.safe_tree(deep),"Reject excessive depth")
	check(not schema.safe_tree({"oversize":"x".repeat(schema.MAX_BYTES+1)}),"Reject excessive text")
	var huge := FileAccess.open("user://oversize.json",FileAccess.WRITE)
	huge.seek(schema.MAX_BYTES);huge.store_8(32);huge.close()
	check(preload("res://scripts/save_repository.gd").read("user://oversize.json") == null,"Reject oversized files before parse")
	check(not preload("res://scripts/save_repository.gd").write("user://deep-valid.json",{"text":"x".repeat(schema.MAX_BYTES)}),"Do not write a save larger than the reader supports")
	check(FileAccess.get_file_as_string("user://deep-valid.json") == before_disk,"Oversized write preserves valid save")
	check(not state._import_external_save_to_paths({"version":31,"plots":baseline.plots,"inventory":{},"storage":[]},"user://rejected.json","user://untouched-recovery.json","user://untouched-backup.json"),"Refuse damaged imports")
	check(not FileAccess.file_exists("user://untouched-recovery.json") and not FileAccess.file_exists("user://untouched-backup.json"),"Do not overwrite recovery files on rejection")
	print("Deep native save: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
