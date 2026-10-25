extends RefCounted
## Pure display descriptors; trade packets remain owned by GameState.
static func descriptor(channel:String,jobs:Array,now:float)->Dictionary:
 if channel not in ["stall","coop"]:return {}
 var key:="fixtures/cooperative_desk" if channel=="coop" else "fixtures/market_stall"
 var row:Dictionary=preload("res://scripts/world_art.gd").entries().get(key,{})
 if not bool(row.get("baseReady",false)):return {}
 var texture:=preload("res://scripts/character_art.gd").texture(str(row.get("path","")))
 var rectangle:Array=row.get("worldRect",[])
 if texture==null or rectangle.size()!=4:return {}
 var goods:Array=[];var ready:=false
 for job in jobs:
  if str(job.get("channel",""))!=channel:continue
  ready=ready or int(job.get("ready",0))<=now
  if goods.size()<3:
   var icon:=preload("res://scripts/item_art.gd").texture_for(str(job.get("id","")),"items")
   goods.append({"id":str(job.get("id","")),"texture":icon,"quantity":int(job.get("qty",0))})
 return {"texture":texture,"rectangle":Rect2(float(rectangle[0]),float(rectangle[1]),float(rectangle[2]),float(rectangle[3])),"ready":ready,"goods":goods,"key":key}
static func draw(target:CanvasItem,at:Vector2,channel:String,jobs:Array,now:float)->bool:
 var display:=descriptor(channel,jobs,now)
 if display.is_empty():return false
 target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 preload("res://scripts/ground_style.gd").shadow(target,at+Vector2(0,1),56,5)
 var rectangle:Rect2=display.rectangle;rectangle.position+=at
 target.draw_texture_rect(display.texture,rectangle,false)
 for i in display.goods.size():
  var item:Dictionary=display.goods[i]
  var offset:=Vector2(-8+i*12,-38) if channel=="coop" else Vector2(-23+i*15,-27)
  if item.texture!=null:target.draw_texture_rect(item.texture,Rect2(at+offset,Vector2(12,12)),false)
 return true
