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
	elif b is Array:
		check(a is Array,label+"/type")
		if not a is Array:return
		check(a.size()==b.size(),label+"/length")
		for i in range(mini(a.size(),b.size())):same(a[i],b[i],label+"/"+str(i))
	elif b is float or b is int:
		check((a is float or a is int) and float(a)==float(b),label+" got "+str(a)+" expected "+str(b))
	else:check(a==b,label+" got "+str(a)+" expected "+str(b))
func spatial(state: Node,expected: Dictionary,label: String) -> void:
	same(state.day,expected.day,label+"/day")
	same(state.minutes,expected.minutes,label+"/minutes")
	same(state.stamina,expected.stamina,label+"/stamina")
	same(state.current_interior,"" if expected.room==null else expected.room,label+"/room")
	same(state.riding,expected.riding,label+"/riding")
	same(state.interior_return_source,expected.back,label+"/return point")
	var point: Dictionary=state.player_navigation_position()
	same(point.x,expected.player.x,label+"/x")
	same(point.y,expected.player.y,label+"/y")
	# Missing direction on a bare house door uses the same down-facing renderer default.
	same(state.player_direction,expected.player.get("direction","down"),label+"/direction")
	same(state.npc_residents,expected.npc,label+"/residents")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	var state=root.get_node("GameState")
	state.set_process(false)
	var file=FileAccess.open(OS.get_environment("PLAYER_SPATIAL_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	var steps:=0
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=CODEC.parse(line)
		check(state.load_game_data(state.convert_external_save(row.before)),"source state loaded")
		# These probes operate on original live state, before C.load normalizes direction/back.
		state.current_interior="" if row.before.village.interior==null else str(row.before.village.interior)
		state.set_player_navigation_position(row.before.player)
		state.interior_return_source=row.before.village.returnPoint.duplicate(true) if row.before.village.returnPoint is Dictionary else null
		state.riding=bool(row.before.village.riding)
		state.npc_residents=row.before.village.npc.duplicate(true)
		for sample in row.samples:
			var operation:=str(sample.operation)
			if operation=="enter":same(state.enter_room_state(str(sample.house)),sample.result,str(row.label)+"/enter")
			elif operation=="leave":same(state.leave_room_state(),sample.result,str(row.label)+"/leave")
			else:
				state.advance_day()
				same(state.message,sample.result.msg,str(row.label)+"/message")
			spatial(state,sample.expected,str(row.label)+"/"+str(steps))
			steps+=1
		check(state.save_game("user://player-spatial-roundtrip.json",true),"write spatial file")
		var stored_position: Dictionary=state.player_navigation_position()
		var stored_back: Variant=state.interior_return_source.duplicate(true) if state.interior_return_source is Dictionary else null
		check(state.load_game("user://player-spatial-roundtrip.json"),"load spatial file")
		same(state.player_navigation_position(),stored_position,"file spatial position")
		same(state.interior_return_source,stored_back,"file return point")
		cases+=1
		if cases%100==0:print("Spatial source progress: ",cases)
	var counts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PLAYER_SPATIAL_FIXTURE")+".counts.json"))
	check(cases==int(counts.cases),"case count")
	check(steps==int(counts.steps),"step count")
	await root.get_node("AudioService").prepare_exit()
	print("Player spatial source: %d cases, %d steps, %d passed, %d failed" % [cases,steps,passed,failed])
	quit(1 if failed else 0)
