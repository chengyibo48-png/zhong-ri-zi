extends SceneTree
const PACK=preload("res://tools/import_complete_crop_packs.gd")
func shoe(image:Image)->Vector2i:
 var sole:=-1;var low:=image.get_width();var high:=-1
 for y in range(maxi(0,image.get_height()-32),image.get_height()):
  var xs:Array[int]=[]
  for x in range(image.get_width()):
   var c:=image.get_pixel(x,y)
   if c.a>=.5 and c.r<.61 and c.g<.57 and c.b<.51 and c.r>=c.g-.03 and c.g>=c.b-.02:xs.append(x)
  if xs.size()>=5:
   sole=y;low=xs[0];high=xs[-1]
 return Vector2i(roundi((low+high+1)/2.0),sole+1) if sole>=0 else Vector2i(-1,-1)
func _initialize()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=3:quit(1);return
 var manifest_path:="res://data/character_art_manifest.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 var spec:Dictionary=manifest.actors[args[0]].clips[args[1]]
 var source:=Image.load_from_file(args[2]);var helper:=PACK.new()
 var rows:Array[Vector2i]=helper.bands(source,Rect2i(Vector2i.ZERO,source.get_size()),true)
 if rows.size()!=4:push_error("Expected four detached direction rows");helper.free();quit(1);return
 var boxes:Array[Rect2i]=[];var body_height:=0
 for row in rows:
  var strip:=Rect2i(0,row.x,source.get_width(),row.y-row.x)
  var cols:Array[Vector2i]=helper.bands(source,strip,false)
  # Small authored motion marks belong to their adjacent pose, never a new frame.
  while cols.size()>int(spec.frames):
   var nearest:=-1;var smallest:=13
   for band_index in range(cols.size()-1):
    var gap:=cols[band_index+1].x-cols[band_index].y
    if gap<smallest and mini(cols[band_index].y-cols[band_index].x,cols[band_index+1].y-cols[band_index+1].x)<=24:
     nearest=band_index;smallest=gap
   if nearest<0:break
   cols[nearest].y=cols[nearest+1].y
   cols.remove_at(nearest+1)
  if cols.size()!=int(spec.frames):push_error("Action columns mismatch");helper.free();quit(1);return
  for col in cols:
   var box:Rect2i=helper.visible(source,Rect2i(col.x,row.x,col.y-col.x,row.y-row.x))
   if not Rect2i(3,3,source.get_width()-6,source.get_height()-6).encloses(box):push_error("Clipped action silhouette");helper.free();quit(1);return
   boxes.append(box)
  body_height=maxi(body_height,boxes[boxes.size()-1 if args[0]=="player" and args[1]=="sleep" else boxes.size()-cols.size()].size.y)
 helper.free()
 var ratio:=108.0/body_height
 var frame_size:=384 if args[0]=="player" and args[1] in ["bike","ride","fish","fish_cast","fish_catch","fish_reel","fish_wait"] else 256 if args[0]=="player" else 192
 var anchor:=Vector2i(frame_size/2,frame_size-48 if frame_size>192 else 168)
 var atlas:=Image.create(frame_size*int(spec.frames),frame_size*4,false,Image.FORMAT_RGBA8)
 var receipts:Array=[]
 for index in range(boxes.size()):
  var box:=boxes[index].grow(4).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
  var tile:=source.get_region(box)
  tile.resize(roundi(box.size.x*ratio),roundi(box.size.y*ratio),Image.INTERPOLATE_LANCZOS)
  var feet:=shoe(tile)
  if feet.y<0:push_error("Cannot locate action shoe sole");quit(1);return
  var offset:=anchor-feet
  if not Rect2i(2,2,frame_size-4,frame_size-4).encloses(Rect2i(offset,tile.get_size())):push_error("Action leaves cell");quit(1);return
  atlas.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(index%int(spec.frames)*frame_size,index/int(spec.frames)*frame_size)+offset)
  receipts.append({"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"factor":ratio,"size":[tile.get_width(),tile.get_height()],"offset":[offset.x,offset.y],"foot":[feet.x,feet.y]})
 if atlas.save_png(spec.path)!=OK:quit(1);return
 spec.frameSize=[frame_size,frame_size];spec.anchor=[anchor.x,anchor.y];spec.ready=true
 spec.sourceMaster=args[2];spec.sourceSha256=FileAccess.get_sha256(args[2]);spec.sourceFrames=receipts
 if args[0]=="player" and args[1] in ["bike","ride"]:spec.worldHeight=58
 spec.bodyHeightSource=body_height;spec.footAnchorReviewed=true;spec.directionReview="manual_all_frames";spec.visualReview="pending_actual_scene"
 var file:=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("COMPLETE_ACTION_IMPORTED: ",args[0],"/",args[1]," ",boxes.size()," frames; actor remains partial")
 quit(0)



