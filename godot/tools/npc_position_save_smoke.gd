extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
var rows := 0
var files := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 20: push_error("FAIL "+label)

func compare(actual: Dictionary, expected: Dictionary, label: String) -> void:
	check(actual.size()==expected.size(),label+" population")
	for id in expected:
		check(actual.has(id),label+" "+str(id))
		if not actual.has(id): continue
		var p: Dictionary = actual[id]; var q: Dictionary = expected[id]
		check(p.size()==q.size(),label+" saved fields "+str(id))
		for field in ["room","direction"]: check(p.get(field)==q.get(field),label+" "+str(id)+" "+field)
		for field in ["x","y"]: check(absf(float(p[field])-float(q[field]))<0.00000001,label+" "+str(id)+" "+field)

func _run() -> void:
	var state = root.get_node("GameState")
	state.set_process(false)
	var path := OS.get_environment("NPC_POSITION_FIXTURE")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit(); quit(1); return
	var base: Dictionary
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = SAVE_JSON.decode(JSON.parse_string(line))
		if str(row.type)=="base": base=row.before; continue
		var source := base.duplicate(true)
		source.day=int(row.day); source.minutes=float(row.minutes); source.village.npc=row.input
		check(state.load_game_data(state.convert_external_save(source)),"browser position import")
		compare(state.npc_residents,row.expected,str(rows)+" imported")
		check(state.npc_movement.clock==0.0 and state.npc_movement.actors.is_empty(),"runtime resets on load")
		var saved: Dictionary = state._make_save_data().duplicate(true)
		check(saved.has("npc_residents"),"positions serialized")
		check(state.load_game_data(saved),"memory load without aliasing")
		compare(state.npc_residents,row.expected,str(rows)+" memory")
		if rows%33==0:
			var save_path := "user://npc-position-%d.json" % rows
			var exact_before: Dictionary = state.npc_residents.duplicate(true)
			check(state.save_game(save_path,true),"native file write")
			check(state.load_game(save_path),"native file read")
			check(state.npc_residents==exact_before,"exact native numeric roundtrip")
			files+=1
		state._reset_npc_morning()
		compare(state.npc_residents,row.morning,str(rows)+" dawn reset")
		check(state.npc_movement.clock==0.0 and state.npc_movement.actors.is_empty(),"runtime resets at dawn")
		rows+=1
	var counts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
	check(rows==int(counts.rows),"independent row count")
	await root.get_node("AudioService").prepare_exit()
	print("NPC original position load/save: %d rows, %d files, %d passed, %d failed" % [rows,files,passed,failed])
	quit(1 if failed else 0)
