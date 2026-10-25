extends SceneTree
func _initialize() -> void:
 var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/farm-earth-inputs-20261009.json"))
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for row in receipt.rows:
  var kind := str(row.kind)
  if kind.ends_with("rejected"): continue
  var image := Image.load_from_file(str(row.master))
  if image == null or image.detect_alpha() == Image.ALPHA_NONE: quit(1);return
  var size := image.get_size()
  var low := size
  var high := Vector2i(-1,-1)
  for y in size.y:
   for x in size.x:
    if image.get_pixel(x,y).a > 0.125:
     if x==0 or y==0 or x==size.x-1 or y==size.y-1:printerr("Clipped silhouette");quit(1);return
     low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  if high.x<0:quit(1);return
  var bounds := Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,size))
  image=image.get_region(bounds)
  var dimensions := image.get_size()
  image.resize(256,maxi(1,roundi(256.0*dimensions.y/dimensions.x)),Image.INTERPOLATE_LANCZOS)
  var path := "res://art/world/terrain/"+kind+".png" if kind!="counter" else "res://art/world/fixtures/general_counter.png"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
  if image.save_png(path)!=OK:quit(1);return
  var key := "terrain/"+kind if kind!="counter" else "fixtures/general_counter"
  var entry: Dictionary = manifest.entries.get(key,{"name":"杂货柜台","requiredChecks":["placement","interaction_alignment","seasonal_variants"]})
  entry.merge({"path":path,"baseReady":true,"status":"partial","sourceSha256":row.sha256,"sourceVisibleRect":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"reviewed":["material_detail"],"visualReview":"pending_actual_scene"},true)
  manifest.entries[key]=entry
 var file := FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("FARM_EARTH_IMPORT: 3 transparent native bitmap assets packed")
 quit(0)
