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
	var file=FileAccess.open(OS.get_environment("PLAYER_CHASE_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	var frames:=0
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=CODEC.parse(line)
		check(state.load_game_data(state.convert_external_save(row.before)),"state loaded")
		state.set_player_navigation_position(row.before.player)
		player.global_position=state.player_position
		state.walking_target=row.initial.duplicate(true)
		player.walk_chase_at=0.0
		player.walk_is_exit=false
		player.walk_source_path=row.initialPath.duplicate(true)
		for sample in row.samples:
			if str(row.kind)=="npc":state.npc_residents[str(row.id)]=sample.actor.duplicate(true)
			else:state.animals[0].position=sample.actor.duplicate(true)
			player._recheck_source_target(float(sample.now))
			var label=str(row.kind)+"/"+str(row.scenario)+"/"+str(frames)
			same(player.walk_chase_at,sample.chaseAt,label+"/chaseAt")
			same(player.walk_source_path,sample.path,label+"/path")
			same(state.walking_target,sample.pending,label+"/pending")
			frames+=1
		cases+=1
	world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Player chase source: %d cases, %d frames, %d passed, %d failed" % [cases,frames,passed,failed])
	quit(1 if failed else 0)
