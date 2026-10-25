extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:
 var art=preload("res://scripts/world_art.gd");var rows:Dictionary=art.entries();var willow:Dictionary=rows["props/willow"]
 check(willow.seasons.size()==4,"four independently painted willow seasons")
 var dims:=Vector2i.ZERO;var hashes:Dictionary={}
 for path in willow.seasons+[rows["forage/mushroom"].path,rows["forage/wood"].path,rows["forage/shoot"].path,rows["forage/berry"].path,rows["forage/tea"].path,rows["forage/wildHerb"].path,rows["forage/bamboo"].path]:
  var texture:=preload("res://scripts/character_art.gd").texture(str(path));check(texture!=null,"native PNG loads "+str(path))
  if texture==null:continue
  var image:=texture.get_image();check(image.detect_alpha()!=Image.ALPHA_NONE,"genuine transparency")
  for p in [Vector2i.ZERO,Vector2i(image.get_width()-1,0),Vector2i(0,image.get_height()-1),image.get_size()-Vector2i.ONE]:check(image.get_pixelv(p).a<.01,"transparent corners")
  var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());var signature:=digest.finish().hex_encode();check(not hashes.has(signature),"independent visible source pixels");hashes[signature]=true
  if str(path).contains("/willow/"):
   if dims==Vector2i.ZERO:dims=image.get_size()
   check(image.get_size()==dims,"shared seasonal canvas")
 for key in ["props/willow","forage/mushroom","forage/wood","forage/shoot","forage/berry","forage/tea","forage/wildHerb","forage/bamboo"]:
  var row:Dictionary=rows[key];check(row.status=="partial","base art not complete action or seasonal states")
  check(is_zero_approx(float(row.worldRect[1])+float(row.worldRect[3])),"stable ground foot")
 check(float(willow.worldRect[2])<=48 and float(willow.worldRect[3])<=56,"original tree envelope retained")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"));var count:=0
 for prop in source.village.allProps:
  if str(prop.get("kind",""))=="willow":count+=1;check(art.key_for(prop)=="props/willow","original willow consumes own art")
 check(count>0,"original map willow nodes retained")
 print("WILLOW_FORAGE: ",passed," passed, ",failed," failed");quit(1 if failed else 0)
