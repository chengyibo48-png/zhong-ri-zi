extends RefCounted
var rows:Array=[]
var next_id:=1
func append(text:String,error:bool,important:bool,seconds:float,now:float)->void:
 expire(now)
 var display:=text+(" · 查看回响 →" if important else "")
 for i in range(rows.size()-1,-1,-1):
  if str(rows[i].text)==display:rows.remove_at(i)
 rows.append({"id":next_id,"text":display,"message":text,"error":error,"important":important,"expires":now+seconds})
 next_id+=1
 while rows.size()>3:rows.pop_front()
func expire(now:float)->bool:
 var changed:=false
 for i in range(rows.size()-1,-1,-1):
  if float(rows[i].expires)<=now:rows.remove_at(i);changed=true
 return changed
