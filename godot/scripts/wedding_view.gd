extends RefCounted
static func describe(state:Node,id:String)->Dictionary:
 var name:="对方"
 for person in state.npc_catalog:
  if str(person.id)==id:name=str(person.name);break
 return {"title":"把两个人的日子放在一起","subtitle":"婚后各自保留工作和朋友。安排共餐、探亲与来年计划，家不是自动农务设施。","quote":name+"愿意与你慢慢生活。你也确定想和对方成为伴侣吗？","needs":"需要：双方心意相通、前四章故事、信任 70、整理好的厢房。婚礼不会消耗贵重礼品。","confirm":"确定，与"+name+"举行婚礼","cancel":"再慢慢想想"}
