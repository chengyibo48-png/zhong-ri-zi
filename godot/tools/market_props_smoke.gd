extends SceneTree
var passed:=0
var failed:=0
const ART=preload("res://scripts/market_art.gd")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:
 var inputs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/market-prop-inputs-20261010.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var hashes:Dictionary={}
 for job in inputs.rows:
  var row:Dictionary=manifest.entries[job.key]
  var master:=Image.load_from_file(str(job.master));var image:=Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
  var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(FileAccess.get_file_as_bytes(str(job.master)));check(hash.finish().hex_encode()==str(job.sha256),"unmodified original source pixels")
  check(row.status=="partial" and bool(row.baseReady),"base artwork does not claim missing seasons or state variants")
  var box:Array=row.sourceVisibleRect
  var expected:=master.get_region(Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3])))
  expected.resize(256,roundi(256.0*int(box[3])/int(box[2])),Image.INTERPOLATE_LANCZOS)
  check(image.get_data()==expected.get_data(),"exact native crop and proportional source packing")
  check(image.get_width()==256 and image.detect_alpha()!=Image.ALPHA_NONE,"real alpha bitmap at production resolution")
  check(image.get_pixel(0,0).a<.01 and image.get_pixel(255,image.get_height()-1).a<.01,"transparent image corners")
  var rectangle:Array=row.worldRect
  check(is_zero_approx(float(rectangle[1])+float(rectangle[3])),"common visible foot line")
  check(is_equal_approx(float(rectangle[2])/float(rectangle[3]),float(box[2])/float(box[3])),"world display keeps source proportions")
  hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data());var signature:=hash.finish().hex_encode();check(not hashes.has(signature),"every new object has a distinct design");hashes[signature]=true
 var jobs:Array=[{"id":"cabbage","qty":7,"channel":"stall","ready":450.25,"price":420,"grade":"good"},{"id":"cabbage","qty":2,"channel":"coop","ready":1830,"price":140,"grade":"normal"}]
 var original:Array=jobs.duplicate(true)
 for channel in ["stall","coop"]:
  for now in [360.0,450.25,1830.0]:
   var display:Dictionary=ART.descriptor(channel,jobs,now)
   check(not display.is_empty(),"explicit handover artwork binding")
   check(display.goods.size()==1,"channel filters other handover jobs")
   check(display.goods[0].texture==preload("res://scripts/item_art.gd").texture_for("cabbage","items"),"real goods illustration selected by original item id")
   check(display.ready==(now>=450 if channel=="stall" else now>=1830),"original integer readiness feedback preserved")
   check(display.goods[0].quantity==(7 if channel=="stall" else 2),"display quantity matches original trade packet")
 check(ART.descriptor("stall",[],360).goods.is_empty(),"empty table has no invented goods")
 check(not ART.descriptor("coop",[],360).ready,"empty table has no invented reward")
 check(ART.descriptor("invalid",jobs,360).is_empty(),"unknown channel cannot borrow another design")
 check(jobs==original,"display cannot change quantities, quality, price, readiness or channel")
 var many:Array=[]
 for i in 5:many.append({"id":"cabbage","qty":1,"channel":"coop","ready":1830})
 check(ART.descriptor("coop",many,360).goods.size()==3,"visible goods limit does not consume hidden jobs")
 check(many.size()==5,"display leaves all pending jobs intact")
 print("MARKET_PROPS: ",passed," passed, ",failed," failed");quit(1 if failed else 0)
