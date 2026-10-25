extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("FAIL "+label)
func freeze(scene: Node) -> void:
	scene.set_process(false)
	scene.player.set_physics_process(false)
func _run() -> void:
	var state=root.get_node("GameState")
	state.set_process(false)
	var file:=FileAccess.open(OS.get_environment("NPC_MAP_FIXTURE"),FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	var seed:Dictionary=SAVE_JSON.decode(JSON.parse_string(file.get_line())).before
	check(state.load_game_data(state.convert_external_save(seed)),"source save loaded")
	state.current_interior=""
	state.day=1;state.minutes=600.0
	state.player_position=Vector2(2831,1652)
	state.npc_residents.qiao={"x":2931.25,"y":1652.5,"room":null,"direction":"left"}
	state.npc_movement.actors.qiao={"walking":true}
	state.npc_movement.publish(state)
	var world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world);current_scene=world
	freeze(world)
	await process_frame
	world.hud.show_neighbors("qiao")
	var journal=world.hud.neighbor_journal
	var location:Dictionary=state.npc_location("qiao")
	check(journal.profile_label.text.contains(str(location.place)) and journal.profile_label.text.contains(str(location.activity)),"journal shows actual location and walking")
	check(journal.profile_label.text.contains(str(location.reason)),"journal shows schedule reason")
	check(journal.find_button.text=="去找对方" and journal.find_button.visible,"find button present")
	journal.find_button.pressed.emit()
	check(not world.hud.neighbors_open() and not state.ui_open,"find button closes paused UI")
	check(str(state.walking_target.get("id",""))=="qiao" and str(state.walking_target.get("kind",""))=="npc","find uses source NPC destination")
	check(float(state.walking_target.get("x",0))==2931.25,"find uses current coordinate")
	state.npc_residents.qiao.x=2971.25
	var targets:Array=world.player._current_navigation_targets()
	check(targets.size()==1 and float(targets[0].x)==2971.25,"moving find target refreshed by identity")
	check(world.player._matches_navigation_target(targets[0]),"moving target resolves")
	var home:Dictionary=state.house_data("home-qiao")
	state.npc_residents.qiao.room=home.id
	targets=world.player._current_navigation_targets()
	check(targets.size()==1 and str(targets[0].house)==str(home.id),"entered NPC redirects find toward own home")
	check(world.player._matches_navigation_target(targets[0]),"NPC changing to door with different id still resolves")
	state.stop_walking()
	var museum:Dictionary=state.system_catalog.museum.house
	state.npc_residents.qiao.room=museum.id
	state.npc_movement.actors.qiao.walking=false
	world.hud.show_map()
	var map=world.hud.map_panel
	map.selected_id="neighbor-qiao"
	map.custom_target.clear()
	map.refresh()
	var map_target:Dictionary=map._selected_target()
	check(str(map_target.get("house",""))==str(museum.id),"map selects actual museum room while find retains own home")
	check(float(map_target.get("x",0))==float(museum.door.x),"map room marker uses actual entrance coordinate")
	check(map.detail_label.text.contains(str(state.npc_location("qiao").reason)),"map detail includes actual activity reason")
	map.go_button.pressed.emit()
	check(not map.visible and str(state.walking_target.get("house",""))==str(museum.id),"actual map departure button starts route to museum entrance")
	state.stop_walking()
	state.npc_residents.qiao={"x":2831.0,"y":1652.0,"room":null,"direction":"left"}
	state.npc_movement.publish(state)
	world.player.global_position=Vector2(2831,1652)
	for npc in world.npc_nodes:npc.present_resident(state)
	check(state.find_npc("qiao"),"nearby find route starts")
	world.player.global_position=Vector2(2831,1652)
	world.player.walk_index=world.player.walk_path.size()
	world.player._walking_direction(0.01)
	await process_frame
	check(state.action_busy(),"arriving at person starts greeting instead of stopping silently")
	for i in range(35):state._process_action(0.1)
	await process_frame
	check(world.hud.npc_dialogue.visible and state.ui_open,"arrival greeting opens actual resident dialogue")
	world.hud.close_top_panel()
	state.stop_walking()
	state.npc_residents.qiao.room=home.id
	state.player_position=Vector2(home.door.x,home.door.y)
	check(state.enter_interior(str(home.id)),"actual room entered")
	await process_frame
	await process_frame
	var interior=current_scene
	freeze(interior)
	interior.hud.show_neighbors("qiao")
	check(state.find_npc("qiao"),"source find in same house starts an outdoor destination")
	check(not state.ui_open and interior.player.walk_is_exit and str(state.walking_target.get("house",""))==str(home.id),"same-house find leaves first as original navigate")
	state.stop_walking()
	state.npc_residents.qiao.room=null
	state.npc_residents.qiao.x=2831.25;state.npc_residents.qiao.y=1652.5
	interior.hud.show_neighbors("qiao")
	check(state.find_npc("qiao"),"indoor find can start toward outside resident")
	check(interior.player.walk_is_exit,"indoor find starts with exit route")
	check(str(state.walking_target.get("id",""))=="qiao","exit retains final resident destination")
	state.stop_walking()
	current_scene=null
	interior.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("NPC find UI and room navigation: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
