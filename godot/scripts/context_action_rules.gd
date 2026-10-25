extends RefCounted
static func describe(near:Dictionary,verb:String,house_id:String,room:String,riding:bool,walking:bool,choices:int,mode:String,menu:bool,locked:bool)->Dictionary:
 var rows:Array=[]
 var id:String=str(near.get("id",""))
 match str(near.get("kind","")):
  "plot":
   rows.append({"label":"查看这块田","action":"f-inspect","id":str(int(near.get("index",0))),"op":""})
   rows.append({"label":"四时农事","action":"farmcare","id":"","op":""})
  "animal":
   rows.append({"label":"看看这位伙伴","action":"r-open","id":id,"op":""})
   rows.append({"label":"喂一份","action":"r-task","id":id,"op":"feed"})
   rows.append({"label":"摸摸它","action":"r-task","id":id,"op":"pet"})
  "fish":rows.append({"label":"鱼饵与垂钓手记","action":"fishing","id":"","op":""})
  "gather":rows.append({"label":"采法与山野手记","action":"forage","id":"","op":""})
  "npc":
   rows.append({"label":"继续聊聊","action":"v-npc-talk","id":id,"op":""})
   rows.append({"label":"送份心意","action":"v-npc-gift","id":id,"op":""})
   rows.append({"label":"去他家看看","action":"v-walk-house","id":house_id,"op":""})
  _:
   if room=="":rows.append({"label":"下车慢慢走" if riding else "骑自行车","action":"v-bike","id":"","op":""})
 if walking:rows.append({"label":"停止带路","action":"v-stop","id":"","op":""})
 if not near.is_empty():rows.push_front({"label":verb,"action":"fb-interact","id":"","op":""})
 if choices>1:rows.append({"label":"换目标 · "+("L3" if mode=="pad" else "点按" if mode=="touch" else "[ / ]"),"action":"fb-cycle","id":"","op":""})
 return {"hidden":menu or locked,"buttons":rows}
static func progress(s:Node,origin:Dictionary,path:Array,pending:String,riding:bool,exiting:bool)->String:
 if path.is_empty():return ""
 var distance:=0.0
 var last:Dictionary=origin
 for point in path:
  distance+=s._atlas_hypot(float(point.x)-float(last.x),float(point.y)-float(last.y))
  last=point
 return ("先出门" if exiting else pending if pending!="" else "前往标记")+" · 约 "+str(maxi(1,ceili(distance/(355.0 if riding else 195.0))))+" 秒"
