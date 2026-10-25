extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
var cases := 0
var categories:Dictionary={}
var variants:Dictionary={}
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=25:push_error("FAIL "+label)
func compare(actual: Variant,expected: Variant,label: String) -> void:
	if expected==null:
		check(actual==null or (actual is Dictionary and actual.is_empty()),label+" null")
	elif actual is Dictionary and expected is Dictionary:
		check(actual.size()==expected.size(),label+" exact field count")
		for field in expected:
			check(actual.has(field),label+"/"+str(field)+" exists")
			if actual.has(field):compare(actual[field],expected[field],label+"/"+str(field))
	elif actual is Array and expected is Array:
		check(actual.size()==expected.size(),label+" length")
		for i in range(mini(actual.size(),expected.size())):compare(actual[i],expected[i],label+"/"+str(i))
	elif (actual is int or actual is float) and (expected is int or expected is float):
		check(float(actual)==float(expected),label+" exact number")
	else:check(typeof(actual)==typeof(expected) and actual==expected,label+" value")
func _run() -> void:
	var state=root.get_node("GameState")
	state.set_process(false)
	var path:=OS.get_environment("ATLAS_TARGETS_FIXTURE")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	while not file.eof_reached():
		var line:=file.get_line()
		if line.is_empty():continue
		var row:Dictionary=SAVE_JSON.decode(JSON.parse_string(line))
		check(state.load_game_data(state.convert_external_save(row.before)),"source atlas input loaded")
		var label:=str(row.day)+"/"+str(row.variant)
		var targets:Array=state.atlas_targets()
		compare(targets,row.targets,label+"/all targets in source order")
		for probe in row.resolves:compare(state.atlas_resolve(probe.input),probe.expected,label+"/resolve")
		for probe in row.clicks:compare(state.atlas_click_point(float(probe.x),float(probe.y),str(probe.layer)),probe.expected,label+"/layer click")
		for target in targets:categories[target.type]=int(categories.get(target.type,0))+1
		var key:=str(int(row.variant));variants[key]=int(variants.get(key,0))+1
		cases+=1
	var counts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
	check(cases==int(counts.cases),"independent case count")
	for key in counts.categories:check(int(categories.get(key,0))==int(counts.categories[key]),"independent category "+str(key))
	for key in counts.variants:check(int(variants.get(key,0))==int(counts.variants[key]),"independent variant "+str(key))
	await root.get_node("AudioService").prepare_exit()
	print("Full source atlas targets: %d cases, %d passed, %d failed; %s" % [cases,passed,failed,JSON.stringify(categories)])
	quit(1 if failed else 0)
