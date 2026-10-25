extends SceneTree
const RIG=preload("res://scripts/painted_wardrobe.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;printerr("FAIL: ",label)
func run()->void:
 var manifest:=RIG.data();var parts:=0
 check(manifest.get("packs",{}).size()==10,"All ten handpainted part packs")
 for pack in manifest.get("packs",{}):
  var entry:Dictionary=manifest.packs[pack];var master:=Image.load_from_file(entry.sourceMaster)
  check(master!=null and FileAccess.get_sha256(entry.sourceMaster)==entry.sourceSha256,"Retained source hash "+str(pack))
  if master==null:continue
  for direction in ["down","left","right","up"]:
   check(entry.parts.has(direction),"Four explicit source directions "+str(pack))
   for key in entry.parts[direction]:
    var spec:Dictionary=entry.parts[direction][key];var image:=Image.load_from_file(ProjectSettings.globalize_path(spec.path))
    check(image!=null and image.get_size()==Vector2i(128,128),"Native part dimensions")
    if image==null:continue
    check(image.detect_alpha()!=Image.ALPHA_NONE and not image.get_used_rect().size==Vector2i.ZERO,"Real visible alpha component")
    var r:Array=spec.rect;var size:Array=spec.size;var offset:Array=spec.offset
    var tile:=master.get_region(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])))
    tile.resize(int(size[0]),int(size[1]),Image.INTERPOLATE_LANCZOS)
    var replay:=Image.create(128,128,false,Image.FORMAT_RGBA8);replay.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(int(offset[0]),int(offset[1])))
    check(replay.get_data()==image.get_data(),"Byte exact native atlas extraction "+str(pack)+direction+str(key))
    check(image.get_pixel(0,0).a==0 and image.get_pixel(127,127).a==0,"Transparent guard pixels")
    parts+=1
 check(parts==232,"232 independent handpainted components")
 var profile:Dictionary={"shirt":0,"skin":0,"hair":0,"hairColor":0,"hat":true,"bag":false,"outfit":"field"}
 var before:=profile.duplicate(true);var combinations:=0
 for shirt in range(4):
  for skin in range(3):
   for hair in range(4):
    for hair_color in range(4):
     for outfit in ["field","apron","traveler","festival"]:
      for hat in [false,true]:
       for bag in [false,true]:
        var option:Dictionary=profile.duplicate(true);option.merge({"shirt":shirt,"skin":skin,"hair":hair,"hairColor":hair_color,"outfit":outfit,"hat":hat,"bag":bag},true)
        var visual:Dictionary={"apron":outfit=="apron","vest":outfit=="traveler","festival":outfit=="festival"}
        check(RIG.pack_for(visual)==outfit,"Saved outfit selector")
        check(RIG.needs_layers(option,visual)==(option!=profile),"Customization selects handpainted rig")
        combinations+=1
 check(combinations==3072 and profile==before,"All existing appearance choices preserved read only")
 for weather in [{"rain":true,"cold":true},{"cold":true},{"festival":true},{"apron":true}]:
  check(RIG.pack_for(weather)==("rain" if weather.get("rain",false) else "cold" if weather.get("cold",false) else "festival" if weather.get("festival",false) else "apron"),"Weather clothing precedence")
 var clips:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json")).actors.player.clips
 check(RIG.CLIPS.size()==clips.size(),"Every player action supported by handpainted parts")
 for clip in RIG.CLIPS:
  check(clips.has(clip),"Existing action name")
  for side in [-1,0,1]:
   for phase in [0.0,.1,.25,.5,.75,1.0]:
    var pose:=RIG.pose_for(clip,phase*1.3,phase,side)
    check(pose.size()==9,"Complete deterministic joint pose")
    for key in pose:
     if key!="mounted":check(is_finite(float(pose[key])),"Finite handpainted joint transform")
 check(RIG.pose_for("chop",0,.5,-1).arm_near>0 and RIG.pose_for("chop",0,.5,1).arm_near<0,"Chop arms follow left and right")
 check(RIG.pose_for("dig",0,.5,-1).arm_near>0 and RIG.pose_for("dig",0,.5,1).arm_near<0,"Dig arms follow left and right")
 print("WARDROBE_ART_SMOKE: ",passed," passed, ",failed," failed; ",parts," components, ",combinations," appearance combinations")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)

