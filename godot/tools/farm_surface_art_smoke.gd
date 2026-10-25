extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed+=1
 else: failed+=1;push_error(label)
func _initialize() -> void:
 var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/farm-earth-inputs-20261009.json"))
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var distinct: Dictionary={}
 for row in receipt.rows:
  var kind:=str(row.kind)
  if kind.ends_with("rejected"):continue
  var key:="fixtures/general_counter" if kind=="counter" else "terrain/"+kind
  var entry: Dictionary=manifest.entries[key]
  check(entry.status=="partial" and bool(entry.baseReady),"base image never claims whole fixture/soil complete")
  var master:=Image.load_from_file(str(row.master))
  check(master!=null,"unaltered original master retained")
  var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(FileAccess.get_file_as_bytes(str(row.master)))
  check(context.finish().hex_encode()==str(row.sha256),"source master exact byte hash")
  var image:=Image.load_from_file(ProjectSettings.globalize_path(str(entry.path)))
  check(image!=null and image.get_width()==256,"real native packed bitmap")
  check(image.detect_alpha()!=Image.ALPHA_NONE,"genuine alpha silhouette")
  for corner in [Vector2i.ZERO,Vector2i(image.get_width()-1,0),Vector2i(0,image.get_height()-1),image.get_size()-Vector2i.ONE]:
   check(image.get_pixelv(corner).a<0.01,"transparent corners")
  var bounds:Array=entry.sourceVisibleRect
  var expected:=master.get_region(Rect2i(int(bounds[0]),int(bounds[1]),int(bounds[2]),int(bounds[3])))
  expected.resize(256,maxi(1,roundi(256.0*float(bounds[3])/float(bounds[2]))),Image.INTERPOLATE_LANCZOS)
  check(expected.get_data()==image.get_data(),"actual asset exact Godot structural crop and resize")
  context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(image.get_data())
  var hash_value:=context.finish().hex_encode();check(not distinct.has(hash_value),"dry/wet/counter are distinct images");distinct[hash_value]=true
 var old:=FileAccess.get_file_as_string("res://artifacts/farm-earth-before-20261009/scripts/farm_plot.gd").replace("\r\n","\n")
 var current:=FileAccess.get_file_as_string("res://scripts/farm_plot.gd").replace("\r\n","\n")
 # 2026-10-16 intentionally adds a soil child and replaces the hover rectangle
 # with corner marks. Preserve the facility and growth-pulse contracts separately;
 # topology, read-only rendering and collision are covered by farming_soil_smoke.
 check(old.substr(old.find("\tfor facility"),old.find("\tif index == FarmWorld.hovered_plot")-old.find("\tfor facility"))==current.substr(current.find("\tfor facility"),current.find("\tif index == FarmWorld.hovered_plot")-current.find("\tfor facility")),"facility identity, durability and glyph rendering preserved")
 check(old.substr(old.find("func notify_growth"),old.find("func _draw")-old.find("func notify_growth"))==current.substr(current.find("func notify_growth"),current.find("func _draw")-current.find("func notify_growth")),"growth pulse and reduced-motion behavior preserved")
 var old_fallback:=old.substr(old.find("\t\tvar height :="),old.find("\tfor facility")-old.find("\t\tvar height :="))
 var new_fallback:=current.substr(current.find("\t\t\tvar height :="),current.find("\t\tif progress>=1.0 and growth_pulse_age")-current.find("\t\t\tvar height :="))
 check(old_fallback.replace("\t","")==new_fallback.replace("\t",""),"missing or unknown crop art retains exact original fallback code")
 check(FileAccess.get_file_as_string("res://scripts/farm_surface_art.gd").contains("Rect2(-15,-1,30,12)"),"bounded soil foot remains within original 30x22 plot")
 check(FileAccess.get_file_as_string("res://scripts/farm_surface_art.gd").contains("clampf(float(data.get(\"moisture\",45))/100.0,0.0,1.0)"),"moisture blend reads clamped original state only")
 var script:=load("res://scripts/farm_surface_art.gd")
 check(script!=null,"typed production renderer compiles")
 for pair in [[-1.0,0],[0.0,0],[0.249,0],[0.25,1],[0.699,1],[0.7,2],[0.999,2],[1.0,3],[8.0,3]]:
  check(script.crop_stage(float(pair[0]))==int(pair[1]),"stage boundary derives from original growth progress")
 var crop:Dictionary=manifest.entries["crops/cabbage"]
 check(crop.status=="partial" and crop.frames==4,"four stages do not claim wilt/pests complete")
 var source_receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/cabbage-input-20261009.json"))
 var master:=Image.load_from_file(str(source_receipt.master))
 var sheet:=Image.load_from_file(ProjectSettings.globalize_path(str(crop.path)))
 check(sheet.get_size()==Vector2i(512,128),"four crop cells")
 var source_context:=HashingContext.new();source_context.start(HashingContext.HASH_SHA256);source_context.update(FileAccess.get_file_as_bytes(str(source_receipt.master)))
 check(source_context.finish().hex_encode()==str(source_receipt.sha256),"unaltered plant source retained")
 var hashes:Dictionary={}
 var last_pixels:=0
 for i in range(4):
  var frame:Dictionary=crop.sourceFrames[i]
  var box:Array=frame.sourceRect
  var expected:=Image.create(128,128,false,Image.FORMAT_RGBA8)
  var tile:=master.get_region(Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3])))
  var dimensions:=Vector2i(int(frame.packedSize[0]),int(frame.packedSize[1]))
  tile.resize(dimensions.x,dimensions.y,Image.INTERPOLATE_LANCZOS)
  expected.blit_rect(tile,Rect2i(Vector2i.ZERO,dimensions),Vector2i(int(frame.packedPosition[0]),int(frame.packedPosition[1])))
  var actual:=sheet.get_region(Rect2i(i*128,0,128,128))
  check(expected.get_data()==actual.get_data(),"native source crop, uniform resize and anchored packing exact")
  var bottom:=-1;var pixels:=0
  for y in 128:
   for x in 128:
    if actual.get_pixel(x,y).a>0.125:
     bottom=maxi(bottom,y);pixels+=1
     check(x>0 and x<127 and y>0 and y<127,"whole plant stays inside own frame")
  check(bottom==116,"visible plant stem shares original foot")
  check(pixels>last_pixels,"successive stage silhouette grows rather than normalized to same size");last_pixels=pixels
  var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(actual.get_data())
  var hash_value:=context.finish().hex_encode();check(not hashes.has(hash_value),"four distinct stages");hashes[hash_value]=true
 print("FARM_SURFACE_ART: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
