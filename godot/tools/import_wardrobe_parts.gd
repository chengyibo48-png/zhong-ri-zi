extends SceneTree
const PACK=preload("res://tools/import_complete_crop_packs.gd")
func _initialize()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:quit(1);return
 var outfit:=args[0];var source:=Image.load_from_file(args[1]);var helper:=PACK.new()
 if source==null or source.detect_alpha()==Image.ALPHA_NONE:push_error("Wardrobe requires alpha");helper.free();quit(1);return
 var rows:=helper.bands(source,Rect2i(Vector2i.ZERO,source.get_size()),true)
 var names:Array=["torso","arm_left","arm_right","leg_left","leg_right","bag"]
 if outfit=="heads":names=["head","short","bob","bun","wave","hat"]
 if outfit=="transport":names=["bike","pony","hood","beanie"]
 if outfit=="tools":names=["hoe","spade","axe","water","rod","sickle"]
 if outfit=="props":names=["brush","hammer","book","parcel","ladle","bell"]
 if rows.size()!=4:push_error("Wardrobe needs four directions");helper.free();quit(1);return
 var path:="res://data/wardrobe_art_manifest.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"packs":{},"directions":["down","left","right","up"],"status":"pending_actual_scene"}
 var parts:Dictionary={}
 for row in range(4):
  var strip:=Rect2i(0,rows[row].x,source.get_width(),rows[row].y-rows[row].x)
  var columns:=helper.bands(source,strip,false)
  if columns.size()!=names.size():push_error("Wardrobe columns mismatch: "+outfit+str(row)+" got "+str(columns.size()));helper.free();quit(1);return
  var direction:String=manifest.directions[row];parts[direction]={}
  for column in range(names.size()):
   var box:=helper.visible(source,Rect2i(columns[column].x,strip.position.y,columns[column].y-columns[column].x,strip.size.y)).grow(3).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
   var tile:=source.get_region(box);var factor:=116.0/maxi(box.size.x,box.size.y)
   tile.resize(maxi(1,roundi(box.size.x*factor)),maxi(1,roundi(box.size.y*factor)),Image.INTERPOLATE_LANCZOS)
   var offset:=Vector2i((128-tile.get_width())/2,(128-tile.get_height())/2)
   var frame:=Image.create(128,128,false,Image.FORMAT_RGBA8);frame.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),offset)
   var output:="res://art/characters/player/wardrobe/"+outfit+"/"+direction+"-"+str(names[column])+".png"
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
   if frame.save_png(output)!=OK:helper.free();quit(1);return
   parts[direction][names[column]]={"path":output,"region":[offset.x,offset.y,tile.get_width(),tile.get_height()],"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"factor":factor,"size":[tile.get_width(),tile.get_height()],"offset":[offset.x,offset.y]}
 manifest.packs[outfit]={"sourceMaster":args[1],"sourceSha256":FileAccess.get_sha256(args[1]),"parts":parts,"visualReview":"pending_actual_scene"}
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close();helper.free()
 print("WARDROBE_PARTS_IMPORTED: ",outfit," ",4*names.size()," handpainted components");quit(0)

