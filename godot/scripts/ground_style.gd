extends RefCounted
## The lookup describes drawn tiles only. It never changes ground metadata or physics.
const BLEND_SHADER := preload("res://art/shaders/cohesion_ground.gdshader")
static var _palette: Texture2D
static func apply(layer: TileMapLayer) -> void:
 var lookup := Image.create(120, 120, false, Image.FORMAT_RGBA8)
 for cell in layer.get_used_cells():
  var coordinates := layer.get_cell_atlas_coords(cell)
  var column := preload("res://scripts/world_layout.gd").ground_column(cell, coordinates.x)
  lookup.set_pixelv(cell, Color(column / 255.0, coordinates.y / 255.0, 0.0, 1.0))
 var material := layer.material as ShaderMaterial
 if material == null:
  material = ShaderMaterial.new()
  material.shader = BLEND_SHADER
  layer.material = material
 var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
 if _palette == null:
  var pixels := atlas.texture.get_image()
  var palette := Image.create(10, 4, false, Image.FORMAT_RGBA8)
  for season in range(4):
   for column in range(10):
    var average := Vector3.ZERO
    for y in range(season * 128, (season + 1) * 128):
     for x in range(column * 32, (column + 1) * 32):
      var color := pixels.get_pixel(x, y)
      average += Vector3(color.r, color.g, color.b)
    average /= 4096.0
    palette.set_pixel(column, season, Color(average.x, average.y, average.z))
  _palette = ImageTexture.create_from_image(palette)
 material.set_shader_parameter("ground_atlas", preload("res://scripts/character_art.gd").texture("res://art/world/terrain/ground_cohesion_hd.png"))
 material.set_shader_parameter("cell_atlas", ImageTexture.create_from_image(lookup))
 material.set_shader_parameter("surface_palette", _palette)
 material.set_shader_parameter("shore_detail", preload("res://scripts/detail_art.gd").texture("terrain/shore"))
 material.set_shader_parameter("snow_detail", preload("res://scripts/detail_art.gd").texture("terrain/snow"))
 update_weather(layer,float(layer.get_meta("painted_snow_cover",0.0)))
 layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

static func shadow(target: CanvasItem, center: Vector2, width: float, depth: float) -> void:
 # Nested transparent ellipses share the warm occlusion hue of the painted materials.
 for ring in range(6):
  var fraction := 1.0 - ring * 0.11
  var points := PackedVector2Array()
  for point in range(32):
   var angle := TAU * point / 32.0
   points.append(center + Vector2(cos(angle) * width, sin(angle) * depth) * fraction * 0.5)
  target.draw_colored_polygon(points, Color(0.24, 0.20, 0.14, 0.028))

static func update_weather(layer: TileMapLayer, snow: float) -> void:
 if layer == null or not layer.material is ShaderMaterial: return
 if is_equal_approx(float(layer.get_meta("painted_snow_cover", -1.0)), snow): return
 layer.set_meta("painted_snow_cover", snow)
 layer.material.set_shader_parameter("snow_cover", snow)
