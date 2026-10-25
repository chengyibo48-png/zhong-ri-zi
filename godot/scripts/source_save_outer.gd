extends RefCounted
const BASE=preload("res://scripts/source_save_validation.gd")
const TEXT=preload("res://scripts/js_string.gd")
static func text(value:Variant,limit:int)->bool:return TEXT.is_string(value) and TEXT.length(value)<=limit
# The outer preference wrappers execute before the lower gameplay loaders.
static func preferences_error(source:Dictionary)->String:
 if source.has("visualFx"):
  var p:Variant=source.visualFx
  if not p is Dictionary or p.get("density") not in ["standard","quiet","off"] or p.get("weather") not in ["standard","gentle"] or not p.get("ambient") is bool:return "特效设置无效，请使用有效存档。"
 if source.has("uiArt"):
  var p:Variant=source.uiArt
  if not p is Dictionary or p.get("theme") not in ["paper","porcelain","timber"] or not p.get("seasonal") is bool:return "界面外观设置无效，请使用有效存档。"
 if source.has("appearance"):
  var p:Variant=source.appearance
  if p==null:return "Cannot read properties of null (reading 'outfit')"
  if p is Dictionary:
   if p.get("outfit","field") not in ["field","apron","traveler","festival"] or not BASE.integer(p.get("hairColor",0),0,3) or not p.get("bag",false) is bool or not p.get("weatherDress",true) is bool:return "角色外观数据无效，请使用存档备份。"
 return ""
static func feedback_error(source:Dictionary,items:Dictionary)->String:
 if not source.has("feedback"):return ""
 var f:Variant=source.feedback;var bad:String="交互回顾存档无效，请读取备份。"
 if not f is Dictionary or not BASE.integer(f.get("version"),1,1) or not BASE.integer(f.get("next"),1,1000000000) or not f.get("rows") is Array or f.rows.size()>80 or not f.get("days") is Array or f.days.size()>7 or not f.get("seen") is Array or f.seen.size()>80 or not f.get("prefs") is Dictionary:return bad
 for value in f.seen:
  if not text(value,140):return bad
 var p:Dictionary=f.prefs
 if p.get("pace") not in ["normal","brisk"] or p.get("motion") not in ["full","reduced"] or p.get("floating") not in ["normal","compact","off"] or not BASE.number(p.get("seconds"),5,12) or float(p.seconds) not in [5.0,8.0,12.0] or not p.get("quiet") is bool:return bad
 var ids:Array=[]
 for r in f.rows:
  if not r is Dictionary or not BASE.integer(r.get("id"),0,float(f.next)-1) or ids.has(r.id) or not BASE.integer(r.get("day"),0,source.day) or not BASE.integer(r.get("minute"),0,1320) or not text(r.get("key"),140) or not text(r.get("title"),120) or not text(r.get("text"),1800) or r.get("type") not in ["收支","照料","社交","提醒","未完成"] or not BASE.integer(r.get("priority"),0,2) or r.get("link") not in ["feedback","bag","farmcare","ranch","processing","build","weather","neighbors","economy","fishing","tools"] or not r.get("read") is bool or not BASE.integer(r.get("count"),1,999999):return bad
  ids.append(r.id)
 var days:Array=[]
 for d in f.days:
  if not d is Dictionary or not BASE.integer(d.get("day"),0,source.day) or days.has(d.day) or not BASE.integer(d.get("actions"),0,1000000000) or not BASE.integer(d.get("income"),0,1000000000000) or not BASE.integer(d.get("spent"),0,1000000000000) or not BASE.truthy(d.get("items")) or d.items is Array:return bad
  for key in BASE.entries(d.items):
   var parts:PackedStringArray=str(key).split(":")
   if parts.size()<2 or not items.has(parts[0]) or parts[1] not in ["0","1","2","3"] or not BASE.integer(BASE.entries(d.items)[key],0,1000000000000):return bad
  days.append(d.day)
 return ""
static func unique(value:Variant,ids:Array)->bool:
 if not value is Array:return false
 var seen:Array=[]
 for id in value:
  if not ids.has(id) or seen.has(id):return false
  seen.append(id)
 return true
static func museum_error(source:Dictionary,systems:Dictionary)->String:
 if not source.has("collection"):return ""
 var m:Variant=source.collection;var defs:Dictionary=systems.get("museum",{});var bad:String="图鉴与村史馆存档无效，请使用备份。"
 var bundles:Array=defs.get("bundles",[]);var bundle_ids:Array=[]
 for b in bundles:bundle_ids.append(b.id)
 if not m is Dictionary or not BASE.integer(m.get("version"),1,1) or not m.get("entries") is Dictionary or not m.get("observations") is Dictionary or not m.get("donated") is Dictionary or not m.get("featured") is Dictionary or not BASE.integer(m.get("level"),0,3) or not unique(m.get("claimed"),bundle_ids) or not unique(m.get("badges"),["observer","researcher"]) or not m.has("tracked") or m.tracked!=null and not bundle_ids.has(m.tracked):return bad
 var known:Dictionary={}
 for e in defs.get("entries",[]):known[e.key]=true
 for key in m.entries:
  var r:Variant=m.entries[key]
  if not known.has(key) or not r is Dictionary or not BASE.integer(r.get("first"),-1,source.day) or not r.get("acquired") is bool or not r.get("researched") is bool or not BASE.integer(r.get("best"),0,3):return bad
 var wild:Array=[]
 for e in defs.get("wildlife",[]):wild.append(e.id)
 for id in m.observations:
  var days:Variant=m.observations[id]
  if not wild.has(id) or not days is Array or days.size()>2:return bad
  var seen:Array=[]
  for day in days:
   if not BASE.integer(day,0,source.day) or seen.has(day):return bad
   seen.append(day)
 var donations:Dictionary=defs.get("donationMap",{})
 var groups:Array=[]
 for key in m.donated:
  var d:Variant=m.donated[key]
  if not donations.has(key) or not m.entries.has(key) or not d is Dictionary or not donations[key].modes.has(d.get("mode")) or not BASE.integer(d.get("grade"),0,3) or not BASE.integer(d.get("day"),0,source.day):return bad
  if not groups.has(donations[key].group):groups.append(donations[key].group)
 for group in m.featured:
  var key:Variant=m.featured[group]
  if not key is String or not m.donated.has(key) or donations[key].group!=group:return bad
 for id in m.claimed:
  for b in bundles:
   if b.id!=id:continue
   for key in b.keys:
    if not m.donated.has(key):return bad
 var levels:Array=defs.get("levels",[])
 if levels.size()!=4:return bad
 var level:Dictionary=levels[int(m.level)]
 if m.donated.size()<int(level.need) or groups.size()<int(level.groups):return bad
 return ""
