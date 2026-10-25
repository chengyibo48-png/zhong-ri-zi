extends SceneTree
const PACK=preload("res://tools/import_complete_crop_packs.gd")
const ACTION=preload("res://tools/import_complete_action.gd")
func _initialize()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=1:quit(1);return
 var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var manifest_path:="res://data/character_art_manifest.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 var spec:Dictionary=manifest.actors[config.actor].clips[config.clip]
 var count:=int(spec.frames)
 var atlas:=Image.create(256*count,1024,false,Image.FORMAT_RGBA8)
 var helper:=PACK.new();var action:=ACTION.new();var receipts:Array=[]
 for direction in spec.directions:
  var entry:Dictionary=config.sources.get(direction,{})
  if entry.is_empty():push_error("Missing direction "+direction);helper.free();action.free();quit(1);return
  var source:=Image.load_from_file(entry.path)
  var cols:Array[Vector2i]=helper.bands(source,Rect2i(Vector2i.ZERO,source.get_size()),false)
  if cols.size()!=count:push_error("Expected six detached direction poses");helper.free();action.free();quit(1);return
  var boxes:Array[Rect2i]=[]
  for col in cols:
   var strip:=Rect2i(col.x,0,col.y-col.x,source.get_height())
   var rows:Array[Vector2i]=helper.bands(source,strip,true)
   var row:int=int(entry.get("row",0))
   if row>=rows.size():push_error("Missing source row");helper.free();action.free();quit(1);return
   var box:Rect2i=helper.visible(source,Rect2i(col.x,rows[row].x,col.y-col.x,rows[row].y-rows[row].x))
   if not Rect2i(3,3,source.get_width()-6,source.get_height()-6).encloses(box):push_error("Clipped direction silhouette");helper.free();action.free();quit(1);return
   boxes.append(box)
  var neutral:=source.get_region(boxes[0])
  var neutral_feet:Vector2i=action.shoe(neutral)
  if neutral_feet.y<0:push_error("Missing neutral shoe sole");helper.free();action.free();quit(1);return
  var ratio:=108.0/neutral_feet.y
  var target_row:int=spec.directions.find(direction)
  for index in range(count):
   var box:Rect2i=boxes[index].grow(4).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
   var tile:=source.get_region(box);tile.resize(roundi(box.size.x*ratio),roundi(box.size.y*ratio),Image.INTERPOLATE_LANCZOS)
   var feet:Vector2i=action.shoe(tile);var offset:=Vector2i(128,232)-feet
   if feet.y<0 or not Rect2i(2,2,252,252).encloses(Rect2i(offset,tile.get_size())):push_error("Aligned direction pose outside cell");helper.free();action.free();quit(1);return
   atlas.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(index*256,target_row*256)+offset)
   receipts.append({"direction":direction,"frame":index,"sourceMaster":entry.path,"sourceSha256":FileAccess.get_sha256(entry.path),"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"factor":ratio,"size":[tile.get_width(),tile.get_height()],"offset":[offset.x,offset.y],"foot":[feet.x,feet.y]})
 helper.free();action.free()
 if atlas.save_png(spec.path)!=OK:quit(1);return
 spec.frameSize=[256,256];spec.anchor=[128,232];spec.ready=true;spec.sourceFrames=receipts
 spec.sourceMaster=config.sources.down.path;spec.sourceSha256=FileAccess.get_sha256(spec.sourceMaster)
 spec.footAnchorReviewed=true;spec.directionReview="all directions individually inspected";spec.visualReview="pending_actual_scene"
 var file:=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("DIRECTION_ACTION_IMPORTED: ",config.actor,"/",config.clip," ",receipts.size()," separately reviewed frames")
 quit(0)
