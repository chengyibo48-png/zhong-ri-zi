extends RefCounted
## This ledger owns every unclaimed output. Animal counters and world pickups are views.
static func initialize(s: Node) -> void:
	if not s.ranch.has("products"):
		s.ranch.products = []
		for a: Dictionary in s.animals:
			for grade: int in range(4):
				var count := int(a.get("qualityStock", [0,0,0,0])[grade])
				if count > 0: produce(s,a,str(a.product),count,grade,s.day)
			if int(a.get("feathers",0)) > 0: produce(s,a,"feather",int(a.feathers),0,s.day)
	for row: Dictionary in s.ranch.get("products",[]):
		for field: String in ["qty","grade","producedDay"]: row[field] = int(row[field])
	s.ranch.productNext = int(s.ranch.get("productNext",1))
	sync(s)

static func produce(s: Node, a: Dictionary, item: String, qty: int, grade: int, produced_day: int, ground: bool = false) -> void:
	if qty <= 0: return
	var spec: Dictionary = s.system_catalog.ranch.species[str(a.type)]
	var p: Dictionary = a.position
	var home := str(spec.home)
	var place := "ground" if ground or item == "manure" else str(spec.get("harvestLocation","animal"))
	var room: Variant = p.get("room") if ground else s.system_catalog.ranch.barns[home].house
	var at: Dictionary = p.get("inside",{}) if ground and room != null else p
	var x := float(at.get("x",480)) if ground else 250.0 + posmod(s.ranch_animal_index(str(a.id)),4)*42.0
	var y := float(at.get("y",490)) if ground else 420.0
	if place == "animal":
		room = p.get("room")
		at = p.get("inside",{}) if room != null else p
		x = float(at.get("x",480)); y = float(at.get("y",490))
	var next := int(s.ranch.get("productNext",1))
	s.ranch.productNext = next+1
	s.ranch.products.append({"id":"produce-%d" % next,"animalId":str(a.id),"home":home,"item":item,"qty":qty,"grade":clampi(grade,0,3),"producedDay":produced_day,"location":place,"room":room,"x":x,"y":y})

static func sync(s: Node) -> void:
	for a: Dictionary in s.animals:
		a.ready = 0; a.feathers = 0; a.qualityStock = [0,0,0,0]
	for row: Dictionary in s.ranch.get("products",[]):
		if str(row.location) == "box": continue
		var index: int = s.ranch_animal_index(str(row.animalId))
		if index < 0: continue
		var a: Dictionary = s.animals[index]
		if str(row.item) == str(a.product):
			a.ready += int(row.qty)
			a.qualityStock[int(row.grade)] += int(row.qty)
		elif str(row.item) == "feather": a.feathers += int(row.qty)

static func box_count(s: Node, home: String) -> int:
	var count := 0
	for row: Dictionary in s.ranch.get("products",[]):
		if str(row.home) == home and str(row.location) == "box": count += int(row.qty)
	return count

static func auto_collect(s: Node, home: String) -> void:
	var barn: Dictionary = s.ranch.barns[home]
	var capacity := int(s.system_catalog.ranch.barns[home].get("boxCapacity",48))
	var count := box_count(s,home)
	var blocked := false
	for row: Dictionary in s.ranch.get("products",[]):
		if str(row.home) != home or str(row.location) == "box": continue
		if count+int(row.qty) > capacity:
			blocked = true
			barn.collectStatus = "箱满 · 产物留在原处"
			continue
		row.location = "box"; row.room = s.system_catalog.ranch.barns[home].house
		row.x = 730; row.y = 492
		count += int(row.qty)
	if not blocked: barn.collectStatus = "运行 · 存入本舍收集箱"
	sync(s)

static func take(s: Node, kind: String, identity: String) -> int:
	var selected: Array = []
	for row: Dictionary in s.ranch.get("products",[]):
		if kind == "box" and str(row.home) == identity and str(row.location) == "box" or kind == "product" and str(row.id) == identity or kind == "animal" and str(row.animalId) == identity and str(row.location) != "box": selected.append(row)
	var count := 0
	for row: Dictionary in selected:
		var item := str(row.item)
		var qty := int(row.qty)
		s._reconcile_kitchen_lots()
		s._add_inventory_count(item,qty)
		if int(row.grade) > 0:
			var grades: Array = s.quality.get(item,[0,0,0])
			grades[int(row.grade)-1] += qty; s.quality[item] = grades
		if s._is_food(item):
			var lots: Dictionary = s.kitchen.get("lots",{"bag":{},"storage":{}})
			var bag: Dictionary = lots.get("bag",{})
			var rows: Array = bag.get(item,[])
			rows.append({"qty":qty,"age":maxf(0.0,float(s.day-int(row.producedDay))),"producedDay":int(row.producedDay),"grade":int(row.grade)})
			bag[item] = rows; lots.bag = bag; s.kitchen.lots = lots
		s.ranch.collection[item] = maxi(int(s.ranch.collection.get(item,0)),int(row.grade)+1)
		var discovered: Array = s.legacy_systems.get("discovered",[])
		if item not in discovered: discovered.append(item)
		s.legacy_systems.discovered = discovered
		s.ranch.products.erase(row); count += qty
	sync(s)
	if count > 0:
		s.quest_event("ranchCollect")
		s._museum_sync()
	return count

static func points(s: Node, room: String) -> Array:
	var result: Array = []
	if room=="":
		var corner:Dictionary=s.system_catalog.ranch.compostCorner
		result.append({"kind":"animals","id":"ranch-compost-corner","x":float(corner.x),"y":float(corner.y),"name":"猪圈旁堆肥加工角","ranchPage":3,"recipe":"compost","ready":true})
	for home: String in s.system_catalog.ranch.barns:
		var spec: Dictionary = s.system_catalog.ranch.barns[home]
		if room != str(spec.house) or not bool(s.ranch.barns[home].built): continue
		result.append({"kind":"ranch-box","id":home,"x":730,"y":492,"name":"本舍收集箱 · %d 份" % box_count(s,home),"ready":box_count(s,home)>0})
		result.append({"kind":"ranch-trough","id":home,"x":250,"y":492,"name":"添满料槽","ready":true})
	for row: Dictionary in s.ranch.get("products",[]):
		var target_room := "" if row.get("room") == null else str(row.room)
		if target_room != room or str(row.location) not in ["nest","ground"]: continue
		result.append({"kind":"ranch-product","id":str(row.id),"x":float(row.x),"y":float(row.y),"name":str(s.item_catalog.get(str(row.item),{}).get("name",row.item))+" ×"+str(row.qty),"ready":true})
	return result

static func collect_near(s: Node, a: Dictionary) -> int:
	var count := 0
	var player: Vector2 = s.player_position if s.current_interior == "" else s.interior_position
	for row: Dictionary in s.ranch.get("products",[]).duplicate():
		if str(row.animalId) != str(a.id) or str(row.location) == "box": continue
		if str(row.location) in ["nest","ground"]:
			var room := "" if row.get("room") == null else str(row.room)
			if room != s.current_interior or player.distance_to(Vector2(float(row.x),float(row.y)))>70: continue
		count += take(s,"product",str(row.id))
	return count

static func follow_animals(s: Node) -> void:
	var by_id: Dictionary = {}
	for a: Dictionary in s.animals: by_id[str(a.id)]=a
	for row: Dictionary in s.ranch.get("products",[]):
		if str(row.location)!="animal" or not by_id.has(str(row.animalId)):continue
		var p: Dictionary=by_id[str(row.animalId)].position
		var room: Variant=p.get("room")
		var at: Dictionary=p.get("inside",{}) if room!=null else p
		row.room=room;row.x=float(at.get("x",480));row.y=float(at.get("y",490))
