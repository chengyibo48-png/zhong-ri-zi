extends RefCounted
class_name ActionArt

static func smooth(value: float) -> float:
 var t:=clampf(value,0.0,1.0)
 return t*t*(3.0-2.0*t)

static func ballistic(from: Vector2,to: Vector2,time: float,lift: float=0.0) -> Vector2:
 var t:=clampf(time,0.0,1.0)
 return from.lerp(to,t)-Vector2(0.0,4.0*lift*t*(1.0-t))

static func xy(point: Vector2) -> Dictionary:return {"x":point.x,"y":point.y}
static func vec(point: Dictionary) -> Vector2:return Vector2(float(point.x),float(point.y))

static func pose(player: Vector2,direction: Vector2,action: Dictionary) -> Dictionary:
 var t:=clampf(float(action.get("progress",0.0)),0.0,1.0)
 var difference:=Vector2(float(action.get("x",player.x)),float(action.get("y",player.y)))-player
 if difference.length()<3.0:difference=Vector2(direction.x*28.0,direction.y*22.0)
 var length:=difference.length()
 var unit:=difference/length
 var contact:=player+unit*minf(length,65.0)
 var reach:=smooth(t/0.3)*(1.0-smooth((t-0.78)/0.22))
 var low:bool=str(action.kind) in ["hoe","dig","cut","chop","seed","harvest","gather","brush"]
 var shoulder:=player+Vector2(unit.x*(5.0+reach*5.0),-18.0+(reach*3.0 if low else 0.0))
 var goal:=contact-Vector2(unit.x*10.0,20.0 if str(action.kind) in ["door","pet","greet"] else 12.0)
 var distance:=goal.distance_to(shoulder)
 var ratio:=1.0 if distance==0.0 else minf(1.0,27.0/distance)
 var hand:=shoulder+Vector2((goal.x-shoulder.x)*ratio*reach,8.0*(1.0-reach)+(goal.y-shoulder.y)*ratio*reach)
 return {"t":t,"ux":unit.x,"uy":unit.y,"contact":xy(contact),"shoulder":xy(shoulder),"hand":xy(hand),"reach":reach,"low":low,
 "elbow":xy(shoulder.lerp(hand,0.5)+Vector2(-unit.y*5.0,unit.x*5.0)),"basket":xy(player+Vector2(-18.0 if unit.x<0.0 else 18.0,3.0))}

static func rect(out: Array,x: float,y: float,w: float,h: float,color: String,origin: Vector2=Vector2.ZERO,angle: float=0.0) -> void:
 out.append({"op":"rect","x":floorf(x+0.5),"y":floorf(y+0.5),"w":w,"h":h,"color":color,"origin":xy(origin),"angle":angle})
static func line(out: Array,points: Array,color: String,width: float=2.0,origin: Vector2=Vector2.ZERO,angle: float=0.0) -> void:
 var data:Array=[]
 for p in points:data.append(xy(p))
 out.append({"op":"line","points":data,"color":color,"width":width,"origin":xy(origin),"angle":angle})
static func oval(out: Array,x: float,y: float,rx: float,ry: float,color: String) -> void:
 out.append({"op":"oval","x":x,"y":y,"rx":rx,"ry":ry,"color":color,"origin":xy(Vector2.ZERO),"angle":0.0})
static func item(out: Array,at: Vector2,id: String,known: bool,scale: float=0.55) -> void:
 if known:out.append({"op":"item","id":id,"x":at.x-8.0,"y":at.y-12.0,"scale":scale,"origin":xy(Vector2.ZERO),"angle":0.0})
 else:
  rect(out,at.x-4.0,at.y-6.0,9.0,7.0,"#9daa60")
  rect(out,at.x,at.y-9.0,2.0,5.0,"#ccca86")

static func frame(player: Vector2,direction: Vector2,action: Dictionary,skin: String="#e3b991",clock: float=0.0,item_known: bool=false,fishing: Dictionary={}) -> Array:
 if action.is_empty():return []
 var q:=pose(player,direction,action)
 var t:=float(q.t)
 var ux:=float(q.ux)
 var uy:=float(q.uy)
 var contact:=vec(q.contact)
 var hand:=vec(q.hand)
 var shoulder:=vec(q.shoulder)
 var elbow:=vec(q.elbow)
 var basket:=vec(q.basket)
 var kind:=str(action.kind)
 var out:Array=[]
 line(out,[player+Vector2(-ux*6.0,-17.0),player+Vector2(-ux*10.0,-7.0)],skin,3.0)
 if kind in ["trade","pack","harvest","gather","feed","chop","dig","cut"] and not (kind=="harvest" and str(action.get("animalType","")) in ["cow","sheep"]):
  oval(out,basket.x,basket.y+2.0,14.0,4.0,"#253c382c")
  rect(out,basket.x-11.0,basket.y-10.0,22.0,11.0,"#947043")
  for i in range(4):rect(out,basket.x-9.0+i*5.0,basket.y-9.0,2.0,9.0,"#c4a16b")
  rect(out,basket.x-13.0,basket.y-12.0,26.0,3.0,"#d1b27b")
  if t>0.66 and kind!="feed":
   item(out,ballistic(contact+Vector2(0,-9),basket+Vector2(0,-5),smooth((t-0.66)/0.24),10.0),str(action.get("item","")),item_known)
 line(out,[shoulder,elbow,hand],"#433f342e",7.0)
 line(out,[shoulder,elbow,hand],skin,4.0)
 oval(out,hand.x,hand.y,3.0,3.0,skin)
 if kind in ["hoe","build","brush","chop","dig","cut"]:
  var hit:=smooth((t-0.22)/0.3)
  var recover:=smooth((t-0.62)/0.35)
  var head:=Vector2(lerpf(hand.x-ux*14.0,contact.x,hit)*(1.0-recover)+(hand.x+ux*6.0)*recover,lerpf(hand.y-30.0,contact.y-2.0,hit)*(1.0-recover)+(hand.y-18.0)*recover)
  line(out,[hand,head],"#a97f4c",3.0)
  var angle:=(head-hand).angle()+PI/2.0
  rect(out,-2.0 if kind=="chop" else -9.0,-3.0,12.0 if kind=="chop" else 18.0,8.0 if kind=="brush" else 11.0 if kind=="chop" else 5.0,"#bd9b5e" if kind=="brush" else "#829c95",head,angle)
  rect(out,-8.0,-3.0,16.0,1.0,"#d2d1ad",head,angle)
  if t>0.5 and t<0.78:
   for i in range(5):
    var at:=ballistic(contact,contact+Vector2((i-2)*9.0,3.0),(t-0.5)/0.28,8.0+(i%2)*5.0)
    rect(out,at.x,at.y,2.0,2.0,"#b09163")
 if kind=="water":
  var pour:=smooth((t-0.23)/0.13)*(1.0-smooth((t-0.7)/0.12))
  var angle:=-pour*0.4 if ux<0.0 else pour*0.4
  rect(out,-8.0,-8.0,15.0,12.0,"#6f9b9b",hand,angle)
  rect(out,-6.0,-6.0,3.0,8.0,"#b0cbc0",hand,angle)
  line(out,[Vector2(-7 if ux<0.0 else 7,-4),Vector2(-15 if ux<0.0 else 15,-8)],"#90b4b1",4.0,hand,angle)
  if t>0.3 and t<0.86:
   var from:=hand+Vector2(-15.0 if ux<0.0 else 15.0,-5.0)
   for i in range(11):
    var u:=(t-0.3)*2.4-i*0.045
    if u<0.0 or u>1.0:continue
    var at:=ballistic(from,contact,u,3.0)
    rect(out,at.x,at.y,2.0,3.0,"#b9e4df")
    if u>0.86:oval(out,contact.x+(i%3-1)*4.0,contact.y,2.0,1.0,"#c4e6d8")
 if kind in ["seed","feed"] and t>0.3 and t<0.9:
  for i in range(7):
   var u:=(t-0.3)*2.2-i*0.04
   if u<0.0 or u>1.0:continue
   var at:=ballistic(hand,contact+Vector2((i%3-1)*5.0,0.0),u,3.0)
   rect(out,at.x,at.y,2.0,2.0,"#dfc180")
 if kind=="harvest" and str(action.get("animalType",""))=="cow":
  var bucket:=contact+Vector2(12,0)
  oval(out,bucket.x,bucket.y+3.0,10.0,3.0,"#293c3528")
  rect(out,bucket.x-7.0,bucket.y-9.0,14.0,12.0,"#8ea69d")
  oval(out,bucket.x,bucket.y-9.0,7.0,3.0,"#e3e6ce")
  if t>0.3 and t<0.78:
   line(out,[hand,contact+Vector2(4,-16)],"#dbad83",3.0)
   line(out,[contact+Vector2(4,-12),bucket+Vector2(0,-9)],"#f3ebd3",1.0)
 if kind=="harvest" and str(action.get("animalType",""))=="sheep":
  var at:=contact+Vector2(0,-16)
  var gap:=2.0+sin(t*16.0)*2.0
  if t>0.2 and t<0.8:
   line(out,[at+Vector2(-8,-gap),at+Vector2(8,gap)],"#a7b6a6",2.0)
   line(out,[at+Vector2(-8,gap),at+Vector2(8,-gap)],"#a7b6a6",2.0)
  if t>0.45:
   for i in range(3):
    var at_wool:=ballistic(at,contact+Vector2((i-1)*8.0,3),clampf((t-0.45)*2.4-i*0.1,0.0,1.0),2.0)
    oval(out,at_wool.x,at_wool.y,4.0,3.0,"#e6dfcd")
 if kind=="door" and t>0.35 and t<0.8:
  out.append({"op":"arc","x":contact.x,"y":contact.y-16.0,"radius":5.0+float(q.reach)*4.0,"start":-0.7,"end":0.7,"color":"#f2d7a678","width":1.0,"origin":xy(Vector2.ZERO),"angle":0.0})
 if kind in ["eat","rest","steam"]:
  var sip:=smooth((t-0.25)/0.3)*(1.0-smooth((t-0.67)/0.25))
  var bowl:=Vector2(lerpf(hand.x,player.x+ux*4.0,sip),lerpf(hand.y,player.y-29.0,sip))
  oval(out,bowl.x,bowl.y+2.0,8.0,3.0,"#4d7c78")
  rect(out,bowl.x-8.0,bowl.y-3.0,16.0,5.0,"#e5d6b5")
  oval(out,bowl.x,bowl.y-3.0,7.0,2.0,"#96754d")
  for i in range(3):
   var u:=fposmod(t*1.1+i*0.27,1.0)
   line(out,[bowl+Vector2(i*3.0-3.0,-7.0-u*15.0),bowl+Vector2(i*3.0-2.0+sin(u*5.0)*2.0,-12.0-u*15.0)],"#f5ead47a",1.0)
 if kind=="read":
  rect(out,hand.x-10.0,hand.y-6.0,10.0,14.0,"#e1cca0")
  rect(out,hand.x+1.0,hand.y-6.0,10.0,14.0,"#f0e1b8")
  rect(out,hand.x,hand.y-7.0,1.0,16.0,"#8d704a")
  for i in range(3):rect(out,hand.x-7.0,hand.y-3.0+i*3.0,5.0,1.0,"#9d8a60")
 if kind=="trade":
  rect(out,player.x-19.0,player.y-17.0,13.0,9.0,"#eedfb5")
  rect(out,player.x-17.0,player.y-14.0,9.0,1.0,"#866c46")
  if t>0.65:oval(out,hand.x,hand.y-6.0,3.0,3.0,"#deb758")
 if kind in ["pet","greet"]:
  var wave:=sin(clampf((t-0.25)/0.5,0.0,1.0)*TAU)*3.0
  oval(out,hand.x+ux*wave,hand.y+wave,3.0,3.0,skin)
 if kind=="bell":
  rect(out,hand.x-3.0,hand.y-8.0,6.0,10.0,"#b59654")
  rect(out,hand.x-5.0,hand.y,10.0,2.0,"#e4c888")
 if kind=="dress":line(out,[player+Vector2(-7,-22),hand,player+Vector2(7,-18)],"#d4c491",2.0)
 if kind=="sleep" and t>0.35:
  out.append({"op":"text","text":"z","x":player.x+12.0,"y":player.y-36.0-smooth(t)*9.0,"color":"#e6e2cb","font":"11px serif","origin":xy(Vector2.ZERO),"angle":0.0})
 if kind=="bike":
  var origin:=player+Vector2(-22 if ux<0.0 else 22,0)
  for x in [-13.0,13.0]:
   out.append({"op":"arc","x":x,"y":1.0,"radius":8.0,"start":0.0,"end":7.0,"color":"#627e74","width":2.0,"origin":xy(origin),"angle":0.0})
  line(out,[Vector2(-13,1),Vector2(0,-13),Vector2(13,1),Vector2(-13,1)],"#849b85",2.0,origin)
  rect(out,-4.0,-17.0,10.0,3.0,"#ad8554",origin)
 if kind=="fish":
  var tip:=hand+Vector2(ux*26.0,-38.0)
  var bob:=ballistic(hand,Vector2(float(action.get("waterX",contact.x+ux*12.0)),float(action.get("waterY",contact.y))),smooth(t/0.12),30.0)
  line(out,[hand,tip],"#bda06b",2.0)
  out.append({"op":"quad","points":[xy(tip),xy(Vector2(lerpf(tip.x,bob.x,0.5),bob.y-8.0)),xy(bob)],"color":"#d8d6b39c","width":1.0,"origin":xy(Vector2.ZERO),"angle":0.0})
  rect(out,bob.x-1.0,bob.y-5.0+sin(clock*8.0)*(4.0 if t>0.2 and t<0.35 else 1.0),3.0,6.0,"#c66c53")
  if t>0.83 and bool(fishing.get("caught",false)):
   var landing:=player+Vector2(18,0)
   var u:=smooth((t-0.83)/0.17)
   var release:=bool(fishing.get("plan",{}).get("release",false))
   var caught:Vector2
   if release:caught=ballistic(bob,landing,u*2.0,14.0) if u<0.5 else ballistic(landing,bob,(u-0.5)*2.0,8.0)
   else:caught=ballistic(bob,landing,u,24.0)
   item(out,caught,str(action.get("item","")),item_known,0.8)
   if release and u>0.8:oval(out,bob.x,bob.y,8.0+(u-0.8)*40.0,3.0,"#c9e8de66")
   else:oval(out,landing.x,landing.y+3.0,15.0,6.0,"#a88957")
 return out
