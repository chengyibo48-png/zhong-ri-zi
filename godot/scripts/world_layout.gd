extends RefCounted
## Planned display placements, explicit wall corrections and reserved walking space.
## Doors, crop indexes, schedules and persisted actor positions retain their identities.
static var _plan:Dictionary={}
static func plan()->Dictionary:
 if _plan.is_empty():
  var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout.json"))
  if parsed is Dictionary:_plan=parsed
 return _plan
static func prop(source:Dictionary,index:int,group:String)->Dictionary:
 var data:Dictionary=source.duplicate(true)
 var placement:Dictionary=plan().get("props",{}).get(group+":"+str(index),{})
 if not placement.is_empty():
  data.x=placement.x;data.y=placement.y;data._layout_rect=placement.rect
 var scenery:Dictionary=plan().get("fixedSceneryPositions",{}).get(group+":"+str(index),{})
 if not scenery.is_empty():
  data.x=scenery.x;data.y=scenery.y
 var fixed:Dictionary=plan().get("fixedVisualRects",{}).get(group+":"+str(index),{})
 if not fixed.is_empty():data._visual_rect=fixed.rect
 return data
static func house_rect(key:String,fallback:Array)->Array:
 return plan().get("houseRects",{}).get(key.trim_prefix("buildings/"),fallback)
static func collision(bounds:Rect2)->Rect2:
 for row in plan().get("collisionOverrides",[]):
  var original:Array=row.source
  if bounds==Rect2(float(original[0]),float(original[1]),float(original[2]),float(original[3])):
   var replacement:Array=row.rect
   return Rect2(float(replacement[0]),float(replacement[1]),float(replacement[2]),float(replacement[3]))
 return bounds
static func ground_column(cell:Vector2i,original:int)->int:
 var result:=original
 var centre:=Vector2(cell)*32+Vector2(16,16)
 for zone in plan().get("groundZones",[]):
  var r:Array=zone.rect
  if Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])).has_point(centre):result=int(zone.atlasColumn)
 return result
static func ambience_world(source:Dictionary)->Dictionary:
 var copy:Dictionary=source.duplicate(true)
 var rows:Array=copy.get("village",{}).get("allProps",[])
 for i in rows.size():rows[i]=prop(rows[i],i,"village")
 var objects:Array=copy.get("tiles",{}).get("objects",[])
 for i in objects.size():objects[i]=prop(objects[i],i,"tiles")
 return copy
