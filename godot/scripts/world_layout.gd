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
  if zone.has("sourceColumns") and original not in zone.sourceColumns:continue
  if bool(zone.get("ellipse",false)):
   var offset:=(centre-Vector2(float(r[0])+float(r[2])*.5,float(r[1])+float(r[3])*.5))/Vector2(float(r[2])*.5,float(r[3])*.5)
   if offset.length_squared()>1:continue
  if Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])).has_point(centre):result=int(zone.atlasColumn)
 return result
static func ambience_world(source:Dictionary)->Dictionary:
 var copy:Dictionary=source.duplicate(true)
 var rows:Array=copy.get("village",{}).get("allProps",[])
 for i in rows.size():rows[i]=prop(rows[i],i,"village")
 var objects:Array=copy.get("tiles",{}).get("objects",[])
 for i in objects.size():objects[i]=prop(objects[i],i,"tiles")
 return copy

static func navigation_village(source:Dictionary)->Dictionary:
 var copy:=source.duplicate(true)
 var rows:Array=copy.get("solids",[])
 for i in rows.size():
  var row:Array=rows[i];var fixed:=collision(Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3])))
  rows[i]=[fixed.position.x,fixed.position.y,fixed.size.x,fixed.size.y]
 var props:Array=copy.get("allProps",[])
 for i in props.size():props[i]=prop(props[i],i,"village")
 return copy
static func newly_blocked(at:Vector2)->bool:
 for row:Dictionary in plan().get("collisionOverrides",[]):
  if not bool(row.get("requiresSafeLanding",false)):continue
  var a:Array=row.source;var b:Array=row.rect
  # Same inflation as source navigation, keeping its strict-boundary behavior.
  var old:=Rect2(float(a[0])-6,float(a[1])-3,float(a[2])+12,float(a[3])+8)
  var current:=Rect2(float(b[0])-6,float(b[1])-3,float(b[2])+12,float(b[3])+8)
  var inside_new:=at.x>current.position.x and at.x<current.end.x and at.y>current.position.y and at.y<current.end.y
  var inside_old:=at.x>old.position.x and at.x<old.end.x and at.y>old.position.y and at.y<old.end.y
  if inside_new and not inside_old:return true
 return false
static func restore_safe_actor(state:Node,actor:Node2D)->void:
 if state.current_interior!="" or not newly_blocked(actor.global_position):return
 var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(state)
 var safe:Dictionary=nav.safe(state,"",{"x":actor.global_position.x,"y":actor.global_position.y})
 actor.global_position=Vector2(float(safe.x),float(safe.y));state.set_player_navigation_position(safe)
