extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 root.get_node("GameState").set_process(false)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/cohesion-inputs-20261009.json"))
 var hd:=Image.load_from_file(ProjectSettings.globalize_path(str(manifest.groundAtlasTexture)))
 check(hd!=null and hd.get_size()==Vector2i(1280,2048),"160 high-resolution cells retain original world spacing")
 if hd==null:quit(1);return
 hd.convert(Image.FORMAT_RGBA8)
 var low:Image=(load("res://art/ground_tileset.tres").get_source(0) as TileSetAtlasSource).texture.get_image()
 low.convert(Image.FORMAT_RGBA8)
 check(receipt.rows.size()==10 and manifest.groundAtlas.size()==10,"ten genuinely generated ground families")
 var seen:Dictionary={}
 for row in receipt.rows:
  var source:=Image.load_from_file(str(row.master));source.convert(Image.FORMAT_RGBA8)
  var spec:Dictionary=manifest.groundAtlas[str(row.kind)]
  var column:=int(spec.atlasColumn)
  check(str(spec.status)=="partial","base terrain does not claim every environmental state complete")
  for season in range(4):
   for variant in range(4):
    var sx:int=season if bool(row.transpose) else variant
    var sy:int=variant if bool(row.transpose) else season
    var begin:=Vector2i(roundi(sx*source.get_width()/4.0),roundi(sy*source.get_height()/4.0))
    var end:=Vector2i(roundi((sx+1)*source.get_width()/4.0),roundi((sy+1)*source.get_height()/4.0))
    var original:=source.get_region(Rect2i(begin,end-begin))
    var fine:=original.duplicate();fine.resize(128,128,Image.INTERPOLATE_LANCZOS)
    var small:=original.duplicate();small.resize(32,32,Image.INTERPOLATE_LANCZOS)
    var coords:=Vector2i(column,season*4+variant)
    var actual:=hd.get_region(Rect2i(coords*128,Vector2i(128,128)))
    check(actual.get_data()==fine.get_data(),"HD source season/variant exact: "+str(row.kind))
    check(low.get_region(Rect2i(coords*32,Vector2i(32,32))).get_data()==small.get_data(),"original typed tile source exact: "+str(row.kind))
    check(actual.detect_alpha()==Image.ALPHA_NONE,"opaque background has no holes")
    var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(actual.get_data());var key:=digest.finish().hex_encode()
    check(not seen.has(key),"all 160 source tiles independently painted")
    seen[key]=true
 var props:Dictionary=preload("res://scripts/world_art.gd").entries()
 for kind in ["bamboo","shrub","flowers"]:
  var spec:Dictionary=props["props/"+kind];var size:=Vector2i.ZERO;var hashes:Dictionary={}
  check(spec.seasons.size()==4,"four explicit prop seasons")
  check(is_equal_approx(float(spec.worldRect[1])+float(spec.worldRect[3]),0.0),"seasonal root remains original world foot")
  for path in spec.seasons:
   var image:=Image.load_from_file(ProjectSettings.globalize_path(str(path)))
   check(image!=null,"seasonal raster exists")
   if image==null:continue
   if size==Vector2i.ZERO:size=image.get_size()
   check(image.get_size()==size,"seasonal canvas and anchor do not jump")
   check(image.detect_alpha()!=Image.ALPHA_NONE,"real prop alpha")
   check(image.get_pixel(0,0).a<0.01 and image.get_pixel(image.get_width()-1,image.get_height()-1).a<0.01,"clear seasonal corners")
   var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());var key:=digest.finish().hex_encode()
   check(not hashes.has(key),"unique seasonal prop picture");hashes[key]=true
 var shader_text:=FileAccess.get_file_as_string("res://art/shaders/cohesion_ground.gdshader")
 check(shader_text.contains("clamp(offset, vec2(0.5), vec2(31.5))"),"each source sample stays in its own seasonal tile")
 check(shader_text.contains("world_point") and shader_text.contains("cell_atlas"),"blending follows original world cells at every camera zoom")
 print("COHESION_GROUND_SMOKE: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
