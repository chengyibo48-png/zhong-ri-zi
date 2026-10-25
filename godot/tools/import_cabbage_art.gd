extends SceneTree
func _initialize()->void:
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/cabbage-input-20261009.json"))
 var image:=Image.load_from_file(str(receipt.master))
 if image==null or image.detect_alpha()==Image.ALPHA_NONE:quit(1);return
 var bands:Array[Vector2i]=[]
 var start:=-1
 for x in image.get_width():
  var occupied:=false
  for y in image.get_height():
   if image.get_pixel(x,y).a>0.125:occupied=true;break
  if occupied and start<0:start=x
  elif not occupied and start>=0:bands.append(Vector2i(start,x));start=-1
 if start>=0:bands.append(Vector2i(start,image.get_width()))
 if bands.size()!=4:printerr("Expected four clearly separated plant silhouettes");quit(1);return
 var bounds:Array[Rect2i]=[]
 var maximum:=0
 for band in bands:
  var low:=image.get_size();var high:=Vector2i(-1,-1)
  for y in image.get_height():
   for x in range(band.x,band.y):
    if image.get_pixel(x,y).a>0.125:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  if low.x<4 or low.y<4 or high.x>image.get_width()-5 or high.y>image.get_height()-5:quit(1);return
  var box:=Rect2i(low,high-low+Vector2i.ONE).grow(4)
  bounds.append(box);maximum=maxi(maximum,maxi(box.size.x,box.size.y))
 var sheet:=Image.create(512,128,false,Image.FORMAT_RGBA8)
 var frames:Array=[]
 var factor:=112.0/maximum
 for i in range(4):
  var box:=bounds[i];var tile:=image.get_region(box)
  var dimensions:=Vector2i(maxi(1,roundi(box.size.x*factor)),maxi(1,roundi(box.size.y*factor)))
  tile.resize(dimensions.x,dimensions.y,Image.INTERPOLATE_LANCZOS)
  var low:=tile.get_size();var high:=Vector2i(-1,-1)
  for y in tile.get_height():
   for x in tile.get_width():
    if tile.get_pixel(x,y).a>0.125:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  var sum_x:=0.0;var count:=0
  for y in range(maxi(low.y,high.y-2),high.y+1):
   for x in tile.get_width():
    if tile.get_pixel(x,y).a>0.125:sum_x+=x;count+=1
  if count==0:quit(1);return
  var position:=Vector2i(64-roundi(sum_x/count),116-high.y)
  if position.x<0 or position.y<0 or position.x+dimensions.x>128 or position.y+dimensions.y>128:printerr("Whole anchored crop must fit frame");quit(1);return
  sheet.blit_rect(tile,Rect2i(Vector2i.ZERO,dimensions),Vector2i(i*128,0)+position)
  frames.append({"sourceRect":[box.position.x,box.position.y,box.size.x,box.size.y],"packedSize":[dimensions.x,dimensions.y],"packedPosition":[position.x,position.y]})
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/world/crops"))
 if sheet.save_png("res://art/world/crops/cabbage.png")!=OK:quit(1);return
 var path:="res://data/world_art_manifest.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var row:Dictionary=manifest.entries["crops/cabbage"]
 row.merge({"baseReady":true,"status":"partial","frames":4,"frameSize":[128,128],"anchor":[64,116],"stages":["seedling","young","growing","mature"],"sourceSha256":receipt.sha256,"sourceFrames":frames,"visualReview":"pending_actual_scene"},true)
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("CABBAGE_IMPORT: four native anchored crop stages; wilted and pest variants still missing")
 quit(0)
