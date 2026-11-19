extends SceneTree
var state: Node
var output: String
var passed := 0
var failed := 0
class Probe extends Node2D:
	func _draw() -> void: draw_rect(Rect2(-6,-34,12,34),Color.MAGENTA)
class Cabinet extends Node2D:
	func _draw() -> void:
		preload("res://scripts/built_furniture_art.gd").draw(self,{"type":"cabinet","rotation":0},Rect2(-44,-44,88,44),720)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL ",label)
func settle() -> void:
	for i in range(8): await process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK,"Capture " + name)
func run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"):
		printerr("Furniture fixture requires an isolated user-data directory")
		quit(1); return
	create_timer(120,true,false,true).timeout.connect(func():quit(1))
	state = root.get_node("GameState"); state.set_process(false)
	output = OS.get_environment("ZRZ_ART_OUTPUT")
	if output == "": output = "user://furniture-art-v4"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	state.flags.introDone = true; state.minutes = 720; state.ui_hud_visible = false
	state.upgrades.yard = true; state.building.house = 3; state.building.layout = []; state.building.revision = 0
	state.current_interior = ""; state.legacy_systems.layouts = []
	var layout: Array = []
	for zone_id: String in ["home","court"]:
		var zone: Dictionary = state.system_catalog.building.zones[zone_id]
		var ids: Array = ["bookshelf","display","cabinet","teaTable","bench","workbench"] if zone_id == "home" else ["bench","teaTable","cabinet","workbench"]
		for id: String in ids:
			state.furniture[id] = 10
			var found := false
			for cell in range(int(zone.cols)*int(zone.rows)):
				var piece := {"key":layout.size()+1,"type":id,"zone":zone_id,"cell":cell,"rotation":0}
				if state.building_placement_valid(piece,layout).ok:
					var candidate: Array = layout.duplicate(true); candidate.append(piece)
					if state.check_building_layout(candidate).ok:
						layout = candidate; found = true; break
			check(found,"Legal isolated fixture placement " + zone_id + "/" + id)
	check(state.apply_building_layout(layout,0,state.building_epoch),"Fixture uses normal inventory and layout commit")
	root.size = Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn"); await settle()
	current_scene.player.set_physics_process(false)
	current_scene.hud.ambient_hud.hide()
	check(current_scene.built_furniture_nodes.size() == 4,"Only four outdoor models; home models excluded")
	check(current_scene.y_sort_enabled,"Courtyard models share player Y sorting")
	for visual: Node2D in current_scene.built_furniture_nodes:
		check(visual.get_parent() == current_scene and visual.position == visual.get_meta("floor_anchor"),"Outdoor model owns correct floor anchor")
		check(visual.find_children("*","CollisionObject2D",true,false).is_empty(),"Art adds no duplicate collisions")
	var first: Node2D = current_scene.built_furniture_nodes[0]
	current_scene.player.global_position = first.position + Vector2(40,45)
	current_scene.player.camera.zoom = Vector2(1.7,1.7)
	current_scene.player.camera.reset_smoothing(); current_scene.player.camera.force_update_scroll()
	await capture("courtyard-furniture")
	var home_id := ""
	for house: Dictionary in state.world_village.houses:
		if str(house.get("name","")) == "爷爷的老屋": home_id = str(house.id)
	if home_id == "": home_id = str(current_scene._grandfather_house_id()) if current_scene.has_method("_grandfather_house_id") else "building-farm-0"
	# The fixture chooses the same authored grandfather home as the actual room script.
	var room_script: Node = load("res://scripts/interior_world.gd").new()
	home_id = room_script._grandfather_house_id(); room_script.free()
	state.current_interior = home_id; state.interior_position = Vector2(480,535)
	change_scene_to_file("res://scenes/interior.tscn"); await settle()
	current_scene.player.set_physics_process(false)
	var custom := 0
	for visual: Node2D in current_scene.furniture_visuals:
		if not visual.custom_piece.is_empty():
			custom += 1
			check(visual.get_parent() == current_scene and visual.position == visual.get_meta("floor_anchor"),"Room model uses floor anchor and Y-sort parent")
	check(custom == 6,"All six custom room models instantiated")
	await capture("home-furniture")
	var bank: Dictionary = state.furniture.duplicate(true)
	var committed: Array = state.building.layout.duplicate(true)
	current_scene.hud.show_building({},true)
	var panel: Node = current_scene.hud.building_panel
	panel._set_tab("layout"); panel.zone_option.select(2); panel._choose_zone(2); panel.furniture_id = "bookshelf"; panel.furniture_rotation = 1; panel.refresh()
	check(panel.layout_preview.furniture_id == "bookshelf" and panel.layout_preview.view_rotation == 1,"Layout preview follows pending orientation")
	for dimensions: Vector2i in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size = dimensions; await capture("layout-preview-" + str(dimensions.x))
		check(panel.grid.columns == 14,"Home spatial grid retains fourteen columns")
		check(panel.grid.get_child(13).position.x > panel.grid.get_child(0).position.x and panel.grid.get_child(14).position.y > panel.grid.get_child(0).position.y,"Cells retain actual map row and column order")
		check(panel.grid.size.x <= panel.grid.get_parent().size.x + 1,"Grid fits its left panel")
	panel._set_tab("craft"); panel.furniture_id = "cabinet"; panel.refresh()
	await capture("craft-preview")
	check(state.furniture == bank and state.building.layout == committed,"Opening and rotating previews preserves stock and committed layout")
	current_scene.queue_free(); await process_frame
	await depth_fixture()
	await gallery()
	print("FURNITURE_GPU: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit(); quit(1 if failed else 0)

func depth_fixture() -> void:
	var view := SubViewport.new(); view.size = Vector2i(320,260); view.disable_3d = true; view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var sorted := Node2D.new(); sorted.y_sort_enabled = true; view.add_child(sorted)
	var furniture := Cabinet.new(); furniture.position = Vector2(160,200); sorted.add_child(furniture)
	await settle(); await RenderingServer.frame_post_draw
	var baseline := view.get_texture().get_image()
	var actor := Probe.new(); actor.position = Vector2(160,180); sorted.add_child(actor)
	await settle(); await RenderingServer.frame_post_draw
	var behind := view.get_texture().get_image()
	actor.position.y = 204
	await settle(); await RenderingServer.frame_post_draw
	var front := view.get_texture().get_image()
	var covered := 0; var visible := 0
	for y in range(172,180):
		for x in range(155,165):
			if baseline.get_pixel(x,y).a < 0.9: continue
			if Vector3(behind.get_pixel(x,y).r,behind.get_pixel(x,y).g,behind.get_pixel(x,y).b).distance_to(Vector3(baseline.get_pixel(x,y).r,baseline.get_pixel(x,y).g,baseline.get_pixel(x,y).b)) < 0.02: covered += 1
			if front.get_pixel(x,y).r > 0.95 and front.get_pixel(x,y).b > 0.95: visible += 1
	check(covered > 40,"GPU pixels: model occludes actor standing behind")
	check(visible > 40,"GPU pixels: actor occludes model when standing in front")
	print("FURNITURE_DEPTH covered_pixels=",covered," front_pixels=",visible)
	view.queue_free(); await process_frame
func gallery() -> void:
	var view := SubViewport.new(); view.size = Vector2i(1000,840); view.disable_3d = true; view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var names := ["bench","teaTable","cabinet","bookshelf","workbench","display"]
	for row in range(names.size()):
		for direction in range(4):
			var preview: Control = load("res://scripts/furniture_preview.gd").new()
			preview.present(names[row],direction); preview.position = Vector2(direction*250,row*140); preview.size = Vector2(246,136); view.add_child(preview)
	await settle(); await RenderingServer.frame_post_draw
	check(view.get_texture().get_image().save_png(output + "/furniture-four-directions.png") == OK,"GPU gallery of all 24 actual direction assets")
	view.queue_free(); await process_frame
