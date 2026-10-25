extends RefCounted
# Read-only source descriptions shared by world prompts and target selection.
static func describe(s:Node,p:Dictionary,_tool:String="hand")->Dictionary:
 if bool(p.get("scenery",false)):
  var verbs:Dictionary={"rest":"坐下歇脚","forage":"翻看山野手记","farmcare":"查看田间照料","weather":"观察风向与天气","tools":"查看工具养护","economy":"查看物产行情","processing":"查看加工与料理","animals":"查看伙伴照料"}
  var kind:String=str(p.get("kind",""))
  return {"name":p.get("name",""),"verb":verbs.get(kind,""),"state":"歇脚恢复体力 · 时间照常流逝" if kind=="rest" else s.weather_for(s.day)+" · "+str(s.weather_profile().get("label","")) if kind=="weather" else "乡村生活设施","detail":p.get("story",""),"reason":"","ready":true}
 var result:Dictionary={"name":str(p.get("name","手边物件")),"verb":"查看","state":"走近后互动","reason":"","detail":"","ready":true}
 var energy:=0
 match str(p.get("kind","")):
  "ranch-box","ranch-product","ranch-trough":
   result.verb="添料" if str(p.kind)=="ranch-trough" else "领取"
   result.state="物资在动作完成后转移 · 保留生产日期"
   return result
  "npc":
   result.verb="聊聊"
   result.state=str(s.npc_location(str(p.get("id",""))).get("activity",""))
   result.detail="停步面对面 · 对话时暂停时间"
  "plot":
   var index:int=int(p.get("index",-1))
   if index<0 or index>=s.plots.size():return {}
   var a:Dictionary=s.plots[index]
   var crop:String=str(a.get("crop",""))
   var ripe:bool=crop!="" and float(a.growth)>=s.crop_days(crop)
   result.name=str(index+1)+" 号田 · "+(s.crop_name(crop) if crop!="" else "菜地")
   result.state=plot_stage(s,index)
   result.detail="水分 "+str(int(floor(float(a.moisture)+0.5)))+" · 肥力 "+str(int(floor(float(a.fertility)+0.5)))
   match _tool:
    "seed":
     result.verb="播种";energy=labor_cost(s,2)
     var id:String=s.seed_variant_id(s.selected_seed)
     var need:int=2 if str(s.farm.get("density","balanced"))=="dense" else 1
     var name:String=str(s.item_catalog.get(id,{}).get("name",id))
     result.reason="已有作物，先收获" if crop!="" else "先用锄头松土" if not bool(a.tilled) or bool(a.get("removed",false)) else "缺少"+name+" ×"+str(need) if int(s.inventory.get(id,0))<need else "非适种季节，换当季种子或查看暖棚" if not s.crop_in_season(s.selected_seed) and not (s.farm_facility_coverage(index,"greenhouse") and str(s.farm.get("seedKind","normal"))!="seasonal") else ""
     result.detail+=" · "+name+" ×"+str(need)
    "hoe":
     var tasks:Array=s.farm_tool_plan(index,"hoe")
     var task:Dictionary={}
     for candidate in tasks:
      if int(candidate.index)==index:task=candidate;break
     result.verb="深耕养土" if str(task.get("action",""))=="deep" else "松土"
     result.reason="" if not task.is_empty() else "先收获现有作物" if crop!="" else "已经松好土，切换种子播种"
     energy=labor_cost(s,4 if str(task.get("action",""))=="deep" else 3,"hoe","hoe")
    "water":
     result.verb="浇水";energy=labor_cost(s,2,"water","water")
     result.reason="范围内暂无缺水田，暂缓再浇" if s.farm_tool_plan(index,"water").is_empty() else ""
    "hand","sickle":
     result.verb="收获";energy=labor_cost(s,2,"sickle")
     result.reason="" if ripe else "尚未成熟，还需约 "+str(int(ceil(s.crop_days(crop)-float(a.growth))))+" 天" if crop!="" else "这里没有成熟作物，选择种子播种"
     if ripe:
      var preview:Dictionary=plot_preview(s,index)
      result.detail+=" · 预计 "+["普通","优质","上品","珍品"][int(preview.grade)]+" ×"+str(int(preview.qty))
    _:
     result.verb="照料";result.reason="换锄头、种子、水壶或双手"
   if _tool in ["hoe","water","sickle"]:
    var tasks:Array=s.farm_tool_plan(index,_tool)
    if tasks.size()>1:result.detail+=" · 沿路逐格 "+str(tasks.size())+" 块"
  "animal":
   var index:int=s.ranch_animal_index(str(p.get("id","")))
   if index>=0:
    var a:Dictionary=s.animals[index]
    var species:Dictionary=s.system_catalog.ranch.species.get(str(a.get("type","")),{})
    result.name=str(a.name)+" · "+str(a.species)
    result.state=animal_status(s,a)[0]
    var action: String = s.ranch_default_action(index)
    result.verb={"collect":str(species.get("harvestVerb","收取产物")),"feed":"喂食","pet":"抚摸","treat":"护理","rescue":"带回"}.get(action,"照料")
    result.state=preload("res://scripts/ranch_care.gd").status(s,a)
    if result.verb=="抚摸" and int(a.care.get("pet",-1))==s.day:result.reason="今天已经陪过它，先让它歇一会儿"
    if result.verb=="喂食":
     var breed:Dictionary=s.system_catalog.ranch.breeds.get(str(a.get("breed","local")),{})
     var need:int=preload("res://scripts/ranch_care.gd").needed(s,a,s.day)
     var id:String=str(s.ranch.get("feed","feed"))
     var name:String=str(s.item_catalog.get(id,{}).get("name",id))
     result.detail=name+" ×"+str(need)
     if int(s.inventory.get(id,0))<need:result.reason="饲料不足，先补充"+name
     if not preload("res://scripts/ranch_care.gd").accepts(s,a,id):result.reason="鸡鸭不吃干草，换基础饲料或谷物精料"
    result.detail+=" · 饱食 "+str(int(floor(float(a.hunger)+0.5)))
    var efficient:bool=bool(s.ranch.barns.get(str(species.get("home","")),{}).get("efficiency",false))
    var base:int=1 if result.verb=="抚摸" or result.verb=="收取产物" and efficient else 2
    energy=labor_cost(s,base,"care" if result.verb=="收取产物" else "")
  "gather":
   result.verb="采集"
   var id:String=str(p.get("id",""))
   var item:String=str(p.get("item",""))
   var event:String=str(p.get("event",""))
   energy=labor_cost(s,(4 if str(s.forage.get("mode","gentle"))=="full" else 3)-(1 if int(s.forage.get("xp",0))>=20 else 0),"","gather")
   result.state=s.forage_description(id,item,event)
   var q:Dictionary=s.forage_status(id,item,event)
   result.reason="" if bool(q.ready) else "还需休养 "+str(int(q.wait))+" 天" if int(q.wait)>0 else "尚未到采集季节" if not bool(q.in_season) else "等待适合的天气"
   result.detail="预计 ×"+str(int(q.quantity))+" · "+("留根采集" if str(s.forage.get("mode","gentle"))=="gentle" else "多取一份，休养更久") if bool(q.ready) else ""
  "quest-project":
   result.verb="查看共建安排";result.state="在此共同动工 · 长期心愿";return result
  "fishtrap":
   result.verb="查看岸边捕笼"
   result.state=preload("res://scripts/fishing_service.gd").trap_status(s,str(p.id))
   return result
  "fish":
   result.verb="抛竿"
   energy=maxi(2,6-int(s.tool_data("rod").get("level",0)))
   var bait_id:String=str(s.fishing.get("bait","plain"))
   var bait:Dictionary=s.system_catalog.get("fishing",{}).get("baits",{}).get(bait_id,{})
   result.state=("轻松观漂" if str(s.fishing.get("mode","relaxed"))=="relaxed" else "手动追踪鱼影")+" · "+str(bait.get("name",""))
   result.reason="" if s.fishing_has_bait(bait_id) else "鱼饵不足，可换免费素饵"
   result.detail="抄鱼后可选择留下或放流；浮漂落水时结算鱼饵与体力。"
  "enter","exit":
   result.verb="推门进入" if p.kind=="enter" else "推门出屋"
   result.state="从这扇门步行通过"
  "kitchen-station":
   result.verb="查看工位"
   var jobs:Array=[]
   var ready:=0
   var remaining:=INF
   for job in s.kitchen.get("jobs",[]):
    if str(job.get("station",""))!=str(p.get("station","")):continue
    jobs.append(job)
    if float(job.get("ready",0))<=s._kitchen_now():ready+=1
    remaining=minf(remaining,float(job.get("ready",0))-s._kitchen_now())
   result.state=str(ready)+" 批可收取" if ready>0 else str(jobs.size())+" 批加工中" if not jobs.is_empty() else "工位空闲"
   result.detail="最快还需 "+str(int(ceil(remaining)))+" 游戏分钟" if not jobs.is_empty() and ready==0 else ""
  "economy":
   result.verb="查看货签"
   var count:=0
   var total:=0
   for job in s.economy.get("jobs",[]):
    if float(job.get("ready",0))<=s._kitchen_now():count+=1;total+=int(job.get("price",0))
   result.state=str(count)+" 张货单可结算 · "+str(total)+" 元待领" if count>0 else "可摆摊、代销与查看订单"
   result.detail="收入以手动领取后的实际到账为准"
  "build":
   result.verb="翻开营造簿"
   var jobs:Array=s.building.get("jobs",[])
   result.state=str(jobs.size())+" 处正在修缮" if not jobs.is_empty() else "可查看修缮、改良与布局"
   var q:Dictionary=s.building_quote("house")
   if not q.is_empty() and not jobs.any(func(job:Dictionary)->bool:return str(job.get("id",""))=="house"):
    var missing:Array[String]=[]
    for id in ["wood","bamboo"]:
     if int(s.inventory.get(id,0))<int(q[id]):missing.append(str(s.item_catalog.get(id,{}).get("name",id))+" ×"+str(int(q[id])-int(s.inventory.get(id,0))))
    if s.money<int(q.money):missing.push_front(str(int(q.money)-s.money)+" 元")
    result.detail="老屋下一阶："+("还缺 "+"、".join(missing) if not missing.is_empty() else "材料与零钱已备齐")+" · 次日竣工"
  "tools":
   result.verb="查看工具";result.state="改良、专长与范围设置";result.detail="范围作业沿路逐格完成，可随时停下"
  "storage":
   result.verb="整理储物"
   var count:=0
   for value in s.storage.values():count+=int(value)
   result.state=str(count)+" 件物品存放中";result.detail="存取物品不会重复计为新获得"
  "build-piece":
   var service:String=str(p.get("service",""))
   result.verb="坐一会儿" if service=="rest" else "补充储水" if service=="water" else "使用" if service!="" else "看看陈设"
   result.state="储水 "+str(int(s.farm.get("water",0)))+" / 120" if service=="water" else "亲手安置的小院物件"
   if service=="water":
    energy=labor_cost(s,3)
    result.detail="补满需 6 元"
    result.reason="水箱已经装满" if int(s.farm.get("water",0))>=120 else "还缺 "+str(6-s.money)+" 元" if s.money<6 else ""
  "rest","tea","bed-visit":
   result.verb="坐一会儿";result.state="歇脚、恢复体力"
  "egg":
   result.verb="看看旧物";result.state="靠近翻看，发现屋主的生活细节"
  "chore":
   result.verb="搭把手";result.state="照料身边的物件"
 if result.reason=="" and energy>0 and s.stamina<energy:result.reason="还需 "+str(energy)+" 体力，先吃点东西或歇脚"
 if energy>0 and result.reason=="":result.detail+=(" · " if result.detail!="" else "")+"体力 "+str(energy)
 result.ready=result.reason==""
 return result

static func labor_cost(s:Node,base:int,kit:String="",tool:String="")->int:
 var value:=base
 var equipment:Dictionary=s.tool_data(kit) if kit!="" else {}
 if int(equipment.get("level",0))>0 and kit in ["sickle","care"]:value-=1
 if kit=="care" and int(equipment.get("level",0))==2 and str(equipment.get("branch",""))=="broad":value-=1
 value-=1 if str(s.skills.get("farming",{}).get("choice",""))=="gentle" else 0
 value-=1 if int(s.legacy_systems.get("buffs",{}).get("laborDay",-1))==s.day else 0
 value-=1 if s.kitchen_active_buff() in ["暖胃","饱足"] else 0
 value-=1 if tool!="" and bool(s.legacy_systems.get("toolUpgrades",{}).get(tool,false)) else 0
 return maxi(1,value)

static func animal_status(s:Node,a:Dictionary)->Array[String]:
 var species:Dictionary=s.system_catalog.ranch.species.get(str(a.get("type","")),{})
 var home:String=str(species.get("home",""))
 var barn:Dictionary=s.ranch.barns.get(home,{})
 var messages:Array[String]=[]
 if bool(a.get("lost",false)):messages.append("走远了：留在南坡标记附近，可带回")
 if float(a.get("illness",0))>=20:messages.append("不适 "+str(int(floor(float(a.illness)+0.5)))+"：休养、营养料或治疗")
 if float(a.get("hunger",100))<40:messages.append("饲料不足")
 if float(a.get("clean",100))<45 or float(barn.get("clean",100))<45:messages.append("垫草潮湿，需要清理")
 var count:=0
 for animal in s.animals:
  var definition:Dictionary=s.system_catalog.ranch.species.get(str(animal.get("type","")),{})
  if str(definition.get("home",""))==home:count+=1
 if count>s.ranch_barn_capacity(home):messages.append("畜舍拥挤，建议扩容")
 if float(barn.get("durability",100))<25:messages.append("屋舍需修缮")
 if float(a.get("health",100))<45:messages.append("健康较弱，建议留舍")
 if int(a.get("ready",0))>0:messages.append("可收 "+str(s.item_catalog.get(str(a.get("product","")),{}).get("name",""))+" ×"+str(int(a.ready)))
 if messages.is_empty():
  messages.append("安心颐养，不再安排生产" if bool(a.get("retired",false)) else "状态安稳，按自己的节奏照料" if float(a.get("age",0))>=float(species.get("adult",0)) else "正在长大，成年后再安排生产")
 return messages

static func plot_stage(s:Node,index:int)->String:
 var p:Dictionary=s.plots[index]
 if bool(p.get("removed",false)):return "待修复地"
 if bool(p.get("fallow",false)):return "休耕养地"
 if not bool(p.tilled):return "荒地"
 var crop:String=str(p.crop)
 if crop=="":return "板结待松土" if float(p.get("compacted",0))>55 else "待播种"
 if float(p.health)<22:return "萎蔫·可抢救"
 if float(p.growth)>=s.crop_days(crop):return "留种期" if int(p.get("ripe_days",0))>=4 else "成熟"
 var k:float=float(p.growth)/s.crop_days(crop)
 return "种子" if k<0.12 else "萌芽" if k<0.28 else "幼苗" if k<0.48 else "生长期" if k<0.72 else "开花结实"

static func plot_preview(s:Node,index:int)->Dictionary:
 return preload("res://scripts/farm_insights.gd").harvest(s,s.plots[index])
