extends RefCounted
static func describe(state:Node,id:String)->Dictionary:
 var person:Dictionary={}
 for row in state.npc_catalog:
  if str(row.id)==id:person=row;break
 if person.is_empty():return {"title":"邻里故事","subtitle":"","text":"","needs":[],"ready":"","choices":[],"find":false,"memories":[],"relationship":""}
 var story:Dictionary=state.npc_stories.get(id,{})
 var arc:Array=state.content.get("arcs",{}).get(id,[])
 var step:=int(story.get("step",0))
 var event:Dictionary=arc[step] if step<arc.size() else {}
 var readiness:Dictionary=state.npc_story_readiness(id)
 var result:Dictionary={"title":str(person.name)+" · "+str(event.get("title","这一段，已经好好记下。")),"subtitle":"故事 "+str(step)+" / "+str(arc.size())+" · 错过日期不会失去剧情。","text":str(event.get("text","")),"needs":[],"ready":str(readiness.get("message","")) if not event.is_empty() else "","choices":[],"find":false,"memories":[],"relationship":""}
 var needs:Dictionary=event.get("needs",{}) if event.get("needs",{}) is Dictionary else {}
 for item in needs:
  var count:=int(state.inventory.get(item,0))
  result.needs.append({"text":str(state.item_catalog.get(item,{}).get("name",item))+" "+str(count)+" / "+str(int(needs[item])),"missing":count<int(needs[item])})
 if not event.is_empty():
  if bool(readiness.get("ok",false)) and state.npc_is_near(id):
   for choice in event.get("choices",[]):result.choices.append(str(choice.get("label","")))
  else:result.find=true
 for index in mini(step,arc.size()):
  var old:Dictionary=arc[index]
  var choices:Array=old.get("choices",[])
  var selected:int=int(story.get("choices",[])[index])
  var choice:Dictionary=choices[selected]
  result.memories.append({"title":str(old.get("title","")),"text":str(old.get("text","")),"choice":"你的回应："+str(choice.get("label","")),"reply":str(choice.get("reply",""))})
 if str(person.get("tier",""))=="romance" and step>=4 and str(state.marriage.get("spouse",""))=="":
  result.relationship="商量婚礼" if state.partners.get(id,"")=="dating" else "重新表达心意"
 return result
