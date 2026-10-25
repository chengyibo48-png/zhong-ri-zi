extends SceneTree
const PACK = preload("res://tools/import_complete_crop_packs.gd")
func _initialize()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:quit(1);return
 var source:=Image.load_from_file(args[1])
 var helper:=PACK.new()
 var rows:Array[Vector2i]=helper.bands(source,Rect2i(Vector2i.ZERO,source.get_size()),true)
 if rows.size()!=2:push_error("Expected two detached portrait rows: "+str(rows));helper.free();quit(1);return
 var frames:Array[Rect2i]=[]
 for row in rows:
  var strip:=Rect2i(0,row.x,source.get_width(),row.y-row.x)
  var columns:Array[Vector2i]=helper.bands(source,strip,false)
  if columns.size()!=3:push_error("Expected three detached expression columns");helper.free();quit(1);return
  for col in columns:frames.append(helper.visible(source,Rect2i(col.x,row.x,col.y-col.x,row.y-row.x)))
 helper.free()
 var ratio:=1.0
 for box in frames:ratio=minf(ratio,minf(236.0/(box.size.x+8),300.0/(box.size.y+8)))
 var manifest_path:="res://data/character_art_manifest.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 var actor:Dictionary=manifest.actors[args[0]]
 var names:=["focus","happy","surprised","thought","tired","worried"]
 var receipts:Dictionary={}
 for index in range(6):
  var box:=frames[index].grow(4).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
  var frame:=source.get_region(box)
  frame.resize(roundi(box.size.x*ratio),roundi(box.size.y*ratio),Image.INTERPOLATE_LANCZOS)
  var offset:=Vector2i((256-frame.get_width())/2,310-frame.get_height())
  var target:=Image.create(256,320,false,Image.FORMAT_RGBA8)
  target.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),offset)
  var output:String=actor.portraits[names[index]]
  if target.save_png(output)!=OK:quit(1);return
  actor.portraitReady[names[index]]=true
  receipts[names[index]]={"sourceMaster":args[1],"sourceSha256":FileAccess.get_sha256(args[1]),"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"factor":ratio,"size":[frame.get_width(),frame.get_height()],"offset":[offset.x,offset.y],"path":output,"visualReview":"pending_actual_scene"}
 actor.expressionSources=receipts
 var file:=FileAccess.open(manifest_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("EXPRESSION_PACK_IMPORTED: ",args[0]," six expressions; actor remains partial")
 quit(0)
