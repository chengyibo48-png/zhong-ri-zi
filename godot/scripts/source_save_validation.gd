extends RefCounted
# Validate before conversion can clamp or discard corrupt browser fields.
static func number(value:Variant, low:float, high:float)->bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
static func integer(value:Variant,low:float,high:float)->bool:
 return number(value,low,high) and floorf(float(value))==float(value)
static func error(source:Dictionary,items:Dictionary,crops:Dictionary,scenes:Dictionary,content:Dictionary={},systems:Dictionary={},world:Dictionary={})->String:
 var outer:Script=load("res://scripts/source_save_outer.gd")
 var preference_error:String=outer.preferences_error(source)
 if preference_error!="":return preference_error
 if not number(source.get("version"),1,3) or not integer(source.get("version"),1,3):return "存档版本不兼容。"
 var extra:Script=load("res://scripts/source_save_extra.gd")
 source=extra.migrate(source)
 var plots:Variant=source.get("plots")
 var bag:Variant=source.get("bag")
 if not integer(source.get("day"),0,100000) or not number(source.get("money"),0,1000000000) or not number(source.get("stamina"),0,100) or not number(source.get("minutes"),360,1320) or not source.get("scene") is String or not scenes.has(source.scene) or not plots is Array or plots.size() not in [24,72] or not bag is Dictionary:
  return "存档的日期、背包或农地数据不完整。"
 for id in bag:
  if not items.has(id) or not integer(bag[id],0,999999):return "背包物品数据无效。"
 for plot in plots:
  if not plot is Dictionary:return "农地数据无效。"
  var crop:Variant=plot.get("crop")
  if not plot.has("crop") or crop!=null and (not crop is String or not crops.has(crop)) or not number(plot.get("growth"),0,12) or not number(plot.get("soil"),0,2):return "农地数据无效。"
 if source.has("worldRevision") and (not integer(source.worldRevision,2,4)):return "地图版本不兼容。"
 var result:String=life_error(source,items,content) if source.version==3 and not content.is_empty() else ""
 if result!="":return result
 result=extra.village_error(source,world)
 if result!="":return result
 result=farm_error(source,crops,systems)
 if result!="":return result
 result=extra.ranch_error(source,items,systems,world)
 if result!="":return result
 result=kitchen_error(source,items,content,systems)
 if result!="":return result
 result=building_error(source,items,systems,world)
 if result!="":return result
 result=tool_error(source,systems)
 if result!="":return result
 result=economy_error(source,items,systems)
 if result!="":return result
 var atlas:Variant=source.get("atlas")
 if truthy(atlas) and not preload("res://scripts/atlas_rules.gd").valid(atlas,world.get("offsets",{})):return "地图手记存档无效，请使用备份。"
 result=extra.environment_error(source,systems)
 if result!="":return result
 result=extra.forage_error(source,systems)
 if result!="":return result
 result=fishing_error(source,systems)
 if result!="":return result
 result=extra.neighbor_error(source,content,systems)
 if result!="":return result
 result=outer.feedback_error(source,items)
 if result!="":return result
 return outer.museum_error(source,systems)

const LIFE_ERROR="新增生活系统的存档字段无效，请使用备份。"
const TEXT=preload("res://scripts/js_string.gd")
static func truthy(value:Variant)->bool:return preload("res://scripts/atlas_rules.gd").truthy(value)
static func fallback(value:Variant)->Variant:return value if truthy(value) else {}
static func entries(value:Variant)->Dictionary:
 if value is Dictionary:return value
 var result:Dictionary={}
 if value is Array:
  for i in range(value.size()):result[str(i)]=value[i]
 elif value is String:
  for i in range(value.length()):result[str(i)]=value[i]
 return result
static func item_map_valid(value:Variant,items:Dictionary)->bool:
 if not value is Dictionary:return false
 for id in value:
  if not items.has(id) or not integer(value[id],0,999999):return false
 return true
static func known_id(rows:Array,id:Variant)->bool:
 for row in rows:
  if id is String and row.get("id")==id:return true
 return false
static func romance(content:Dictionary,id:Variant)->bool:
 if not id is String:return false
 for npc in content.get("npcs",[]):
  if npc.get("id")==id:return npc.get("tier")=="romance"
 return false
static func pattern(text:Variant,regex:String)->bool:
 return text is String and RegEx.create_from_string(regex).search(text)!=null
static func life_error(source:Dictionary,items:Dictionary,content:Dictionary)->String:
 var storage:Variant=fallback(source.get("storage"))
 if not item_map_valid(storage,items):return LIFE_ERROR
 for side in ["quality","storageQuality"]:
  var quality:Variant=fallback(source.get(side))
  if not quality is Dictionary:return LIFE_ERROR
  var bag:Dictionary=source.bag if side=="quality" else storage
  for id in quality:
   var grades:Variant=quality[id]
   if not items.has(id) or not grades is Array or grades.size() not in [2,3]:return LIFE_ERROR
   var total:=0.0
   for grade in grades:
    if not integer(grade,0,999999):return LIFE_ERROR
    total+=float(grade)
   if total>float(bag.get(id,0)):return LIFE_ERROR
 var recipes:Variant=source.get("knownRecipes")
 if not recipes is Array:return LIFE_ERROR
 for id in recipes:
  if not known_id(content.get("recipes",[]),id):return LIFE_ERROR
 var stories:Dictionary=entries(source.get("stories"))
 for npc in content.get("npcs",[]):
  var story:Variant=stories.get(npc.id)
  if not truthy(story):continue
  if not story is Dictionary or not integer(story.get("step"),0,content.get("arcs",{}).get(npc.id,[]).size()) or not story.get("choices") is Array or story.choices.size()!=int(story.step) or not integer(story.get("lastDay"),-1,source.day):return LIFE_ERROR
  for choice in story.choices:
   if not integer(choice,0,1):return LIFE_ERROR
 var partners:Variant=fallback(source.get("partners"))
 if not partners is Dictionary:return LIFE_ERROR
 for id in partners:
  if not romance(content,id) or partners[id] not in ["friend","dating"]:return LIFE_ERROR
 var marriage:Variant=source.get("marriage")
 if not marriage is Dictionary or not marriage.has("spouse") or not (marriage.spouse==null or romance(content,marriage.spouse)) or not integer(marriage.get("day"),-1,source.day) or not marriage.get("weekly") is Dictionary or not marriage.get("memories") is Array:return LIFE_ERROR
 if truthy(marriage.spouse):
  var spouse_story:Variant=stories.get(marriage.spouse,{})
  if partners.get(marriage.spouse)!="dating" or not spouse_story is Dictionary or float(spouse_story.get("step",0))<4:return LIFE_ERROR
 for key in ["projects","toolUpgrades"]:
  for id in entries(source.get(key)):
   if not content.get(key,{}).has(id) or not entries(source.get(key))[id] is bool:return LIFE_ERROR
 var layouts:Variant=source.get("layouts")
 if not layouts is Array or layouts.size()>24:return LIFE_ERROR
 var slots:Array=[]
 for layout in layouts:
  if not layout is Dictionary or not content.get("furniture",{}).has(layout.get("id")) or not integer(layout.get("slot"),0,23) or slots.has(layout.slot):return LIFE_ERROR
  slots.append(layout.slot)
 for id in entries(source.get("furniture")):
  if not content.get("furniture",{}).has(id) or not integer(entries(source.get("furniture"))[id],0,99999):return LIFE_ERROR
 var skills:Dictionary=entries(source.get("skills"))
 for id in content.get("skillChoices",{}):
  var skill:Variant=skills.get(id)
  if not skill is Dictionary or not integer(skill.get("xp"),0,99999) or not skill.has("choice"):return LIFE_ERROR
  if skill.choice!=null:
   var valid:=false
   for choice in content.skillChoices[id]:
    if skill.choice is String and skill.choice==choice[0]:valid=true
   if not valid:return LIFE_ERROR
 for key in ["chapters","yearPlans"]:
  for id in entries(source.get(key)):
   if not pattern(id,"^\\d+-[0-3]$" if key=="chapters" else "^\\d+$") or not integer(entries(source.get(key))[id],0,1 if key=="chapters" else 2):return LIFE_ERROR
 var letters:Variant=source.get("letters",[])
 if letters is Array:
  for letter in letters.slice(0,150):
   if not letter is Dictionary or not TEXT.is_string(letter.get("id")) or TEXT.length(letter.id)>80 or not integer(letter.get("day"),0,source.day):return LIFE_ERROR
   for key in ["title","from","text"]:
    if not TEXT.is_string(letter.get(key)) or TEXT.length(letter[key])>=2000:return LIFE_ERROR
   if truthy(letter.get("gift")) and not item_map_valid(letter.gift,items):return LIFE_ERROR
 for key in ["archives","achievements"]:
  var collected:Variant=source.get(key)
  if not collected is Array:return LIFE_ERROR
  for id in collected:
   if not known_id(content.get(key,[]),id):return LIFE_ERROR
 var appearance:Variant=source.get("appearance")
 if not appearance is Dictionary:return LIFE_ERROR
 for key in ["shirt","hair","skin"]:
  if not integer(appearance.get(key),0,2 if key=="skin" else 3):return LIFE_ERROR
 var pet:Variant=source.get("pet")
 if not pet is Dictionary or pet.get("type") not in ["cat","dog"] or not TEXT.is_string(pet.get("name")) or not number(pet.get("bond"),0,100) or not integer(pet.get("patted"),-1,source.day):return LIFE_ERROR
 for key in ["seasonEvents","animalCare","lastGifts","resourcePressure"]:
  var value:Variant=fallback(source.get(key))
  if not value is Dictionary or value.size()>20000:return LIFE_ERROR
 var processing:Variant=source.get("processing",[])
 if processing is Array:
  for job in processing:
   if not job is Dictionary or not items.has(job.get("id")) or not integer(job.get("qty"),1,400) or not integer(job.get("readyDay"),source.day,source.day+3) or job.get("station") not in ["晾晒架","腌菜坛","堆肥箱"] and job.id!="pickles":return LIFE_ERROR
   if job.has("farmGrade") and not integer(job.farmGrade,1,3):return LIFE_ERROR
 for plot in source.plots:
  var care:Variant=plot.get("care",0)
  if care==null:care=0
  if not integer(care,0,30):return LIFE_ERROR
 return ""

static func food(id:Variant,items:Dictionary)->bool:
 return id is String and items.has(id) and (items[id].get("kind") in ["食材","料理"] or id in ["flour","oil","driedMushroom","driedFish","dryTea","cream","yogurt","cheese","riceWine","berryJam"])
static func kitchen_error(source:Dictionary,items:Dictionary,content:Dictionary,systems:Dictionary)->String:
 var k:Variant=source.get("kitchen")
 if not truthy(k) or systems.is_empty():return ""
 var bad:="厨房存档字段无效，请使用备份。"
 if not k is Dictionary or not integer(k.get("version"),1,1) or not integer(k.get("nextId"),1,1000000000) or not k.get("cold") is bool or not k.get("equipment") is Dictionary or not k.get("mastery") is Dictionary or not k.get("lots") is Dictionary or not k.get("jobs") is Array or k.jobs.size()>40 or not k.get("experiments") is Array or k.experiments.size()>40:return bad
 var stations:Dictionary=systems.get("kitchen",{}).get("stations",{})
 for id in stations:
  var equipment:Variant=k.equipment.get(id)
  if not equipment is Dictionary or not integer(equipment.get("level"),0,2) or not number(equipment.get("clean"),0,100):return bad
 var keys:Array=[]
 for job in k.jobs:
  if not job is Dictionary or not integer(job.get("key"),1,float(k.nextId)-1) or keys.has(job.key) or not items.has(job.get("id")) or not stations.has(job.get("station")) or not integer(job.get("qty"),1,400) or not integer(job.get("grade"),0,3) or not number(job.get("start"),0,1000000000000) or not number(job.get("ready"),job.start,1000000000000) or not integer(job.get("weatherDelay"),0,999999) or not job.get("cooking") is bool or not job.get("recipe") is String:return bad
  var recipe_valid:=false
  for recipe in systems.get("kitchen",{}).get("processing",[]):
   if recipe.get("id")==job.get("recipe") and recipe.get("out")==job.id and recipe.get("stationId")==job.station:recipe_valid=true
  for recipe in content.get("recipes",[]):
   if recipe.get("id")!=job.get("recipe") or recipe.id!=job.id:continue
   var station_id:="stove"
   for id in stations:
    if stations[id].has("station") and stations[id].station==recipe.get("station"):station_id=id;break
   if station_id==job.station:recipe_valid=true
  if not recipe_valid:return bad
  keys.append(job.key)
 for side in ["bag","storage"]:
  var side_lots:Variant=k.lots.get(side)
  if not side_lots is Dictionary:return bad
  var inventory:Dictionary=source.bag if side=="bag" else fallback(source.get("storage"))
  for id in side_lots:
   var lots:Variant=side_lots[id]
   if not food(id,items) or not lots is Array or lots.size()>5000:return bad
   var total:=0.0
   for lot in lots:
    if not lot is Dictionary or not integer(lot.get("qty"),1,999999) or not number(lot.get("age"),0,3650):return bad
    total+=float(lot.qty)
   if total>float(inventory.get(id,0)):return bad
 for id in k.mastery:
  if not items.has(id) or not integer(k.mastery[id],0,9999):return bad
 for experiment in k.experiments:
  if not TEXT.is_string(experiment) or TEXT.length(experiment)>100:return bad
  var parts:PackedStringArray=str(experiment).split("+")
  if parts.size()!=2 or not food(parts[0],items) or not food(parts[1],items):return bad
 if truthy(k.get("buff")):
  var buff:Variant=k.buff
  if not buff is Dictionary or buff.get("kind") not in ["轻快","暖胃","饱足"] or not number(buff.get("until"),0,1000000000000):return bad
 return ""
static func economy_error(source:Dictionary,items:Dictionary,systems:Dictionary)->String:
 var e:Variant=source.get("economy")
 if not truthy(e) or systems.is_empty():return ""
 var bad:="物品经济存档无效，请使用备份。"
 if not e is Dictionary or not integer(e.get("version"),1,1) or not integer(e.get("rep"),0,99999) or not integer(e.get("nextId"),1,1000000000):return bad
 for key in ["locked","pinned"]:
  var list:Variant=e.get(key)
  if not list is Array or list.size()>(items.size() if key=="locked" else 6):return bad
  var found:Array=[]
  for id in list:
   if not items.has(id) or found.has(id):return bad
   found.append(id)
 var daily:Variant=e.get("daily")
 if not daily is Dictionary or not integer(daily.get("day"),0,source.day) or not daily.get("bought") is Dictionary:return bad
 for id in daily.bought:
  if not items.has(id) or not integer(daily.bought[id],0,5):return bad
 var claimed:Variant=e.get("claimed")
 if not claimed is Array or claimed.size()>90:return bad
 var found:Array=[]
 for id in claimed:
  if not pattern(id,"^\\d+-[0-2]$") or found.has(id) or float(str(id).split("-")[0])>floorf(float(source.day)/7):return bad
  found.append(id)
 var keys:Array=[]
 var stalls:=0
 for key in ["jobs","receipts"]:
  var list:Variant=e.get(key)
  if not list is Array or list.size()>(8 if key=="jobs" else 30):return bad
  for job in list:
   if not job is Dictionary or not items.has(job.get("id")) or not integer(job.get("key"),1,float(e.nextId)-1) or keys.has(job.key) or not integer(job.get("day"),0,source.day) or not integer(job.get("qty"),1,999999) or not integer(job.get("price"),0,1000000000) or not job.get("grades") is Array or job.grades.size()!=4 or not job.get("lots") is Array or job.lots.size()>5000:return bad
   var total:=0.0
   for grade in job.grades:
    if not integer(grade,0,job.qty):return bad
    total+=float(grade)
   if total!=float(job.qty):return bad
   total=0.0
   for lot in job.lots:
    if not lot is Dictionary or not integer(lot.get("qty"),1,job.qty) or not number(lot.get("age"),0,3650):return bad
    total+=float(lot.qty)
   if total!=(float(job.qty) if food(job.id,items) else 0.0):return bad
   keys.append(job.key)
   if key=="jobs":
    if job.get("channel") not in ["coop","stall"] or not systems.get("economy",{}).get("themes",{}).has(job.get("theme")) or not number(job.get("ready"),float(job.day)*1440,(float(job.day)+2)*1440):return bad
    if job.channel=="stall":stalls+=1
 if stalls>1:return bad
 var ledger:Variant=e.get("ledger")
 if not ledger is Array or ledger.size()>80:return bad
 for row in ledger:
  if not row is Dictionary or not items.has(row.get("id")) or not integer(row.get("day"),0,source.day) or not integer(row.get("qty"),1,999999) or not integer(row.get("money"),-1000000000,1000000000) or row.get("kind") not in ["现售","回购","买入","交代销","摆摊","撤回","结算","订单"]:return bad
 return ""

static func tool_error(source:Dictionary,systems:Dictionary)->String:
 if systems.is_empty():return ""
 var farm:Dictionary=source.get("farm") if source.get("farm") is Dictionary else {}
 var facilities:Array=farm.get("facilities",[]) if farm.get("facilities",[]) is Array else []
 var k:Variant=source.get("toolkit")
 if not truthy(k):
  for facility in facilities:
   if facility is Dictionary and facility.has("level") and not integer(facility.level,0,1):return "设施改良存档无效，请使用备份。"
  return ""
 var bad:="工具与设施存档无效，请使用备份。"
 var defs:Dictionary=systems.get("tools",{}).get("defs",{})
 if not k is Dictionary or not integer(k.get("version"),1,1) or not truthy(k.get("tools")) or not k.get("stock") is Array or k.stock.size()>144 or not defs.has(k.get("selected")) or not k.get("overlay") is bool:return bad
 var tools:Dictionary=entries(k.tools)
 for id in defs:
  var tool:Variant=tools.get(id)
  if not tool is Dictionary or not integer(tool.get("level"),0,2) or not integer(tool.get("xp"),0,99999) or tool.get("branch") not in ["broad","care"] or tool.get("shape") not in ["single","row","cross"]:return bad
  if tool.shape!="single" and float(tool.level)<1 or tool.shape=="cross" and (float(tool.level)!=2 or tool.branch!="broad"):return bad
 var all:Array=k.stock.duplicate();all.append_array(facilities)
 for facility in all:
  if not facility is Dictionary or not systems.get("farming",{}).get("facilities",{}).has(facility.get("type")) or not number(facility.get("durability"),0,100) or not facility.get("enabled") is bool:return bad
  var level:Variant=facility.get("level",0)
  if level==null:level=0
  if not integer(level,0,1):return bad
 return ""
static func fishing_error(source:Dictionary,systems:Dictionary)->String:
 if not source.has("fishing") or systems.is_empty():return ""
 var bad:="垂钓手记数据无效。"
 var f:Variant=source.fishing
 var catalog:Dictionary=systems.get("fishing",{})
 var waters:Dictionary=catalog.get("waters",{})
 var species:Dictionary=catalog.get("species",{})
 if not f is Dictionary or not integer(f.get("version"),1,1) or f.get("mode") not in ["relaxed","standard"] or not catalog.get("baits",{}).has(f.get("bait")) or not f.get("release") is bool or not truthy(f.get("waters")) or not truthy(f.get("records")) or f.waters is Array or f.records is Array:return bad
 for id in entries(f.waters):
  var row:Variant=entries(f.waters)[id]
  if not waters.has(id) or not row is Dictionary or not integer(row.get("day"),0,source.day) or not integer(row.get("casts"),0,200):return bad
 for id in entries(f.records):
  var row:Variant=entries(f.records)[id]
  if not species.has(id) or not row is Dictionary or not integer(row.get("count"),0,1000000) or not number(row.get("best"),0,100) or not integer(row.get("grade"),0,3) or not row.get("waters") is Array or row.waters.size()>5:return bad
  for water in row.waters:
   if not waters.has(water):return bad
 var last:Variant=f.get("last")
 if truthy(last):
  if not last is Dictionary or not integer(last.get("day"),0,source.day) or not waters.has(last.get("water")) or not last.has("fish"):return bad
  if last.fish!=null:
   if not species.has(last.fish) or not number(last.get("length"),0,100) or not integer(last.get("grade"),0,3) or not last.get("released") is bool:return bad
  elif last.get("reason") not in ["张力过高或收线不足","错过咬钩窗口"]:return bad
 return ""

static func farm_error(source:Dictionary,crops:Dictionary,systems:Dictionary)->String:
 var f:Variant=source.get("farm")
 if not truthy(f) or systems.is_empty():return ""
 var bad:="种植系统存档无效，请使用备份。"
 var catalog:Dictionary=systems.get("farming",{})
 if not f is Dictionary or not integer(f.get("version"),1,1) or not f.get("beds") is Array or f.beds.size()!=source.plots.size() or not f.get("facilities") is Array or f.facilities.size()>144 or not number(f.get("water"),0,120) or not number(f.get("threshold"),20,65) or not catalog.get("kinds",{}).has(f.get("seedKind")) or f.get("density") not in ["sparse","balanced","dense"]:return bad
 for bed in f.beds:
  if not bed is Dictionary or not catalog.get("soils",{}).has(bed.get("type")) or not catalog.get("kinds",{}).has(bed.get("kind")) or bed.get("density") not in ["sparse","balanced","dense"]:return bad
  for key in ["fertility","moisture","health","pests","disease","weeds","compacted","condition","penalty"]:
   if not number(bed.get(key),0,100):return bad
  for key in ["ripeDays","ticks"]:
   if not number(bed.get(key),0,100000):return bad
  if not number(bed.get("stress"),0,999) or not number(bed.get("slow"),0,5) or not number(bed.get("fertilized"),-1,source.day) or not number(bed.get("treated"),-1,source.day) or not bed.get("removed") is bool or not bed.get("fallow") is bool:return bad
  var companion:Variant=bed.get("companion")
  if truthy(companion):
   if not companion is Dictionary or not crops.has(companion.get("crop")) or not catalog.get("kinds",{}).has(companion.get("kind")) or not number(companion.get("growth"),0,float(crops[companion.crop].get("days",0))):return bad
 var seen:Array=[]
 var counts:Dictionary={}
 for facility in f.facilities:
  if not facility is Dictionary or not catalog.get("facilities",{}).has(facility.get("type")) or not integer(facility.get("anchor"),0,source.plots.size()-1) or not number(facility.get("durability"),0,100) or not facility.get("enabled") is bool:return bad
  var key:=str(facility.anchor)+"/"+str(facility.type)
  if seen.has(key):return bad
  seen.append(key);counts[str(facility.anchor)]=int(counts.get(str(facility.anchor),0))+1
  if int(counts[str(facility.anchor)])>2:return bad
 if not f.get("collection") is Dictionary:return bad
 for id in f.collection:
  if not crops.has(id) or not integer(f.collection[id],1,4):return bad
 return ""
static func building_error(source:Dictionary,items:Dictionary,systems:Dictionary,world:Dictionary={})->String:
 var b:Variant=source.get("building")
 if not truthy(b) or systems.is_empty():return ""
 var bad:="营造系统存档无效，请使用备份。"
 var catalog:Dictionary=systems.get("building",{})
 if not b is Dictionary or not integer(b.get("version"),1,1) or not integer(b.get("house"),0,3) or not b.get("land") is Dictionary or not b.land.get("orchard") is bool or not b.get("levels") is Dictionary or not b.get("modes") is Dictionary or not integer(b.get("revision"),0,1000000000) or not integer(b.get("nextId"),1,1000000000) or not b.get("jobs") is Array or b.jobs.size()>4 or not b.get("layout") is Array or not b.get("claimed") is Array or not catalog.get("styles",{}).has(b.get("style")) or b.get("roomUse") not in ["display","workshop","nursery","storage"] or not b.has("showcase"):return bad
 var discovered:Array=source.get("discovered",[]) if source.get("discovered") is Array else source.bag.keys()
 if b.showcase!=null and (not items.has(b.showcase) or not discovered.has(b.showcase)):return bad
 for id in catalog.get("modes",{}):
  if not integer(b.levels.get(id),0,2):return bad
  var valid:=false
  for mode in catalog.modes[id]:
   if b.modes.get(id) is String and b.modes[id]==mode[0]:valid=true
  if not valid:return bad
 var seen:Array=[]
 for job in b.jobs:
  if not job is Dictionary or not catalog.get("projects",{}).has(job.get("id")) or seen.has(job.id):return bad
  if not integer(job.get("level"),1,float(catalog.projects[job.id].get("max",0))) or not integer(job.get("readyDay"),source.day,float(source.day)+1):return bad
  var current:float=float(b.house) if job.id=="house" else (1.0 if b.land.orchard else 0.0) if job.id=="orchard" else float(b.levels.get(job.id,0))
  if float(job.level)!=current+1:return bad
  seen.append(job.id)
 seen=[]
 for id in b.claimed:
  if not catalog.get("milestones",{}).has(id) or seen.has(id):return bad
  seen.append(id)
 if b.layout.size()>100:return bad
 seen=[]
 var zones:Dictionary=catalog.get("zones",{})
 var defs:Dictionary=catalog.get("defs",{})
 for piece in b.layout:
  if not piece is Dictionary or not integer(piece.get("key"),1,float(b.nextId)-1) or seen.has(piece.key) or not defs.has(piece.get("type")) or not zones.has(piece.get("zone")) or not integer(piece.get("rotation"),0,3):return bad
  var zone:Dictionary=zones[piece.zone]
  if not integer(piece.get("cell"),0,int(zone.cols)*int(zone.rows)-1):return bad
  var width:int=int(defs[piece.type].get("w",1)) if int(piece.rotation)%2==0 else int(defs[piece.type].get("h",1))
  var height:int=int(defs[piece.type].get("h",1)) if int(piece.rotation)%2==0 else int(defs[piece.type].get("w",1))
  if int(piece.cell)%int(zone.cols)+width>int(zone.cols) or int(float(piece.cell)/float(zone.cols))+height>int(zone.rows):return bad
  if defs[piece.type].get("where")=="yard" and piece.zone=="home" or defs[piece.type].get("where")=="home" and piece.zone!="home":return bad
  var upgrades:Dictionary=source.get("upgrades",{}) if source.get("upgrades") is Dictionary else {}
  if piece.zone=="court" and not truthy(upgrades.get("yard")) or piece.zone=="orchard" and not b.land.orchard:return bad
  seen.append(piece.key)
 var context:Node=load("res://scripts/game_state.gd").new()
 context.system_catalog=systems;context.building=b
 context.upgrades={"yard":truthy(source.get("upgrades",{}).get("yard")) if source.get("upgrades") is Dictionary else false}
 context.legacy_systems={"layouts":source.get("layouts",[]) if source.get("layouts") is Array else []}
 context.collection=source.get("collection",{}) if source.get("collection") is Dictionary else {}
 if world.is_empty():
  var data:Variant=load("res://scripts/save_json.gd").decode(JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")))
  if data is Dictionary:context.world_village=data.get("world",data).get("village",{})
 else:context.world_village=world
 var checked:Dictionary=preload("res://scripts/building_geometry.gd").check_layout(context,b.layout)
 context.free()
 return "" if checked.ok else bad
