extends RefCounted
# Independent source load wrappers. Never mutate the caller's save.
const BASE=preload("res://scripts/source_save_validation.gd")
const TEXT=preload("res://scripts/js_string.gd")
const ENV=preload("res://scripts/environment_rules.gd")
static func text(value:Variant,limit:int)->bool:return TEXT.is_string(value) and TEXT.length(value)<=limit
static func object(value:Variant)->bool:return value is Dictionary
static func id_in(table:Dictionary,value:Variant)->bool:return value is String and table.has(value)
static func move(point:Variant)->void:
 if not point is Dictionary or not BASE.number(point.get("x"),3840,1.7976931348623157e308):return
 if not BASE.number(point.get("y"),-1.7976931348623157e308,1.7976931348623157e308):return
 if float(point.y)<1152:point.x=float(point.x)-3840;point.y=float(point.y)+2304
 else:point.x=float(point.x)-1920;point.y=float(point.y)+1152
static func migrate(source:Dictionary)->Dictionary:
 if not BASE.integer(source.get("worldRevision"),3,3):return source
 var value:Dictionary=source.duplicate(true)
 var village:Dictionary=value.get("village",{}) if value.get("village") is Dictionary else {}
 if not BASE.truthy(village.get("interior")):move(value.get("player"))
 move(village.get("returnPoint"))
 for point in BASE.entries(village.get("npc")).values():move(point)
 var ranch:Dictionary=value.get("ranch",{}) if value.get("ranch") is Dictionary else {}
 for animal in value.get("animals",[]) if value.get("animals") is Array else []:
  if animal is Dictionary:move(animal.get("position"))
 for row in ranch.get("rehomed",[]) if ranch.get("rehomed") is Array else []:
  if row is Dictionary and row.get("animal") is Dictionary:move(row.animal.get("position"))
 if ranch.get("pet") is Dictionary:move(ranch.pet.get("position"))
 var atlas:Dictionary=value.get("atlas",{}) if value.get("atlas") is Dictionary else {}
 for point in atlas.get("pins",[]) if atlas.get("pins") is Array else []:move(point)
 move(atlas.get("tracking"));value.worldRevision=4
 return value
static func village_error(source:Dictionary,world:Dictionary)->String:
 if not BASE.number(source.get("worldRevision"),3,4) or not source.get("village") is Dictionary:return ""
 var interior:Variant=source.village.get("interior")
 if interior==null:return ""
 if not TEXT.is_string(interior):return "房屋存档数据无效。"
 for house in world.get("houses",[]):
  if TEXT.equal(house.id,interior):return ""
 return "房屋存档数据无效。"
static func animal_valid(a:Variant,ids:Array,day:float,defs:Dictionary,world:Dictionary)->bool:
 if not a is Dictionary:return false
 var species:Dictionary=defs.get("species",{})
 if not a.get("id") is String or not BASE.pattern(a.id,"^(hen|duck|cow|livestock-\\d+)$") or ids.has(a.id) or not id_in(species,a.get("type")) or not id_in(defs.get("breeds",{}),a.get("breed")) or not id_in(defs.get("traits",{}),a.get("trait")) or a.get("sex") not in ["female","male"] or not text(a.get("name"),12):return false
 if not TEXT.equal(a.get("species"),species[a.type].name) or not TEXT.equal(a.get("product"),species[a.type].product) or not BASE.integer(a.get("age"),0,100000) or not BASE.integer(a.get("generation"),0,100000):return false
 for key in ["bond","hunger","health","mood","clean","stress","illness","warning","feedQuality"]:
  if not BASE.number(a.get(key),0,100):return false
 if not BASE.number(a.get("progress"),0,10) or not a.get("qualityStock") is Array or a.qualityStock.size()!=4 or not BASE.integer(a.get("feathers"),0,20):return false
 var total:float=0
 for n in a.qualityStock:
  if not BASE.integer(n,0,28):return false
  total+=float(n)
 if total>28:return false
 for key in ["retired","rest","lost"]:
  if not a.get(key) is bool:return false
 if not a.get("care") is Dictionary or not a.get("parents") is Array or a.parents.size()>2:return false
 for key in ["feed","pet","clean","treat","breed"]:
  if not BASE.integer(a.care.get(key),-20,day):return false
 for parent in a.parents:
  if not text(parent,40):return false
 var pos:Variant=a.get("position")
 if not pos is Dictionary or not BASE.number(pos.get("x"),24,float(world.get("WIDTH",3840))-24) or not BASE.number(pos.get("y"),38,float(world.get("HEIGHT",3840))-24) or not pos.has("room") or pos.room!=null and not TEXT.equal(pos.room,defs.barns[species[a.type].home].house) or not pos.get("inside") is Dictionary:return false
 if not BASE.number(pos.inside.get("x"),113,847) or not BASE.number(pos.inside.get("y"),205,602):return false
 ids.append(a.id);return true
static func ranch_error(source:Dictionary,items:Dictionary,systems:Dictionary,world:Dictionary)->String:
 var r:Variant=source.get("ranch")
 if not BASE.truthy(r):return ""
 var bad:String="畜牧存档数据无效，请使用备份。"
 var defs:Dictionary=systems.get("ranch",{})
 if not r is Dictionary or not BASE.integer(r.get("version"),1,1) or not r.get("barns") is Dictionary or not BASE.integer(r.get("nextId"),1,1000000) or r.get("policy") not in ["safe","day","inside"] or not BASE.integer(r.get("zone"),0,1) or not id_in(defs.get("feedKinds",{}),r.get("feed")) or not r.get("grass") is Array or r.grass.size()!=2 or not r.get("stores") is Dictionary or not source.get("animals") is Array or source.animals.size()>32:return bad
 for n in r.grass:
  if not BASE.number(n,0,100):return bad
 for id in defs.get("barns",{}):
  var barn:Variant=r.barns.get(id)
  if not barn is Dictionary or not barn.get("built") is bool:return bad
  for key in ["space","comfort","protection","efficiency"]:
   if not BASE.integer(barn.get(key),0,3):return bad
  for key in ["durability","clean"]:
   if not BASE.number(barn.get(key),0,100):return bad
  if not BASE.integer(barn.get("waste"),0,99) or not BASE.integer(barn.get("lastClean"),-1,source.day):return bad
  for key in ["autoFeed","autoClean","autoCollect"]:
   if not barn.get(key) is bool:return bad
 for key in ["feed","hay","grainFeed","healthFeed","bedding"]:
  if not BASE.integer(r.stores.get(key),0,9999):return bad
 var ids:Array=[]
 for animal in source.animals:
  if not animal_valid(animal,ids,float(source.day),defs,world):return bad
 if not r.get("rehomed") is Array or r.rehomed.size()>32:return bad
 for row in r.rehomed:
  if not row is Dictionary or not BASE.integer(row.get("fee"),0,100000) or not BASE.integer(row.get("day"),0,source.day) or not animal_valid(row.get("animal"),ids,float(source.day),defs,world):return bad
 if not r.get("births") is Array or r.births.size()+source.animals.size()>32:return bad
 var births:Array=[];var mothers:Array=[]
 for row in r.births:
  if not row is Dictionary or not TEXT.is_string(row.get("id")) or births.has(row.id) or not id_in(defs.species,row.get("type")) or not id_in(defs.breeds,row.get("breed")) or not BASE.integer(row.get("total"),1,10) or not BASE.integer(row.get("remaining"),0,float(row.total)):return bad
  for key in ["mother","father"]:
   if not row.has(key):return bad
   if row[key]==null:continue
   var found:bool=false
   for animal in source.animals:
    if TEXT.equal(animal.id,row[key]) and TEXT.equal(animal.type,row.type) and animal.sex==("female" if key=="mother" else "male"):found=true;break
   if not found:return bad
  if BASE.truthy(row.mother):
   if mothers.has(row.mother):return bad
   mothers.append(row.mother)
  births.append(row.id)
 var pet:Variant=r.get("pet")
 if not pet is Dictionary or pet.get("mode") not in ["home","follow","patrol"] or not BASE.integer(pet.get("fed"),-1,source.day) or not BASE.integer(pet.get("trained"),-1,source.day) or not pet.get("position") is Dictionary:return bad
 for key in ["hunger","energy","training"]:
  if not BASE.number(pet.get(key),0,100):return bad
 if not BASE.number(pet.position.get("x"),24,float(world.get("WIDTH",3840))-24) or not BASE.number(pet.position.get("y"),38,float(world.get("HEIGHT",3840))-24):return bad
 if not r.get("notices") is Array or r.notices.size()>24 or not r.get("collection") is Dictionary:return bad
 for row in r.notices:
  if row==null:return "Cannot read properties of null (reading 'day')"
  if not row is Dictionary or not BASE.integer(row.get("day"),0,source.day) or not text(row.get("text"),300):return bad
 for id in r.collection:
  if not id_in(items,id) or not BASE.integer(r.collection[id],1,4):return bad
 var delivered:Variant=r.get("delivered")
 if BASE.truthy(delivered):
  if not delivered is Array:return "牧场心愿记录无效。"
  for id in delivered:
   if id not in ["ranchMilk","ranchWool","ranchYogurt"]:return "牧场心愿记录无效。"
 return ""
static func weather(day:int,systems:Dictionary)->String:return ENV.profile(day,720,systems.get("environment",{}).get("events",[])).kind
static func environment_error(source:Dictionary,systems:Dictionary)->String:
 var value:Variant=source.get("environment")
 if not BASE.truthy(value):return ""
 var bad:String="天气记录无效，请使用备份。"
 if not value is Dictionary or not BASE.integer(value.get("version"),1,1) or not value.get("history") is Array or value.history.size()>14:return bad
 var prior:float=-1
 for row in value.history:
  if not row is Dictionary or not BASE.integer(row.get("day"),0,source.day) or not TEXT.equal(row.get("kind"),weather(int(row.day),systems)) or float(row.day)<=prior:return bad
  prior=float(row.day)
 return ""
static var resource_items:Dictionary={}
static func resources()->Dictionary:
 if resource_items.is_empty():
  var rows:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_resources.json"))
  if rows is Array:
   for row in rows:resource_items[row.id]=row.item
 return resource_items
static func forage_error(source:Dictionary,systems:Dictionary)->String:
 if not source.has("forage"):return ""
 var f:Variant=source.forage;var points:Dictionary=resources();var bad:String="采集手记数据无效。"
 if not f is Dictionary or not BASE.integer(f.get("version"),1,1) or f.get("mode") not in ["gentle","full"] or not BASE.integer(f.get("xp"),0,1000000) or not f.get("discovered") is Array or f.discovered.size()>points.size() or not f.get("patches") is Dictionary or f.patches.size()>points.size():return bad
 for id in f.discovered:
  if not id_in(points,id):return bad
 for id in f.patches:
  var row:Variant=f.patches[id]
  if not id_in(points,id) or not row is Dictionary or not BASE.integer(row.get("lastDay"),0,source.day) or not BASE.integer(row.get("readyDay"),0,float(source.day)+8) or float(row.readyDay)<float(row.lastDay) or not BASE.integer(row.get("pressure"),0,8) or row.has("lastCare") and not BASE.integer(row.lastCare,0,source.day):return "资源再生记录无效。"
 var ledger:Variant=f.get("finds")
 if ledger==null:ledger=[]
 if not ledger is Array or ledger.size()>14:return "采集产地记录无效。"
 for row in ledger:
  if not row is Dictionary or not id_in(points,row.get("id")) or not TEXT.equal(row.get("item"),points[row.id]) or not BASE.integer(row.get("day"),0,source.day) or not BASE.integer(row.get("qty"),1,6) or not BASE.integer(row.get("grade"),0,1) or not TEXT.equal(row.get("weather"),weather(int(row.day),systems)):return "采集产地记录无效。"
 return ""
static func neighbor_record(row:Variant,ids:Array,day:float)->bool:
 return row is Dictionary and ids.has(row.get("id")) and text(row.get("key"),100) and BASE.integer(row.get("day"),0,day) and BASE.integer(row.get("minute"),0,1320) and text(row.get("text"),2200) and text(row.get("choice"),200) and row.get("category") in ["日常","线索","回忆","初识","故事","节庆","邻里小事","生活","村庄","关系","天气","时令"] and row.get("emotion") in ["calm","happy","focus","thought"]
static func neighbor_error(source:Dictionary,content:Dictionary,systems:Dictionary)->String:
 if not source.has("neighbors"):return ""
 var f:Variant=source.neighbors;var bad:String="邻里手记存档无效，请使用备份。"
 if not f is Dictionary or not BASE.integer(f.get("version"),1,1) or not BASE.integer(f.get("day"),0,source.day) or not f.get("people") is Dictionary or f.people.size()!=24 or not f.get("history") is Array or f.history.size()>int(systems.get("npc",{}).get("historyLimit",160)):return bad
 var ids:Array=[]
 for npc in content.get("npcs",[]):ids.append(npc.id)
 for id in ids:
  var person:Variant=f.people.get(id)
  if not person is Dictionary or not person.get("introduced") is bool or not person.get("recent") is Array or person.recent.size()>12:return bad
  for key in person.recent:
   if not text(key,100):return bad
  var last:Variant=person.get("last")
  if BASE.truthy(last) and (not neighbor_record(last,ids,float(source.day)) or last.id!=id):return bad
  var event:Variant=person.get("event")
  if not BASE.truthy(event):continue
  if not event is Dictionary or not BASE.integer(event.get("day"),0,source.day) or event.get("status") not in ["offered","accepted","postponed","done"] or not event.has("method") or event.method not in ["join","supply",null]:return bad
  if event.status=="done":
   if not BASE.integer(event.get("completed"),0,source.day) or float(event.completed)<float(event.day) or not BASE.truthy(event.method):return bad
  elif not event.has("completed") or event.completed!=null or event.method!=null:return bad
 for row in f.history:
  if not neighbor_record(row,ids,float(source.day)):return bad
 return ""

static func numeric(value:Variant)->float:
 if value is int or value is float:return float(value)
 if value==null:return 0
 if value is bool:return 1.0 if value else 0.0
 if value is Array:
  if value.size()==0:return 0
  if value.size()!=1:return NAN
  return numeric("" if value[0]==null else str(value[0]))
 if not TEXT.is_string(value):return NAN
 var clean:String=str(TEXT.trim(value))
 if clean=="":return 0
 if clean in ["Infinity","+Infinity"]:return INF
 if clean=="-Infinity":return -INF
 if clean.length()>2 and clean.left(2).to_lower() in ["0x","0b","0o"]:
  var radix:int=16 if clean[1].to_lower()=="x" else 2 if clean[1].to_lower()=="b" else 8
  var out:float=0
  for ch in clean.substr(2).to_lower():
   var digit:int="0123456789abcdef".find(ch)
   if digit<0 or digit>=radix:return NAN
   out=out*radix+digit
  return out
 return clean.to_float() if BASE.pattern(clean,"^[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?$") else NAN
static func number_or_zero(value:Variant)->float:
 var n:float=numeric(value)
 return 0.0 if is_nan(n) or n==0 else n
static func normalize_ranch(source:Dictionary,initial:Dictionary,systems:Dictionary,world:Dictionary)->Dictionary:
 var navigation:RefCounted=preload("res://scripts/npc_navigation.gd").new()
 var context:Node=load("res://scripts/game_state.gd").new()
 context.system_catalog=systems;context.world_village=world
 context.building=initial.get("building",{}).duplicate(true);context.upgrades={};context.legacy_systems={"layouts":[]};context.collection={}
 navigation.refresh(context)
 var r:Dictionary
 var animals:Array=[]
 if BASE.truthy(source.get("ranch")):
  r=source.ranch.duplicate(true);animals=source.animals.duplicate(true)
  var used:Array=animals.duplicate()
  for row in r.rehomed:used.append(row.animal)
  var next:float=float(r.nextId)
  for animal in used:
   animal.ready=0
   for count in animal.qualityStock:animal.ready+=int(count)
   animal.fed=float(animal.hunger)>=60
   var position:Dictionary=animal.position
   if position.room==null:position.merge(navigation.safe(context,"",position),true)
   var house:String=str(systems.ranch.barns[systems.ranch.species[animal.type].home].house)
   position.inside.merge(navigation.safe(context,house,position.inside),true)
   next=maxf(next,number_or_zero(str(animal.id).split("-")[-1])+1)
  for row in r.births:next=maxf(next,number_or_zero(str(row.id).split("-")[-1])+1)
  r.nextId=next
 else:
  r=initial.get("ranch",{}).duplicate(true)
  var coop:bool=BASE.truthy(BASE.entries(source.get("upgrades")).get("coop"))
  for barn in r.barns.values():
   barn.space=1 if coop else 0;barn.autoFeed=coop
   if coop:barn.autoFeedBuilt=true
   else:barn.erase("autoFeedBuilt")
  var previous:Array=source.get("animals",[]) if source.get("animals") is Array else []
  for template in initial.get("animals",[]):
   var animal:Dictionary=template.duplicate(true)
   var raw:Dictionary={}
   for candidate in previous:
    if candidate is Dictionary and TEXT.equal(candidate.get("id"),animal.id):raw=candidate;break
   var fed:bool=BASE.truthy(raw.get("fed"))
   animal.bond=clampf(number_or_zero(raw.get("bond")),0,100)
   animal.ready=clampf(floorf(number_or_zero(raw.get("ready"))),0,7)
   animal.qualityStock=[int(animal.ready),0,0,0]
   if TEXT.is_string(raw.get("name")):
    var name:Variant=TEXT.prefix(raw.name,12)
    if TEXT.length(name)>0:animal.name=name
   animal.fed=true;animal.hunger=95 if fed else 65;animal.care.feed=int(source.day) if fed else -1
   animals.append(animal)
 var delivered:Variant=r.get("delivered")
 if not BASE.truthy(delivered):delivered=[]
 r.delivered=[]
 for id in delivered:
  if not r.delivered.has(id):r.delivered.append(id)
 context.free()
 return {"ranch":r,"animals":animals}

static func village_history(value:Variant,day:float)->Dictionary:
 var result:Dictionary={}
 for key in BASE.entries(value):
  var date:Variant=BASE.entries(value)[key]
  if TEXT.is_string(key) and TEXT.length(key)<90 and BASE.integer(date,0,day):result[key]=date
 return result
