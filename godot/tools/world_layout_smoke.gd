extends SceneTree
var passed:=0
var failed:=0
const LAYOUT=preload("res://scripts/world_layout.gd")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func rect(row:Array)->Rect2:return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
func _initialize()->void:
 var plan:Dictionary=LAYOUT.plan()
 var raw:=FileAccess.get_file_as_bytes("res://data/world.json")
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(raw)
 check(context.finish().hex_encode()==str(plan.source_world_sha256),"source map used by the planner is exactly the retained map")
 var world:Dictionary=JSON.parse_string(raw.get_string_from_utf8())
 var original:Dictionary=world.duplicate(true)
 var houses:Array=[]
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for house in world.village.houses:
  var key:="buildings/"+str(house.id)
  var rectangle:=rect(LAYOUT.house_rect(key,manifest.entries[key].worldRect))
  rectangle.position+=Vector2(float(house.x)+float(house.w)*.5,float(house.y)+float(house.h))
  houses.append(rectangle)
  check(rectangle.size.x>0 and rectangle.size.y>0,"positive original building envelope")
 for i in houses.size():
  for j in range(i+1,houses.size()):check(not houses[i].intersects(houses[j]),"all 47 building silhouettes are separate")
 var props:Array=[]
 for key in plan.props:
  var row:Dictionary=plan.props[key]
  var tokens:Array=key.split(":")
  var source:Array=world.village.allProps if tokens[0]=="village" else world.tiles.objects
  var data:Dictionary=source[int(tokens[1])]
  var planned:Dictionary=LAYOUT.prop(data,int(tokens[1]),str(tokens[0]))
  check(planned.x==row.x and planned.y==row.y,"runtime placement consumes audited position")
  check(data.x==row.source[0] and data.y==row.source[1],"stable source identity")
  check(planned.get("kind",planned.get("type"))==data.get("kind",data.get("type")),"every object retains identity")
  check(not world.tiles.assets.get(str(row.kind),{}).get("box"),"movable scenery has no authored collider")
  var box:=rect(row.rect);box.position+=Vector2(float(row.x),float(row.y))
  var bounds:=Rect2(Vector2(world.village.offsets[row.region].x,world.village.offsets[row.region].y)+Vector2(18,18),Vector2(1884,1116))
  check(bounds.encloses(box),"whole object stays in its region")
  var clear:=true
  for reservation in plan.reservations:
   if box.grow(3).intersects(rect(reservation.rect)):clear=false
  check(clear,"no overlap with a road, building, entrance, crop area or construction zone")
  clear=true
  for obstacle in world.village.solids+world.tiles.collisions:
   if box.grow(3).intersects(rect(obstacle)):clear=false
  check(clear,"planned scenery cannot cover any authored collision area")
  props.append(box)
 for i in props.size():
  for j in range(i+1,props.size()):check(not props[i].grow(3).intersects(props[j]),"all planned decorations have a gap")
 check(props.size()==352,"every planned decorative object is accounted for")
 for override in plan.collisionOverrides:
  check(LAYOUT.collision(rect(override.source))==rect(override.rect),"explicit corrected wall box applied")
  var before:=rect(override.source);var after:=rect(override.rect)
  var before_cells:Array=[];var after_cells:Array=[]
  for y in range(floori(before.position.y/32),floori((before.end.y-.01)/32)+1):
   for x in range(floori(before.position.x/32),floori((before.end.x-.01)/32)+1):before_cells.append(Vector2i(x,y))
  for y in range(floori(after.position.y/32),floori((after.end.y-.01)/32)+1):
   for x in range(floori(after.position.x/32),floori((after.end.x-.01)/32)+1):after_cells.append(Vector2i(x,y))
  check(before_cells==after_cells,"wall correction retains authored conservative navigation cells")
 check(not rect(plan.collisionOverrides[0].rect).intersects(rect(plan.collisionOverrides[1].rect)),"corrected grain-store and compost walls have a physical gap")
 check(LAYOUT.ground_column(Vector2i(86,55),7)==4,"crop rows draw grass instead of a crossing stone road")
 check(LAYOUT.ground_column(Vector2i(82,56),4)==6,"farm west lane draws an earth walking route")
 var stove_box:=rect(plan.fixtures.kitchen_stove)
 for i in 72:
  var position:=Vector2(2710+(i%6)*42,1731+floori(float(i)/6)*36) if i<24 else Vector2(2020+((i-24)%12)*43,3152+floori(float(i-24)/12)*39)
  check(not stove_box.intersects(Rect2(position-Vector2(16,29),Vector2(32,31))),"stove clears every crop and grown foliage envelope")
 for identity in plan.get("fixedSceneryPositions",{}):
  var parts:Array=identity.split(":");var rows:Array=world.village.allProps if parts[0]=="village" else world.tiles.objects
  var data:Dictionary=rows[int(parts[1])];var update:Dictionary=plan.fixedSceneryPositions[identity]
  var actual:Dictionary=LAYOUT.prop(data,int(parts[1]),str(parts[0]))
  check(data.kind in ["tree","blossom","orchard"] and not world.tiles.assets.get(str(data.kind),{}).get("box"),"relocation limited to non-collidable garden tree")
  check(actual.x==update.x and actual.y==update.y,"garden tree consumes planned position")
  check(data.x==update.source[0] and data.y==update.source[1],"authored garden identity retained")
  var bounds:Array=preload("res://scripts/world_art.gd").entries()["props/"+str(data.kind)].worldRect
  var envelope:=rect(bounds);envelope.position+=Vector2(float(actual.x),float(actual.y))
  for reservation in plan.reservations:check(not envelope.grow(3).intersects(rect(reservation.rect)),"garden tree clears reserved paths, buildings, entrances and activities")
  for obstacle in world.village.solids+world.tiles.collisions:check(not envelope.grow(3).intersects(rect(obstacle)),"garden tree clears unchanged physical geometry")
  for decoration in props:check(not envelope.grow(3).intersects(decoration),"garden tree clears planned decorative objects")
 var ambience:Dictionary=LAYOUT.ambience_world(world)
 check(ambience.village.allProps.size()==world.village.allProps.size() and ambience.tiles.objects.size()==world.tiles.objects.size(),"no scenery removed or duplicated")
 check(world==original,"layout renderer never mutates logical source map or save state")
 print("WORLD_LAYOUT: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
