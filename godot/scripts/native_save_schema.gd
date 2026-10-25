extends RefCounted
## Structural validation before the loader touches live state. Missing old fields
## retain the loader's existing defaults; present fields must have usable types.
const BASE := preload("res://scripts/source_save_validation.gd")
const TEXT := preload("res://scripts/js_string.gd")
const MAX_DEPTH := 64
const MAX_NODES := 200000
const MAX_BYTES := 16 * 1024 * 1024
const NUMBER := -1
const OPTIONAL_OBJECT := -2
const PRIMITIVE_MAP := -3
const IDENTIFIER := -4
const ROOT_OBJECTS := ["player", "interior_position", "interior_state", "inventory", "storage", "quality", "crop_grades", "storage_quality", "economy", "environment", "forage", "fishing", "kitchen", "toolkit", "skills", "community_projects", "projects", "legacy_chapters", "chapters", "year_plans", "yearPlans", "farm", "building", "ranch", "upgrades", "relations", "neighbors", "npc_residents", "last_gifts", "npc_stories", "partners", "marriage", "collection", "furniture", "pet", "season_events", "flags", "gathered", "player_settings", "settings", "visual_fx", "visualFx", "ui_art", "uiArt", "appearance", "feedback", "player_stats", "stats", "legacy_systems", "legacy_archive"]
const ROOT_ARRAYS := ["plots", "animals", "letters", "mail_read", "mailRead", "legacy_processing", "processing", "known_recipes", "knownRecipes", "achievements", "archives", "festivals", "player_journal", "journal"]
const ALIASES := {"player_settings":"settings", "visual_fx":"visualFx", "ui_art":"uiArt", "player_stats":"stats", "player_journal":"journal", "storage_quality":"storageQuality", "community_projects":"projects", "legacy_chapters":"chapters", "year_plans":"yearPlans", "known_recipes":"knownRecipes", "season_events":"seasonEvents", "last_gifts":"lastGifts", "npc_stories":"stories"}

static func safe_tree(value: Variant) -> bool:
	return _tree(value, 0, {"remaining":MAX_NODES})

static func _tree(value: Variant, depth: int, budget: Dictionary) -> bool:
	budget.remaining -= 1
	if depth > MAX_DEPTH or int(budget.remaining) < 0: return false
	if value == null or value is bool or value is int: return true
	if value is float: return is_finite(value)
	if value is StringName: return String(value).length() <= MAX_BYTES
	if TEXT.is_string(value): return TEXT.length(value) <= MAX_BYTES
	if value is Array:
		if value.size() > int(budget.remaining): return false
		for child: Variant in value:
			if not _tree(child, depth + 1, budget): return false
		return true
	if value is Dictionary:
		if value.size() > int(budget.remaining): return false
		for key: Variant in value:
			if key is StringName:
				if String(key).length() > 4096: return false
			elif not TEXT.is_string(key) or TEXT.length(key) > 4096: return false
			if not _tree(value[key], depth + 1, budget): return false
		return true
	return false

static func _kind(value: Variant, kind: int) -> bool:
	if kind == NUMBER: return BASE.number(value, -1.0e15, 1.0e15)
	if kind == OPTIONAL_OBJECT: return value == null or value is Dictionary
	if kind == PRIMITIVE_MAP: return value is Dictionary or value is bool or value is int or value is float
	if kind == IDENTIFIER: return value is StringName or TEXT.is_string(value) or BASE.number(value,-1.0e15,1.0e15)
	if kind == TYPE_STRING: return value is StringName or TEXT.is_string(value)
	return typeof(value) == kind

static func _fields(row: Variant, spec: Dictionary, path: String) -> String:
	if not row is Dictionary: return path
	for key: String in spec:
		if row.has(key) and not _kind(row[key], int(spec[key])): return path + "." + key
	return ""

static func _records(value: Variant, spec: Dictionary, path: String) -> String:
	if not value is Array: return path
	for index: int in range(value.size()):
		var bad := _fields(value[index], spec, "%s[%d]" % [path,index])
		if not bad.is_empty(): return bad
	return ""

static func _map(value: Variant, kind: int, path: String) -> String:
	if not value is Dictionary: return path
	for key: Variant in value:
		if not _kind(value[key], kind): return path + "." + str(key)
	return ""

static func _template(value: Variant, expected: Variant, path: String) -> String:
	# These old fields are deliberately coerced by the gameplay loaders.
	if path in ["farm.autoSeed","farm.overlay"]: return ""
	if path in ["fishing.waters","fishing.records"] and _kind(value,PRIMITIVE_MAP):
		if not value is Dictionary: return ""
	if expected == null: return ""
	if expected is Dictionary:
		if not value is Dictionary: return path
		for key: Variant in expected:
			if not value.has(key): continue
			var bad := _template(value[key], expected[key], path + "." + str(key))
			if not bad.is_empty(): return bad
		return ""
	if expected is Array:
		if not value is Array: return path
		if expected.is_empty(): return ""
		for index: int in range(value.size()):
			var bad := _template(value[index], expected[0], "%s[%d]" % [path,index])
			if not bad.is_empty(): return bad
		return ""
	return "" if _kind(value, NUMBER if expected is int or expected is float else typeof(expected)) else path

static func error(data: Dictionary, initial: Dictionary) -> String:
	for key: String in ROOT_OBJECTS:
		if key in ["neighbors","npc_residents"]: continue
		if data.has(key) and not data[key] is Dictionary: return key
	for key: String in ROOT_ARRAYS:
		if data.has(key) and not data[key] is Array: return key
	for key: Variant in data:
		if not (key is String or key is StringName): continue
		var initial_key: String = ALIASES.get(key,String(key))
		if initial.has(initial_key) and key not in ["player", "plots", "animals", "relations", "atlas", "neighbors", "npc_residents", "legacy_archive"]:
			var bad := _template(data[key],initial[initial_key],key)
			if not bad.is_empty(): return bad
	var bad := _fields(data,{"interior_return_position":OPTIONAL_OBJECT,"_source_ranch_bundle":TYPE_DICTIONARY,"riding":TYPE_BOOL,"fish_caught":NUMBER,"_restore_source_player":TYPE_BOOL},"save")
	if not bad.is_empty(): return bad
	for key: String in ["player","interior_position","interior_return_position"]:
		if data.get(key) == null: continue
		bad = _fields(data[key],{"x":NUMBER,"y":NUMBER,"direction":TYPE_STRING},key)
		if not bad.is_empty(): return bad
	for key: String in ["storage","gathered","furniture","player_stats","stats","year_plans","yearPlans","legacy_chapters","chapters"]:
		bad = _map(data.get(key,{}),NUMBER,key)
		if not bad.is_empty(): return bad
	for side: String in ["quality","crop_grades","storage_quality"]:
		for key: Variant in data.get(side,{}):
			var grades: Variant = data[side][key]
			if not grades is Array or grades.size() not in [2,3,4]: return side + "." + str(key)
			for quantity: Variant in grades:
				if not BASE.integer(quantity,0,999999): return side + "." + str(key)
	bad = _records(data.plots,{"crop":TYPE_STRING,"regrow_days":NUMBER,"harvest_count":NUMBER,"care":NUMBER,"companion":TYPE_DICTIONARY,"repeats":NUMBER,"tilled":TYPE_BOOL,"watered":TYPE_BOOL},"plots")
	if not bad.is_empty(): return bad
	for plot: Dictionary in data.plots:
		bad = _fields(plot.get("companion",{}),{"growth":NUMBER,"condition":NUMBER,"ticks":NUMBER,"ripe_days":NUMBER,"crop":TYPE_STRING},"plots.companion")
		if not bad.is_empty(): return bad
	bad = _animals(data.get("animals",[]),"animals")
	if not bad.is_empty(): return bad
	bad = _farm(data.get("farm",{}))
	if not bad.is_empty(): return bad
	bad = _ranch(data.get("ranch",{}),"ranch")
	if not bad.is_empty(): return bad
	bad = _kitchen(data.get("kitchen",{}))
	if not bad.is_empty(): return bad
	bad = _social(data)
	if not bad.is_empty(): return bad
	bad = _other_systems(data)
	if not bad.is_empty(): return bad
	if data.has("_source_ranch_bundle"):
		var bundle: Dictionary = data._source_ranch_bundle
		if not bundle.get("ranch") is Dictionary or not bundle.get("animals") is Array: return "_source_ranch_bundle"
		bad = _ranch(bundle.ranch,"_source_ranch_bundle.ranch")
		if not bad.is_empty(): return bad
		bad = _animals(bundle.animals,"_source_ranch_bundle.animals")
		if not bad.is_empty(): return bad
	return ""

static func _record_map(value: Variant, spec: Dictionary, path: String) -> String:
	if path in ["fishing.waters","fishing.records"] and _kind(value,PRIMITIVE_MAP) and not value is Dictionary: return ""
	if not value is Dictionary: return path
	for key: Variant in value:
		var bad := _fields(value[key],spec,path + "." + str(key))
		if not bad.is_empty(): return bad
	return ""

static func _other_systems(data: Dictionary) -> String:
	var sections := {
		"economy":{"daily":TYPE_DICTIONARY,"jobs":TYPE_ARRAY,"receipts":TYPE_ARRAY,"ledger":TYPE_ARRAY,"rep":NUMBER,"nextId":NUMBER},
		"environment":{"history":TYPE_ARRAY},
		"forage":{"patches":TYPE_DICTIONARY,"xp":NUMBER,"finds":TYPE_ARRAY,"discovered":TYPE_ARRAY},
		"fishing":{"waters":PRIMITIVE_MAP,"records":PRIMITIVE_MAP,"last":OPTIONAL_OBJECT,"pending":TYPE_DICTIONARY,"traps":TYPE_DICTIONARY,"queue":TYPE_ARRAY,"rng":NUMBER,"nextId":NUMBER,"settled":NUMBER},
		"toolkit":{"tools":TYPE_DICTIONARY},
		"building":{"jobs":TYPE_ARRAY,"layout":TYPE_ARRAY,"levels":TYPE_DICTIONARY,"house":NUMBER,"revision":NUMBER,"nextId":NUMBER},
		"collection":{"entries":TYPE_DICTIONARY,"donated":TYPE_DICTIONARY,"observations":TYPE_DICTIONARY,"featured":TYPE_DICTIONARY,"level":NUMBER},
		"feedback":{"rows":TYPE_ARRAY,"days":TYPE_ARRAY,"prefs":TYPE_DICTIONARY,"next":NUMBER}
	}
	for section: String in sections:
		var bad := _fields(data.get(section,{}),sections[section],section)
		if not bad.is_empty(): return bad
	var maps := [
		["forage","patches",{"lastDay":NUMBER,"readyDay":NUMBER,"pressure":NUMBER}],
		["fishing","waters",{"day":NUMBER,"casts":NUMBER}],
		["fishing","records",{"length":NUMBER,"count":NUMBER,"best":NUMBER,"caught":NUMBER}],
		["toolkit","tools",{"condition":NUMBER,"wear":NUMBER,"durability":NUMBER,"level":NUMBER}],
		["kitchen","equipment",{"level":NUMBER,"clean":NUMBER}],
		["collection","entries",{"first":NUMBER,"best":NUMBER,"acquired":TYPE_BOOL,"researched":TYPE_BOOL}],
		["collection","donated",{"day":NUMBER,"grade":NUMBER}],
		["skills","",{"xp":NUMBER}]
	]
	for entry: Array in maps:
		var value: Variant = data.get(entry[0],{})
		if not String(entry[1]).is_empty(): value = value.get(entry[1],{})
		var bad := _record_map(value,entry[2],String(entry[0])+"."+String(entry[1]))
		if not bad.is_empty(): return bad
	var records := [
		["environment","history",{"day":NUMBER,"kind":TYPE_STRING}],
		["forage","finds",{"day":NUMBER,"qty":NUMBER,"count":NUMBER}],
		["building","jobs",{"level":NUMBER,"readyDay":NUMBER}],
		["building","layout",{"key":NUMBER,"x":NUMBER,"y":NUMBER,"rotation":NUMBER,"level":NUMBER}],
		["economy","jobs",{"day":NUMBER,"readyDay":NUMBER,"progress":NUMBER,"count":NUMBER}],
		["economy","ledger",{"day":NUMBER,"amount":NUMBER,"money":NUMBER}],
		["feedback","rows",{"id":NUMBER,"day":NUMBER,"minute":NUMBER,"priority":NUMBER,"count":NUMBER,"read":TYPE_BOOL}],
		["feedback","days",{"day":NUMBER,"actions":NUMBER,"income":NUMBER,"spent":NUMBER,"items":PRIMITIVE_MAP}],
		["letters","",{"day":NUMBER,"gift":OPTIONAL_OBJECT}]
	]
	for entry: Array in records:
		var value: Variant = data.get(entry[0],[] if String(entry[1]).is_empty() else {})
		if not String(entry[1]).is_empty(): value = value.get(entry[1],[])
		var bad := _records(value,entry[2],String(entry[0])+"."+String(entry[1]))
		if not bad.is_empty(): return bad
	var economy: Dictionary = data.get("economy",{})
	var daily: Variant = economy.get("daily",{})
	var bad := _fields(daily,{"day":NUMBER,"bought":TYPE_DICTIONARY},"economy.daily")
	if not bad.is_empty(): return bad
	bad = _map(daily.get("bought",{}),NUMBER,"economy.daily.bought")
	if not bad.is_empty(): return bad
	bad = _map(data.get("building",{}).get("levels",{}),NUMBER,"building.levels")
	if not bad.is_empty(): return bad
	var last: Variant = data.get("fishing",{}).get("last")
	if last != null:
		bad = _fields(last,{"day":NUMBER,"length":NUMBER,"grade":NUMBER},"fishing.last")
		if not bad.is_empty(): return bad
		if last.has("grade") and not BASE.integer(last.grade,0,3): return "fishing.last.grade"
	var fish_records: Variant = data.get("fishing",{}).get("records",{})
	if fish_records is Dictionary:
		for record: Dictionary in fish_records.values():
			if record.has("grade") and not BASE.integer(record.grade,0,3): return "fishing.records.grade"
	for summary: Dictionary in data.get("feedback",{}).get("days",[]):
		if not summary.get("items",{}) is Dictionary: continue
		bad = _map(summary.get("items",{}),NUMBER,"feedback.days.items")
		if not bad.is_empty(): return bad
	for id: Variant in data.get("collection",{}).get("observations",{}):
		var days: Variant = data.collection.observations[id]
		if not days is Array: return "collection.observations." + str(id)
		for day: Variant in days:
			if not BASE.integer(day,0,100000): return "collection.observations." + str(id)
	for side: String in ["storage","furniture"]:
		for quantity: Variant in data.get(side,{}).values():
			if not BASE.integer(quantity,0,999999): return side
	for key: String in ["player_settings","settings"]:
		bad = _fields(data.get(key,{}),{"zoom":NUMBER,"volume":NUMBER,"music":NUMBER,"ambient":NUMBER,"effects":NUMBER,"textScale":NUMBER,"bindings":TYPE_DICTIONARY,"performance":TYPE_STRING},key)
		if not bad.is_empty(): return bad
	return ""

static func _animals(animals: Array, path: String) -> String:
	var spec := {"care":TYPE_DICTIONARY,"position":TYPE_DICTIONARY,"qualityStock":TYPE_ARRAY,"parents":TYPE_ARRAY,"ready":NUMBER,"age":NUMBER,"generation":NUMBER,"bond":NUMBER,"hunger":NUMBER,"health":NUMBER,"mood":NUMBER,"clean":NUMBER,"stress":NUMBER,"illness":NUMBER,"warning":NUMBER,"progress":NUMBER,"feedQuality":NUMBER,"feathers":NUMBER}
	var bad := _records(animals,spec,path)
	if not bad.is_empty(): return bad
	for index: int in range(animals.size()):
		var row: Dictionary = animals[index]
		var at := "%s[%d]" % [path,index]
		bad = _map(row.get("care",{}),NUMBER,at + ".care")
		if not bad.is_empty(): return bad
		for n: Variant in row.get("qualityStock",[]):
			if not BASE.integer(n,0,999999): return at + ".qualityStock"
		bad = _fields(row.get("position",{}),{"x":NUMBER,"y":NUMBER,"inside":TYPE_DICTIONARY},at + ".position")
		if not bad.is_empty(): return bad
		bad = _fields(row.get("position",{}).get("inside",{}),{"x":NUMBER,"y":NUMBER},at + ".position.inside")
		if not bad.is_empty(): return bad
	return ""

static func _farm(farm: Dictionary) -> String:
	var bad := _fields(farm,{"beds":TYPE_ARRAY,"facilities":TYPE_ARRAY,"stock":TYPE_ARRAY,"water":NUMBER,"threshold":NUMBER},"farm")
	if not bad.is_empty(): return bad
	bad = _records(farm.get("facilities",[]),{"anchor":NUMBER,"durability":NUMBER,"level":NUMBER,"enabled":TYPE_BOOL},"farm.facilities")
	if not bad.is_empty(): return bad
	bad = _records(farm.get("beds",[]),{"companion":OPTIONAL_OBJECT},"farm.beds")
	if not bad.is_empty(): return bad
	bad = _records(farm.get("stock",[]),{"qty":NUMBER,"durability":NUMBER,"count":NUMBER,"level":NUMBER},"farm.stock")
	if not bad.is_empty(): return bad
	for index: int in range(farm.get("beds",[]).size()):
		var bed: Dictionary = farm.beds[index]
		if bed.get("companion") != null:
			bad = _fields(bed.companion,{"growth":NUMBER},"farm.beds.companion")
			if not bad.is_empty(): return bad
	return ""

static func _ranch(ranch: Dictionary, path: String) -> String:
	var bad := _fields(ranch,{"barns":TYPE_DICTIONARY,"stores":TYPE_DICTIONARY,"grass":TYPE_ARRAY,"pet":TYPE_DICTIONARY,"births":TYPE_ARRAY,"rehomed":TYPE_ARRAY,"notices":TYPE_ARRAY,"jobs":TYPE_ARRAY,"nextId":NUMBER},path)
	if not bad.is_empty(): return bad
	if ranch.has("products"):
		if not ranch.products is Array: return path+".products"
		var ids: Dictionary = {}
		for value: Variant in ranch.products:
			if not value is Dictionary: return path+".products"
			for field: String in ["id","animalId","home","item","location"]:
				if not value.get(field) is String: return path+".products."+field
			if ids.has(value.id): return path+".products.duplicate"
			ids[value.id] = true
			if not BASE.integer(value.get("qty"),1,9999) or not BASE.integer(value.get("grade"),0,3) or not BASE.integer(value.get("producedDay"),0,100000): return path+".products.quantity"
			if value.location not in ["animal","nest","ground","box"]: return path+".products.location"
			if not BASE.number(value.get("x"),-100000,100000) or not BASE.number(value.get("y"),-100000,100000): return path+".products.position"
			if value.get("room") != null and not value.room is String: return path+".products.room"

	for key: Variant in ranch.get("barns",{}):
		bad = _fields(ranch.barns[key],{"space":NUMBER,"comfort":NUMBER,"protection":NUMBER,"efficiency":NUMBER,"durability":NUMBER,"clean":NUMBER,"waste":NUMBER,"lastClean":NUMBER},path + ".barns." + str(key))
		if not bad.is_empty(): return bad
	bad = _map(ranch.get("stores",{}),NUMBER,path + ".stores")
	if not bad.is_empty(): return bad
	for n: Variant in ranch.get("grass",[]):
		if not BASE.number(n,0,100): return path + ".grass"
	bad = _fields(ranch.get("pet",{}),{"hunger":NUMBER,"energy":NUMBER,"training":NUMBER,"fed":NUMBER,"trained":NUMBER,"position":TYPE_DICTIONARY},path + ".pet")
	if not bad.is_empty(): return bad
	bad = _fields(ranch.get("pet",{}).get("position",{}),{"x":NUMBER,"y":NUMBER},path + ".pet.position")
	if not bad.is_empty(): return bad
	for field: String in ["births","rehomed","notices","jobs"]:
		bad = _records(ranch.get(field,[]),{"day":NUMBER,"remaining":NUMBER,"total":NUMBER,"fee":NUMBER},path + "." + field)
		if not bad.is_empty(): return bad
	for row: Dictionary in ranch.get("rehomed",[]):
		if row.has("animal"):
			bad = _animals([row.animal],path + ".rehomed.animal")
			if not bad.is_empty(): return bad
	return ""

static func _kitchen(kitchen: Dictionary) -> String:
	var bad := _fields(kitchen,{"jobs":TYPE_ARRAY,"lots":TYPE_DICTIONARY,"mastery":TYPE_DICTIONARY,"equipment":TYPE_DICTIONARY,"experiments":TYPE_ARRAY,"buff":OPTIONAL_OBJECT,"nextId":NUMBER},"kitchen")
	if not bad.is_empty(): return bad
	bad = _records(kitchen.get("jobs",[]),{"id":TYPE_STRING,"key":IDENTIFIER,"qty":NUMBER,"start":NUMBER,"ready":NUMBER,"weatherDelay":NUMBER,"progress":NUMBER,"duration":NUMBER,"remaining":NUMBER,"readyDay":NUMBER,"grade":NUMBER,"amount":NUMBER,"count":NUMBER},"kitchen.jobs")
	if not bad.is_empty(): return bad
	for job: Dictionary in kitchen.get("jobs",[]):
		if job.has("grade") and not BASE.integer(job.grade,0,3): return "kitchen.jobs.grade"
		if job.has("qty") and not BASE.integer(job.qty,0,999999): return "kitchen.jobs.qty"
	for side: String in ["bag","storage"]:
		var lots: Variant = kitchen.get("lots",{}).get(side,{})
		if not lots is Dictionary: return "kitchen.lots." + side
		for item: Variant in lots:
			bad = _records(lots[item],{"qty":NUMBER,"age":NUMBER},"kitchen.lots." + side + "." + str(item))
			if not bad.is_empty(): return bad
			for lot: Dictionary in lots[item]:
				if lot.has("qty") and not BASE.integer(lot.qty,0,999999): return "kitchen.lots.qty"
	return _map(kitchen.get("mastery",{}),NUMBER,"kitchen.mastery")

static func _social(data: Dictionary) -> String:
	for npc: Variant in data.get("relations",{}):
		var relation_bad := _fields(data.relations[npc],{"points":NUMBER,"talked":NUMBER,"gifted":NUMBER,"returnGift":TYPE_BOOL},"relations." + str(npc))
		if not relation_bad.is_empty(): return relation_bad
	for npc: Variant in data.get("npc_stories",{}):
		var bad := _fields(data.npc_stories[npc],{"step":NUMBER,"lastDay":NUMBER,"choices":TYPE_ARRAY},"npc_stories." + str(npc))
		if not bad.is_empty(): return bad
	var marriage: Dictionary = data.get("marriage",{})
	var bad := _fields(marriage,{"day":NUMBER,"weekly":TYPE_DICTIONARY,"memories":TYPE_ARRAY},"marriage")
	if not bad.is_empty(): return bad
	bad = _records(marriage.get("memories",[]),{"day":NUMBER},"marriage.memories")
	if not bad.is_empty(): return bad
	bad = _fields(data.get("pet",{}),{"bond":NUMBER,"patted":NUMBER},"pet")
	if not bad.is_empty(): return bad
	bad = _fields(data.get("interior_state",{}),{"memories":TYPE_DICTIONARY,"chores":TYPE_DICTIONARY},"interior_state")
	if not bad.is_empty(): return bad
	return ""

static func fishing_error(data: Dictionary) -> String:
	var f: Dictionary=data.get("fishing",{})
	if int(f.get("version",1))!=2:return "fishing.version"
	if not BASE.integer(f.get("rng"),1,2147483646) or not BASE.integer(f.get("nextId"),1,1000000000) or not BASE.integer(f.get("settled"),0,int(f.nextId)-1):return "fishing.random"
	if f.get("mode") not in ["relaxed","standard"] or f.get("inputStyle") not in ["hold","toggle"]:return "fishing.options"
	if not f.get("pending",{}) is Dictionary or not f.get("traps",{}) is Dictionary or f.traps.size()>8:return "fishing.containers"
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/systems.json")).fishing
	if not catalog.baits.has(f.get("bait")) or not BASE.integer(f.get("depth"),0,2) or not f.get("tackles",[]) is Array or f.get("tackles",[]).size()>2:return "fishing.loadout"
	var seen_tackles: Array=[]
	for id: Variant in f.get("tackles",[]):
		if not catalog.tackles.has(id) or seen_tackles.has(id):return "fishing.tackles"
		seen_tackles.append(id)
	for id: String in f.get("records",{}):
		var row: Dictionary=f.records[id]
		if not catalog.species.has(id) or not BASE.integer(row.get("count"),0,1000000) or not BASE.number(row.get("best"),0,200) or not BASE.integer(row.get("grade"),0,3) or not row.get("waters") is Array:return "fishing.records"
		for water: Variant in row.waters:
			if not catalog.waters.has(water):return "fishing.records.waters"
		for field: String in ["rod","trap","released"]:
			if not BASE.integer(row.get(field,0),0,int(row.count)):return "fishing.records.count"
	var pending: Dictionary=f.get("pending",{})
	if not pending.is_empty():
		if not pending.get("name") is String or not BASE.integer(pending.get("id"),1,int(f.settled)) or not _fish_product(pending,catalog,int(data.day)):return "fishing.pending"
	var slots: Array=[]
	for at: Dictionary in catalog.trapSlots:slots.append(str(at.id))
	for id: String in f.traps:
		if id not in slots or not f.traps[id] is Dictionary:return "fishing.traps"
		var row: Dictionary=f.traps[id]
		if not BASE.integer(row.get("baitedDay"),-1,int(data.day)) or not BASE.integer(row.get("lastDay"),0,int(data.day)) or not row.get("product") is Dictionary:return "fishing.trap.fields"
		if int(row.baitedDay)>=0 and not catalog.baits.has(row.get("bait")):return "fishing.trap.bait"
		if not row.product.is_empty() and (int(row.baitedDay)>=0 or not _fish_product(row.product,catalog,int(data.day))):return "fishing.trap.product"
	return ""

static func _fish_product(product: Dictionary, catalog: Dictionary, day_value: int) -> bool:
	if not catalog.species.has(product.get("fish")) or not catalog.waters.has(product.get("water")):return false
	var fish: Dictionary=catalog.species[product.fish]
	if not fish.methods.has(product.get("method")) or not fish.waters.has(product.get("water")):return false
	return BASE.integer(product.get("grade"),0,2 if product.get("method")=="trap" else 3) and BASE.number(product.get("length"),0,200) and BASE.integer(product.get("producedDay"),0,day_value)
