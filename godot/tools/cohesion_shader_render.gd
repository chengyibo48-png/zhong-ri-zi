extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 create_timer(120).timeout.connect(func():quit(1))
 root.get_node("GameState").set_process(false)
 var view:=SubViewport.new();view.size=Vector2i(64,64);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.world_2d=World2D.new();root.add_child(view)
 var layer:=TileMapLayer.new();layer.tile_set=load("res://art/ground_tileset.tres");view.add_child(layer)
 layer.set_cell(Vector2i(0,0),0,Vector2i(4,0));layer.set_cell(Vector2i(1,0),0,Vector2i(6,0));layer.set_cell(Vector2i(0,1),0,Vector2i(8,0));layer.set_cell(Vector2i(1,1),0,Vector2i(9,0))
 preload("res://scripts/ground_style.gd").apply(layer)
 var material:=layer.material as ShaderMaterial
 var lookup:Image=material.get_shader_parameter("cell_atlas").get_image()
 for cell in layer.get_used_cells():
  var encoded:=lookup.get_pixelv(cell);var original:=layer.get_cell_atlas_coords(cell)
  check(roundi(encoded.r*255)==original.x and roundi(encoded.g*255)==original.y,"lookup encodes original typed coordinates")
 # Diagnostic solid colors exercise the production shader; they are not game art.
 var atlas:=Image.create(320,512,false,Image.FORMAT_RGBA8);atlas.fill(Color.BLACK)
 var palette:=Image.create(10,4,false,Image.FORMAT_RGBA8);palette.fill(Color.BLACK)
 var colors:Dictionary={4:Color.RED,6:Color.BLUE,8:Color.GREEN,9:Color.WHITE}
 for column in colors:
  atlas.fill_rect(Rect2i(column*32,0,32,128),colors[column]);palette.fill_rect(Rect2i(column,0,1,4),colors[column])
 material.set_shader_parameter("ground_atlas",ImageTexture.create_from_image(atlas));material.set_shader_parameter("surface_palette",ImageTexture.create_from_image(palette));material.set_shader_parameter("texture_strength",1.0)
 for frame in range(8):await process_frame
 await RenderingServer.frame_post_draw
 var image:=view.get_texture().get_image()
 var red:=image.get_pixel(16,16);var blue:=image.get_pixel(48,16)
 check(red.r>0.95 and red.b<0.05,"red center keeps exact source family")
 check(blue.b>0.95 and blue.r<0.05,"blue center keeps exact source family")
 var left:=image.get_pixel(31,16);var right:=image.get_pixel(32,16)
 check(left.r>0.25 and left.b>0.25 and right.r>0.25 and right.b>0.25,"both sides contain their own and adjacent material")
 check(absf(left.r-right.r)<0.12 and absf(left.b-right.b)<0.12,"no hard material jump across shared cell edge")
 var corner:=image.get_pixel(32,32)
 check(minf(corner.r,minf(corner.g,corner.b))>0.20,"four neighboring tiles blend at a corner without holes")
 check(image.save_png("res://artifacts/cohesion-shader-calibration-20261009.png")==OK,"preserve diagnostic native GPU image")
 view.queue_free();await process_frame
 print("COHESION_SHADER_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
