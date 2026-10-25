extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func settle() -> void:
	for frame in range(5): await process_frame
func capture(path: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "rendered viewport " + path)
	if image != null: check(image.save_png(path) == OK, "saved " + path)
func run() -> void:
	create_timer(180).timeout.connect(func(): quit(1))
	var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"): quit(1); return
	var state := root.get_node("GameState")
	state.set_process(false)
	state.ui_art.theme = "paper"
	state.flags.introDone = true
	state.appearance = preload("res://scripts/character_art.gd").data().playerProfile.duplicate(true)
	state.appearance.weatherDress = false
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/main.tscn")
	await settle()
	var world := current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	# The frozen world cannot recompute pointer/selected targets after camera teleports.
	world.pointer_hover = {}
	world.selected_world_target = {}
	var hud = world.hud
	if hud.onboarding_open(): hud.toggle_onboarding()
	root.get_node("UIArtService").apply_all()
	await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-world-1280.png")
	check(world.player.character_visual.painted_active, "real painted player visible in rendered world")
	var original_position: Vector2 = world.player.global_position
	var original_day: int = state.day
	var tree_row: Dictionary = preload("res://scripts/world_art.gd").entries().get("props/tree",{})
	check(bool(tree_row.get("baseReady",false)),"seasonal tree artwork imported")
	var tree_point := Vector2.ZERO
	for prop in state.world_village.allProps:
		if str(prop.get("kind",""))=="tree":tree_point=Vector2(float(prop.x),float(prop.y));break
	var tree_zoom: Vector2 = world.player.camera.zoom
	for season in range(4):
		state.day=28*season;world.player.global_position=tree_point+Vector2(0,20)
		world.player.camera.zoom=Vector2(3,3)
		call_group("seasonal_world_props","refresh_season")
		hud.refresh();world.queue_redraw();world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-tree-season-%d.png"%season)
		check(preload("res://scripts/character_art.gd").texture(str(tree_row.seasons[season]))!=null,"live seasonal PNG binding "+str(season))
	state.day=original_day;call_group("seasonal_world_props","refresh_season")
	world.player.camera.zoom=tree_zoom
	world.player.global_position=original_position
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	var drying_row: Dictionary = preload("res://scripts/world_art.gd").entries().get("props/drying", {})
	if bool(drying_row.get("baseReady", false)):
		var drying_rect: Array = drying_row.get("worldRect", [])
		check(drying_rect.size() == 4, "drying prop has a four-value anchored rectangle")
		if drying_rect.size() == 4:
			check(float(drying_rect[2]) <= 36.0 and float(drying_rect[3]) <= 29.0, "low drying rack fits approved display bounds")
			check(is_equal_approx(float(drying_rect[0]), -float(drying_rect[2]) / 2.0) and is_equal_approx(float(drying_rect[1]), -float(drying_rect[3])), "drying feet retain original centered world anchor")
		check(preload("res://scripts/character_art.gd").texture(str(drying_row.path)) != null, "drying PNG binds in actual world renderer")
		var drying_instances := 0
		for prop in world.get_children():
			if prop.get_script() == null or prop.get_script().resource_path != "res://scripts/world_prop.gd": continue
			var prop_data: Dictionary = prop.get("data")
			if str(prop_data.get("kind", "")) != "drying": continue
			drying_instances += 1
			check(prop.position == Vector2(float(prop_data.x), float(prop_data.y)), "drying original placement preserved")
			check(preload("res://scripts/world_art.gd").key_for(prop_data) == "props/drying", "original drying instance selects the correct bitmap")
			check(bool(prop.get("painted_active")), "drying instance actually issued bitmap drawing commands")
		check(drying_instances > 0, "actual village contains bound drying racks")
	var building_ids: Array[String] = []
	for key in preload("res://scripts/world_art.gd").entries():
		if str(key).begins_with("buildings/") and bool(preload("res://scripts/world_art.gd").entries()[key].get("baseReady",false)):building_ids.append(str(key).get_slice("/",1))
	building_ids.sort()
	for building_id in building_ids:
		var building_row: Dictionary = preload("res://scripts/world_art.gd").entries().get("buildings/" + building_id, {})
		check(bool(building_row.get("baseReady", false)), "building has imported artwork: " + building_id)
		if not bool(building_row.get("baseReady", false)): continue
		var door: Dictionary = building_row.door
		world.player.global_position = Vector2(float(door.x), float(door.y) + 45)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		var screenshot_name: String = "cooperative" if building_id == "building-town-2" else building_id
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-" + screenshot_name + "-1280.png")
		check(preload("res://scripts/character_art.gd").texture(str(building_row.path)) != null, "building PNG loads in live renderer: " + building_id)
		check(painted_prop_present("buildings/" + building_id), "actual building node rendered its bitmap: " + building_id)
	world.player.global_position = original_position
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()

	var reviewed_npcs: Array = []
	var review_npc_ids: Array[String] = []
	for actor_id in preload("res://scripts/character_art.gd").data().actors:
		if str(actor_id)!="player" and preload("res://scripts/character_art.gd").has_clip(str(actor_id),"idle"):review_npc_ids.append(str(actor_id))
	review_npc_ids.sort()
	var original_zoom: Vector2 = world.player.camera.zoom
	for npc in world.get_children():
		if npc.get_script() != load("res://scripts/world_npc.gd"): continue
		if str(npc.npc_id) not in review_npc_ids: continue
		reviewed_npcs.append({"node":npc,"position":npc.global_position,"visible":npc.visible})
		npc.show()
		npc.global_position = original_position + Vector2((review_npc_ids.find(str(npc.npc_id))-(review_npc_ids.size()-1)*0.5)*34,0)
		npc.character_visual.set_pose(Vector2.DOWN,false)
	world.player.camera.zoom = Vector2(2,2)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-characters-1280.png")
	check(reviewed_npcs.size()==review_npc_ids.size(),"all original residents with imported idle PNGs present in live scene")
	for row in reviewed_npcs:
		check(row.node.character_visual.painted_active,"resident uses actual painted PNG: "+str(row.node.npc_id))
		row.node.global_position=row.position
		row.node.visible=row.visible
	world.player.camera.zoom=original_zoom
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()

	# Inspect all imported idle directions and both breathing/blink poses.
	var idle_actors: Array[String] = []
	for actor_id in preload("res://scripts/character_art.gd").data().actors:
		if preload("res://scripts/character_art.gd").has_clip(str(actor_id),"idle"):idle_actors.append(str(actor_id))
	idle_actors.sort()
	for idle_page in range(ceili(idle_actors.size()/2.0)):
		var idle_layer := CanvasLayer.new();idle_layer.layer=1000;root.add_child(idle_layer)
		var idle_background := ColorRect.new();idle_background.color=Color("f2e8d2");idle_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);idle_layer.add_child(idle_background)
		for actor_index in range(2):
			var index := idle_page*2+actor_index
			if index>=idle_actors.size():break
			var actor_id: String = idle_actors[index]
			var label := Label.new();label.position=Vector2(18+actor_index*480,16);label.text=actor_id+" · 四向待机帧";label.add_theme_color_override("font_color",Color("354537"));idle_background.add_child(label)
			for row_index in range(4):
				for column_index in range(2):
					var visual = load("res://scripts/character_visual.gd").new();idle_background.add_child(visual)
					if actor_id=="player":visual.configure_player()
					else:visual.configure(actor_id)
					visual.position=Vector2(100+actor_index*480+column_index*140,130+row_index*134);visual.scale=Vector2(2.1,2.1)
					visual.set_pose([Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][row_index],false);visual.set_process(false);visual.walk_clock=float(column_index)/float(preload("res://scripts/character_art.gd").data().actors[actor_id].clips.idle.fps);visual.queue_redraw()
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-idle-page-%d-1280.png"%idle_page)
		for visual in idle_background.get_children():
			if visual is Node2D:check(visual.painted_active,"idle review uses live hand-painted direction and frame")
		idle_layer.queue_free();await settle()

	# Review the new texture in the actual farm, with original season/cell metadata.
	check(world.ground_layer.tile_set.get_source(0).texture.resource_path=="res://art/ground_tiles_handpainted.png","actual farm TileMap loads the hand-painted atlas")
	var grass_cell := Vector2i.ZERO
	var closest := INF
	for cell in world.ground_layer.get_used_cells():
		if world.ground_layer.get_cell_atlas_coords(cell).x!=4:continue
		var distance: float=world.ground_layer.map_to_local(cell).distance_to(original_position)
		if distance<closest:closest=distance;grass_cell=cell
	world.player.global_position=world.ground_layer.map_to_local(grass_cell)
	world.player.camera.zoom=Vector2(2,2)
	for season in range(4):
		state.day=28*season;world._refresh_ground_season(season)
		call_group("seasonal_world_props","refresh_season")
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-ground-season-world-%d.png"%season)
		check(floori(world.ground_layer.get_cell_atlas_coords(grass_cell).y/4.0)==season,"live farm ground changes season "+str(season))
		check(world.ground_layer.get_cell_tile_data(grass_cell).get_custom_data("surface_kind")=="farm_grass","live ground retains original surface metadata")
	# Verify original stone path cells in the actual seasonal TileMap.
	var path_cell := Vector2i.ZERO
	var path_found := false
	var path_distance := INF
	for cell in world.ground_layer.get_used_cells():
		if world.ground_layer.get_cell_atlas_coords(cell).x != 7: continue
		var distance: float = world.ground_layer.map_to_local(cell).distance_to(original_position)
		if distance < path_distance: path_distance = distance; path_cell = cell; path_found = true
	check(path_found, "original map includes stone path cells")
	if path_found:
		world.player.global_position = world.ground_layer.map_to_local(path_cell)
		for season in range(4):
			state.day = 28 * season; world._refresh_ground_season(season)
			call_group("seasonal_world_props", "refresh_season")
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-stone-path-world-%d.png" % season)
			check(floori(world.ground_layer.get_cell_atlas_coords(path_cell).y / 4.0) == season, "live stone path season " + str(season))
			check(world.ground_layer.get_cell_tile_data(path_cell).get_custom_data("surface_kind") == "stone_path", "stone path original surface metadata retained")
	# Capture actual automatic opacity, without setting modulate in the test.
	var canopy: Node2D
	for prop in world.get_children():
		if prop.get_script() != null and prop.get_script().resource_path == "res://scripts/world_prop.gd" and prop.position.distance_to(Vector2(3685, 527)) < 0.01: canopy = prop
	check(canopy != null, "original Lin doorstep canopy exists")
	if canopy != null:
		var lin_door: Dictionary = preload("res://scripts/world_art.gd").entries()["buildings/home-lin"].door
		world.player.camera.zoom = Vector2(3, 3)
		world.player.global_position = Vector2(float(lin_door.x), float(lin_door.y) + 45.0)
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		await create_timer(0.23).timeout
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-canopy-player-behind.png")
		check(is_equal_approx(canopy.modulate.a, 0.42) and bool(canopy.get("painted_active")), "production tree fades while its real bitmap remains drawn")
		world.player.global_position = canopy.global_position + Vector2(0, 30)
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		await create_timer(0.23).timeout
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-canopy-player-front.png")
		check(is_equal_approx(canopy.modulate.a, 1.0), "production tree restores full opacity when player is in front")

	state.day=original_day;world._refresh_ground_season(state.season_index());call_group("seasonal_world_props","refresh_season")
	world.player.global_position=original_position;world.player.camera.zoom=original_zoom;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()

	# Review every actually imported walk clip in the logical UI viewport.
	var gait_actors: Array[String] = []
	for actor_id in preload("res://scripts/character_art.gd").data().actors:
		if preload("res://scripts/character_art.gd").has_clip(str(actor_id),"walk"):gait_actors.append(str(actor_id))
	gait_actors.sort()
	for gait_page in range(ceili(gait_actors.size()/2.0)):
		var gait_layer := CanvasLayer.new();gait_layer.layer=1000;root.add_child(gait_layer)
		var gait_backdrop := ColorRect.new();gait_backdrop.color=Color("f2e8d2");gait_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);gait_layer.add_child(gait_backdrop)
		for actor_index in range(2):
			var gait_index := gait_page*2+actor_index
			if gait_index>=gait_actors.size():break
			var actor_id: String = gait_actors[gait_index]
			var label := Label.new();label.position=Vector2(18+actor_index*480,16);label.text=actor_id+" · 四向行走六帧";label.add_theme_color_override("font_color",Color("354537"));gait_backdrop.add_child(label)
			for row_index in range(4):
				for column_index in range(6):
					var visual = load("res://scripts/character_visual.gd").new();gait_backdrop.add_child(visual)
					if actor_id=="player":
						visual.configure_player()
					else:visual.configure(actor_id)
					visual.position=Vector2(52+actor_index*480+column_index*74,150+row_index*136);visual.scale=Vector2(1.9,1.9)
					visual.set_pose([Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][row_index],true);visual.set_process(false);visual.walk_clock=float(column_index)/float(preload("res://scripts/character_art.gd").data().actors[actor_id].clips.walk.fps);visual.queue_redraw()
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-walk-gait-page-%d-1280.png"%gait_page)
		for visual in gait_backdrop.get_children():
			if visual is Node2D:check(visual.painted_active,"gait review uses live painted walk frame")
		gait_layer.queue_free();await settle()

	# Inspect all actually imported action clips through the real visual/snapshot route.
	for actor_id in preload("res://scripts/character_art.gd").data().actors:
		var actor_entry: Dictionary=preload("res://scripts/character_art.gd").data().actors[actor_id]
		for clip in actor_entry.clips:
			if str(clip) in ["idle","walk"] or not preload("res://scripts/character_art.gd").has_clip(str(actor_id),str(clip)):continue
			var spec: Dictionary=actor_entry.clips[clip]
			var action_layer := CanvasLayer.new();action_layer.layer=1000;root.add_child(action_layer)
			var action_background := ColorRect.new();action_background.color=Color("f2e8d2");action_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);action_layer.add_child(action_background)
			var label := Label.new();label.position=Vector2(18,16);label.text=str(actor_id)+" · "+str(clip)+" · 四方向动作帧";label.add_theme_color_override("font_color",Color("354537"));action_background.add_child(label)
			var frame_count: int=int(spec.frames)
			for row_index in range(spec.directions.size()):
				for column_index in range(frame_count):
					var visual=load("res://scripts/character_visual.gd").new();action_background.add_child(visual)
					if str(actor_id)=="player":visual.configure_player()
					else:visual.configure(str(actor_id))
					visual.position=Vector2(85+column_index*145,145+row_index*134);visual.scale=Vector2(1.9,1.9)
					var direction: Vector2={"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP}[str(spec.directions[row_index])]
					visual.set_pose(direction,false)
					visual.set_sequence_snapshot({"kind":str(clip),"duration":1.25,"progress":(column_index+0.25)/frame_count})
					visual.set_process(false);visual.queue_redraw()
			await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-action-"+str(actor_id)+"-"+str(clip)+"-1280.png")
			for visual in action_background.get_children():
				if visual is Node2D:
					check(visual.painted_active,"live action uses imported painted frame")
					check(visual.sequence_managed and visual.action_state==str(clip),"actual action snapshot preserves animation identity")
			action_layer.queue_free();await settle()

	# Exercise dynamic prompt styling in the real renderer after content changes.
	var prompt = hud.interaction_prompt
	prompt.set_process(false)
	for high_contrast in [false, true]:
		state.player_settings.contrast = high_contrast
		for theme_key in ["paper", "porcelain", "timber"]:
			state.ui_art.theme = theme_key
			root.get_node("UIArtService").apply_all()
			for available in [true, false]:
				prompt.update_content({"verb":"播种","name":"七号田 · 韭菜","ready":available,"state":"可以操作","reason":"" if available else "缺少韭菜种子 ×2","detail":"水分 20 · 肥力 80"}, "E", Vector2(480,330), root.get_visible_rect().size)
				prompt.advance_visibility(0.14)
				var panel_style: StyleBox = prompt.get_theme_stylebox("panel")
				var palette: Dictionary = root.get_node("UIArtService")._effective_palette(theme_key)
				check(root.get_node("UIArtService").style_background(panel_style).is_equal_approx(Color(str(palette.panel), root.get_node("UIArtService").style_background(panel_style).a)), "live dynamic prompt follows theme")
				check(prompt.description.get_theme_color("font_color") == Color(str(palette.ink)), "live dynamic prompt ink follows theme")
				check(prompt.size.y < 180, "first live content update has compact text height")
				await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-interaction-%s-%s-%s.png" % [theme_key, "contrast" if high_contrast else "normal", "ready" if available else "unavailable"])
	prompt._set_presence(false)
	prompt.advance_visibility(0.14)
	prompt.set_process(true)
	state.player_settings.contrast = false
	state.ui_art.theme = "paper"
	root.get_node("UIArtService").apply_all()

	# Load after autoload initialization; the real dialogue and portrait scripts use GameState.
	var dialogue: Control = load("res://scripts/npc_dialogue.gd").new()
	hud.add_child(dialogue)
	for actor_id in review_npc_ids:
		if not bool(preload("res://scripts/character_art.gd").data().actors[actor_id].get("portraitReady",{}).get("calm",false)):continue
		dialogue.open_panel(actor_id)
		root.get_node("UIArtService").apply_all()
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-dialogue-"+actor_id+"-1280.png")
		var portrait_found:=false
		for control in dialogue.find_children("*","Control",true,false):
			var script: Variant = control.get_script()
			if script==null or script.resource_path!="res://scripts/character_portrait.gd":continue
			portrait_found=true
			check(control.character_key==actor_id and control.painted_active,"actual dialogue binds unique portrait: "+actor_id)
			control.rain=true;control.queue_redraw()
			await settle()
			check(not control.painted_active,"unfinished rain portrait preserves weather renderer")
		check(portrait_found,"dialogue includes original portrait control")
		dialogue.close()
	# Keep all original calm/weather checks above; additionally test each ready emotion.
	for actor_id in review_npc_ids:
		var ready_emotions: Dictionary = preload("res://scripts/character_art.gd").data().actors[actor_id].get("portraitReady", {})
		for emotion_key in ready_emotions:
			if str(emotion_key) == "calm" or not bool(ready_emotions[emotion_key]): continue
			var resident: Dictionary = state.neighbors.people[actor_id]
			var had_last := resident.has("last")
			var old_last: Dictionary = resident.get("last", {}).duplicate(true)
			var next_last := old_last.duplicate(true); next_last.emotion = str(emotion_key); resident.last = next_last
			dialogue.open_panel(actor_id)
			root.get_node("UIArtService").apply_all()
			await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-dialogue-"+actor_id+"-"+str(emotion_key)+"-1280.png")
			var emotion_found := false
			for control in dialogue.find_children("*", "Control", true, false):
				var loaded_script: Variant = control.get_script()
				if loaded_script == null or loaded_script.resource_path != "res://scripts/character_portrait.gd": continue
				emotion_found = true
				check(str(control.get("character_key")) == actor_id and str(control.get("emotion")) == str(emotion_key) and bool(control.get("painted_active")), "live emotion binds unique portrait: "+actor_id+"/"+str(emotion_key))
			check(emotion_found, "ready emotion is present in actual dialogue")
			dialogue.close()
			if had_last: resident.last = old_last
			else: resident.erase("last")
	dialogue.queue_free()
	await settle()
	# The player calm portrait is a resource preview, not a new game menu.
	var player_portrait_layer := CanvasLayer.new(); player_portrait_layer.layer = 1000; root.add_child(player_portrait_layer)
	var player_portrait_background := ColorRect.new(); player_portrait_background.color = Color("f2e8d2"); player_portrait_background.size = Vector2(root.size); player_portrait_layer.add_child(player_portrait_background)
	var player_portrait_label := Label.new(); player_portrait_label.text = "主角 · 常态肖像（资源预览）"; player_portrait_label.position = Vector2(22, 22); player_portrait_label.add_theme_color_override("font_color", Color("354537")); player_portrait_background.add_child(player_portrait_label)
	var player_portrait = load("res://scripts/character_portrait.gd").new(); player_portrait_background.add_child(player_portrait)
	player_portrait.position = Vector2(root.size.x * 0.5 - 128, 170); player_portrait.size = Vector2(256, 320); player_portrait.configure("player", {}, "calm")
	await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-player-calm-resource-1280.png")
	check(player_portrait.character_key == "player" and player_portrait.emotion == "calm" and player_portrait.painted_active, "default player calm resource uses the actual portrait renderer")
	player_portrait_layer.queue_free()
	await settle()

	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		await settle()
		hud.show_market("inventory", false)
		hud.market_panel.selected_id = "cabbage"
		hud.market_panel.refresh()
		await settle()
		check(hud.market_panel.item_list.fixed_icon_size == Vector2i(48, 48), "48px list icons")
		check(hud.toolbar_icons.seed.item_id == state.seed_variant_id(state.selected_seed), "toolbar selected seed illustration")
		var body: Rect2 = hud.market_panel.get_child(1).get_global_rect()
		check(body.position.x >= 0 and body.position.y >= 0 and body.end.x <= root.get_visible_rect().size.x and body.end.y <= root.get_visible_rect().size.y, "inventory stays within viewport")
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-inventory-%d.png" % resolution.x)
		hud.close_top_panel()
		# The live crafting list must bind the explicit furniture namespace.
		hud.show_building({},true)
		hud.building_panel.call("_set_tab","craft")
		root.get_node("UIArtService").apply_all()
		await settle()
		var furniture_list: ItemList=hud.building_panel.furniture_list
		check(furniture_list.fixed_icon_size==Vector2i(48,48),"live crafting 48px furniture icons")
		for furniture_index in range(furniture_list.item_count):
			var furniture_id: String=str(furniture_list.get_item_metadata(furniture_index))
			var expected: Texture2D=preload("res://scripts/item_art.gd").texture_for(furniture_id,"furniture")
			check(furniture_list.get_item_icon(furniture_index)==expected,"crafting exact furniture icon namespace: "+furniture_id)
			if furniture_id=="bench":furniture_list.select(furniture_index);hud.building_panel.call("_choose_furniture",furniture_index)
		var craft_body: Rect2=hud.building_panel.get_child(1).get_global_rect()
		check(root.get_visible_rect().encloses(craft_body),"crafting stays inside logical viewport")
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-furniture-craft-%d.png"%resolution.x)
		hud.close_top_panel()
	root.size=Vector2i(1280,800)
	await settle()
	var item_art=load("res://scripts/item_art.gd")
	var ready_keys:Array=[]
	for key in item_art.manifest():
		if str(item_art.manifest()[key].get("status","missing"))=="ready":ready_keys.append(key)
	ready_keys.sort()
	for page in range(ceili(ready_keys.size()/24.0)):
		var layer:=CanvasLayer.new();layer.layer=1000;root.add_child(layer)
		var backdrop:=ColorRect.new();backdrop.color=Color("f2e8d2");backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(backdrop)
		var header:=Label.new();header.position=Vector2(24,20);header.text="真实图标画面核查 · 第 %d 页"%(page+1);header.add_theme_font_size_override("font_size",24);header.add_theme_color_override("font_color",Color("354537"));backdrop.add_child(header)
		var grid:=GridContainer.new();grid.columns=6;grid.position=Vector2(24,64);grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);backdrop.add_child(grid)
		for i in range(page*24,mini((page+1)*24,ready_keys.size())):
			var key:String=ready_keys[i];var entry:Dictionary=item_art.manifest()[key]
			var cell:=Control.new();cell.custom_minimum_size=Vector2(143,118);grid.add_child(cell)
			var icon:Control=load("res://scripts/item_icon.gd").new();icon.position=Vector2(35,0);icon.size=Vector2(72,72);cell.add_child(icon);icon.configure(key)
			var label:=Label.new();label.position=Vector2(0,77);label.size=Vector2(143,19);label.text=str(entry.name);label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",Color("354537"));cell.add_child(label)
			var identity:=Label.new();identity.position=Vector2(0,99);identity.size=Vector2(143,16);identity.text=key;identity.clip_text=true;identity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;identity.add_theme_font_size_override("font_size",9);identity.add_theme_color_override("font_color",Color("6c6957"));cell.add_child(identity)
			check(item_art.texture_for(key.get_slice("/",1),key.get_slice("/",0))!=null,"review page loads exact icon: "+key)
		await settle()
		for cell in grid.get_children():
			var live_icon: Control = cell.get_child(0)
			check(str(live_icon.get("painted_key")) == str(live_icon.get("item_id")), "actual drawn icon matches qualified ID: " + str(live_icon.get("item_id")))
			check(root.get_visible_rect().encloses(cell.get_global_rect()),"review icon cell stays within viewport: %s in %s" % [str(cell.get_global_rect()),str(root.get_visible_rect())])
		await capture("res://artifacts/quality-redesign-20261015/legacy-ui/ui/handpainted-icon-review-page-%d.png"%page)
		layer.queue_free();await settle()
	print("ART_UI_RENDER: %d passed, %d failed" % [passed, failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)


func painted_prop_present(key: String) -> bool:
	for prop in current_scene.get_children():
		if prop.get_script() == null or prop.get_script().resource_path != "res://scripts/world_prop.gd": continue
		if preload("res://scripts/world_art.gd").key_for(prop.get("data")) == key and bool(prop.get("painted_active")): return true
	return false
