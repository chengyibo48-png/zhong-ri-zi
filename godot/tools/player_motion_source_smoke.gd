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
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	var state=root.get_node("GameState")
	state.set_process(false)
	var world=Node2D.new()
	root.add_child(world)
	var player=load("res://scripts/player.gd").new()
	world.add_child(player)
	player.set_physics_process(false)
	var file=FileAccess.open(OS.get_environment("PLAYER_MOTION_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	var frames:=0
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=CODEC.parse(line)
		check(state.load_game_data(state.convert_external_save(row.before)),"state load")
		state.current_interior="" if row.room==null else str(row.room)
		state.set_player_navigation_position(row.before.player)
		player.global_position=Vector2(row.before.player.x,row.before.player.y)
		player.walk_source_path=row.initialPath.duplicate(true)
		player.walk_index=0
		var shift_event:=InputEventKey.new()
		shift_event.keycode=KEY_SHIFT
		shift_event.pressed=str(row.speed)=="shift"
		Input.parse_input_event(shift_event)
		Input.flush_buffered_events()
		check(Input.is_key_pressed(KEY_SHIFT)==(str(row.speed)=="shift"),"actual shift input applied")
		for sample in row.samples:
			var label=str(row.room)+"/"+str(row.weather)+"/"+str(row.speed)+"/"+str(row.mode)+"/"+str(frames)
			same(state.player_movement_rate(bool(sample.fast)),sample.rate,label+"/rate")
			if str(row.mode)=="frame":
				# Actual physics callback, with no keyboard input and a static ground-click route.
				player.walk_path.clear()
				for point in player.walk_source_path:player.walk_path.append(Vector2(point.x,point.y))
				player.walk_index=0
				if not player.walk_source_path.is_empty():state.walking_target={"kind":"walk","name":"frame route"}
				player._physics_process(float(sample.dt))
				same(state.minutes,sample.minutes,label+"/minutes")
			else:
				var walking: bool=player._move_source(float(sample.dt),float(sample.input[0]),float(sample.input[1]),bool(sample.fast),str(row.mode)=="path")
				same(walking,sample.walking,label+"/walking")
			same(state.player_navigation_position(),sample.p,label+"/position")
			same(player.walk_source_path,sample.path,label+"/path")
			var saved: Dictionary=state._make_save_data()
			if state.current_interior=="":
				same(saved.player,sample.p,label+"/saved player")
			else:
				same(saved.interior_position,{"x":sample.p.x,"y":sample.p.y},label+"/saved interior")
			check(player.global_position==Vector2(sample.p.x,sample.p.y),label+"/scene projection")
			frames+=1
		var final_position: Dictionary=state.player_navigation_position()
		check(state.save_game("user://player-motion-source-roundtrip.json",true),"write actual file")
		check(state.load_game("user://player-motion-source-roundtrip.json"),"read actual file")
		same(state.player_navigation_position(),final_position,"file roundtrip position")
		cases+=1
		if cases%20==0:print("Player source progress: ",cases)
	var counts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PLAYER_MOTION_FIXTURE")+".counts.json"))
	check(cases==int(counts.cases),"case count")
	check(frames==int(counts.frames),"frame count")
	var shift_release:=InputEventKey.new()
	shift_release.keycode=KEY_SHIFT
	shift_release.pressed=false
	Input.parse_input_event(shift_release)
	Input.flush_buffered_events()
	world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Player source movement: %d cases, %d frames, %d passed, %d failed" % [cases,frames,passed,failed])
	quit(1 if failed else 0)
