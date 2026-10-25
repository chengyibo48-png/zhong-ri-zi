extends SceneTree
class TerrainBoard extends Control:
 var atlas: Texture2D
 func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO,size),Color("#e9ddbc"))
  for season in range(4):
   var origin := Vector2(20+(season%2)*440,106+floori(season/2.0)*326)
   for y in range(5):
    for x in range(8):
     var variant := posmod(x*5+y*3,4)
     draw_texture_rect_region(atlas,Rect2(origin+Vector2(x,y)*48,Vector2(48,48)),Rect2(Vector2(variant,season)*32,Vector2(32,32)))
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(30).timeout.connect(func():quit(1))
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 root.get_node("GameState").set_process(false)
 root.get_node("GameState").ui_art.theme="paper"
 root.content_scale_size=Vector2i(920,720)
 root.size=Vector2i(920,720)
 var image := Image.load_from_file(ProjectSettings.globalize_path("res://artifacts/terrain-preview/stone_path/stone_path.png"))
 if image==null or image.get_size()!=Vector2i(128,128):quit(1);return
 var board := TerrainBoard.new()
 board.size=Vector2(920,720);board.atlas=ImageTexture.create_from_image(image)
 board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;root.add_child(board)
 var title:=Label.new();title.position=Vector2(20,16);title.text="石板路 · 32 像素瓦片重复铺设预览（未导入生产地图）";title.add_theme_font_size_override("font_size",22);board.add_child(title)
 for season in range(4):
  var label:=Label.new();label.position=Vector2(20+(season%2)*440,70+floori(season/2.0)*326)
  label.text=["春 · 石缝青草","夏 · 苔绿","秋 · 落叶","冬 · 薄霜"][season];label.add_theme_font_size_override("font_size",18);board.add_child(label)
 root.get_node("UIArtService").apply_subtree(board)
 for frame in range(10): await process_frame
 await RenderingServer.frame_post_draw
 var captured:=root.get_texture().get_image()
 if captured==null or captured.get_size()!=Vector2i(920,720):
  printerr("Preview render target dimensions do not match the entire tile board");quit(1);return
 if captured==null or captured.is_empty() or captured.save_png("res://artifacts/terrain-preview/stone_path/repeated-tiles.png")!=OK:quit(1);return
 print("STONE_PATH_REPEAT_PREVIEW: captured four actual packed seasonal tile patterns")
 await root.get_node("AudioService").prepare_exit()
 quit(0)
