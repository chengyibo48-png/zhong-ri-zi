extends SceneTree
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=4:quit(1);return
 var kind:=str(args[0]);var limits:=Vector2(float(args[2]),float(args[3]))
 var master:=Image.load_from_file(str(args[1]))
 if master==null or master.detect_alpha()==Image.ALPHA_NONE:quit(1);return
 master.convert(Image.FORMAT_RGBA8)
 var bands:Array[Rect2i]=[];var left:=-1
 for x in range(master.get_width()+1):
  var active:=false
  if x<master.get_width():
   for y in range(master.get_height()):
    if master.get_pixel(x,y).a>0.125:active=true;break
  if active and left<0:left=x
  elif not active and left>=0:bands.append(Rect2i(left,0,x-left,master.get_height()));left=-1
 if bands.size()!=4:printerr("Expected four isolated seasonal sprites");quit(1);return
 var crops:Array[Image]=[];var shared:=Vector2i.ZERO
 for band in bands:
  var low:=master.get_size();var high:=Vector2i(-1,-1)
  for x in range(band.position.x,band.end.x):
   for y in range(master.get_height()):
    if master.get_pixel(x,y).a<=0.125:continue
    if x<2 or y<2 or x>=master.get_width()-2 or y>=master.get_height()-2:printerr("Clipped silhouette");quit(1);return
    low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  var crop:=master.get_region(Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,master.get_size())))
  crops.append(crop);shared=shared.max(crop.get_size())
 var factor:=minf(limits.x/shared.x,limits.y/shared.y)
 var world_size:=Vector2(shared)*factor
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var row:Dictionary=manifest.entries["props/"+kind];var paths:Array=[];var hashes:Dictionary={}
 for season in range(4):
  var canvas:=Image.create(shared.x,shared.y,false,Image.FORMAT_RGBA8)
  var crop:Image=crops[season]
  canvas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((shared.x-crop.get_width())/2,shared.y-crop.get_height()))
  canvas.resize(256,maxi(1,roundi(256.0*shared.y/shared.x)),Image.INTERPOLATE_LANCZOS)
  var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(canvas.get_data());var hash_value:=digest.finish().hex_encode()
  if hashes.has(hash_value):printerr("Repeated seasonal image");quit(1);return
  hashes[hash_value]=true
  var path: String="res://art/world/props/"+kind+"/"+str(["spring","summer","autumn","winter"][season])+".png"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
  if canvas.save_png(path)!=OK:quit(1);return
  paths.append(path)
 row.path=paths[0];row.seasons=paths;row.worldRect=[-world_size.x/2,-world_size.y,world_size.x,world_size.y]
 row.baseReady=true;row.status="partial";row.reviewed=["material_detail","seasonal_variants"];row.verifiedChecks=[]
 var file:=FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("COHESION_SEASONAL_PROP_PACKED: ",kind,"; four independent seasons with shared foot canvas")
 quit(0)
