extends RefCounted
## Optional intentions derive completion from real records and never grant rewards.
const IDS := ["grow","cook","trade","neighbor","museum"]
static func cards(state: Node) -> Array[Dictionary]:
	var cabbage := int(state.inventory.get("cabbage",0))
	var meal := int(state.inventory.get("greens",0))
	return [
		{"id":"grow","title":"收下一篮时令","body":"从成熟田开始，收成可以做饭、出售，也可以送去村史馆。","needs":"种子来自杂货铺；先松土，再播种、补水。","done":int(state.player_stats.get("harvested",0))>0,"page":"farmcare"},
		{"id":"cook","title":"把收成做成家常","body":"清炒时蔬：小青菜 ×2 → 家常菜 ×1。","needs":"%s；去禾溪小灶使用灶台。" % ("食材齐了" if cabbage>=2 else "还缺小青菜 ×%d，可收获或在杂货铺购买" % (2-cabbage)),"done":int(state.player_stats.get("cooked",0))>0,"page":"recipes"},
		{"id":"trade","title":"给收成找个好去处","body":"背包中留一份自己用，其余可以现售、摆摊或交合作订单。","needs":"到实际柜台交易；品质和陈放时间会影响报价。","done":int(state.player_stats.get("earned",0))>0,"page":"economy"},
		{"id":"neighbor","title":"给阿婆带一道菜","body":"把一份清炒时蔬送给林阿婆，接上第一段邻里故事。","needs":"%s；邻里心愿中交付，没有期限。" % ("家常菜齐了" if meal>=1 else "还缺清炒时蔬 ×1：先备小青菜 ×2，在小灶烹饪"),"done":bool(state.flags.get("firstDish",false)),"page":"orders"},
		{"id":"museum","title":"给村庄留一份记录","body":"物产、鱼获、旧物和共同经历，都能成为这一年的留痕。","needs":"在图鉴查看可捐条目与数量，再去村史馆登记；受保护的物品不会被取走。","done":not state.collection.get("donated",{}).is_empty(),"page":"catalog"}
	]
static func target(state: Node, id: String) -> Dictionary:
	var candidates: Array[Dictionary] = state.atlas_targets()
	for row: Dictionary in candidates:
		if id=="grow" and str(row.get("type",""))=="harvest": return row.duplicate(true)
		if id=="neighbor" and str(row.get("npcId",row.get("id","")))=="granny" and str(row.get("type",""))=="npcs": return row.duplicate(true)
	for row: Dictionary in candidates:
		var name := str(row.get("name",""))
		if (id=="cook" and "小灶" in name or id=="trade" and "杂货" in name or id=="museum" and "村史馆" in name or id=="neighbor" and "阿婆" in name) and str(row.get("kind",""))=="enter": return row.duplicate(true)
		if id=="grow" and str(row.get("id",""))=="farm": return row.duplicate(true)
	return {}
