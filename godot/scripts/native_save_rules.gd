extends RefCounted
## Reject dangerous scalar/container types before any native state is changed.
const BASE := preload("res://scripts/source_save_validation.gd")
const SCHEMA := preload("res://scripts/native_save_schema.gd")
static func error(value: Variant, initial: Dictionary, offsets: Dictionary) -> String:
	if not valid(value,initial):
		return "存档数据无效，当前进度未改动。请读取有效备份。"
	var atlas := preload("res://scripts/atlas_rules.gd")
	if atlas.truthy(value.get("atlas")) and not atlas.valid(value.atlas,offsets): return atlas.ERROR_MESSAGE
	var delivered: Variant = value.get("ranch",{}).get("delivered",[])
	if not atlas.truthy(delivered): return ""
	if not delivered is Array: return "牧场心愿记录无效。"
	for order: Variant in delivered:
		if not order is String or order not in ["ranchMilk","ranchWool","ranchYogurt"]: return "牧场心愿记录无效。"
	return ""

static func valid(value: Variant, initial: Dictionary = {}) -> bool:
	if not value is Dictionary or not SCHEMA.safe_tree(value): return false
	if not BASE.integer(value.get("version"),1,33): return false
	if not BASE.integer(value.get("day",0),0,100000): return false
	if not BASE.number(value.get("money",0),0,1000000000): return false
	if not BASE.number(value.get("stamina",100),0,100): return false
	if not BASE.number(value.get("minutes",390),360,1320): return false
	if not value.get("plots",[]) is Array or value.get("plots",[]).size() != preload("res://scripts/farm_layout.gd").TOTAL: return false
	if not value.get("inventory",{}) is Dictionary: return false
	for field: String in ["player", "interior_position"]:
		if not value.get(field,{}) is Dictionary: return false
		for axis: String in ["x", "y"]:
			if value.get(field,{}).has(axis) and not BASE.number(value[field][axis],-1000000,1000000): return false
	for plot: Variant in value.plots:
		if not plot is Dictionary: return false
		for field: String in ["growth","soil","fertility","moisture","health","pests","disease","weeds","slow","compacted","condition","penalty","ticks","ripe_days","stress","fertilized","treated","irrigated"]:
			if plot.has(field) and not BASE.number(plot[field],-1000000,1000000): return false
		# Farm care is a numeric counter; animal care is a separate dictionary.
		if plot.has("care") and not BASE.number(plot.care,0,1000000): return false
	for quantity: Variant in value.get("inventory",{}).values():
		if not BASE.integer(quantity,0,999999): return false
	if int(value.get("version",0))>=33 and not preload("res://scripts/quest_save_rules.gd").validate(value.get("quests"),int(value.get("day",0))):return false
	return SCHEMA.error(value,initial).is_empty() and SCHEMA.fishing_error(value).is_empty()
