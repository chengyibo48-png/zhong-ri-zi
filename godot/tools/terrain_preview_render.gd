extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(120).timeout.connect(func():quit(1))
	root.size = Vector2i(1280,800)
	root.get_node("GameState").set_process(false)
	var original_set: TileSet = load("res://art/ground_tileset.tres")
	var preview_image := Image.load_from_file(ProjectSettings.globalize_path("res://artifacts/terrain-preview/ground.png"))
	check(preview_image != null and preview_image.get_size() == Vector2i(320,512), "original atlas dimensions preserved")
	if preview_image == null: quit(1); return
	var original_atlas := original_set.get_source(0) as TileSetAtlasSource
	var original_image := original_atlas.texture.get_image()
	original_image.convert(Image.FORMAT_RGBA8); preview_image.convert(Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(10):
			if x == 4: continue
			var area := Rect2i(x*32,y*32,32,32)
			check(original_image.get_region(area).get_data() == preview_image.get_region(area).get_data(), "unchanged other tile %d:%d"%[x,y])
	var preview_set: TileSet = original_set.duplicate(true)
	var preview_atlas := preview_set.get_source(0) as TileSetAtlasSource
	preview_atlas.texture = ImageTexture.create_from_image(preview_image)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var background := ColorRect.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.color=Color("f2e8d2"); layer.add_child(background)
	var title := Label.new(); title.position=Vector2(24,12);title.text="四季草地 · 原生 TileMapLayer 预览";title.add_theme_color_override("font_color",Color("354537"));layer.add_child(title)
	for season in range(4):
		var board := Node2D.new(); board.position=Vector2(24+posmod(season,2)*480,84+floori(season/2.0)*260);layer.add_child(board)
		var label := Label.new();label.position=Vector2(0,-28);label.text=["春 · 柔绿","夏 · 草青","秋 · 草黄","冬 · 枯草与霜"][season];label.add_theme_color_override("font_color",Color("354537"));board.add_child(label)
		var ground := TileMapLayer.new();ground.tile_set=preview_set;board.add_child(ground)
		for row in range(6):
			for column in range(12):
				var variant := posmod(column*17+row*31+column*row,4)
				ground.set_cell(Vector2i(column,row),0,Vector2i(4,season*4+variant))
				check(ground.get_cell_tile_data(Vector2i(column,row)).get_custom_data("surface_kind") == "farm_grass","original farm-ground type")
		check(ground.tile_set.tile_size==Vector2i(32,32), "original world-cell geometry")
		check(ground.map_to_local(Vector2i(1,0))-ground.map_to_local(Vector2i(0,0))==Vector2(32,0),"adjacent cells meet at original spacing")
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	check(rendered != null and not rendered.is_empty(),"native GPU ground rendered")
	if rendered != null: check(rendered.save_png("res://artifacts/handpainted-ground-preview-1280.png")==OK,"native ground preview saved")
	print("Terrain preview: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)

