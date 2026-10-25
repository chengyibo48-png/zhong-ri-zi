extends SceneTree
const QUEUE_PATH="res://artifacts/characters-crops-completion-20261010/queue.json"
const MANIFEST_PATH="res://data/world_art_manifest.json"
var failed:=false
func bands(image:Image,area:Rect2i,vertical:bool)->Array[Vector2i]:
 var out:Array[Vector2i]=[];var start:=-1
 for axis in range(area.size.y if vertical else area.size.x):
  var used:=false
  for cross in range(area.size.x if vertical else area.size.y):
   var p:=area.position+(Vector2i(cross,axis) if vertical else Vector2i(axis,cross))
   if image.get_pixelv(p).a>.125:used=true;break
  if used and start<0:start=axis
  if not used and start>=0:out.append(Vector2i(start,axis));start=-1
 if start>=0:out.append(Vector2i(start,area.size.y if vertical else area.size.x))
 return out
func visible(image:Image,area:Rect2i)->Rect2i:
 var low:=area.end;var high:=Vector2i(-1,-1)
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   if image.get_pixel(x,y).a>.125:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
 return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()
func foot(image:Image,box:Rect2i)->Vector2i:
 var low:=box.end.x;var high:=box.position.x
 for y in range(maxi(box.position.y,box.end.y-5),box.end.y):
  for x in range(box.position.x,box.end.x):
   if image.get_pixel(x,y).a>.125:low=mini(low,x);high=maxi(high,x)
 return Vector2i(roundi((low+high)/2.0),box.end.y-1)
func fit_frames(source:Image,bounds:Array[Rect2i],ratio:float)->Array:
 var out:Array=[]
 for box in bounds:
  var padded:=box.grow(4).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
  var image:=source.get_region(padded)
  image.resize(maxi(1,roundi(padded.size.x*ratio)),maxi(1,roundi(padded.size.y*ratio)),Image.INTERPOLATE_LANCZOS)
  var actual:=visible(image,Rect2i(Vector2i.ZERO,image.get_size()))
  var root:=foot(image,actual);var offset:=Vector2i(64,116)-root
  if not Rect2i(1,1,126,126).encloses(Rect2i(offset,image.get_size())):return []
  out.append({"image":image,"offset":offset,"sourceRect":[padded.position.x,padded.position.y,padded.size.x,padded.size.y],"factor":ratio,"size":[image.get_width(),image.get_height()],"root":[root.x,root.y]})
 return out
func _initialize()->void:
 var queue:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
 var imported:=0
 for job in queue.cropJobs:
  if job.status!="approved_source":continue
  var source:=Image.load_from_file(str(job.master))
  if source==null or source.detect_alpha()==Image.ALPHA_NONE or FileAccess.get_sha256(str(job.master))!=str(job.sha256):push_error("Invalid source "+str(job.id));failed=true;continue
  var whole:=visible(source,Rect2i(Vector2i.ZERO,source.get_size()))
  if not Rect2i(4,4,source.get_width()-8,source.get_height()-8).encloses(whole):push_error("Clipped outer silhouette "+str(job.id));failed=true;continue
  var rows:=bands(source,Rect2i(Vector2i.ZERO,source.get_size()),true)
  if rows.size()!=4:push_error("Expected four separate condition rows "+str(job.id)+" got "+str(rows.size()));failed=true;continue
  var bounds:Array[Rect2i]=[];var maximum:=0
  for row in rows:
   var strip:=Rect2i(0,row.x,source.get_width(),row.y-row.x)
   var columns:=bands(source,strip,false)
   if columns.size()!=4:push_error("Expected four separate stage columns "+str(job.id)+" got "+str(columns.size()));failed=true;break
   for column in columns:
    var box:=visible(source,Rect2i(column.x,row.x,column.y-column.x,row.y-row.x))
    bounds.append(box);maximum=maxi(maximum,maxi(box.size.x,box.size.y))
  if bounds.size()!=16:continue
  var factor:=112.0/maximum;var frames:Array=[]
  for attempt in range(24):
   frames=fit_frames(source,bounds,factor)
   if frames.size()==16:break
   factor*=.95
  if frames.size()!=16:push_error("Cannot fit complete silhouettes "+str(job.id));failed=true;continue
  var entry:Dictionary=manifest.entries["crops/"+str(job.id)]
  var receipt:Array=[]
  for row in range(4):
   var kind:String=["healthy","wilt","pest","disease"][row]
   if row==0 and bool(job.preserveHealthy):continue
   var atlas:=Image.create(512,128,false,Image.FORMAT_RGBA8)
   var sources:Array=[]
   for column in range(4):
    var item:Dictionary=frames[row*4+column]
    atlas.blit_rect(item.image,Rect2i(Vector2i.ZERO,item.image.get_size()),Vector2i(column*128,0)+item.offset)
    sources.append({"rect":item.sourceRect,"factor":item.factor,"size":item.size,"offset":[item.offset.x,item.offset.y],"root":item.root})
   var path:="res://art/world/crops/complete/"+str(job.id)+"/"+kind+".png"
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
   if atlas.save_png(path)!=OK:push_error("PNG save failed");quit(1);return
   var spec:Dictionary={"path":path,"status":"partial","baseReady":true,"frames":4,"frameSize":[128,128],"anchor":[64,116],"sourceFrames":sources,"sourceSha256":job.sha256,"sourceMaster":job.master,"condition":kind,"visualReview":"pending_actual_scene"}
   if row==0:entry.merge(spec,true)
   else:
    if not entry.has("stateVariants"):entry.stateVariants={}
    entry.stateVariants[kind]=spec
   receipt.append({"kind":kind,"path":path,"sha256":FileAccess.get_sha256(path)})
  manifest.entries["crops/"+str(job.id)]=entry
  job.status="imported_pending_live_review";job.outputs=receipt;job.commonFactor=factor;imported+=1
 var file:=FileAccess.open(MANIFEST_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 file=FileAccess.open(QUEUE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(queue,"  ")+"\n");file.close()
 print("COMPLETE_CROP_PACK_IMPORT: ",imported," packs imported; failures=",failed)
 quit(1 if failed else 0)
