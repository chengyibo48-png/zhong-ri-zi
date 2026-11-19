extends SceneTree
const ART := preload("res://scripts/built_furniture_art.gd")
const IDS := ["well","trellis","flowerbed","stoneLantern"]
var state: Node
var output: String
var passed := 0
var failed := 0
class Probe extends Node2D:
	func _draw() -> void: draw_rect(Rect2(-16,-110,32,110),Color.MAGENTA)
class GardenModel extends Node2D:
	var model_id := "well"
	var minutes := 720
	func _draw() -> void:
		var dimensions := Vector2(96,96) if model_id == "well" else Vector2(48,48) if model_id == "stoneLantern" else Vector2(96,48)
		preload("res://scripts/built_furniture_art.gd").draw(self,{"type":model_id,"rotation":0},Rect2(Vector2(-dimensions.x*0.5,-dimensions.y),dimensions),minutes)
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL ",label)
func settle() -> void:
	for i in range(8): await process_frame
func capture(name: String) -> void:
	await settle()
	for key: String in ["notification_stack","hover_card","interaction_prompt","context_actions","restore_hud_button"]:
		current_scene.hud.get(key).hide()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK,"Actual garden screenshot " + name)
func fixture_layout(direction: int) -> Array:
	var layout: Array = []
	var zone: Dictionary = state.system_catalog.building.zones.court
	for id: String in IDS:
		var found := false
		for cell in range(int(zone.cols)*int(zone.rows)):
			var piece := {"key":layout.size()+1,"type":id,"zone":"court","cell":cell,"rotation":direction}
			if not state.building_placement_valid(piece,layout).ok: continue
			var candidate := layout.duplicate(true); candidate.append(piece)
			if not state.check_building_layout(candidate).ok: continue
			layout = candidate; found = true; break
		check(found,"Legal garden placement " + id + "/" + str(direction))
	return layout
func run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		printerr("Garden fixture requires isolated user data"); quit(1); return
	create_timer(120,true,false,true).timeout.connect(func():quit(1))
	state = root.get_node("GameState"); state.set_process(false)
	state.flags.introDone = true; state.minutes = 720; state.ui_hud_visible = false
	state.upgrades.yard = true; state.building.house = 3; state.building.layout = []; state.building.revision = 0
	state.current_interior = ""; state.legacy_systems.layouts = []
	for id: String in IDS: state.furniture[id] = 10
	output = OS.get_environment("ZRZ_ART_OUTPUT")
	if output == "": output = "user://garden-art-v5"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var economy: Dictionary = {"money":state.money,"inventory":state.inventory.duplicate(true),"plots":state.plots.duplicate(true)}
	check(state.apply_building_layout(fixture_layout(0),0,state.building_epoch),"Initial fixture commits with normal placement and stock rules")
	root.size = Vector2i(1280,800)
	change_scene_to_file("res://scenes/main.tscn"); await settle()
	current_scene.player.set_physics_process(false)
	current_scene.hud.ambient_hud.hide()
	var zone: Dictionary = state.system_catalog.building.zones.court
	current_scene.player.global_position = Vector2(float(zone.x)+float(zone.cols)*float(zone.size)*0.5,float(zone.y)+float(zone.rows)*float(zone.size)*0.65)
	current_scene.player.camera.zoom = Vector2(1.45,1.45)
	current_scene.player.camera.reset_smoothing(); current_scene.player.camera.force_update_scroll()
	for direction in range(4):
		if direction > 0: check(state.apply_building_layout(fixture_layout(direction),int(state.building.revision),state.building_epoch),"Apply normal rotation layout " + str(direction))
		await settle()
		check(current_scene.built_furniture_nodes.size() == 4,"Exactly four new garden models")
		for visual: Node2D in current_scene.built_furniture_nodes:
			check(int(visual.piece.rotation) == direction and visual.position == visual.get_meta("floor_anchor"),"Rotation and floor anchor follow committed piece")
			check(visual.get_parent() == current_scene and visual.find_children("*","CollisionObject2D",true,false).is_empty(),"Garden art shares Y sorting without adding collisions")
		var blocking := 0
		for child: Node in current_scene.building_collision_root.get_children():
			if not child.is_queued_for_deletion(): blocking += 1
		check(blocking == 4,"Original blocking footprints remain active")
		await capture("garden-direction-" + str(direction))
	check(state.apply_building_layout(fixture_layout(0),int(state.building.revision),state.building_epoch),"Restore front-facing garden")
	for minutes in [720,1200,1260]:
		state.minutes = minutes; state.clock_changed.emit(); state.changed.emit()
		await capture("garden-time-" + str(minutes))

	var original_position: Vector2 = current_scene.player.global_position
	for visual: Node2D in current_scene.built_furniture_nodes:
		if str(visual.piece.type) != "stoneLantern": continue
		current_scene.player.global_position = visual.position + Vector2(0,-25)
		current_scene.player.visible = false
		current_scene.player.camera.zoom = Vector2(4,4)
		current_scene.player.camera.reset_smoothing(); current_scene.player.camera.force_update_scroll()
		for minutes in [720,1260]:
			state.minutes = minutes; state.clock_changed.emit(); state.changed.emit()
			current_scene.player.camera.zoom = Vector2(4,4)
			current_scene.player.camera.reset_smoothing(); current_scene.player.camera.force_update_scroll()
			await capture("stone-lantern-" + str(minutes))
	current_scene.player.visible = true
	current_scene.player.global_position = original_position
	current_scene.player.camera.zoom = Vector2(1.45,1.45)
	current_scene.player.camera.reset_smoothing(); current_scene.player.camera.force_update_scroll()
	check(str(state.system_catalog.building.defs.well.service) == "water","Well keeps its original water service")
	var bank: Dictionary = state.furniture.duplicate(true)
	var committed: Array = state.building.layout.duplicate(true)
	current_scene.hud.show_building({},true)
	var panel: Node = current_scene.hud.building_panel
	panel._set_tab("craft")
	for id: String in IDS:
		panel.furniture_id = id; panel.refresh(); await settle()
		check(panel.craft_preview.furniture_id == id,"Craft preview uses actual new model " + id)
	panel._set_tab("layout"); panel.furniture_id = "well"; panel.furniture_rotation = 1; panel.refresh()
	for dimensions: Vector2i in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size = dimensions; await capture("garden-layout-" + str(dimensions.x))
		check(panel.grid.columns == 8,"Courtyard map preserves eight columns")
		check(panel.grid.size.x <= panel.grid.get_parent().size.x+1,"Courtyard map fits panel")
		check(panel.layout_preview.furniture_id == "well" and panel.layout_preview.view_rotation == 1,"Well preview follows pending direction")
	check(state.furniture == bank and state.building.layout == committed,"Previews preserve stock and committed layout")
	check(state.money == economy.money and state.inventory == economy.inventory and state.plots == economy.plots,"Rendering and layout previews preserve economy and crops")
	current_scene.queue_free(); await process_frame
	await model_fixtures()
	await gallery()
	print("GARDEN_GPU: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit(); quit(1 if failed else 0)
func model_fixtures() -> void:
	var view := SubViewport.new(); view.size = Vector2i(256,240); view.disable_3d = true; view.transparent_bg = true; view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var sorted := Node2D.new(); sorted.y_sort_enabled = true; view.add_child(sorted)
	for id: String in IDS:
		var model := GardenModel.new(); model.model_id = id; model.position = Vector2(128,200); sorted.add_child(model)
		await settle(); await RenderingServer.frame_post_draw
		var baseline := view.get_texture().get_image()
		var actor := Probe.new(); actor.position = Vector2(128,190); sorted.add_child(actor)
		await settle(); await RenderingServer.frame_post_draw
		var behind := view.get_texture().get_image()
		actor.position.y = 210
		await settle(); await RenderingServer.frame_post_draw
		var front := view.get_texture().get_image()
		var covered := 0; var visible := 0
		for y in range(110,180):
			for x in range(116,140):
				var a := baseline.get_pixel(x,y); var z := behind.get_pixel(x,y); var f := front.get_pixel(x,y)
				if a.a < 0.92: continue
				if Vector3(a.r,a.g,a.b).distance_to(Vector3(z.r,z.g,z.b)) < 0.03: covered += 1
				if f.r > 0.95 and f.b > 0.95: visible += 1
		check(covered > 20,"Actual opaque model pixels cover rear actor " + id)
		check(visible > 20,"Front actor covers actual model pixels " + id)
		print("GARDEN_DEPTH ",id," covered=",covered," front=",visible)
		actor.free()
		if id == "stoneLantern":
			model.minutes = 1260; model.queue_redraw()
			await settle(); await RenderingServer.frame_post_draw
			var night := view.get_texture().get_image(); var glow := 0
			for y in range(95,200):
				for x in range(80,176):
					var a := baseline.get_pixel(x,y); var z := night.get_pixel(x,y)
					if a.a < 0.01 and z.a > 0.015 and z.r > z.b: glow += 1
			check(glow > 30,"Actual clock-driven lamp glow paints warm transparent surroundings")
			print("GARDEN_LAMP glow_pixels=",glow)
		model.free()
	view.queue_free(); await process_frame
func gallery() -> void:
	var view := SubViewport.new(); view.size = Vector2i(1000,640); view.disable_3d = true; view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for row in range(IDS.size()):
		for direction in range(4):
			var preview: Control = load("res://scripts/furniture_preview.gd").new()
			preview.present(IDS[row],direction); preview.position = Vector2(direction*250,row*160); preview.size = Vector2(246,156); view.add_child(preview)
	await settle(); await RenderingServer.frame_post_draw
	check(view.get_texture().get_image().save_png(output + "/garden-four-directions.png") == OK,"All sixteen runtime direction sprites")
	view.queue_free(); await process_frame
