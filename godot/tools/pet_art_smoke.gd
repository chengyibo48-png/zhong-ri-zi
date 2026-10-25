extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:
 call_deferred("run")
func run()->void:
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/layout-cat-input-20261009.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var row:Dictionary=manifest.entries["pets/cat"]
 var image:=Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
 var master:=Image.load_from_file(str(receipt.master))
 check(image.get_size()==Vector2i(1024,128),"four full-body cat directions")
 check(row.status=="partial" and row.frames==1,"idle still is not claimed as a gait/action loop")
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(FileAccess.get_file_as_bytes(str(receipt.master)))
 check(context.finish().hex_encode()==str(receipt.sha256),"source pixels unaltered")
 var actor:Dictionary={"position":{"direction":"down"},"energy":100}
 var original:Dictionary=actor.duplicate(true)
 var art=load("res://scripts/pet_art.gd")
 var hashes:Dictionary={}
 for i in range(4):
  var spec:Dictionary=row.sourceFrames[i];var bounds:Array=spec.sourceRect
  var tile:=master.get_region(Rect2i(int(bounds[0]),int(bounds[1]),int(bounds[2]),int(bounds[3])))
  var size:=Vector2i(int(spec.packedSize[0]),int(spec.packedSize[1]));tile.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  var expected:=Image.create(256,128,false,Image.FORMAT_RGBA8);expected.blit_rect(tile,Rect2i(Vector2i.ZERO,size),Vector2i(int(spec.packedPosition[0]),int(spec.packedPosition[1])))
  var frame:=image.get_region(Rect2i(i*256,0,256,128))
  check(expected.get_data()==frame.get_data(),"exact native source crop, resize and foot packing")
  var bottom:=-1
  for y in 128:
   for x in 256:
    if frame.get_pixel(x,y).a>.125:
     check(x>0 and x<255 and y>0 and y<127,"cat silhouette stays within own cell");bottom=maxi(bottom,y)
  check(bottom==116,"visible paws retain a common foot")
  context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(frame.get_data());var hash_value:=context.finish().hex_encode();check(not hashes.has(hash_value),"distinct directional cat view");hashes[hash_value]=true
  actor.position.direction=row.directions[i]
  var descriptor:Dictionary=art.frame(actor,{"type":"cat"},360)
  check(descriptor.direction==i,"original pet direction selects correct image")
  check(descriptor.destination.size.y<22,"cat is appropriately smaller than the player")
 var dog:Dictionary=art.frame(actor,{"type":"dog"},360)
 check(not dog.is_empty() and dog.texture.resource_path.contains("dog"),"dog uses its independent artwork")
 check(art.action_frame(actor,{"type":"cat"},1200,0).state=="sleeping","night sleep uses authored sleeping pose")
 actor.energy=10;check(art.action_frame(actor,{"type":"cat"},360,0).state=="sleeping","tired state uses authored sleeping feedback")
 actor=original.duplicate(true);art.frame(actor,{"type":"cat"},360);check(actor==original,"visual frame lookup cannot mutate saved pet state")
 var stove_receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/layout-stove-input-20261009.json"))
 var stove_row:Dictionary=manifest.entries["fixtures/kitchen_stove"]
 var stove_master:=Image.load_from_file(str(stove_receipt.master))
 var stove_image:=Image.load_from_file(ProjectSettings.globalize_path(str(stove_row.path)))
 context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(FileAccess.get_file_as_bytes(str(stove_receipt.master)))
 check(context.finish().hex_encode()==str(stove_receipt.sha256),"stove source pixels retain original generation hash")
 var stove_box:Array=stove_row.sourceVisibleRect
 var stove_expected:=stove_master.get_region(Rect2i(int(stove_box[0]),int(stove_box[1]),int(stove_box[2]),int(stove_box[3])))
 stove_expected.resize(256,roundi(256.0*int(stove_box[3])/int(stove_box[2])),Image.INTERPOLATE_LANCZOS)
 check(stove_expected.get_data()==stove_image.get_data(),"stove is exact native crop and proportional resize of real source")
 check(stove_image.detect_alpha()!=Image.ALPHA_NONE,"stove has transparent background")
 check(stove_row.status=="partial","stove cooking variants remain explicitly partial")
 print("PET_ART: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
