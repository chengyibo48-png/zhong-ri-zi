extends RefCounted
## Reviewed animal atlases share the existing movement clock and ground anchor.
static func frame(a: Dictionary, appearance: Dictionary, clock: float) -> Dictionary:
 var row:Dictionary=preload("res://scripts/world_art.gd").entries().get("animals/"+str(a.get("type","")),{})
 if not bool(row.get("baseReady",false)):return {}
 var directions:Array=row.get("directions",[])
 var direction:int=directions.find(str(appearance.get("direction","down")))
 if direction<0:return {}
 var count:int=int(row.get("frames",0))
 var dimensions:Array=row.get("frameSize",[])
 var anchor_values:Array=row.get("anchor",[])
 if count<=0 or dimensions.size()!=2 or anchor_values.size()!=2:return {}
 var texture:Texture2D=preload("res://scripts/character_art.gd").texture(str(row.get("path","")))
 if texture==null:return {}
 var cell:=Vector2(float(dimensions[0]),float(dimensions[1]))
 if texture.get_size()!=Vector2(cell.x*count,cell.y*directions.size()):return {}
 var index:int=posmod(floori(clock*float(row.get("fps",6))),count) if bool(appearance.get("walking",false)) else clampi(int(row.get("idleFrame",0)),0,count-1)
 var pose_atlas:Dictionary=row.get("poseAtlas",{})
 var pose_name:String="eat" if bool(appearance.get("eating",false)) else "sleep" if bool(appearance.get("sleepy",false)) and not bool(appearance.get("walking",false)) else ""
 var source_rect:=Rect2(Vector2(index*cell.x,direction*cell.y),cell)
 if pose_name!="" and not pose_atlas.is_empty():
  var pose_texture:Texture2D=preload("res://scripts/character_art.gd").texture(str(pose_atlas.get("path","")))
  if pose_texture!=null and pose_texture.get_size()==Vector2(1024,256):
   texture=pose_texture;source_rect=Rect2(Vector2(direction*256,int(pose_atlas.states[pose_name])*128),Vector2(256,128))
 var ratio:float=float(row.get("worldHeight",42))/108.0
 if bool(appearance.get("young",false)):ratio*=0.64
 if ratio<=0 or not is_finite(ratio):return {}
 var anchor:=Vector2(float(anchor_values[0]),float(anchor_values[1]))
 return {"texture":texture,"source":source_rect,"destination":Rect2(-anchor*ratio,cell*ratio),"index":index,"direction":direction,"anchor":anchor*ratio}

static func draw(target:CanvasItem,a:Dictionary,appearance:Dictionary,at:Vector2,clock:float)->bool:
 if preload("res://scripts/animal_layers.gd").draw(target,a,appearance,at,clock):return true
 var descriptor:Dictionary=frame(a,appearance,clock)
 if descriptor.is_empty():return false
 target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var rectangle:Rect2=descriptor.destination
 var resting:bool=bool(appearance.get("sleepy",false))
 var feeding:bool=bool(appearance.get("eating",false))
 var tilt:float=sin(clock*5)*0.045 if feeding else sin(clock*3)*0.025 if bool(appearance.get("happy",false)) else 0.0
 var scale_y:float=1.0 if resting or feeding else 0.99+sin(clock*2)*0.01
 target.draw_set_transform(at,tilt,Vector2(1.0,scale_y))
 var tint:=Color(0.83,0.79,0.71) if bool(appearance.get("dirty",false)) else Color(0.86,0.9,0.82) if bool(appearance.get("sick",false)) else Color.WHITE
 if str(a.get("breed","local"))=="hardy":tint=tint.darkened(0.08)
 elif str(a.get("breed","local"))=="productive":tint=tint.lightened(0.06)
 preload("res://scripts/ground_style.gd").shadow(target,Vector2(0,0.5),rectangle.size.x*0.32,rectangle.size.y*0.07)
 target.draw_texture_rect_region(descriptor.texture,rectangle,descriptor.source,tint)
 target.draw_set_transform(Vector2.ZERO)
 return true
