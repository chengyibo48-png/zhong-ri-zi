extends SceneTree
func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size() != 1: quit(1); return
 var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var surface_columns := {"mountain_gravel":0,"town_stone":1,"river_sand":2,"bamboo_ground":3,"farm_grass":4,"pasture_grass":5,"earth_path":6,"stone_path":7,"water":8,"wood_path":9}
 var aliases := {"farm_grass":"grass","river_sand":"sand"}
 var tile_set: TileSet = load("res://art/ground_tileset.tres")
 var atlas := tile_set.get_source(0) as TileSetAtlasSource
 var combined := atlas.texture.get_image()
 combined.convert(Image.FORMAT_RGBA8)
 if combined.get_size() != Vector2i(320,512):quit(1);return
 var high_resolution := Image.create(1280,2048,false,Image.FORMAT_RGBA8)
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 manifest.groundAtlas = {}
 if receipt.rows.size() != 10:quit(1);return
 for row in receipt.rows:
  var kind := str(row.kind)
  var column: int = surface_columns[kind]
  var master := Image.load_from_file(str(row.master))
  if master == null or master.get_width() != master.get_height() or master.get_width() < 512:quit(1);return
  master.convert(Image.FORMAT_RGBA8)
  var packed := Image.create(128,128,false,Image.FORMAT_RGBA8)
  var hashes: Dictionary = {}
  for season in range(4):
   for variant in range(4):
    var source_column: int = season if bool(row.transpose) else variant
    var source_row: int = variant if bool(row.transpose) else season
    var begin := Vector2i(roundi(source_column * master.get_width()/4.0), roundi(source_row * master.get_height()/4.0))
    var end := Vector2i(roundi((source_column+1) * master.get_width()/4.0), roundi((source_row+1) * master.get_height()/4.0))
    var tile := master.get_region(Rect2i(begin,end-begin))
    var detailed := tile.duplicate()
    detailed.resize(128,128,Image.INTERPOLATE_LANCZOS)
    high_resolution.blit_rect(detailed,Rect2i(0,0,128,128),Vector2i(column,season*4+variant)*128)
    tile.resize(32,32,Image.INTERPOLATE_LANCZOS)
    if tile.detect_alpha()!=Image.ALPHA_NONE:printerr("Alpha hole "+kind);quit(1);return
    var digest := HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(tile.get_data())
    var hash_value := digest.finish().hex_encode()
    if hashes.has(hash_value):printerr("Duplicate tile "+kind);quit(1);return
    hashes[hash_value]=true
    var coords := Vector2i(column,season*4+variant)
    if str(atlas.get_tile_data(coords,0).get_custom_data("surface_kind"))!=kind:quit(1);return
    packed.blit_rect(tile,Rect2i(0,0,32,32),Vector2i(variant,season)*32)
    combined.blit_rect(tile,Rect2i(0,0,32,32),coords*32)
  var name := str(aliases.get(kind,kind))
  var path := "res://art/world/terrain/"+name+".png"
  if packed.save_png(path)!=OK:quit(1);return
  var spec := {"name":kind,"path":path,"status":"partial","baseReady":true,"atlasColumn":column,"tileSize":[32,32],"seasonalVariants":[4,4],"visualReview":"pending_actual_scene"}
  manifest.groundAtlas[kind]=spec
  if manifest.entries.has("terrain/"+name):
   manifest.entries["terrain/"+name].merge(spec,true)
 if combined.save_png("res://art/ground_tiles_handpainted.png")!=OK:quit(1);return
 if high_resolution.save_png("res://art/world/terrain/ground_cohesion_hd.png")!=OK:quit(1);return
 manifest.groundAtlasTexture="res://art/world/terrain/ground_cohesion_hd.png"
 var file := FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("COHESION_GROUND_PACKED: 160 unique seasonal tiles; all 160 typed coordinates preserved")
 quit(0)
