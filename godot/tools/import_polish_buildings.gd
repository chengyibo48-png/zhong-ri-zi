extends SceneTree
func _initialize()->void:
 var receipts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/polish-buildings-inputs-20261010.json"))
 var path:="res://data/world_art_manifest.json"
 var m:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var row:Dictionary=m.entries["buildings/home-an"]
 var base:=Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
 if base==null:quit(1);return
 var variants:Array=[str(row.path)]
 var source_frames:Array=[]
 for entry in receipts.rows:
  var image:=Image.load_from_file(str(entry.master))
  if image==null or image.detect_alpha()==Image.ALPHA_NONE:quit(1);return
  var low:=image.get_size();var high:=Vector2i(-1,-1)
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x,y).a>0.125:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  if low.x<2 or low.y<2 or high.x>image.get_width()-3 or high.y>image.get_height()-3:printerr("Seasonal roof clipped: ",entry.season);quit(1);return
  var box:=Rect2i(low,high-low+Vector2i.ONE).grow(2)
  var tile:=image.get_region(box)
  var factor:=minf(float(base.get_width())/box.size.x,float(base.get_height())/box.size.y)
  var dims:=Vector2i(maxi(1,roundi(box.size.x*factor)),maxi(1,roundi(box.size.y*factor)))
  tile.resize(dims.x,dims.y,Image.INTERPOLATE_LANCZOS)
  var offset:=Vector2i((base.get_width()-dims.x)/2,base.get_height()-dims.y)
  var canvas:=Image.create(base.get_width(),base.get_height(),false,Image.FORMAT_RGBA8)
  canvas.blit_rect(tile,Rect2i(Vector2i.ZERO,dims),offset)
  var output:="res://art/world/buildings/home-an/"+str(entry.season)+".png"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
  if canvas.save_png(output)!=OK:quit(1);return
  variants.append(output)
  source_frames.append({"season":entry.season,"sourceRect":[box.position.x,box.position.y,box.size.x,box.size.y],"packedSize":[dims.x,dims.y],"packedPosition":[offset.x,offset.y],"sourceSha256":entry.sha256})
 row.seasons=variants;row.seasonSourceFrames=source_frames;row.status="partial"
 row.seasonReview="pending_actual_scene; fine roof/door registration still subject to visual review"
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(m,"  ")+"\n");f.close()
 print("HOME_SEASONS_IMPORTED: unchanged spring base plus three real variants; same world rect, foot and entrance")
 quit(0)
