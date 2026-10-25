extends SceneTree
const ART=preload("res://scripts/character_art.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json"))
 var queue:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/characters-crops-completion-20261010/queue.json"))
 var portraits:=0;var clips:=0;var frames:=0
 for actor_id in manifest.actors:
  var actor:Dictionary=manifest.actors[actor_id]
  for emotion in actor.get("expressionSources",{}):
   var receipt:Dictionary=actor.expressionSources[emotion]
   var image:=Image.load_from_file(ProjectSettings.globalize_path(receipt.path))
   check(image!=null and image.get_size()==Vector2i(256,320),str(actor_id)+emotion+" dimensions")
   if image==null:continue
   check(image.detect_alpha()!=Image.ALPHA_NONE and image.get_used_rect().has_area(),"Portrait alpha "+str(actor_id)+emotion)
   check(bool(actor.portraitReady[emotion]),"Portrait wired "+str(actor_id)+emotion)
   check(ART.portrait(actor_id,emotion)!=null,"Runtime portrait "+str(actor_id)+emotion)
   replay(image,receipt,Vector2i(256,320),"Portrait "+str(actor_id)+emotion)
   portraits+=1
  for clip in actor.clips:
   var spec:Dictionary=actor.clips[clip]
   if not spec.has("sourceFrames") or not spec.sourceFrames[0].has("rect"):continue
   check(bool(spec.ready) and ART.has_clip(actor_id,clip),"Clip wired "+str(actor_id)+clip)
   var size:=Vector2i(int(spec.frameSize[0]),int(spec.frameSize[1]))
   var atlas:=Image.load_from_file(ProjectSettings.globalize_path(spec.path))
   check(atlas!=null and atlas.get_size()==Vector2i(size.x*int(spec.frames),size.y*4),"Action dimensions "+str(actor_id)+clip)
   if atlas==null:continue
   check(spec.directions==["down","left","right","up"],"Direction ordering "+str(actor_id)+clip)
   check(spec.sourceFrames.size()==int(spec.frames)*4,"All frames "+str(actor_id)+clip)
   for index in spec.sourceFrames.size():
    var receipt:Dictionary=spec.sourceFrames[index].duplicate(true)
    receipt.sourceMaster=receipt.get("sourceMaster",spec.sourceMaster)
    receipt.sourceSha256=receipt.get("sourceSha256",spec.sourceSha256)
    var tile:=atlas.get_region(Rect2i(index%int(spec.frames)*size.x,index/int(spec.frames)*size.y,size.x,size.y))
    replay(tile,receipt,size,str(actor_id)+clip+str(index))
    check(int(receipt.foot[0])+int(receipt.offset[0])==int(spec.anchor[0]) and int(receipt.foot[1])+int(receipt.offset[1])==int(spec.anchor[1]),"Feet anchor "+str(actor_id)+clip+str(index))
    check(tile.get_used_rect().has_area(),"Nonempty action "+str(actor_id)+clip+str(index));frames+=1
   clips+=1
 for item in queue.missingPortraits:check(item.get("status","")=="imported_pending_live_review" or item.get("status","")=="verified","Requested portrait imported")
 check(portraits==138,"Exactly 138 requested expression portraits")
 print("COMPLETE_CHARACTERS: ",passed," passed, ",failed," failed; ",portraits," portraits, ",clips," new clips, ",frames," replayed action frames")
 quit(1 if failed else 0)
func replay(actual:Image,receipt:Dictionary,size:Vector2i,label:String)->void:
 var source:=Image.load_from_file(ProjectSettings.globalize_path(receipt.sourceMaster))
 check(source!=null and FileAccess.get_sha256(receipt.sourceMaster)==str(receipt.sourceSha256),"Source provenance "+label)
 if source==null:return
 var rect:Array=receipt.rect;var dimensions:Array=receipt.size;var offset:Array=receipt.offset
 var tile:=source.get_region(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3])))
 tile.resize(int(dimensions[0]),int(dimensions[1]),Image.INTERPOLATE_LANCZOS)
 var expected:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 expected.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(int(offset[0]),int(offset[1])))
 check(expected.get_data()==actual.get_data(),"Exact native replay "+label)

