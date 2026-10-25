extends RefCounted
# Source building.js placement, reserved cells, accessibility and route checks.
const NAVIGATION=preload("res://scripts/npc_navigation.gd")
static func result(ok:bool,message:String)->Dictionary:return {"ok":ok,"message":message}
static func integer(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value)) and floorf(float(value))==float(value)
static func rect(state:Node,piece:Dictionary)->Dictionary:
 var zone:Dictionary=state.system_catalog.building.zones[piece.zone]
 var definition:Dictionary=state.system_catalog.building.defs[piece.type]
 var rotated:bool=int(piece.rotation)%2!=0
 var width:int=int(definition.h if rotated else definition.w)
 var height:int=int(definition.w if rotated else definition.h)
 var size:float=float(zone.size)
 return {"x":float(zone.x)+(int(piece.cell)%int(zone.cols))*size,"y":float(zone.y)+floorf(float(piece.cell)/float(zone.cols))*size,"w":width*size,"h":height*size,"cols":width,"rows":height}
static func overlaps(a:Dictionary,b:Dictionary,pad:float=0)->bool:
 return float(a.x)<float(b.x)+float(b.w)+pad and float(a.x)+float(a.w)>float(b.x)-pad and float(a.y)<float(b.y)+float(b.h)+pad and float(a.y)+float(a.h)>float(b.y)-pad
static func cells(state:Node,piece:Dictionary)->Array:
 var zone:Dictionary=state.system_catalog.building.zones[piece.zone]
 var bounds:Dictionary=rect(state,piece)
 var out:Array=[]
 for y in range(int(bounds.rows)):
  for x in range(int(bounds.cols)):out.append(int(piece.cell)+y*int(zone.cols)+x)
 return out
static func zone_open(state:Node,id:String)->bool:
 return id=="home" or id=="court" and bool(state.upgrades.get("yard",false)) or id=="orchard" and bool(state.building.land.orchard)
static func reserved(state:Node,zone_id:String,cell:int)->String:
 var zone:Dictionary=state.system_catalog.building.zones[zone_id]
 var col:int=cell%int(zone.cols)
 var row:int=int(float(cell)/float(zone.cols))
 var bounds:Dictionary={"x":float(zone.x)+col*float(zone.size),"y":float(zone.y)+row*float(zone.size),"w":float(zone.size),"h":float(zone.size)}
 if zone_id=="home":
  if col in [6,7] or row in [3,7] or col<3 and row<2 or col==1 and row==2 or col>=10 and col<=12 and row>=1 and row<=2 or col<3 and row>=4 and row<=5 or col==13 and row>=4 and row<=5:return "过道 / 床铺"
  var required:int=(0 if col<6 else 1) if row<3 else (2 if col<6 else 3)
  return "扩建后开放" if int(state.building.house)<required else ""
 if col==3 or row==int(zone.rows)-1:return "预留通路"
 for corridor in state.world_village.get("corridors",[]):
  if overlaps(bounds,corridor,8):return "乡间道路"
 var farm:Dictionary=state.world_village.get("maps",{}).get("farm",{})
 for path in farm.get("paths",[]):
  var shifted:Dictionary=path.duplicate();shifted.x=float(path.x)+1920;shifted.y=float(path.y)+1152
  if overlaps(bounds,shifted,8):return "乡间道路"
 for water in farm.get("water",[]):
  var shifted:Dictionary=water.duplicate();shifted.x=float(water.x)+1920;shifted.y=float(water.y)+1152
  if overlaps(bounds,shifted,12):return "房屋 / 水面"
 for house in state.world_village.get("houses",[]):
  if overlaps(bounds,{"x":float(house.x)-10,"y":float(house.y)-10,"w":float(house.w)+20,"h":float(house.h)+55}):return "房屋 / 水面"
 for old in state.legacy_systems.get("layouts",[]):
  var slot:int=int(old.slot)
  var x:float=float([536,644,752,1032,1140,1248][slot%6])
  var y:float=874+floorf(float(slot)/6.0)*52
  if overlaps(bounds,{"x":x+1920-25,"y":y+1152-25,"w":50,"h":50}):return "旧家具（可收回）"
 return ""
static func placement(state:Node,piece:Dictionary,layout:Array)->Dictionary:
 var defs:Dictionary=state.system_catalog.building.defs
 var zones:Dictionary=state.system_catalog.building.zones
 if not defs.has(piece.get("type")) or not zones.has(piece.get("zone")) or not integer(piece.get("cell")) or not integer(piece.get("rotation")) or float(piece.rotation)<0 or float(piece.rotation)>3:return result(false,"布局位置无效。")
 var zone:Dictionary=zones[piece.zone]
 var definition:Dictionary=defs[piece.type]
 if float(piece.cell)<0 or float(piece.cell)>=int(zone.cols)*int(zone.rows):return result(false,"布局位置无效。")
 if not zone_open(state,piece.zone):return result(false,"先完成这片院子的整备。")
 if definition.get("where")=="yard" and piece.zone=="home" or definition.get("where")=="home" and piece.zone!="home":return result(false,"这件家具适合"+("室内" if definition.where=="home" else "室外")+"。")
 var bounds:Dictionary=rect(state,piece)
 if int(piece.cell)%int(zone.cols)+int(bounds.cols)>int(zone.cols) or floorf(float(piece.cell)/float(zone.cols))+int(bounds.rows)>int(zone.rows):return result(false,"占地超出可布置边界。")
 for cell in cells(state,piece):
  var reason:String=reserved(state,piece.zone,int(cell))
  if reason!="":return result(false,"此处保留给"+reason+"。")
 for other in layout:
  if other.get("key")!=piece.get("key") and other.get("zone")==piece.zone and overlaps(bounds,rect(state,other)):return result(false,"这里与另一件摆设重叠。")
 return result(true,"位置合适，门口和通路保持畅通。")
static func accessible(state:Node,layout:Array,zone_id:String)->bool:
 var zone:Dictionary=state.system_catalog.building.zones[zone_id]
 var cols:int=int(zone.cols);var rows:int=int(zone.rows)
 var solid:Dictionary={}
 var pieces:Array=[]
 for piece in layout:
  if piece.zone==zone_id and bool(state.system_catalog.building.defs[piece.type].solid):
   var occupied:Array=cells(state,piece);pieces.append(occupied)
   for cell in occupied:solid[int(cell)]=true
 var entry:int=(rows-1)*cols+(6 if zone_id=="home" else 3)
 var seen:Dictionary={entry:true};var queue:Array=[entry];var cursor:int=0
 while cursor<queue.size():
  var a:int=int(queue[cursor]);cursor+=1
  for b in [a-1,a+1,a-cols,a+cols]:
   if b<0 or b>=cols*rows or absi(a-b)==1 and int(float(a)/cols)!=int(float(b)/cols) or solid.has(b) or seen.has(b):continue
   seen[b]=true;queue.append(b)
 for occupied in pieces:
  var reached:bool=false
  for a in occupied:
   for b in [int(a)-1,int(a)+1,int(a)-cols,int(a)+cols]:
    if seen.has(b) and b>=0 and b<cols*rows and (absi(int(a)-b)!=1 or int(float(a)/cols)==int(float(b)/cols)):reached=true
  if not reached:return false
 return true
static func home_id(state:Node)->String:
 for house in state.world_village.get("houses",[]):
  if house.get("name")=="爷爷的老屋":return str(house.id)
 return ""
static func action_point(state:Node,piece:Dictionary,navigation:RefCounted)->Dictionary:
 var bounds:Dictionary=rect(state,piece)
 var candidates:Array=[{"x":bounds.x+bounds.w/2,"y":bounds.y+bounds.h+15},{"x":bounds.x+bounds.w/2,"y":bounds.y-15},{"x":bounds.x-15,"y":bounds.y+bounds.h/2},{"x":bounds.x+bounds.w+15,"y":bounds.y+bounds.h/2}]
 var zone:Dictionary=state.system_catalog.building.zones[piece.zone]
 var room:String=home_id(state) if piece.zone=="home" else ""
 var origin:Dictionary={"x":480,"y":580} if piece.zone=="home" else {"x":float(zone.x)+3.5*48,"y":float(zone.y)+(float(zone.rows)-0.5)*48}
 for candidate in candidates:
  if not navigation.blocked(state,room,candidate.x,candidate.y) and not navigation.route(state,room,origin,candidate).is_empty():return candidate
 return {}
static func check_layout(state:Node,layout:Variant)->Dictionary:
 if not layout is Array or layout.size()>100:return result(false,"最多摆放 100 件。")
 var seen:Dictionary={}
 for piece in layout:
  if not piece is Dictionary or not integer(piece.get("key")) or float(piece.key)<1 or seen.has(piece.key):return result(false,"家具标识重复或无效。")
  seen[piece.key]=true
  var valid:Dictionary=placement(state,piece,layout)
  if not valid.ok:return valid
 for zone in state.system_catalog.building.zones:
  if not accessible(state,layout,str(zone)):return result(false,"有家具被围住了，请留出能走近的一侧。")
 var projected:Node=state.get_script().new()
 projected.world_village=state.world_village;projected.system_catalog=state.system_catalog
 projected.upgrades=state.upgrades;projected.collection=state.collection
 projected.building=state.building.duplicate(true);projected.building.layout=layout
 var checked:Dictionary=_check_routes(projected,layout)
 projected.free()
 return checked
static func _check_routes(state:Node,layout:Array)->Dictionary:
 var navigation:RefCounted=NAVIGATION.new();navigation.refresh(state)
 var points:Array=[]
 for piece in layout:
  var at:Dictionary=action_point(state,piece,navigation)
  if at.is_empty():return result(false,"有家具无法走近使用，请留出至少一侧的空位。")
  if piece.zone=="home":points.append(at)
 var home:String=home_id(state)
 var origin:Dictionary={"x":480,"y":580}
 points.append_array([{"x":480,"y":590},{"x":238,"y":315},{"x":480,"y":540}])
 if int(state.building.house)>=1:points.append({"x":650,"y":376})
 if int(state.building.house)>=2:points.append({"x":300,"y":376})
 if int(state.building.house)>=3:points.append({"x":650,"y":550})
 for point in points:
  if navigation.route(state,home,origin,{"x":point.x,"y":float(point.y)+5}).is_empty():return result(false,"门口或屋内服务被挡住了，请调整附近家具。")
 return result(true,"布局与通路检查通过。")

static func commit(state:Node,layout:Array,base_revision:int)->Dictionary:
 if base_revision!=int(state.building.revision):return result(false,"场地刚有变化，请重新打开布置图。")
 var checked:Dictionary=check_layout(state,layout)
 if not checked.ok:return checked
 var bank:Dictionary=state.furniture.duplicate(true)
 for piece in state.building.layout:bank[piece.type]=int(bank.get(piece.type,0))+1
 for piece in layout:
  if int(bank.get(piece.type,0))<=0:return result(false,"缺少"+str(state.content.furniture[piece.type].name)+"，先制作或收回一件。")
  bank[piece.type]=int(bank[piece.type])-1
 var inside:bool=state.current_interior==home_id(state)
 var actor:Dictionary=state.player_navigation_position()
 for piece in layout:
  if (piece.zone=="home")==inside and (state.current_interior=="" or inside) and bool(state.system_catalog.building.defs[piece.type].solid):
   var bounds:Dictionary=rect(state,piece)
   if actor.x>=float(bounds.x) and actor.x<float(bounds.x)+float(bounds.w) and actor.y>=float(bounds.y) and actor.y<float(bounds.y)+float(bounds.h):return result(false,"脚下需要留空。先走开一点，再应用这份布局。")
 state.furniture=bank;state.building.layout=layout.duplicate(true)
 state.building.nextId=maxi(1,int(state.building.nextId))
 for piece in layout:state.building.nextId=maxi(int(state.building.nextId),int(piece.key)+1)
 state.building.revision=int(state.building.revision)+1
 return result(true,"布局已安好。移动和回收不扣材料，家具功能、库存与生产进度均保留。")
