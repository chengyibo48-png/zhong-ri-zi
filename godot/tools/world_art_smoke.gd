extends SceneTree
const ART=preload("res://scripts/world_art.gd")
var passed:=0
var failed:=0
class PaintProbe extends Node2D:
 var season:=0
 var painted:=false
 func _draw()->void:
  painted=preload("res://scripts/world_art.gd").draw_prop(self,{"kind":"tree"},season)
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state:=root.get_node("GameState");state.set_process(false)
 var row:Dictionary=ART.entries().get("props/tree",{})
 check(bool(row.get("baseReady",false)),"seasonal tree PNGs imported")
 var paths:Array=row.get("seasons",[])
 check(paths.size()==4,"four seasons have explicit bindings")
 var hashes:Dictionary={}
 var shared_size:=Vector2i.ZERO
 for path in paths:
  var texture:=preload("res://scripts/character_art.gd").texture(str(path))
  check(texture!=null,"tree PNG loads: "+str(path))
  if texture==null:continue
  var image:=texture.get_image()
  if shared_size==Vector2i.ZERO:shared_size=image.get_size()
  check(image.get_size()==shared_size,"shared seasonal canvas preserves root anchor")
  check(image.detect_alpha()!=Image.ALPHA_NONE,"tree transparency")
  check(image.get_pixel(0,0).a<0.01 and image.get_pixel(image.get_width()-1,image.get_height()-1).a<0.01,"transparent tree corners")
  var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());var signature:=digest.finish().hex_encode()
  check(not hashes.has(signature),"season is independently painted, no duplicate PNG")
  hashes[signature]=true
 var rectangle:Array=row.get("worldRect",[])
 check(rectangle.size()==4,"world placement has explicit foot rectangle")
 if rectangle.size()==4:
  check(is_equal_approx(float(rectangle[1])+float(rectangle[3]),0.0),"root foot remains on authored world origin")
  check(float(rectangle[2])<=48 and float(rectangle[3])<=56,"tree silhouette retains original visual envelope")
 var world:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
 var tree_count:=0
 for prop in world.village.allProps:
  if str(prop.get("kind",""))!="tree":continue
  tree_count+=1
  check(ART.key_for(prop)=="props/tree","every authored tree resolves the seasonal artwork")
 check(tree_count==191,"all 191 existing trees covered")
 var probe:=PaintProbe.new();probe.position=Vector2(200,200);root.add_child(probe)
 for season in range(4):
  probe.season=season;probe.painted=false;probe.queue_redraw()
  await process_frame;await process_frame
  check(probe.painted,"actual CanvasItem draws season "+str(season))
 probe.queue_free();await process_frame
 print("World art: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
