extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=25:push_error(label)
func same(a: Variant,b: Variant,label: String) -> void:
	if b is Dictionary:
		check(a is Dictionary,label+"/type")
		if not a is Dictionary:return
		check(a.size()==b.size(),label+"/keys")
		for k in b:
			check(a.has(k),label+"/"+str(k)+"/present")
			if a.has(k):same(a[k],b[k],label+"/"+str(k))
	elif b is float or b is int:
		check((a is float or a is int) and float(a)==float(b),label+" got "+str(a)+" expected "+str(b))
	else:check(a==b,label+" got "+str(a)+" expected "+str(b))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	var state=root.get_node("GameState")
	state.set_process(false)
	var file=FileAccess.open(OS.get_environment("PLAYER_ROOM_IMPORT_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=CODEC.parse(line)
		check(state.load_game_data(state.convert_external_save(row.before)),str(row.label)+"/load")
		same(state.current_interior,row.expected.room,str(row.label)+"/room")
		same(state.player_navigation_position(),row.expected.player,str(row.label)+"/player")
		same(state.interior_return_source,row.expected.back,str(row.label)+"/back")
		same(state.riding,row.expected.riding,str(row.label)+"/riding")
		check(not state._make_save_data().has("_restore_source_player"),"transient restore flag not saved")
		cases+=1
	await root.get_node("AudioService").prepare_exit()
	print("Player room import source: %d cases, %d passed, %d failed" % [cases,passed,failed])
	quit(1 if failed else 0)
