extends RefCounted
## Reject dangerous scalar/container types before any native state is changed.
const BASE := preload("res://scripts/source_save_validation.gd")
const SCHEMA := preload("res://scripts/native_save_schema.gd")
static func error(value: Variant, initial: Dictionary, offsets: Dictionary) -> String:
	if value is Dictionary and (not BASE.integer(value.get("version"),38,38) or not value.get("quests") is Dictionary or not BASE.integer(value.quests.get("version"),3,3)):
		return "本轮为 v38 村庄成长循环，旧版本原档已保留，请开始新生活。"
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
	if not load("res://scripts/village_growth.gd").save_valid(value):return false
	value=prepare_legacy(value)
	if not BASE.integer(value.get("version"),38,38): return false
	if not BASE.integer(value.get("day",0),0,100000): return false
	if not BASE.number(value.get("money",0),0,1000000000): return false
	if not BASE.number(value.get("stamina",100),0,100): return false
	if not BASE.number(value.get("minutes",390),360,1320): return false
	if not value.get("plots",[]) is Array:return false
	# Authored historical layouts are 24 and 72 plots. Unknown counts still indicate
	# truncation; content expansion did not change the persisted save version.
	var count:int=value.plots.size()
	var total:int=preload("res://scripts/farm_layout.gd").TOTAL
	if count!=total and (count not in [24,72] or count>total):return false
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
	if not SCHEMA.error(value,initial).is_empty():return false
	if not preload("res://scripts/house_save.gd").error(value).is_empty():return false
	if not preload("res://scripts/ranch_nurture.gd").data_error(value).is_empty():return false
	if not value.has("fishing") and int(value.version)<33:return true
	return SCHEMA.fishing_error(value).is_empty()

static func prepare_legacy(value:Dictionary)->Dictionary:
	value=preload("res://scripts/ranch_migration_v36.gd").prepare(value)
	value=preload("res://scripts/house_save.gd").prepare(value)
	# The existing schema explicitly admits primitive legacy maps. Materialize their
	# empty defaults before strict v2 validation and typed initialization.
	var raw:Variant=value.get("fishing",{})
	if raw is Dictionary and raw.get("version")==1 and BASE.integer(value.get("version"),1,32):
		var systems:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/systems.json"))
		if not BASE.fishing_error({"day":value.get("day",0),"fishing":raw},systems).is_empty():return value
		var defaults:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/initial_state.json")).fishing.duplicate(true)
		defaults.merge(raw.duplicate(true),true);defaults.version=2
		value=value.duplicate(true);value.fishing=defaults;raw=defaults
	if not raw is Dictionary or raw.get("version")!=2:return value
	var result:=value
	for key:String in ["waters","records"]:
		var old:Variant=raw.get(key,{})
		if old is bool or old is int or old is float:
			if result==value:result=value.duplicate(true)
			result.fishing[key]={}
	return result
