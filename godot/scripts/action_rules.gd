extends RefCounted
class_name ActionRules
const CATALOG := {
 "chop":["扶稳枝料，挥斧取材",1.9],"dig":["沿笋根松土取笋",1.65],"cut":["拢叶剪取嫩梢",1.45],
 "hoe":["翻松土壤",1.25],"water":["倾壶补水",1.25],"seed":["俯身落种",1.15],
 "harvest":["摘下收进竹篮",1.3],"gather":["整理采下物产",1.3],"feed":["舀料添进食槽",1.25],
 "brush":["梳洗与清扫",1.3],"pet":["伸手轻轻抚摸",1.1],"steam":["生火料理",1.6],
 "trade":["点货、交接与记账",1.6],"pack":["分拣物品入篮",1.2],"build":["丈量、敲打与安置",1.7],
 "door":["伸手推门",0.75],"read":["翻开手边物件",0.7],"greet":["招手、侧身交谈",1.1],
 "eat":["拿起食物慢慢吃",1.4],"rest":["落座歇一歇",1.5],"sleep":["铺好被褥，安静入梦",2.2],
 "fish":["抛竿、等漂、收线",2.2],"bell":["握住铜铃轻轻摇",1.1],
 "dress":["整理衣袖与装束",1.1],"bike":["扶稳车把上落车",0.9]
}
const UI_GROUPS := {
 "trade":["buy","sell-item","sell-all","gift-item","deliver","join-festival","f-buy","r-buy","k-buy","e-recipe-buy","e-favor","e-festival","e-host","e-shared","e-marry","e-date"],
 "pack":["ec-transfer","ec-tidy","ec-lock","ec-pin","e-store","e-take","e-store-all","e-take-all","r-store","r-withdraw","k-store","b-store","b-withdraw","e-mail","e-achievement","b-claim","r-adopt","r-confirm"],
 "build":["repair","upgrade","b-apply","b-recover","b-mode","b-style","b-room","b-showcase","e-project","e-craft","e-place","e-tool-upgrade","k-cold"],
 "eat":["eat","ec-eat","k-eat"],"steam":["cook-item","e-sub-cook","e-trial","e-process","k-finish","k-assist"],
 "read":["e-chapter","e-small-event","e-year-plan","e-skill","e-pet-name","e-animal-name","r-rename","r-policy","r-pet-mode","e-free-range","t-branch","t-shape","f-selection","f-threshold","f-auto-seed","sc-pin","sc-remove"],
 "dress":["e-appearance"],"pet":["e-pet","e-animal"],"greet":["v-npc-talk","e-story-choice","e-separate"],
 "water":["e-fill-water"],"hoe":["e-fertilize","e-pest"],"sleep":["next-day"],"bike":["v-bike"]
}
static func spec(kind: String,label: String="",item: Variant=null) -> Dictionary:
 var row:Array=CATALOG.get(kind,CATALOG.read)
 var result:Dictionary={"kind":kind if CATALOG.has(kind) else "read","label":label if label!="" else str(row[0]),"duration":float(row[1])}
 if item!=null:result.item=item
 return result

static func duration(action: Dictionary,pace: String="normal") -> float:
 var seconds:=float(action.duration)
 return maxf(0.45,seconds*0.65) if pace=="brisk" and str(action.kind) not in ["fish","sleep"] else seconds

static func ui(id: String,label: String="") -> Dictionary:
 for kind in UI_GROUPS:
  if UI_GROUPS[kind].has(id):return spec(str(kind),label)
 return {}

static func point(p: Dictionary,tool: String="hand") -> Dictionary:
 var type:=str(p.get("kind",""))
 var action:=str(p.get("action",""))
 var kind:="read"
 if type=="walk":return {}
 if type=="animal" or type=="plot" and tool in ["hoe","water","sickle"] or type=="chore" and action=="churn":return {}
 if type=="forage-care":kind="seed"
 elif type=="build-task":kind="trade" if str(p.get("op","")).begins_with("economy-") else "build"
 elif type=="kitchen-task":kind="pack" if str(p.get("op",""))=="collect" else "brush" if str(p.get("op",""))=="clean" else "build" if str(p.get("op",""))=="upgrade" else "steam"
 elif type=="farm-task":kind="harvest" if action in ["harvest","companionHarvest","seedSave"] else "water" if action in ["water","fill"] else "seed" if action in ["sow","companion"] else "build" if action=="facility" else "read" if action=="inspect" else "hoe"
 elif type=="ranch-task" and action=="claimBox":kind="pack"
 elif type=="ranch-task":kind="harvest" if action=="collect" else "feed" if action=="feed" else "brush" if action=="clean" else "water" if action=="water" else "build" if action in ["build","upgrade","repair"] else "trade" if action=="purchase" else "pet"
 elif type in ["enter","exit"]:kind="door"
 elif type=="npc":kind="greet"
 elif type=="gather":kind="chop" if str(p.get("item","")) in ["wood","bamboo"] else "dig" if str(p.get("item",""))=="shoot" else "cut" if str(p.get("item",""))=="tea" else "gather"
 elif type=="plot":kind="harvest" if tool=="hand" else tool
 elif type in ["tea","rest","bed-visit"]:kind="rest"
 elif type=="fish":kind="fish"
 elif type=="pet":kind="pet"
 elif type=="chore":kind=action if action in ["feed","brush","water","bell"] else "hoe"
 elif type=="ambient":kind="bell"
 elif type=="build-piece":kind="water" if str(p.get("service",""))=="water" else "rest" if str(p.get("service",""))=="rest" else "read"
 var result:=spec(kind,str(p.get("harvestVerb","")),p.get("item",p.get("id",null)))
 result.door=type in ["enter","exit"]
 return result
