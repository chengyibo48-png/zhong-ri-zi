extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func hash_bytes(bytes:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func _initialize()->void:call_deferred("run")
func run()->void:
 var state:=root.get_node("GameState");state.set_process(false)
 var m:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 var receipts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/polish-crops-inputs-20261010.json"))
 var distinct:Dictionary={}
 for source in receipts.rows:
  check(hash_bytes(FileAccess.get_file_as_bytes(str(source.master)))==str(source.sha256),"crop source retained unchanged")
  var master:=Image.load_from_file(str(source.master));var row:Dictionary=m.entries["crops/"+str(source.id)]
  var sheet:=Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
  check(sheet.get_size()==Vector2i(512,128) and row.status=="partial" and bool(row.baseReady),"four actual stages, not full crop art")
  var previous:=0
  for i in range(4):
   var info:Dictionary=row.sourceFrames[i];var box:Array=info.sourceRect
   var expected:=Image.create(128,128,false,Image.FORMAT_RGBA8)
   var tile:=master.get_region(Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3])))
   var dims:=Vector2i(int(info.packedSize[0]),int(info.packedSize[1]));tile.resize(dims.x,dims.y,Image.INTERPOLATE_LANCZOS)
   expected.blit_rect(tile,Rect2i(Vector2i.ZERO,dims),Vector2i(int(info.packedPosition[0]),int(info.packedPosition[1])))
   var actual:=sheet.get_region(Rect2i(i*128,0,128,128))
   check(expected.get_data()==actual.get_data(),"crop exact native crop, resize and foot packing")
   var count:=0;var bottom:=-1
   for y in 128:
    for x in 128:
     if actual.get_pixel(x,y).a>0.125:
      count+=1;bottom=maxi(bottom,y)
      check(x>0 and x<127 and y>0 and y<127,"crop stays wholly inside its own cell")
   check(bottom==116,"all crop stage base anchors fixed")
   check(count>previous,"stage visibly grows");previous=count
   var digest:=hash_bytes(actual.get_data());check(not distinct.has(digest),"unique botanical stage");distinct[digest]=true
 var hoe:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/polish-hoe-input-20261010.json"))
 check(hash_bytes(FileAccess.get_file_as_bytes(str(hoe.row.master)))==str(hoe.row.sha256),"hoe source unchanged")
 var source:=Image.load_from_file(str(hoe.row.master))
 var actors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json"))
 var spec:Dictionary=actors.actors.player.clips.hoe
 check(not bool(actors.actors.player.ready) and bool(spec.ready),"one usable clip cannot complete player")
 var atlas:=Image.load_from_file(ProjectSettings.globalize_path(str(spec.path)))
 check(atlas.get_size()==Vector2i(1152,768),"24 larger cells provide tool clearance")
 for info in spec.sourceFrames:
  var box:Array=info.sourceRect;var dims:=Vector2i(int(info.packedSize[0]),int(info.packedSize[1]));var offset:=Vector2i(int(info.packedPosition[0]),int(info.packedPosition[1]))
  var expected:=Image.create(192,192,false,Image.FORMAT_RGBA8)
  var tile:=source.get_region(Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3])));tile.resize(dims.x,dims.y,Image.INTERPOLATE_LANCZOS)
  expected.blit_rect(tile,Rect2i(Vector2i.ZERO,dims),offset)
  var actual:=atlas.get_region(Rect2i(int(info.column)*192,int(info.row)*192,192,192))
  check(actual.get_data()==expected.get_data(),"whole original pose packed without repainting")
  var used:=actual.get_used_rect();check(used.position.x>0 and used.position.y>0 and used.end.x<192 and used.end.y<192,"whole tool and body remain inside cell")
  var original_row:int=hoe.row.feet.sourceDirections.find(["down","left","right","up"][int(info.row)])
  var shoe:Array=hoe.row.feet.shoeRegions[original_row][int(info.column)]
  var points:Array[Vector2i]=[];var bottom:=-1
  for y in 192:
   for x in 192:
    var original:=Vector2(float(x-offset.x)/float(info.ratio)+float(box[0]),float(y-offset.y)/float(info.ratio)+float(box[1]))
    if not Rect2(float(shoe[0]),float(shoe[1]),float(shoe[2]),float(shoe[3])).has_point(original):continue
    var c:=actual.get_pixel(x,y)
    if c.a>=0.5 and c.r>=c.g+8.0/255 and c.g>=c.b+8.0/255 and (c.r+c.g+c.b)/3<160.0/255:
     points.append(Vector2i(x,y));bottom=maxi(bottom,y)
  check(not points.is_empty(),"shoe regions contain actual visible boots")
  var left:=192;var right:=-1
  for point in points:left=mini(left,point.x);right=maxi(right,point.x)
  check(absf((left+right+1)/2.0-96)<=3.0 and absi(bottom+1-168)<=3,"actual boots share ground anchor independently of tool")
  var digest:=hash_bytes(actual.get_data());check(not distinct.has(digest),"24 distinct action poses");distinct[digest]=true
 var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/polish-before-20261010/data/world_art_manifest.json"))
 var house:Dictionary=m.entries["buildings/home-an"]
 check(house.worldRect==before.entries["buildings/home-an"].worldRect and house.door==before.entries["buildings/home-an"].door,"season changes preserve building bounds and entry")
 check(house.seasons.size()==4 and house.seasons[0]==house.path,"spring keeps original building base")
 for path in house.seasons:
  var image:=Image.load_from_file(ProjectSettings.globalize_path(str(path)));check(image!=null and image.get_size()==Vector2i(512,333),"season variants share full canvas")
  var digest:=hash_bytes(image.get_data());check(not distinct.has(digest),"distinct building seasons");distinct[digest]=true
 for key in ["props/teaRack","props/lamp","ui/panel","ui/button","effects/leaves","interior_surfaces/wood"]:
  var row:Dictionary=m.entries[key];var image:=Image.load_from_file(ProjectSettings.globalize_path(str(row.path)))
  check(image!=null and row.status=="partial" and bool(row.baseReady),"new real base resource is partial: "+key)
  if key!="interior_surfaces/wood":check(image.detect_alpha()!=Image.ALPHA_NONE,"genuine alpha: "+key)
 await root.get_node("AudioService").prepare_exit()
 print("POLISH_ASSETS: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
