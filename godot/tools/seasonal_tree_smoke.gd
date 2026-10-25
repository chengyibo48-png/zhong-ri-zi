extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed+=1
 else: failed+=1;push_error(label)
func _initialize() -> void:
 var rows: Dictionary = preload("res://scripts/world_art.gd").entries()
 var signatures: Dictionary = {}
 for kind in ["blossom","orchard"]:
  var row: Dictionary = rows["props/"+kind]
  check(row.baseReady and row.status=="partial","painted base does not imply complete seasonal motion")
  check(row.seasons.size()==4,"four independent seasonal PNGs")
  var dimensions := Vector2i.ZERO
  for path in row.seasons:
   var texture := preload("res://scripts/character_art.gd").texture(str(path))
   check(texture!=null,"real imported tree PNG")
   if texture==null:continue
   var image := texture.get_image()
   check(image.detect_alpha()!=Image.ALPHA_NONE,"genuine alpha")
   for point in [Vector2i.ZERO,Vector2i(image.get_width()-1,0),Vector2i(0,image.get_height()-1),image.get_size()-Vector2i.ONE]:
    check(image.get_pixelv(point).a<.01,"empty transparent corners")
   if dimensions==Vector2i.ZERO:dimensions=image.get_size()
   check(dimensions==image.get_size(),"shared seasonal canvas dimensions")
   var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data());var signature:=hash.finish().hex_encode()
   check(not signatures.has(signature),"season is independently painted");signatures[signature]=true
  var rect: Array = row.worldRect
  check(float(rect[2])<=48.001 and float(rect[3])<=56.001,"bounded original tree envelope")
  check(is_zero_approx(float(rect[1])+float(rect[3])),"bottom anchor remains on ground")
 var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
 var counts: Dictionary = {"blossom":0,"orchard":0}
 for prop in source.village.allProps:
  var kind:=str(prop.get("kind",""))
  if counts.has(kind):counts[kind]+=1;check(preload("res://scripts/world_art.gd").key_for(prop)=="props/"+kind,"all original trees consume own family")
 check(counts.blossom==4 and counts.orchard==8,"all twelve original identities retained")
 print("SEASONAL_TREE: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
