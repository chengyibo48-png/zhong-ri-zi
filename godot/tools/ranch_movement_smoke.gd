extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _point(p: Dictionary) -> Vector2:
	return Vector2(float(p.get("x",0)),float(p.get("y",0)))
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1); return
	create_timer(80).timeout.connect(func(): quit(1))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RANCH_MOVEMENT_FIXTURE")))
	if not raw is Dictionary: quit(1); return
	var fixture: Dictionary = raw
	var state = load("res://scripts/game_state.gd").new()
	state._load_content(); state._load_initial_state()
	var movement = load("res://scripts/ranch_movement.gd").new()
	var visual = load("res://scripts/ranch_visual.gd")
	for row in fixture.visuals:
		_check(JSON.parse_string(JSON.stringify(visual.appearance(row.a,state.system_catalog.ranch,float(row.clock),row.pose))) == JSON.parse_string(JSON.stringify(row.expected)),"原版动物外观状态 "+str(row.a.type)+"/"+str(row.expected.direction))
	for row in fixture.effects:
		var actual: Array = visual.action_primitives(row.animal,_point(row.at),str(row.action),float(row.age))
		var equal: bool = actual.size()==row.expected.size()
		for i in range(mini(actual.size(),row.expected.size())):
			equal = equal and actual[i].size()==row.expected[i].size()
			for j in range(mini(actual[i].size(),row.expected[i].size())):
				if actual[i][j] is float or actual[i][j] is int: equal = equal and absf(float(actual[i][j])-float(row.expected[i][j]))<0.0001
				else: equal = equal and actual[i][j]==row.expected[i][j]
		_check(equal,"原版操作特效几何 "+str(row.action)+"/"+str(row.animal.type)+"/"+str(row.age))
	var fx := {"id":"hen-test","room":null,"at":5.0}
	_check(visual.action_visible(fx,"hen-test","",7.2),"操作特效包含2.2秒边界")
	_check(not visual.action_visible(fx,"hen-test","",7.201),"操作特效到期消失")
	_check(not visual.action_visible(fx,"hen-test","barn",6),"操作特效不跨房间绘制")
	_check(not visual.action_visible(fx,"other","",6),"只绘制最后操作的动物特效")
	for row in fixture.rules:
		state.day = int(row.day); state.minutes = int(row.minutes); state.ranch.policy = str(row.policy)
		_check(movement.safe_out(state,row.animal) == bool(row.out),"原版出舍 "+str(row.animal.type)+"/"+str(row.variant))
	for row in fixture.trajectories:
		_check(state.load_game_data(state.convert_external_save(row.before)),"原版活动输入 "+str(row.mode))
		if str(row.mode) == "held": state.hold_ranch_actor(str(state.animals[0].id))
		if str(row.mode) == "gather": state.gather_ranch_actors(Vector2(2600,2700))
		for step in row.steps:
			state.advance_ranch_movement(float(step.dt))
			var p: Dictionary = state.animals[0].position
			var expected: Dictionary = step.animal
			_check(p.get("room") == expected.get("room"),"原版房间转换 "+str(row.mode))
			var room := str(p.room) if p.get("room")!=null else ""
			var current: Dictionary = p.get("inside",{}) if room!="" else p
			var goal: Dictionary = expected.get("inside",{}) if room!="" else expected
			if bool(step.animalRoute.direct):
				_check(_point(current).distance_to(_point(goal))<0.06,"原版直达活动轨迹 "+str(row.mode)+" got "+str(_point(current))+" expected "+str(_point(goal)))
				_check(str(current.get("direction","down")) == str(goal.get("direction","down")) and bool(current.get("walking",false)) == bool(goal.get("walking",false)),"原版直达方向和步态 "+str(row.mode))
			else:
				# Both engines now use the original 24 px navigation.
				# Exact per-frame paths are checked by ranch_continuous_source_smoke.
				var runtime: Dictionary = state.ranch_movement.actors[str(state.animals[0].id)]
				_check(_point(runtime.get("target",{})).distance_to(_point(step.animalRoute))<0.06,"原版绕障目标 "+str(row.mode))
				_check(str(current.get("direction","")) in ["up","down","left","right"] and bool(current.get("walking",false)),"绕障仍提供步态与朝向 "+str(row.mode))
			_check(state.ranch_movement.clear(state,room,_point(current)),"动物脚点不穿过房间/世界碰撞 "+str(row.mode))
			var pet: Dictionary = state.ranch.pet.position
			if bool(step.petRoute.direct):
				_check(_point(pet).distance_to(_point(step.pet))<0.06,"原版宠物直达轨迹 "+str(row.mode)+" got "+str(_point(pet))+" expected "+str(_point(step.pet)))
			else:
				_check(_point(state.ranch_movement.actors.pet.get("target",{})).distance_to(_point(step.petRoute))<0.06,"原版宠物绕障目标 "+str(row.mode))
			_check(state.ranch_movement.clear(state,"",_point(pet)),"宠物脚点不穿过世界碰撞")
	# Many frames check paths, bounded travel, grass pen bounds and return to barn.
	state.load_game_data(state.convert_external_save(fixture.trajectories[0].before))
	var frames_ok := true
	for frame in range(300):
		var p: Dictionary = state.animals[0].position
		var before := _point(p)
		state.advance_ranch_movement(0.05)
		var after := _point(p)
		frames_ok = frames_ok and state.ranch_movement.clear(state,"",after) and before.distance_to(after)<=1.901
	_check(frames_ok,"持续游荡每步遵守速度和碰撞")
	var pen: Dictionary = state.system_catalog.forage.pens[0]
	var target: Vector2 = _point(state.ranch_movement.actors[str(state.animals[0].id)].wander)
	_check(target.x>=float(pen.x)+36 and target.x<=float(pen.x)+float(pen.w)-36 and target.y>=float(pen.y)+36 and target.y<=float(pen.y)+float(pen.h)-36,"游荡目标保持草圈内侧")
	state.minutes = 1050
	for frame in range(2400):
		state.advance_ranch_movement(0.1)
		if state.animals[0].position.get("room")!=null: break
	_check(state.animals[0].position.get("room") == state.system_catalog.ranch.barns.poultry.house,"傍晚沿世界碰撞路径返舍")
	state.minutes = 600
	for frame in range(300):
		state.advance_ranch_movement(0.1)
		if state.animals[0].position.get("room")==null: break
	_check(state.animals[0].position.get("room")==null,"白天沿房内出口路径出舍")
	var before_pause: Dictionary = state.animals[0].position.duplicate(true)
	var clock_before := float(state.ranch_actor_clock)
	state.ui_open = true; state.advance_ranch_movement(20)
	_check(state.animals[0].position == before_pause and state.ranch_actor_clock == clock_before,"模态页面暂停活动与时钟")
	state.ui_open = false
	state.hold_ranch_actor(str(state.animals[0].id))
	state.advance_ranch_movement(34)
	_check(state.animals[0].position.x == before_pause.x and state.animals[0].position.y == before_pause.y,"照料定位维持35秒")
	state.advance_ranch_movement(1.1)
	_check(not state.ranch_actor_held(str(state.animals[0].id)),"定位到期恢复活动")
	# Obstacles changed during walking invalidate the movement step without crossing.
	state.load_game_data(state.convert_external_save(fixture.trajectories[0].before))
	state.advance_ranch_movement(0.1)
	var at := _point(state.animals[0].position)
	var new_obstacles: Array[Rect2] = [Rect2(at+Vector2(1,-10),Vector2(15,20))]
	state.atlas_set_dynamic_obstacles(new_obstacles)
	state.advance_ranch_movement(0.1)
	_check(state.ranch_movement.clear(state,"",_point(state.animals[0].position)),"行走途中新增实体障碍仍保持安全脚点")
	state.load_game_data(state.convert_external_save(fixture.trajectories[0].before))
	state.animals.clear()
	state.ranch.pet.mode = "follow"
	var pet_before := _point(state.ranch.pet.position)
	state.advance_ranch_movement(0.1)
	_check(_point(state.ranch.pet.position).distance_to(pet_before)>0.01,"没有家畜时宠物仍独立活动")
	state.free()
	print("Ranch movement smoke: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
