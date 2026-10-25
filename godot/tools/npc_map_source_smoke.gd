extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
var queries := 0
var regions := 0
var seed: Dictionary = {}
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 25: push_error("FAIL "+label)
func compare(actual: Variant, expected: Variant, label: String) -> void:
	if actual is Dictionary and expected is Dictionary:
		for field in expected:
			check(actual.has(field),label+"/"+str(field)+" exists")
			if actual.has(field):
				var value: Variant=actual.get("target_point",actual[field]) if field=="target" else actual[field]
				compare(value,expected[field],label+"/"+str(field))
	elif actual is Array and expected is Array:
		check(actual.size()==expected.size(),label+" length")
		for i in range(mini(actual.size(),expected.size())):compare(actual[i],expected[i],label+"/"+str(i))
	elif (actual is int or actual is float) and (expected is int or expected is float):
		check(float(actual)==float(expected),label+" exact number")
	else:check(typeof(actual)==typeof(expected) and actual==expected,label+" value")
func _run() -> void:
	var state = root.get_node("GameState")
	state.set_process(false)
	var path := OS.get_environment("NPC_MAP_FIXTURE")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():continue
		var row: Dictionary=SAVE_JSON.decode(JSON.parse_string(line))
		if row.kind=="seed":
			seed=row.before.duplicate(true)
			check(state.load_game_data(state.convert_external_save(seed)),"source seed imported")
		elif row.kind=="bounds":
			check(state.atlas_region_bounds(str(row.id))==Rect2(float(row.x),float(row.y),float(row.width),float(row.height)),"source region draw bounds")
		elif row.kind=="region":
			check(state.atlas_region_point(float(row.x),float(row.y))==str(row.expected),"source region boundary")
			regions+=1
		else:
			state.day=int(row.day);state.minutes=float(row.minutes);state.collection.level=int(row.level)
			state.npc_residents[row.id]=row.resident.duplicate(true)
			state.npc_movement.actors[row.id]={"walking":bool(row.walking)}
			var person:Dictionary={}
			for n in state.npc_catalog:
				if str(n.id)==str(row.id):person=n;break
			var label := str(row.id)+"/"+str(row.scenario)+"/"+str(row.walking)
			compare(state.npc_location(str(row.id)),row.expected.location,label+"/location")
			compare(state.npc_scene_region(str(row.id)),row.expected.scene,label+"/scene")
			compare(state.npc_destination(str(row.id)),row.expected.destination,label+"/find destination")
			compare(state.atlas_npc_target(person),row.expected.atlas,label+"/map target")
			var targets:Array=state.atlas_targets()
			var found:Dictionary={}
			for t in targets:
				if str(t.id)=="neighbor-"+str(row.id):found=t;break
			compare(found,row.expected.atlas,label+"/full map")
			queries+=1
	var counts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
	check(queries==int(counts.queries),"independent query count")
	check(regions==int(counts.regions),"independent region count")
	await root.get_node("AudioService").prepare_exit()
	print("NPC source location and map: %d queries, %d boundaries, %d passed, %d failed" % [queries,regions,passed,failed])
	quit(1 if failed else 0)
