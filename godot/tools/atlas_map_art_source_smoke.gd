extends SceneTree
const SAVE_JSON=preload("res://scripts/save_json.gd")
const MAP_ART=preload("res://scripts/atlas_map_art.gd")
var passed:=0
var failed:=0
var cases:=0
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=20:push_error("FAIL "+label)
func _run() -> void:
	var state=root.get_node("GameState")
	state.set_process(false)
	var path:=OS.get_environment("ATLAS_ART_FIXTURE")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit();quit(1);return
	while not file.eof_reached():
		var line:=file.get_line()
		if line.is_empty():continue
		var row:Dictionary=SAVE_JSON.decode(JSON.parse_string(line))
		check(state.load_game_data(state.convert_external_save(row.before)),"source map art state loaded")
		var fills:Array=MAP_ART.rectangles(state)
		check(fills.size()==row.fills.size(),"source rectangle count")
		for i in range(mini(fills.size(),row.fills.size())):
			var actual:Dictionary=fills[i]
			var expected:Dictionary=row.fills[i]
			for key in ["x","y","w","h","alpha"]:check(float(actual[key])==float(expected[key]),str(i)+"/"+key+" exact map rectangle")
			check(str(actual.color)==str(expected.color),str(i)+" source color")
		cases+=1
	var counts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".counts.json"))
	check(cases==int(counts.cases),"independent art case count")
	await root.get_node("AudioService").prepare_exit()
	print("Source Canvas atlas world rectangles: %d cases, %d passed, %d failed" % [cases,passed,failed])
	quit(1 if failed else 0)
