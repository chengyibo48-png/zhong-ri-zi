extends RefCounted
## One-time initial livestock entitlement, committed with the existing save transaction.
const FLAG:="starter_livestock_v1"
static func count(s:Node)->int:
 var total:int=0
 for animal:Dictionary in s.animals:
  var spec:Dictionary=s.system_catalog.ranch.species.get(str(animal.get("type","")),{})
  if str(spec.get("family",""))=="mammal":total+=1
 return total
static func grant(s:Node)->bool:
 if s.incompatible_save or bool(s.flags.get(FLAG,false)):return false
 return s.transactions.submit("starter_livestock_v1",_apply.bind(s))
static func _apply(s:Node)->bool:
 if bool(s.flags.get(FLAG,false)):return false
 var added:int=0
 while count(s)<2:
  if not s._ranch_space_for("cow"):
   s.message="初始牲畜尚未领取：请先为牛棚腾出空间，再重新进入游戏。"
   return false
  var animal:Dictionary=s._ranch_new_animal("cow","female","local",int(s.system_catalog.ranch.species.cow.adult))
  if animal.is_empty():return false
  animal.name="麦麦" if added==0 else "豆花"
  added+=1
 s.flags[FLAG]=true
 if added>0:
  s._ranch_notice("已安置初始牲畜 ×"+str(added)+"，可在牧场名册查看。")
  s.message="初始牲畜已安置：现在拥有两只牲畜，鸡鸭继续保留。"
 return true
