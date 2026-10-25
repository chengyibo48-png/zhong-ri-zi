extends RefCounted
static func hover_content(info:Dictionary,key:String)->Dictionary:
 var body:String=str(info.get("state",""))+"\n"+(str(info.get("reason","")) if str(info.get("reason",""))!="" else str(info.get("verb","")))
 if str(info.get("detail",""))!="":body+="\n"+str(info.detail)
 body+="\n点击走近 · "+key+" 交互"
 return {"name":str(info.get("name","")),"body":body}
static func hover_position(pointer:Vector2,box:Vector2,view:Vector2)->Vector2:
 return Vector2(maxf(8,minf(view.x-box.x-12,pointer.x+20)),maxf(8,minf(view.y-box.y-150,pointer.y+23)))
static func css_ease(progress:float)->float:
 if progress<=0:return 0
 if progress>=1:return 1
 var low:=0.0
 var high:=1.0
 for i in range(32):
  var t:float=(low+high)/2.0
  if bezier(t,0.25,0.25)<progress:low=t
  else:high=t
 return bezier((low+high)/2.0,0.1,1.0)
static func bezier(t:float,p1:float,p2:float)->float:
 var inv:=1.0-t
 return 3.0*inv*inv*t*p1+3.0*inv*t*t*p2+t*t*t
