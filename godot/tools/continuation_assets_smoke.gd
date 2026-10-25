extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 create_timer(120).timeout.connect(func():quit(1))
 await process_frame
 var state:=root.get_node("GameState");state.set_process(false)
 var inputs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/continuation-inputs-20261010.json"))
 var world:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var actors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json"))
 var hashes:Dictionary={}
 for input in inputs.rows:
  var source:=Image.load_from_file(str(input.master))
  check(FileAccess.get_sha256(str(input.master))==str(input.sha256),"unchanged original generated master")
  var spec:Dictionary
  if input.kind=="action":spec=actors.actors.player.clips[str(input.id)]
  elif input.kind=="crop_state":
   var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/characters-crops-completion-20261010/before/data/world_art_manifest.json"))
   spec=baseline.entries["crops/cabbage"].stateVariants[str(input.id).trim_prefix("cabbage_")]
  else:spec=world.entries["crops/"+str(input.id)]
  var atlas:=Image.load_from_file(ProjectSettings.globalize_path(str(spec.path)))
  check(atlas!=null and source.detect_alpha()!=Image.ALPHA_NONE,"real transparent PNG")
  check(atlas.get_size()==(Vector2i(768,512) if input.kind=="action" else Vector2i(512,128)),"declared atlas geometry")
  var previous:=0
  for i in spec.sourceFrames.size():
   var info:Dictionary=spec.sourceFrames[i];var b:Array=info.sourceRect;var d:Array=info.packedSize;var o:Array=info.packedPosition
   var tile:=source.get_region(Rect2i(int(b[0]),int(b[1]),int(b[2]),int(b[3])))
   tile.resize(int(d[0]),int(d[1]),Image.INTERPOLATE_LANCZOS)
   var expected:=Image.create(128,128,false,Image.FORMAT_RGBA8);expected.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(int(o[0]),int(o[1])))
   var actual:=atlas.get_region(Rect2i(int(info.get("column",i))*128,int(info.get("row",0))*128,128,128))
   check(actual.get_data()==expected.get_data(),"exact native source crop resize and anchored packing")
   var occupied:=0;var bottom:=-1;var shoes:Array[Vector2i]=[]
   for y in 128:
    for x in 128:
     var c:=actual.get_pixel(x,y)
     if c.a>.125:
      occupied+=1;bottom=maxi(bottom,y);check(x>0 and x<127 and y>0 and y<127,"no clipped silhouette or frame bleed")
     if input.kind=="action" and y>94 and c.a>=.5 and c.r>=c.g+8.0/255 and c.g>=c.b+8.0/255 and (c.r+c.g+c.b)/3<160.0/255:shoes.append(Vector2i(x,y))
   if input.kind=="action":
    var left:=128;var right:=-1;var sole:=-1
    for point in shoes:left=mini(left,point.x);right=maxi(right,point.x);sole=maxi(sole,point.y)
    check(right>=0 and absf((left+right+1)/2.0-64)<=3 and absi(sole+1-116)<=2,"actual seed shoes align independently of pouch")
   else:
    check(bottom==116 and occupied>previous,"crop stage grows and retains fixed rooted base");previous=occupied
   var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(actual.get_data());var key:=digest.finish().hex_encode()
   check(not hashes.has(key),"distinct stage or action pose");hashes[key]=true
 var props:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/continuation-prop-inputs-20261010.json"))
 for input in props.rows:
  var row:Dictionary=world.entries[input.key]
  var master:=Image.load_from_file(str(input.master))
  check(FileAccess.get_sha256(str(input.master))==str(input.sha256),"prop master provenance matches")
  var box:Array=row.sourceVisibleRect
  var expected:=master.get_region(Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3])))
  expected.resize(256,roundi(256.0*float(box[3])/float(box[2])),Image.INTERPOLATE_LANCZOS)
  var actual:=Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
  check(actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data(),"prop PNG exactly matches native source crop and scale")
  check(actual.detect_alpha()!=Image.ALPHA_NONE and bool(row.fitLayout),"prop keeps genuine transparency and aspect-safe fit")
  check(row.status=="partial" and bool(row.baseReady),"prop seasons and interaction art stay incomplete")
 var art:=preload("res://scripts/farm_surface_art.gd")
 for h in [10,21,22,100]:
  for p in [0,24,25,100]:
   var data:Dictionary={"health":h,"pests":p,"disease":0}
   var old:Dictionary=data.duplicate(true)
   check(art.crop_condition(data)==("wilt" if h<22 else "pest" if p>=25 else "healthy"),"exact reversible stress and pest thresholds; disease is not mislabeled as insects")
   check(data==old,"visual state lookup never changes plot")
 var all_clips:=true
 for spec in actors.actors.player.clips.values():all_clips=all_clips and bool(spec.get("ready",false))
 check(not bool(actors.actors.player.ready) or all_clips,"player cannot be marked complete before every required action")
 for draft in inputs.rejected:
  var current:Dictionary=actors.actors.player.clips[str(draft.id)]
  check(not bool(current.get("ready",false)) or str(current.get("sourceSha256",""))!=FileAccess.get_sha256(str(draft.source)),"rejected direction draft cannot become an approved clip")
 print("CONTINUATION_ASSETS: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
