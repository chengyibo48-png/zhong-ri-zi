extends RefCounted
const BASE=preload("res://scripts/source_save_validation.gd")
static func defaults()->Dictionary:return {"revision":1,"nextReceipt":1,"receipts":{},"relationClaims":{}}
static func prepare(value:Dictionary)->Dictionary:
	if int(value.get("version",0))!=36:return value
	var result:Dictionary=value.duplicate(true)
	if not result.get("interior_state",{}) is Dictionary:return value
	if not result.has("interior_state"):result.interior_state={"memories":{},"chores":{}}
	result.interior_state.household=defaults();result.version=37
	return result
static func error(data:Dictionary)->String:
	if int(data.get("version",0))<37:return ""
	var h:Variant=data.get("interior_state",{}).get("household")
	if not h is Dictionary:return "屋内活动记录缺失。"
	if not BASE.integer(h.get("revision"),1,1) or not BASE.integer(h.get("nextReceipt"),1,1000000000):return "屋内活动修订无效。"
	if not h.get("receipts") is Dictionary or not h.get("relationClaims") is Dictionary:return "屋内活动凭据无效。"
	var rooms:Dictionary=preload("res://scripts/house_geometry.gd").all()
	if h.receipts.size()>144 or h.relationClaims.size()>24:return "屋内活动记录超出范围。"
	for key:Variant in h.receipts:
		var r:Variant=h.receipts[key]
		if not r is Dictionary or not rooms.has(str(r.get("room",""))) or r.get("kind") not in ["theme","seat","browse"]:return "屋内活动身份无效。"
		if str(key)!=str(r.room)+":"+str(r.kind) or not BASE.integer(r.get("day"),0,int(data.day)) or not BASE.integer(r.get("serial"),1,int(h.nextReceipt)-1):return "屋内活动凭据无效。"
		if not r.get("choices") is Array or r.choices.size()!=3:return "屋内活动选择无效。"
		for choice:Variant in r.choices:
			if not BASE.integer(choice,0,1):return "屋内活动选择无效。"
	for id:Variant in h.relationClaims:
		if not rooms.has("home-"+str(id)) or not h.relationClaims[id] is bool:return "屋内活动关系凭据无效。"
	if h.has("homePreset") and not h.homePreset is bool:return "自家补充布置状态无效。"
	if h.has("fixtureStates"):
		if not h.fixtureStates is Dictionary or h.fixtureStates.size()>96:return "生活物件状态无效。"
		for id:Variant in h.fixtureStates:
			if not id is String or not h.fixtureStates[id] is bool:return "生活物件状态无效。"
			var room:String=str(id).split(":fixture:")[0]
			var f:Dictionary=load("res://scripts/house_life.gd").fixture(room,str(id))
			if f.is_empty() or str(f.type)=="preset":return "生活物件身份无效。"
	return ""
