extends Node2D
## Handpainted components use the original action clock, never game-state writes.
const ART=preload("res://scripts/character_art.gd")
const RIG=preload("res://scripts/player_rig.gd")
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
var rig_frame:Dictionary={}
var locomotion_state:Dictionary={}
var contact_description:Dictionary={}
var fishing_tension:=0.0
var fishing_fish:="fish"
static var _rod_meshes:Dictionary={}
# Keep the original shaft and reel, excluding the float/hook painted into the
# source illustration. The live float and line are drawn once by FishSpot.
const ROD_TIPS={"down":Vector2(64,9),"left":Vector2(52,9),"right":Vector2(72,9),"up":Vector2(65,9)}
const ROD_BODY={
 "down":[Vector3(6,59,70),Vector3(30,57,69),Vector3(54,54,68),Vector3(72,51,68),Vector3(84,49,78),Vector3(104,47,76),Vector3(122,46,62)],
 "left":[Vector3(6,47,57),Vector3(30,54,66),Vector3(54,59,74),Vector3(72,62,78),Vector3(84,53,82),Vector3(104,55,84),Vector3(122,72,84)],
 "right":[Vector3(6,67,77),Vector3(30,63,74),Vector3(54,58,72),Vector3(72,54,70),Vector3(84,51,79),Vector3(104,48,76),Vector3(122,46,62)],
 "up":[Vector3(6,60,71),Vector3(30,63,74),Vector3(54,66,78),Vector3(72,68,81),Vector3(84,56,84),Vector3(104,58,85),Vector3(122,72,84)]}
var contact_effects:Node2D
func _ready()->void:
 contact_effects=preload("res://scripts/action_contact_effects.gd").new()
 contact_effects.use_parent_material=false
 add_child(contact_effects)
var palette_key:=""
var transition_from:Dictionary={}
var transition_started:=0.0
static var _resolved:Dictionary={}
static var _limb_meshes:Dictionary={}
const LIMB_CACHE_LIMIT:=256
var _draw_mesh_refs:Array[ArrayMesh]=[]
static func component(pack:String,key:String,direction:String)->Dictionary:
 var id:=pack+"/"+direction+"/"+key
 if _resolved.has(id):return _resolved[id]
 var art_direction:=direction
 if pack=="rain" and key=="torso" and direction in ["left","right"]:art_direction="right" if direction=="left" else "left"
 var spec:Dictionary=data().get("packs",{}).get(pack,{}).get("parts",{}).get(art_direction,{}).get(key,{})
 if spec.is_empty():return {}
 var texture:=ART.texture(str(spec.path))
 if texture==null:return {}
 var r:Array=spec.region
 var result:Dictionary={"texture":texture,"region":Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))}
 _resolved[id]=result
 return result
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
 if source!=profile:source=profile.duplicate(true)
 if clothes!=visual:clothes=visual.duplicate(true)
 if clip!=next_clip and direction==next_direction and not rig_frame.is_empty() and bool(locomotion_state.get("sampled",false)) and clip not in ["bike","ride"] and next_clip not in ["bike","ride"]:
  transition_from=rig_frame.pose.duplicate(true);transition_started=time
 elif direction!=next_direction:transition_from.clear()
 clip=next_clip;direction=next_direction;clock=time;progress=phase
 var animated:bool=load("res://scripts/life_presentation.gd").animate()
 var motion:=locomotion_state.duplicate(true)
 if not transition_from.is_empty():
  motion.blend_from=transition_from;motion.blend=smoothstep(0.0,.10,maxf(0.0,time-transition_started))
  if motion.blend>=1.0:transition_from.clear()
 rig_frame=RIG.solve(source,clothes,pack_for(clothes),direction,clip,clock,progress,motion,animated)
 for row:Dictionary in rig_frame.commands:
  if component(str(row.pack),str(row.key),direction).is_empty():painted_active=false;hide();return false
 preload("res://scripts/action_contact.gd").align(rig_frame,contact_description,direction,component)
 if clip in ["fish","fish_cast","fish_wait","fish_reel"]:_prepare_rod()
 if material==null:
  var shader_material:=ShaderMaterial.new();shader_material.shader=load("res://art/characters/player/wardrobe_palette.gdshader");material=shader_material
 var next_palette:=str([source.get("shirt",0),source.get("skin",0),source.get("hairColor",0)])
 if next_palette!=palette_key:
  palette_key=next_palette
  var palette:=material as ShaderMaterial
  palette.set_shader_parameter("shirt_color",Color(SHIRTS[clampi(int(source.get("shirt",0)),0,3)]))
  palette.set_shader_parameter("skin_color",Color(SKINS[clampi(int(source.get("skin",0)),0,2)]))
  palette.set_shader_parameter("hair_color",Color(HAIRS[clampi(int(source.get("hairColor",0)),0,3)]))
 if is_instance_valid(contact_effects):
  contact_effects.frame=rig_frame;contact_effects.show_behind_parent=direction=="up";contact_effects.queue_redraw()
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;show();queue_redraw();return true
static func pose_for(kind:String,time:float,phase:float,side:int)->Dictionary:
 return RIG.pose_for(kind,time,phase,side)

func piece(pack:String,key:String,at:Vector2,size:Vector2,pivot:Vector2=Vector2(.5,0),rotation_angle:float=0.0,kind:float=.8,alpha:float=1.0,shade:float=1.0)->void:
 var resolved:=component(pack,key,direction)
 if resolved.is_empty():painted_active=false;return
 draw_set_transform(at,rotation_angle,Vector2.ONE)
 draw_texture_rect_region(resolved.texture,Rect2(-size*pivot,size),resolved.region,Color(kind,shade,1,alpha))
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
 painted_active=true;last_parts.clear();_draw_mesh_refs.clear()
 if rig_frame.is_empty():painted_active=false;return
 last_pose=rig_frame.pose
 for row:Dictionary in rig_frame.commands:
  if direction=="up" and str(row.get("role",""))=="torso":_draw_item()
  var size:Vector2=row.size
  if bool(row.get("fit_aspect",false)):
   var region:Rect2=component(str(row.pack),str(row.key),direction).region
   size=region.size*minf(size.x/region.size.x,size.y/region.size.y)
  if str(row.get("key",""))=="rod" and clip in ["fish","fish_cast","fish_wait","fish_reel"]:
   _draw_rod(row,size)
  elif row.has("joints"):
   _draw_limb(row)
  else:piece(str(row.pack),str(row.key),row.at,size,row.pivot,float(row.angle),float(row.kind),1.0,float(row.get("shade",1.0)))
 if direction!="up":_draw_item()

func _draw_item()->void:
 if not rig_frame.tool.is_empty():return
 if clip=="fish_catch" and fishing_fish=="":return
 var item:=tool_for();var texture:=ICONS.texture_for("items/"+fishing_fish) if clip=="fish_catch" else (ICONS.texture_for(item) if item!="" else null)
 if texture==null:return
 var hand:Vector2=rig_frame.sockets.hand
 var size:=Vector2(9,9) if clip=="seed" else Vector2(14,14)
 if clip=="seed":hand=rig_frame.sockets.secondary_hand+Vector2(0,4)
 draw_set_transform(hand,float(last_pose.tool),Vector2.ONE)
 draw_texture_rect(texture,Rect2(-size*Vector2(.5,.75),size),false,Color(.8,1,1,1))
 draw_set_transform(Vector2.ZERO,0,Vector2.ONE);last_parts.append(item)

func _draw_limb(row:Dictionary)->void:
 var spec:=component(str(row.pack),str(row.key),direction)
 var cache_key:=str(row.pack)+"/"+direction+"/"+str(row.key)+"/"+str(row.get("shade",1.0))
 for joint:Vector2 in row.joints:cache_key+="/%.2f,%.2f"%[joint.x,joint.y]
 var mesh:ArrayMesh=_limb_meshes.get(cache_key)
 if mesh==null:
  var geometry:=RIG.limb_mesh(row,spec.region,spec.texture.get_size())
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=geometry.vertices;arrays[Mesh.ARRAY_TEX_UV]=geometry.uvs;arrays[Mesh.ARRAY_INDEX]=geometry.indices
  var colors:=PackedColorArray()
  for i in range(geometry.vertices.size()):colors.append(Color(float(row.kind),float(row.get("shade",1.0)),1,1))
  arrays[Mesh.ARRAY_COLOR]=colors
  mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  while _limb_meshes.size()>=LIMB_CACHE_LIMIT:_limb_meshes.erase(_limb_meshes.keys()[0])
  _limb_meshes[cache_key]=mesh
 _draw_mesh_refs.append(mesh)
 draw_mesh(mesh,spec.texture)
 last_parts.append(str(row.pack)+"/"+direction+"/"+str(row.key))

func _prepare_rod()->void:
 var lean:float=-clampf(fishing_tension,0,1)*.025 if clip=="fish_reel" else 0.0
 var hip:Vector2=rig_frame.sockets.hip
 for row:Dictionary in rig_frame.commands:
  if str(row.get("role","")) in ["near_leg","far_leg"]:continue
  row.at=hip+(Vector2(row.at)-hip).rotated(lean);row.angle+=lean
  if row.has("joints"):
   for index:int in row.joints.size():row.joints[index]=hip+(row.joints[index]-hip).rotated(lean)
 for key:String in ["hand","secondary_hand","shoulder_near","shoulder_far","head","chest"]:rig_frame.sockets[key]=hip+(Vector2(rig_frame.sockets[key])-hip).rotated(lean)
 for row:Dictionary in rig_frame.commands:
  if str(row.get("key",""))!="rod":continue
  var spec:Dictionary=component(str(row.pack),str(row.key),direction)
  var size:Vector2=spec.region.size*minf(float(row.size.x)/spec.region.size.x,float(row.size.y)/spec.region.size.y)
  var bend:float=_rod_bend()
  var tip_uv:Vector2=(Vector2(ROD_TIPS[direction])-spec.region.position)/spec.region.size
  var offset:Vector2=(tip_uv-Vector2(row.pivot))*size+Vector2(bend*pow(maxf(0,(float(row.pivot.y)-tip_uv.y)/float(row.pivot.y)),2),0)
  var contact:Dictionary=rig_frame.get("contact",{})
  contact.kind=clip;contact.phase=0.0;contact.impact=Vector2(row.at)+offset.rotated(float(row.angle));contact.emitter=rig_frame.sockets.hand
  if not contact.has("surface"):contact.surface=contact.impact
  rig_frame.contact=contact;rig_frame.rod_bend=bend
func _rod_bend()->float:
 return snappedf(clampf(fishing_tension,0,1),1.0/32.0)*3.5*(-1 if direction=="left" else 1)
func _draw_rod(row:Dictionary,size:Vector2)->void:
 var spec:Dictionary=component(str(row.pack),str(row.key),direction)
 var bend:float=_rod_bend();var key:String=direction+"/"+str(bend)+"/"+str(size)
 var mesh:ArrayMesh=_rod_meshes.get(key)
 if mesh==null:
  var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array();var colors:=PackedColorArray()
  var outline:Array=ROD_BODY[direction]
  for band:Vector3 in outline:
   var y:float=(band.x-spec.region.position.y)/spec.region.size.y;var shift:float=bend*pow(maxf(0,(float(row.pivot.y)-y)/float(row.pivot.y)),2)
   for x:float in [band.y,band.z]:
    var pixel:=Vector2(x,band.x);var uv:Vector2=(pixel-spec.region.position)/spec.region.size
    var at:Vector2=(uv-Vector2(row.pivot))*size+Vector2(shift,0)
    vertices.append(Vector3(at.x,at.y,0));uvs.append(pixel/Vector2(spec.texture.get_size()));colors.append(Color(float(row.kind),float(row.get("shade",1.0)),1,1))
  for index:int in outline.size()-1:
   var n:int=index*2;indices.append_array(PackedInt32Array([n,n+1,n+3,n,n+3,n+2]))
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_COLOR]=colors
  mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  if _rod_meshes.size()>=128:_rod_meshes.erase(_rod_meshes.keys()[0])
  _rod_meshes[key]=mesh
 _draw_mesh_refs.append(mesh);draw_set_transform(Vector2(row.at),float(row.angle),Vector2.ONE);draw_mesh(mesh,spec.texture);draw_set_transform(Vector2.ZERO)
 last_parts.append(str(row.pack)+"/"+direction+"/rod")
