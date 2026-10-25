extends SceneTree
const ART=preload("res://scripts/farm_surface_art.gd")
var passed:=0
var failed:=0
func check(value:bool,label:String)->void:
 if value:passed+=1
 else:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:
 call_deferred("run")
func run()->void:
 var queue:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/characters-crops-completion-20261010/queue.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 check(queue.cropJobs.size()==28,"28 crop families")
 var new_bases:=0;var states:=0;var checked_frames:=0
 for job in queue.cropJobs:
  check(job.status=="imported_pending_live_review" or job.status=="verified","Imported "+str(job.id))
  var entry:Dictionary=manifest.entries["crops/"+str(job.id)]
  check(bool(entry.get("baseReady",false)),"Healthy base "+str(job.id))
  if not bool(job.preserveHealthy):new_bases+=1
  for kind in ["healthy","wilt","pest","disease"]:
   var spec:Dictionary=entry if kind=="healthy" else entry.get("stateVariants",{}).get(kind,{})
   check(not spec.is_empty(),str(job.id)+" "+kind)
   if spec.is_empty():continue
   if kind!="healthy":states+=1
   var atlas:=Image.load_from_file(ProjectSettings.globalize_path(spec.path))
   check(atlas!=null and atlas.get_size()==Vector2i(512,128),"Atlas dimensions "+str(job.id)+kind)
   if atlas==null:continue
   var hashes:Dictionary={}
   for stage in range(4):
    var tile:=atlas.get_region(Rect2i(stage*128,0,128,128))
    check(tile.get_used_rect().has_area(),"Visible stage "+str(job.id)+kind+str(stage))
    hashes[tile.get_data().hex_encode().sha256_text()]=true
   check(hashes.size()==4,"Distinct stages "+str(job.id)+kind)
   if not spec.has("sourceMaster") or (kind=="healthy" and bool(job.preserveHealthy)):continue
   var source:=Image.load_from_file(ProjectSettings.globalize_path(spec.sourceMaster))
   check(FileAccess.get_sha256(spec.sourceMaster)==str(spec.sourceSha256),"Source hash "+str(job.id)+kind)
   for stage in range(4):
    var receipt:Dictionary=spec.sourceFrames[stage]
    var rect:Array=receipt.rect;var size:Array=receipt.size;var offset:Array=receipt.offset
    var tile:=source.get_region(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3])))
    tile.resize(int(size[0]),int(size[1]),Image.INTERPOLATE_LANCZOS)
    var expected:=Image.create(128,128,false,Image.FORMAT_RGBA8)
    expected.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(int(offset[0]),int(offset[1])))
    check(expected.get_data()==atlas.get_region(Rect2i(stage*128,0,128,128)).get_data(),"Native replay "+str(job.id)+kind+str(stage));checked_frames+=1
    var root:Array=receipt.root
    check(int(root[0])+int(offset[0])==64 and int(root[1])+int(offset[1])==116,"Stable root "+str(job.id)+kind+str(stage))
 check(new_bases==20,"20 new base stage packs")
 check(states==84,"28 independent wilt/pest/disease sets")
 check(checked_frames==416,"416 newly packed frames")
 for row in [[0.0,0],[.249,0],[.25,1],[.699,1],[.7,2],[.999,2],[1.0,3],[2.0,3]]:check(ART.crop_stage(row[0])==int(row[1]),"Stage threshold "+str(row[0]))
 for row in [[{},"healthy"],[{"health":21},"wilt"],[{"pests":25},"pest"],[{"disease":25},"disease"],[{"disease":40,"pests":60},"pest"],[{"disease":60,"pests":40},"disease"],[{"disease":60,"pests":60},"disease"],[{"health":21,"disease":60},"wilt"],[{"health":100,"pests":0,"disease":0},"healthy"]]:
  var before:Dictionary=row[0].duplicate(true)
  check(ART.crop_condition(row[0])==row[1],"Condition priority "+str(row))
  check(before==row[0],"Read-only presentation")
 print("COMPLETE_CROPS: ",passed," passed, ",failed," failed; 20 bases, 84 state sets, 416 native replay frames")
 quit(1 if failed else 0)
