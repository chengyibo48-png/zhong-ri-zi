extends RefCounted
## Bitmap replacement only: all plot, stock and interaction data stay in GameState.
static func soil(target: CanvasItem, data: Dictionary) -> bool:
 var connected := target.get_node_or_null("CultivatedSoil")
 if connected != null:
  connected.call("set_state",data)
  return true
 if not bool(data.get("tilled",false)): return true
 var dry := preload("res://scripts/character_art.gd").texture("res://art/world/terrain/soil.png")
 var wet := preload("res://scripts/character_art.gd").texture("res://art/world/terrain/wet_soil.png")
 if dry==null or wet==null:return false
 target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var amount := clampf(float(data.get("moisture",45))/100.0,0.0,1.0)
 var tint := Color("c7c0af") if int(data.get("fertility",65))<30 else Color.WHITE
 # Both moisture states share one foot and visible rectangle; no plot geometry moves.
 var rectangle := Rect2(-15,-1,30,12)
 target.draw_texture_rect(dry,rectangle,false,tint)
 target.draw_texture_rect(wet,rectangle,false,Color(tint.r,tint.g,tint.b,amount))
 return true
static func counter(target: CanvasItem) -> bool:
 var texture := preload("res://scripts/character_art.gd").texture("res://art/world/fixtures/general_counter.png")
 if texture==null:return false
 target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 preload("res://scripts/ground_style.gd").shadow(target,Vector2(2542,1734),46,5)
 target.draw_texture_rect(texture,Rect2(2512,1709,60,26),false)
 return true

static func crop_stage(progress: float) -> int:
 if progress>=1.0:return 3
 if progress>=0.7:return 2
 if progress>=0.25:return 1
 return 0
static func crop(target: CanvasItem, crop_id: String, progress: float, growth_scale: float, condition: Dictionary = {}, presentation: Dictionary = {}) -> bool:
 var entry:Dictionary=preload("res://scripts/world_art.gd").entries().get("crops/"+crop_id,{})
 if not bool(entry.get("baseReady",false)) or int(entry.get("frames",0))!=4:return false
 var variant:=crop_condition(condition)
 var display:Dictionary=entry.get("stateVariants",{}).get(variant,entry)
 var texture:=preload("res://scripts/character_art.gd").texture(str(display.get("path","")))
 if texture==null:return false
 var scale_factor:=0.25*growth_scale*float(presentation.get("scale",1.0))
 var angle:=0.0
 if bool(presentation.get("motion",false)):
  angle=sin(float(presentation.get("clock",0))*1.8+float(presentation.get("phase",0)))*clampf(float(presentation.get("wind",4))*.001,0,.022)
 var season:=clampi(int(presentation.get("season",0)),0,3)
 var tint:Color=[Color(.97,1,.96),Color(1,.985,.94),Color(1,.94,.86),Color(.88,.94,1)][season]
 var offset: Vector2 = presentation.get("offset",Vector2.ZERO)
 target.draw_set_transform(Vector2(0,7)+offset,angle,Vector2.ONE)
 var rectangle:=Rect2(Vector2(-64*scale_factor,-116*scale_factor),Vector2(128,128)*scale_factor)
 target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 target.draw_texture_rect_region(texture,rectangle,Rect2(crop_stage(progress)*128,0,128,128),tint)
 target.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
 return true

static func stove(target:CanvasItem)->bool:
 var texture:=preload("res://scripts/character_art.gd").texture("res://art/world/fixtures/kitchen_stove.png")
 if texture==null:return false
 target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 preload("res://scripts/ground_style.gd").shadow(target,Vector2(2793,1695),45,5)
 target.draw_texture_rect(texture,Rect2(2765,1655,56,40),false)
 return true

## Presentation only: low health is reversible stress in the original rules.
static func crop_condition(data:Dictionary)->String:
 if float(data.get("health",100))<22.0:return "wilt"
 var pests:=float(data.get("pests",0));var disease:=float(data.get("disease",0))
 if disease>=25.0 and disease>=pests:return "disease"
 if pests>=25.0:return "pest"
 return "healthy"
