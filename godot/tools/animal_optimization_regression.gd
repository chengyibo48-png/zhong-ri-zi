extends SceneTree
var ART: Script
var VISUAL: Script
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 ART=load("res://scripts/animal_art.gd")
 VISUAL=load("res://scripts/ranch_visual.gd")
 create_timer(90).timeout.connect(func():quit(1))
 var state:Node=root.get_node("GameState");state.set_process(false)
 var inventory:Dictionary=state.inventory.duplicate(true)
 var animals:Array=state.animals.duplicate(true)
 var catalog:Dictionary=state.system_catalog.ranch
 var hashes:Dictionary={}
 for species in ["hen","duck","cow","sheep","pig"]:
  var entry:Dictionary=preload("res://scripts/world_art.gd").entries().get("animals/"+species,{})
  check(bool(entry.get("baseReady",false)),"actual atlas imported "+species)
  if not bool(entry.get("baseReady",false)):continue
  check(str(entry.status)=="partial","base movement cannot mark all animal art complete "+species)
  var a:Dictionary={"id":"review-"+species,"type":species,"age":40,"breed":"local","trait":"calm","hunger":80,"clean":80,"illness":0,"rest":false,"position":{"direction":"down","walking":false}}
  var original:Dictionary=a.duplicate(true)
  var texture:Texture2D=preload("res://scripts/character_art.gd").texture(str(entry.path))
  check(texture!=null,"actual raster loads "+species)
  if texture==null:continue
  var image:Image=texture.get_image()
  check(image.get_size()==Vector2i(1536,512),"strict 4-direction six-frame atlas shape "+species)
  check(image.detect_alpha()!=Image.ALPHA_NONE,"genuine animal transparency "+species)
  var hash:HashingContext=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data());var digest:String=hash.finish().hex_encode()
  check(not hashes.has(digest),"species has its own bitmap "+species);hashes[digest]=true
  for direction in ["down","left","right","up"]:
   a.position.direction=direction;a.position.walking=false
   var v:Dictionary=VISUAL.appearance(a,catalog,0)
   var idle:Dictionary=ART.frame(a,v,999)
   check(not idle.is_empty() and int(idle.get("index",-1))==0,"quiet frame is stable "+species+direction)
   a.position.walking=true
   for index in range(6):
    v=VISUAL.appearance(a,catalog,0)
    var descriptor:Dictionary=ART.frame(a,v,(float(index)+0.1)/6.0)
    check(not descriptor.is_empty(),"real walk frame "+species+direction+str(index))
    if descriptor.is_empty():continue
    check(int(descriptor.index)==index,"existing clock selects correct frame "+species+direction+str(index))
    var region:Image=image.get_region(Rect2i(descriptor.source))
    var used:Rect2i=region.get_used_rect()
    check(used.has_area(),"frame is not blank "+species+direction+str(index))
    check(used.position.x>0 and used.position.y>0 and used.end.x<256 and used.end.y<128,"full silhouette stays in cell "+species+direction+str(index))
    var sole:int=-1
    for pixel_y in range(region.get_height()-1,-1,-1):
     for pixel_x in range(region.get_width()):
      if region.get_pixel(pixel_x,pixel_y).a>=0.5:sole=pixel_y+1;break
     if sole>=0:break
    var sole_offset:float=(float(sole)-float(entry.anchor[1]))*float(entry.worldHeight)/108.0
    check(sole>=0 and absf(sole_offset)<=1.5,"actual visible hoof touches ground "+species+direction+str(index))
    var rectangle:Rect2=descriptor.destination
    check((rectangle.position+Vector2(descriptor.anchor)).length()<0.001,"ground point remains authored origin "+species+direction+str(index))
  a=original.duplicate(true)
  for property in ["breed","age","illness","clean","rest","lost","trait"]:
   var altered:Dictionary=a.duplicate(true)
   altered[property]="productive" if property=="breed" else 1 if property=="age" else 50 if property=="illness" else 1 if property=="clean" else "friendly" if property=="trait" else true
   var v:Dictionary=VISUAL.appearance(altered,catalog,0)
   check(ART.frame(altered,v,0).is_empty(),"specialized legacy appearance retained "+species+property)
  for action in ["feed","pet","clean","collect"]:
   if action=="collect" and species!="sheep":continue
   var v:Dictionary=VISUAL.appearance(a,catalog,0,{"action":action,"until":2.0})
   check(ART.frame(a,v,0).is_empty(),"unfinished action keeps original visible feedback "+species+action)
  var invalid:Dictionary=VISUAL.appearance(a,catalog,0);invalid.direction="unknown"
  check(ART.frame(a,invalid,0).is_empty(),"unknown direction handled safely "+species)
  check(a==original,"raster selection cannot change animal data "+species)
 check(state.inventory==inventory,"art selection preserves inventory")
 check(state.animals==animals,"art selection preserves real animal save data")
 print("ANIMAL_ART: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
