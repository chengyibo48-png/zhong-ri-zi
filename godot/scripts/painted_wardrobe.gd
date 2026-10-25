extends Node2D
## Handpainted components use the original action clock, never game-state writes.
const ART=preload("res://scripts/character_art.gd")
const ICONS=preload("res://scripts/item_art.gd")
const SHIRTS=["#427660","#506c93","#a76755","#a38b48"]
const SKINS=["#e3b991","#c69b74","#a87e5d"]
const HAIRS=["#394337","#674c3b","#80634a","#a6a79a"]
const CLIPS=["idle","walk","hoe","seed","water","harvest","chop","dig","bell","bike","brush","build","care","cut","door","dress","eat","feed","fish","fish_cast","fish_catch","fish_reel","fish_wait","gather","greet","pack","pet","read","rest","ride","sleep","steam","trade"]
static var _manifest:Dictionary={}
var source:Dictionary={}
var clothes:Dictionary={}
var direction:="down"
var clip:="idle"
var progress:=-1.0
var clock:=0.0
var painted_active:=false
var last_parts:Array[String]=[]
var last_pose:Dictionary={}
static func data()->Dictionary:
 if _manifest.is_empty() and FileAccess.file_exists("res://data/wardrobe_art_manifest.json"):
  var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/wardrobe_art_manifest.json"))
  if parsed is Dictionary:_manifest=parsed
 return _manifest
static func pack_for(visual:Dictionary)->String:
 if bool(visual.get("rain",false)):return "rain"
 if bool(visual.get("cold",false)):return "cold"
 if bool(visual.get("festival",false)):return "festival"
 if bool(visual.get("apron",false)):return "apron"
 if bool(visual.get("vest",false)):return "traveler"
 return "field"
static func needs_layers(profile:Dictionary,visual:Dictionary)->bool:
 if pack_for(visual)!="field":return true
 for key in ART.data().get("playerProfile",{}):
  if profile.get(key)!=ART.data().playerProfile[key]:return true
 return false
func present(profile:Dictionary,visual:Dictionary,next_clip:String,next_direction:String,time:float,phase:float)->bool:
 if not CLIPS.has(next_clip) or not data().get("packs",{}).has(pack_for(visual)):hide();return false
 source=profile.duplicate(true);clothes=visual.duplicate(true);clip=next_clip;direction=next_direction;clock=time;progress=phase
 if material==null:
  var shader_material:=ShaderMaterial.new();shader_material.shader=load("res://art/characters/player/wardrobe_palette.gdshader");material=shader_material
 var palette:=material as ShaderMaterial
 palette.set_shader_parameter("shirt_color",Color(SHIRTS[clampi(int(source.get("shirt",0)),0,3)]))
 palette.set_shader_parameter("skin_color",Color(SKINS[clampi(int(source.get("skin",0)),0,2)]))
 palette.set_shader_parameter("hair_color",Color(HAIRS[clampi(int(source.get("hairColor",0)),0,3)]))
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;show();queue_redraw();return true
static func pose_for(kind:String,time:float,phase:float,side:int)->Dictionary:
 var p:=clampf(phase,0,1) if phase>=0 else fposmod(time*.9,1.0)
 var pulse:=sin(PI*smoothstep(0.0,1.0,p));var beat:=sin(TAU*p)
 var result:Dictionary={"lean":0.0,"crouch":0.0,"arm_near":0.0,"arm_far":0.0,"leg_near":0.0,"leg_far":0.0,"head":0.0,"tool":0.0,"mounted":false}
 var sign_side:=-float(side) if side!=0 else 1.0
 match kind:
  "walk":
   var stride:=sin(time*8.0);result.leg_near=.32*stride;result.leg_far=-.32*stride;result.arm_near=-.23*stride;result.arm_far=.23*stride
  "chop","dig","hoe","cut","build":
   result.arm_near=sign_side*(.35+1.6*pulse);result.arm_far=sign_side*(.25+1.3*pulse);result.lean=sign_side*.18*pulse;result.crouch=2.0*pulse;result.tool=sign_side*beat*.85
  "seed","harvest","gather","pet","brush","feed","care":
   result.crouch=4.0*pulse;result.lean=sign_side*.22*pulse;result.arm_near=sign_side*.95*pulse;result.arm_far=sign_side*.35*pulse
  "water":result.arm_near=sign_side*.8*pulse;result.arm_far=sign_side*.7*pulse;result.tool=sign_side*.4*pulse
  "greet","bell":result.arm_near=sign_side*(1.8*pulse+.18*beat);result.head=.04*beat
  "fish","fish_wait":result.arm_near=sign_side*.7;result.arm_far=sign_side*.55;result.tool=.035*sin(time*3)
  "fish_cast":result.arm_near=sign_side*(.4+1.45*pulse);result.arm_far=sign_side*(.3+1.2*pulse);result.tool=sign_side*.55*beat
  "fish_reel","fish_catch":result.arm_near=sign_side*(.7+.35*pulse);result.arm_far=sign_side*(.5+.2*beat);result.lean=sign_side*.08*pulse
  "eat","read","pack","trade","steam","door":result.arm_near=sign_side*(.2+1.1*pulse);result.arm_far=-sign_side*.35*pulse;result.head=.05*pulse;result.tool=.12*beat
  "rest","sleep","dress":result.arm_near=sign_side*1.8*pulse;result.arm_far=-sign_side*1.5*pulse;result.head=.08*pulse
  "bike":
   var pedal:=time*TAU*1.5
   result.mounted=true;result.crouch=-8.0-.35*cos(pedal*2.0)
   result.leg_near=.60+sin(pedal)*.45;result.leg_far=.60+sin(pedal+PI)*.45
   result.lean=sign_side*.10;result.arm_near=sign_side*.8;result.arm_far=sign_side*.65
  "ride":
   var gait:=time*TAU*1.2
   result.mounted=true;result.crouch=-8.0-.65*sin(gait*2.0)
   result.leg_near=.28+.10*sin(gait);result.leg_far=-.28-.10*sin(gait+PI)
   result.arm_near=sign_side*.72;result.arm_far=sign_side*.60
 return result
func piece(pack:String,key:String,at:Vector2,size:Vector2,pivot:Vector2=Vector2(.5,0),rotation_angle:float=0.0,kind:float=.8,alpha:float=1.0)->void:
 var art_direction:=direction
 if pack=="rain" and key=="torso" and direction in ["left","right"]:art_direction="right" if direction=="left" else "left"
 var spec:Dictionary=data().get("packs",{}).get(pack,{}).get("parts",{}).get(art_direction,{}).get(key,{})
 if spec.is_empty():painted_active=false;return
 var texture:=ART.texture(str(spec.path))
 if texture==null:painted_active=false;return
 var r:Array=spec.region;var region:=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
 draw_set_transform(at,rotation_angle,Vector2(-1,1) if pack=="tools" and key=="axe" and side_direction() else Vector2.ONE)
 draw_texture_rect_region(texture,Rect2(-size*pivot,size),region,Color(kind,1,1,alpha))
 draw_set_transform(Vector2.ZERO,0,Vector2.ONE);last_parts.append(pack+"/"+direction+"/"+key)
func side_direction()->bool:return direction in ["left","right"]
func painted_tool()->Array:
 match clip:
  "hoe":return ["tools","hoe"]
  "dig":return ["tools","spade"]
  "chop":return ["tools","axe"]
  "water":return ["tools","water"]
  "cut":return ["tools","sickle"]
  "fish","fish_cast","fish_wait","fish_reel":return ["tools","rod"]
  "brush","care":return ["props","brush"]
  "build":return ["props","hammer"]
  "read":return ["props","book"]
  "trade","pack":return ["props","parcel"]
  "steam","eat":return ["props","ladle"]
  "bell":return ["props","bell"]
 return []
func tool_for()->String:
 match clip:
  "hoe":return "tools/hoe"
  "chop":return "tools/axe"
  "dig":return "tools/hoe"
  "water":return "tools/water"
  "cut":return "tools/sickle"
  "fish","fish_cast","fish_wait","fish_reel":return "tools/rod"
  "fish_catch":return "items/fish"
  "seed","feed":return "items/feed"
  "read":return "archives/teaBook"
  "steam","eat":return "items/rice"
  "build":return "tools/axe"
 return ""
func _draw()->void:
 painted_active=true;last_parts.clear()
 var pack:=pack_for(clothes);var side:=-1 if direction=="left" else 1 if direction=="right" else 0
 last_pose=pose_for(clip,clock,progress,side)
 var lift:=float(last_pose.crouch);var lean:=float(last_pose.lean);var mounted:=bool(last_pose.mounted)
 if mounted:piece("transport","pony" if clip=="ride" else "bike",Vector2(0,1),Vector2(35,31) if side!=0 else Vector2(20,31),Vector2(.5,1))
 var hip:=Vector2(0,-13+lift);var chest:=hip+Vector2(0,-14).rotated(lean)
 var far_x:=-2.5 if side==0 else -1.4;var near_x:=2.5 if side==0 else 1.4
 piece(pack,"leg_left",hip+Vector2(far_x,0),Vector2(6.5,13),Vector2(.5,0),float(last_pose.leg_far),.5)
 piece(pack,"leg_right",hip+Vector2(near_x,0),Vector2(6.5,13),Vector2(.5,0),float(last_pose.leg_near),.5)
 var shoulder_far:=chest+Vector2(-6 if side==0 else -1,3).rotated(lean)
 var shoulder_near:=chest+Vector2(6 if side==0 else 1,3).rotated(lean)
 piece(pack,"arm_left",shoulder_far,Vector2(5,17),Vector2(.5,0),float(last_pose.arm_far)+lean,.4)
 piece(pack,"torso",chest,Vector2(16 if side==0 else 12,21 if pack in ["apron","rain"] else 17 if pack in ["cold","festival"] else 15),Vector2(.5,0),lean,.3)
 var head:=chest+Vector2(0,1.2).rotated(lean)
 if pack=="rain" and direction!="up":piece("transport","hood",head+Vector2(0,1),Vector2(19,20),Vector2(.5,1),lean,.7)
 piece("heads","head",head,Vector2(15,16.5),Vector2(.5,1),lean+float(last_pose.head),.1)
 var hairstyle:String=["short","bob","bun","wave"][clampi(int(source.get("hair",0)),0,3)]
 var hair_size:Vector2={"short":Vector2(17,12),"bob":Vector2(18,18),"bun":Vector2(17,21),"wave":Vector2(18,17)}[hairstyle]
 var hair_bottom:=head+Vector2(0,-4 if hairstyle=="short" else 1)
 piece("heads",hairstyle,hair_bottom,hair_size,Vector2(.5,1),lean+float(last_pose.head),.2)
 if pack=="rain" and direction=="up":piece("transport","hood",head+Vector2(0,1),Vector2(19,20),Vector2(.5,1),lean,.7)
 if pack=="cold":piece("transport","beanie",head+Vector2(0,-10),Vector2(18,9),Vector2(.5,1),lean,.7)
 elif pack!="rain" and bool(source.get("hat",true)):piece("heads","hat",head+Vector2(0,-8),Vector2(23,11),Vector2(.5,1),lean,.8)
 if bool(source.get("bag",false)):piece(pack,"bag",chest+Vector2(-3 if side==0 else -2,1),Vector2(10,16),Vector2(.5,0),lean,.8)
 piece(pack,"arm_right",shoulder_near,Vector2(5,17),Vector2(.5,0),float(last_pose.arm_near)+lean,.4)
 var prop:=painted_tool()
 if not prop.is_empty():
  var hand:=shoulder_near+Vector2(0,15).rotated(float(last_pose.arm_near)+lean)
  var size:=Vector2(13,22) if prop[0]=="tools" else Vector2(10,12)
  piece(str(prop[0]),str(prop[1]),hand,size,Vector2(.5,.5),float(last_pose.tool),.8)
 var item:=tool_for() if prop.is_empty() else "";var texture:=ICONS.texture_for(item) if item!="" else null
 if texture!=null:
  var hand:=shoulder_near+Vector2(0,15).rotated(float(last_pose.arm_near)+lean)
  var size:=Vector2(14,14) if clip not in ["chop","dig","hoe","fish","fish_cast","fish_wait","fish_reel"] else Vector2(21,21)
  draw_set_transform(hand,float(last_pose.tool),Vector2.ONE);draw_texture_rect(texture,Rect2(-size*.5,size),false,Color(.8,1,1,1));draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
  last_parts.append(item)

