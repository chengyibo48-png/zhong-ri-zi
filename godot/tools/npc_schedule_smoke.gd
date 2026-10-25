extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules = load("res://scripts/npc_schedule.gd")
	var state = root.get_node("GameState")
	state.set_process(false)
	var content: Dictionary = state.content
	var systems: Dictionary = state.system_catalog
	var people: Array = content.get("npcs", [])
	var profiles: Dictionary = systems.get("npc", {}).get("profiles", {})
	var works: Dictionary = systems.get("npc", {}).get("workpoints", {})
	for npc_index in range(people.size()):
		var person: Dictionary = people[npc_index]
		_check(works.has(str(person.id)) and profiles.has(str(person.id)), "原版为 %s 导出行程资料" % str(person.id))
	var granny: Dictionary = people[0]
	var home := Vector2(2493.76, 1356.0)
	var work := Vector2(float(works.granny.x), float(works.granny.y))
	var plan: Dictionary = rules.activity(granny, 0, 0, 400, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "night", "清晨尚未起床时留在家中")
	plan = rules.activity(granny, 0, 0, 450, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "morning", "起床后先整理手边事务")
	plan = rules.activity(granny, 0, 0, 600, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "work" and plan.target.distance_to(work) < 1.0, "平日工作计划使用原版位置")
	plan = rules.activity(granny, 0, 0, 600, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭", true)
	_check(str(plan.key) == "housework" and bool(plan.indoors), "未完成的邻里小事会让年长村民回家处理")
	var qiao: Dictionary = people[1]
	var qiao_home := Vector2(3517.76, 1356.0)
	plan = rules.activity(qiao, 1, 0, 740, false, qiao_home, Vector2(float(works.qiao.x), float(works.qiao.y)), Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "lunch", "不同村民午休时间错开")
	var child: Dictionary = people[20]
	plan = rules.activity(child, 20, 0, 600, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "school", "工作日儿童前往学校")
	var xu: Dictionary = people[4]
	plan = rules.activity(xu, 4, 5, 600, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "夏夜纳凉会")
	_check(str(plan.key) == "market", "每周赶集日相关居民前往老街")
	plan = rules.activity(granny, 0, 13, 700, false, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "festival", "节令当天居民前往聚会")
	plan = rules.activity(granny, 0, 0, 600, true, home, work, Vector2(2189.8, 284), Vector2(2623.12, 552), home, "", false, "春日邻里饭")
	_check(str(plan.key) == "shelter" and bool(plan.indoors), "恶劣天气切换室内避险")
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	await process_frame
	_check(world.npc_nodes.size() == 24, "村庄实例化全部二十四位村民")
	var reachable_workplaces := 0
	for npc in world.npc_nodes:
		var route: Array = state.npc_movement.navigation.route(state, "", state.npc_residents[str(npc.npc_id)], works[str(npc.npc_id)])
		if not route.is_empty():
			reachable_workplaces += 1
	_check(reachable_workplaces == 24, "全部村民的工作地点均有避障路径")
	state.day = 0
	state.minutes = 600
	world.npc_schedule_stamp = ""
	world._refresh_npc_schedules()
	var moving_npc = world.npc_nodes[1]
	_check(str(moving_npc.schedule_key) == "work", "村民节点接收当前工作计划")
	_check(not moving_npc.path.is_empty(), "村民获得避开建筑与水域的路径")
	var start_position: Vector2 = moving_npc.global_position
	state.player_position = Vector2(24,38)
	state.npc_residents.qiao.room = null
	state.advance_npc_movement(0.5)
	moving_npc.present_resident(state)
	_check(moving_npc.global_position.distance_to(start_position) > 1.0, "村民沿寻路结果实际移动")
	var saved_level := int(state.collection.get("level", 0))
	state.minutes = 930.0
	state.collection.level = 0
	world._refresh_npc_schedules()
	var he_actor: Node2D
	for npc in world.npc_nodes:
		if str(npc.npc_id) == "he": he_actor = npc
	_check(str(he_actor.schedule_key) == "work", "展馆未升至二级时沿用工作安排")
	state.collection.level = 2
	world._refresh_npc_schedules()
	_check(str(he_actor.schedule_key) == "museum", "同一分钟升级展馆立即刷新室外访客安排")
	state.minutes = 1080.0
	world._refresh_npc_schedules()
	_check(str(he_actor.schedule_key) == "museum", "参观窗口包含十八点整")
	state.minutes = 1080.25
	world._refresh_npc_schedules()
	_check(str(he_actor.schedule_key) == "evening", "越过参观窗口后同一分钟立即结束参观")
	state.collection.level = saved_level
	var previous_interior := str(state.current_interior)
	var interior_profiles: Dictionary = systems.get("interiors", {}).get("profiles", {})
	var interior_world = load("res://scripts/interior_world.gd").new()
	var personal_prop_indices: Array[int] = [4, 6, 8]
	for npc_index in range(people.size()):
		var person: Dictionary = people[npc_index]
		var npc_id := str(person.get("id", ""))
		var profile_data: Variant = interior_profiles.get(npc_id, [])
		if not profile_data is Array or profile_data.size() <= 8:
			_check(false, "%s 有三件原版室内纪念物" % npc_id)
			continue
		state.current_interior = "home-" + npc_id
		var activity: Dictionary = interior_world._room_activity(npc_id, {"key": "housework"}, npc_index, 0)
		var expected_prop := str(profile_data[personal_prop_indices[posmod(npc_index, personal_prop_indices.size())]])
		_check(str(activity.get("label", "")).contains(expected_prop), "%s 会在家中照看自己的%s" % [str(person.get("name", npc_id)), expected_prop])
	var previous_minutes := int(state.minutes)
	state.current_interior = "home-granny"
	state.minutes = 450
	state.interior_position = Vector2(113,205)
	state.advance_npc_movement(0.25)
	var interior_scene = load("res://scenes/interior.tscn").instantiate()
	root.add_child(interior_scene)
	await process_frame
	_check(interior_scene.owner_npc != null, "进入住户家中时会实例化屋主")
	state.interior_position = Vector2(113,205)
	interior_scene.set_process(false)
	interior_scene.player.set_physics_process(false)
	state.advance_npc_movement(0.25)
	interior_scene._sync_room_residents()
	interior_scene._publish_npc_positions()
	_check(str(interior_scene.owner_npc.schedule_label) == str(rules.from_state(state, granny).label) and not state.npc_movement.actors.granny.insideRt.path.is_empty(), "屋主按原版活动沿室内路径移动")
	var previous_interior_position: Vector2 = state.interior_position
	var previous_collection_level := int(state.collection.get("level", 0))
	state.interior_position = interior_scene.owner_npc.global_position
	_check(state.npc_is_near("granny"), "室内屋主按房间位置允许面对面互动")
	_check(not state.npc_is_near("qiao"), "室外村民不会借用室外坐标在房间里互动")
	interior_scene.queue_free()
	await process_frame
	state.current_interior = "building-river-10"
	state.collection.level = 2
	state.minutes = 930
	var museum_door: Dictionary = systems.museum.house.door
	state.npc_residents.he = {"x":float(museum_door.x),"y":float(museum_door.y)+10.0,"direction":"up","room":null}
	state.npc_movement.actors.erase("he")
	state.interior_position = Vector2(113,205)
	state.advance_npc_movement(0.25)
	var museum_scene = load("res://scenes/interior.tscn").instantiate()
	root.add_child(museum_scene)
	await process_frame
	museum_scene.set_process(false)
	museum_scene.player.set_physics_process(false)
	_check(museum_scene.visitor_npc != null, "轮值访客实际走进展馆后出现")
	if museum_scene.visitor_npc != null:
		state.interior_position = museum_scene.visitor_npc.global_position
		_check(state.npc_is_near("he"), "展馆访客按馆内位置允许面对面互动")
		state.minutes = 1081
		state.interior_position = Vector2(113,205)
		state.advance_npc_movement(2.0)
		museum_scene._sync_museum_visitor()
		museum_scene._publish_npc_positions()
		_check(not state.npc_is_near("he"), "访客离场后不能在馆内继续远程互动")
	museum_scene.queue_free()
	state.collection.level = previous_collection_level
	state.interior_position = previous_interior_position
	state.current_interior = previous_interior
	state.interior_npc_positions.clear()
	state.minutes = previous_minutes
	interior_world.free()
	world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("NPC schedule migration: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
