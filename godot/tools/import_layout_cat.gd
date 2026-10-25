extends SceneTree
func _initialize()->void:
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/layout-cat-input-20261009.json"))
 var image:=Image.load_from_file(str(receipt.master))
 if image==null or image.detect_alpha()==Image.ALPHA_NONE:quit(1);return
 var bands:Array[Vector2i]=[];var start:=-1
 for x in image.get_width():
  var filled:=false
  for y in image.get_height():
   if image.get_pixel(x,y).a>0.125:filled=true;break
  if filled and start<0:start=x
  elif not filled and start>=0:bands.append(Vector2i(start,x));start=-1
 if start>=0:bands.append(Vector2i(start,image.get_width()))
 if bands.size()!=4:printerr("Four isolated full-body directions required");quit(1);return
 var boxes:Array[Rect2i]=[];var tallest:=0
 for band in bands:
  var low:=image.get_size();var high:=Vector2i(-1,-1)
  for y in image.get_height():
   for x in range(band.x,band.y):
    if image.get_pixel(x,y).a>0.125:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  if low.x<4 or low.y<4 or high.x>image.get_width()-5 or high.y>image.get_height()-5:quit(1);return
  var box:=Rect2i(low,high-low+Vector2i.ONE).grow(4);boxes.append(box);tallest=maxi(tallest,box.size.y)
 var sheet:=Image.create(1024,128,false,Image.FORMAT_RGBA8);var frames:Array=[];var ratio:=108.0/tallest
 for i in range(4):
  var tile:=image.get_region(boxes[i]);var dimensions:=Vector2i(roundi(tile.get_width()*ratio),roundi(tile.get_height()*ratio));tile.resize(dimensions.x,dimensions.y,Image.INTERPOLATE_LANCZOS)
  var bottom:=-1
  for y in tile.get_height():
   for x in tile.get_width():
    if tile.get_pixel(x,y).a>0.125:bottom=maxi(bottom,y)
  var sum_x:=0.0;var count:=0
  for y in range(bottom-2,bottom+1):
   for x in tile.get_width():
    if tile.get_pixel(x,y).a>0.125:sum_x+=x;count+=1
  if count==0:quit(1);return
  var position:=Vector2i(128-roundi(sum_x/count),116-bottom)
  if position.x<0 or position.y<0 or position.x+dimensions.x>256 or position.y+dimensions.y>128:quit(1);return
  sheet.blit_rect(tile,Rect2i(Vector2i.ZERO,dimensions),Vector2i(i*256,0)+position)
  var b:=boxes[i];frames.append({"sourceRect":[b.position.x,b.position.y,b.size.x,b.size.y],"packedSize":[dimensions.x,dimensions.y],"packedPosition":[position.x,position.y]})
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/world/pets"))
 if sheet.save_png("res://art/world/pets/cat.png")!=OK:quit(1);return
 var path:="res://data/world_art_manifest.json";var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var row:Dictionary=manifest.entries["pets/cat"]
 row.merge({"baseReady":true,"status":"partial","directions":["down","left","right","up"],"frames":1,"frameSize":[256,128],"anchor":[128,116],"worldHeight":18,"sourceSha256":receipt.sha256,"sourceFrames":frames,"reviewed":["idle","proportion","interaction_alignment"],"visualReview":"pending_actual_scene"},true)
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("LAYOUT_CAT_IMPORT: four directions anchored; walking/action/sleep sprites remain pending");quit(0)
