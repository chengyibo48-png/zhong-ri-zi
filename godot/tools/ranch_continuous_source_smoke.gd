extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<25:push_error(label)
func compare(a: Variant,b: Variant,label: String) -> void:
	if b is Dictionary:
		check(a is Dictionary,label+"/type")
		if not a is Dictionary:return
		check(a.size()==b.size(),label+"/keys")
		for k in b:
			check(a.has(k),label+"/"+str(k)+"/present")
			if a.has(k):compare(a[k],b[k],label+"/"+str(k))
	elif b is Array:
		check(a is Array,label+"/type")
		if not a is Array:return
		check(a.size()==b.size(),label+"/length")
		for i in range(mini(a.size(),b.size())):compare(a[i],b[i],label+"/"+str(i))
	elif b is float or b is int:
		check((a is float or a is int) and float(a)==float(b),label+" got "+str(a)+" expected "+str(b))
	else:check(a==b,label+" got "+str(a)+" expected "+str(b))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	var state=root.get_node("GameState")
	state.set_process(false)
	var file=FileAccess.open(OS.get_environment("RANCH_CONTINUOUS_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	var frames:=0
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=CODEC.parse(line)
		check(state.load_game_data(state.convert_external_save(row.before)),"state loaded")
		state.animals.assign(row.before.animals.duplicate(true))
		state.ranch=row.before.ranch.duplicate(true)
		state.current_interior=""
		state.player_position=Vector2(row.before.player.x,row.before.player.y)
		state.ranch_actor_focus={} if row.focus==null else row.focus.duplicate(true)
		if str(row.mode)=="held":state.hold_ranch_actor(str(state.animals[0].id))
		if str(row.mode)=="pet-held":state.hold_ranch_actor("pet")
		if str(row.mode)=="sequence":state.action_sequence.active={"animalId":str(state.animals[0].id)}
		if state.ranch_movement==null:state.ranch_movement=state.RANCH_MOVEMENT_SCRIPT.new()
		for sample in row.samples:
			var patch: Dictionary=sample.get("patch",{})
			if patch.has("minutes"):state.minutes=int(patch.minutes)
			if patch.has("petMode"):state.ranch.pet.mode=patch.petMode
			if patch.has("focus"):state.ranch_actor_focus=patch.focus.duplicate(true)
			if patch.has("sequence"):state.action_sequence.active={} if patch.sequence==null else patch.sequence.duplicate(true)
			if patch.has("animals"):state.animals.assign(patch.animals.duplicate(true))
			state.advance_ranch_movement(float(sample.dt))
			# GameState advances village/NPC time after ranch movement in the same frame.
			state.npc_movement.clock+=float(sample.dt)
			var label=str(row.type)+"/"+str(row.mode)+"/"+str(frames)
			compare(state.ranch_actor_clock,sample.clock,label+"/clock")
			compare(state.npc_movement.clock,sample.villageClock,label+"/village clock")
			compare(state.ranch_movement.actors,sample.actors,label+"/actors")
			var positions: Array=[]
			for animal in state.animals:positions.append(animal.position)
			compare(positions,sample.positions,label+"/positions")
			compare(state.ranch.pet.position,sample.pet,label+"/pet")
			frames+=1
		state.action_sequence.active.clear()
		cases+=1
		if cases%12==0:print("Ranch continuous progress: ",cases)
	var counts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RANCH_CONTINUOUS_FIXTURE")+".counts.json"))
	check(cases==int(counts.cases),"case count")
	check(frames==int(counts.frames),"frame count")
	await root.get_node("AudioService").prepare_exit()
	print("Ranch continuous source: %d cases, %d frames, %d passed, %d failed" % [cases,frames,passed,failed])
	quit(1 if failed else 0)
