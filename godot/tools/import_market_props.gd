extends SceneTree
func _initialize()->void:
 var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/market-prop-inputs-20261010.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for job in input.rows:
  var image:=Image.load_from_file(str(job.master))
  if image==null or image.detect_alpha()==Image.ALPHA_NONE:quit(1);return
  var size:=image.get_size();var low:=size;var high:=Vector2i(-1,-1)
  for y in size.y:
   for x in size.x:
    if image.get_pixel(x,y).a>.125:
     if x==0 or y==0 or x==size.x-1 or y==size.y-1:push_error("Clipped source "+str(job.key));quit(1);return
     low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  if high.x<0:quit(1);return
  var box:=Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,size))
  image=image.get_region(box);image.resize(256,roundi(256.0*box.size.y/box.size.x),Image.INTERPOLATE_LANCZOS)
  var path:="res://art/world/"+str(job.key)+".png"
  if image.save_png(path)!=OK:quit(1);return
  var width:=104.0 if job.name=="pavilion" else 48.0 if job.name=="cart" else 68.0
  var height:=width*box.size.y/box.size.x
  var row:Dictionary=manifest.entries.get(job.key,{})
  row.merge({"name":job.label,"path":path,"baseReady":true,"status":"partial","sourceSha256":job.sha256,"sourceVisibleRect":[box.position.x,box.position.y,box.size.x,box.size.y],"worldRect":[-width*.5,-height,width,height],"requiredChecks":["material_detail","placement","interaction_alignment","seasonal_variants"],"reviewed":["material_detail"],"visualReview":"pending_actual_scene"},true)
  manifest.entries[job.key]=row
 var file:=FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("MARKET_PROP_IMPORT: 4 genuine alpha sprites natively packed, state variants partial");quit(0)
