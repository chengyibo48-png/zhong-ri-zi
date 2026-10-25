extends SceneTree
func _initialize()->void:
 var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/willow-forage-inputs-20261010.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var shared:=Vector2i.ZERO;var sources:Array[Image]=[]
 for job in input.rows:
  var image:=Image.load_from_file(str(job.master))
  if image==null or image.detect_alpha()==Image.ALPHA_NONE:quit(1);return
  var low:=image.get_size();var high:=Vector2i(-1,-1)
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x,y).a>.125:
     if x==0 or y==0 or x==image.get_width()-1 or y==image.get_height()-1:push_error("Clipped source "+str(job.name));quit(1);return
     low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  if high.x<0:quit(1);return
  var crop:=image.get_region(Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,image.get_size())))
  sources.append(crop)
  if job.group=="willow":shared=shared.max(crop.get_size())
 var paths:Array=[]
 for i in input.rows.size():
  var job:Dictionary=input.rows[i];var image:Image=sources[i];var size:=image.get_size()
  if job.group=="willow":
   var canvas:=Image.create(shared.x,shared.y,false,Image.FORMAT_RGBA8);canvas.blit_rect(image,Rect2i(Vector2i.ZERO,size),Vector2i((shared.x-size.x)/2,shared.y-size.y));image=canvas;size=shared
  image.resize(256,maxi(1,roundi(256.0*size.y/size.x)),Image.INTERPOLATE_LANCZOS)
  var path:="res://art/world/"+("props/willow/"+str(job.name) if job.group=="willow" else "forage/"+str(job.name))+".png"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
  if image.save_png(path)!=OK:quit(1);return
  if job.group=="willow":paths.append(path)
  else:
   var width:=30.0;var height:=width*size.y/size.x
   manifest.entries["forage/"+str(job.name)]={"name":job.label,"path":path,"baseReady":true,"status":"partial","sourceSha256":job.sha256,"worldRect":[-width/2,-height,width,height],"requiredChecks":["material_detail","placement","regrowth_states","seasonal_variants"],"reviewed":["material_detail"]}
 var factor:=minf(48.0/shared.x,56.0/shared.y);var bounds:=Vector2(shared)*factor
 var row:Dictionary=manifest.entries["props/willow"]
 row.path=paths[0];row.seasons=paths;row.baseReady=true;row.status="partial";row.worldRect=[-bounds.x/2,-bounds.y,bounds.x,bounds.y];row.reviewed=["material_detail","seasonal_variants"];row.verifiedChecks=[]
 var f:=FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"  ")+"\n");f.close()
 print("WILLOW_FORAGE_IMPORT: four willow seasons and two distinct resource sprites packed natively");quit(0)
