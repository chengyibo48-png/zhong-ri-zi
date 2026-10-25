extends RefCounted
## A single read model for both the portable item guide and the discovery book.
const FISH=preload("res://scripts/fishing_rules.gd")
static var _pictures: Dictionary={}
static var _silhouettes: Dictionary={}

static func needs(s: Node, ingredients: Dictionary) -> String:
	var values: Array[String]=[]
	for id: String in ingredients:values.append(str(s.item_catalog.get(id,{}).get("name",id))+" ×"+str(int(ingredients[id])))
	return "、".join(values)

static func state(s: Node, key: String) -> Dictionary:
	return s.collection.get("entries",{}).get(key if key.contains(":") else "item:"+key,{})

static func seasons(indices: Array) -> String:
	var names: Array[String]=[]
	for index in indices:names.append(["春","夏","秋","冬"][int(index)])
	return "、".join(names)

static func hours(intervals: Array) -> String:
	var names: Array[String]=[]
	for row: Array in intervals:names.append("%02d:%02d—%02d:%02d" % [int(row[0])/60,int(row[0])%60,int(row[1])/60,int(row[1])%60])
	return "、".join(names)

static func describe(s: Node, key: String) -> Dictionary:
	var entry: Dictionary=s.museum_entries.get(key,{})
	if entry.is_empty():return {}
	var id:=str(entry.id)
	var known:=not state(s,key).is_empty()
	var result: Dictionary={"title":str(entry.name) if known else "尚待发现","source":str(entry.get("hint","")),"detail":"","uses":[],"links":[],"records":"","available":true,"seasonal":true,"reason":"","target":{}}
	var type:=str(entry.type)
	if type=="item":
		var item: Dictionary=s.item_catalog.get(id,{})
		var metadata: Dictionary=s.inventory_metadata.get(id,{})
		result.source=str(metadata.get("sources",entry.get("hint","")))
		result.uses=metadata.get("uses",[]).duplicate()
		result.detail="售价参考：%d 金币" % int(item.get("price",0))
		var crop: Dictionary=s.crop_catalog.get(id,{})
		if not crop.is_empty():
			result.source="种子互助屋购种 · "+seasons(crop.get("seasons",[]))+"季种植"
			result.detail+="\n生长 %d 天 · 种子：%s · %s" % [int(crop.days),str(s.item_catalog.get(str(crop.seed),{}).get("name",crop.seed)),str(crop.get("group",""))]
			result.seasonal=crop.get("seasons",[]).any(func(value: Variant):return int(value)==s.season_index());result.available=result.seasonal
			if not result.available:result.reason="等待适种季节："+seasons(crop.get("seasons",[]))
			result.target=_house(s,"seed")
			result.links.append("item:"+str(crop.seed))
		for recipe: Dictionary in s.content.get("recipes",[]):
			if str(recipe.id)==id:
				result.source=str(recipe.get("station","厨房"))+"制作 · "+_recipe_source(s,recipe)
				result.detail+="\n食材："+needs(s,recipe.get("ingredients",{}))
				for ingredient: String in recipe.get("ingredients",{}):result.links.append("item:"+ingredient)
				result.target=_house(s,"kitchen")
				result.available=s.known_recipes.has(id) and s._kitchen_has(recipe.get("ingredients",{}),1) and s.kitchen_station_available(s.kitchen_station_for_recipe(id))
				if not result.available:result.reason="先学习菜谱、备齐食材并启用对应工位。"
			if recipe.get("ingredients",{}).has(id):result.links.append("item:"+str(recipe.id))
		for recipe: Dictionary in s.system_catalog.kitchen.get("processing",[]):
			if str(recipe.get("out",recipe.id))==id:
				result.available=s._kitchen_has(recipe.needs,1) and s.kitchen_station_available(str(recipe.stationId))
				result.source="加工 · "+str(s.system_catalog.kitchen.stations.get(str(recipe.stationId),{}).get("name",recipe.stationId))
				result.detail+="\n"+str(recipe.name)+"："+needs(s,recipe.needs)+" → ×"+str(int(recipe.get("qty",1)))
				result.target=_house(s,"kitchen")
				for ingredient: String in recipe.needs:result.links.append("item:"+ingredient)
			if recipe.get("needs",{}).has(id):result.links.append("item:"+str(recipe.get("out",recipe.id)))
		for recipe_id: String in s.system_catalog.ranch.get("recipes",{}):
			var recipe: Dictionary=s.system_catalog.ranch.recipes[recipe_id]
			if str(recipe.get("out",recipe_id))==id:
				result.source="牧场服务区加工 · "+str(recipe.get("name",item.get("name",id)))
				result.detail+="\n材料："+needs(s,recipe.get("needs",{}))
				for ingredient: String in recipe.get("needs",{}):result.links.append("item:"+ingredient)
				result.available=s._kitchen_has(recipe.get("needs",{}),1)
				result.target=_house(s,"kitchen") if recipe_id in ["cream","yogurt"] else s.ranch_task_destination({"barnId":"cattle","action":"craft","arg":recipe_id})
		if s.system_catalog.fishing.crafts.has(id):
			var craft: Dictionary=s.system_catalog.fishing.crafts[id]
			result.available=s._kitchen_has(craft.needs,1)
			if not result.available:result.reason="先备齐制作材料。"
			result.source="水畔手记制作 · 合作社购买"
			result.detail+="\n材料："+needs(s,craft.needs)+" → ×"+str(int(craft.qty))
			for ingredient: String in craft.needs:result.links.append("item:"+ingredient)
			result.target=_house(s,"workshop")
		if s.system_catalog.fishing.tackles.has(id):result.detail+="\n效果："+str(s.system_catalog.fishing.tackles[id].tip)
		if s.system_catalog.fishing.species.has(id):_fish(s,id,result,known)
		elif result.target.is_empty():result.target=_item_target(s,id)
	elif type=="animal":
		var animal: Dictionary=s.system_catalog.ranch.species.get(id,{})
		var barn: Dictionary=s.system_catalog.ranch.barns.get(str(animal.get("home","")),{})
		result.available=s._ranch_space_for(id)
		if not result.available:result.reason="对应畜舍尚未建成，或床位已占用／预留。"
		result.source=str(barn.get("name","牧场畜舍"))+" · 有空床位可购买入住"
		result.detail="成年 %d 天 · 饲料 %d 份 · 基础生产周期 %d 天\n产物：%s · %s\n长期亲近、当日心情与健康分别影响生活状态。" % [int(animal.get("adult",0)),int(animal.get("feed",animal.get("feedUnits",1))),int(animal.get("cycle",1)),str(s.item_catalog.get(str(animal.get("product","")),{}).get("name",animal.get("product",""))),str(animal.get("harvestVerb","收取"))]
		result.detail+="\n饮食："+"、".join(animal.get("diet",[]).map(func(food: Variant):return str(s.item_catalog.get(str(food),{}).get("name",food))))
		result.detail+="\n产出条件："+("成年母畜" if bool(animal.get("femaleOnly",false)) else "成年伙伴")
		result.links.append("item:"+str(animal.get("product","")))
		result.target=s.house_data(str(barn.get("house",""))).get("door",{}).duplicate(true)
		if not result.target.is_empty():result.target.name=str(barn.get("name","牧场"))
	elif type=="npc":
		for person: Dictionary in s.npc_catalog:
			if str(person.id)==id:
				result.source=str(person.get("role","乡亲"))+" · 面对面交谈，逐章了解故事"
				if known:
					var profile: Dictionary=s.system_catalog.get("npc",{}).get("profiles",{}).get(id,{})
					var relation: Dictionary=s.relations.get(id,{})
					var researched:=bool(state(s,key).get("researched",false))
					result.detail=str(person.get("role","乡亲"))+" · %d 岁" % int(person.get("age",0))
					if not str(profile.get("trait","")).is_empty():result.detail+="\n性格："+str(profile.trait)
					result.detail+="\n初识："+str(person.get("greeting",""))
					if researched:result.detail+="\n\n身世与家人："+str(person.get("family",person.get("warm","")))
					else:result.detail+="\n\n听完一章个人故事后，展开身世与家庭记录。"
					if int(relation.get("points",0))>=15 and person.has("birthday"):
						var birthday:=int(person.birthday);result.detail+="\n生日：%s %d 日" % [["春","夏","秋","冬"][int(birthday/28)%4],birthday%28+1]
					if researched or int(relation.get("points",0))>=20:
						var likes: Array[String]=[]
						for item: String in person.get("likes",[]):likes.append(str(s.item_catalog.get(item,{}).get("name",item)));result.links.append("item:"+item)
						if not likes.is_empty():result.detail+="\n喜欢的心意："+"、".join(likes)
					result.records="已听故事：%d 章 · 共同经历可在邻里簿回看。" % int(s.npc_stories.get(id,{}).get("step",0))
				result.target=s.atlas_npc_target(person)
	elif type=="archive":
		for archive: Dictionary in s.content.get("archives",[]):
			if str(archive.id)==id:
				result.source=str(archive.source);result.detail=str(archive.text) if known else "沿村庄旧物与乡亲故事寻找线索。"
				for npc: Dictionary in s.npc_catalog:
					if str(archive.source).contains(str(npc.name)):result.target=s.atlas_npc_target(npc);break
				if result.target.is_empty():result.target=_house(s,"禾溪村史馆")
	elif type=="region":
		for region: Dictionary in s.atlas_catalog.get("regions",[]):
			if str(region.get("region",region.get("id","")))==id:result.target=region.duplicate(true);result.source="沿村道走访 · "+str(region.get("name",entry.name));result.detail=str(region.get("detail",region.get("story","")))
	elif type=="festival":
		result.source=["春","夏","秋","冬"][clampi(int(id),0,3)]+"季村庄节庆 · 查看当季日历"
		result.seasonal=s.season_index()==int(id);result.available=result.seasonal
		result.detail="参与当季节庆后留下记录，再去村史馆整理见闻。"
		result.target=_house(s,"合作社")
	elif type=="pet":result.source="自家小院 · 伙伴相处";result.detail="每天陪伴、照料，亲近达到 15 后补齐记录。";result.target=_house(s,"home")
	elif type=="wild":
		result.source=str(entry.get("hint",""))+" · 不同日期观察两次"
		for wild: Dictionary in s.system_catalog.museum.get("wildlife",[]):
			if str(wild.id)==id:
				result.target=wild.duplicate(true)
				result.detail=str(wild.get("text","")) if known else ""
				result.records="不同日期观察：%d / 2" % s.collection.get("observations",{}).get(id,[]).size()
				result.available=preload("res://scripts/life_presentation.gd").wildlife_available(id,s.season_index(),s.minutes,s.weather_profile())
				if not result.available:result.reason=str(wild.get("tip","等待合适的观察时机。"))
	return result

static func _fish(s: Node, id: String, result: Dictionary, known: bool) -> void:
	var fish: Dictionary=s.system_catalog.fishing.species[id]
	var waters: Array[String]=[]
	for water: String in fish.waters:waters.append(str(s.system_catalog.fishing.waters[water].name))
	result.source="、".join(waters)+" · "+seasons(fish.seasons)+"季 · "+("笼捕" if fish.methods==["trap"] else "垂钓／笼捕" if fish.methods.size()>1 else "垂钓")
	result.seasonal=fish.seasons.any(func(value: Variant):return int(value)==s.season_index())
	result.available=false
	for water: String in fish.waters:
		for method: String in fish.methods:
			if FISH.available(fish,water,s.season_index(),s.weather_for(s.day),s.minutes,method):result.available=true
	result.reason="" if result.available else "等待季节："+seasons(fish.seasons) if not result.seasonal else "等待时段："+hours(fish.times)+( " · 天气："+"、".join(fish.weather) if not fish.weather.is_empty() else "")
	var best:=INF
	for at: Dictionary in s.system_catalog.fishing.spots:
		if not fish.waters.has(str(at.water)):continue
		var distance: float=s.player_position.distance_to(Vector2(float(at.x),float(at.y)))
		if distance<best:best=distance;result.target=at.duplicate(true);result.target.kind="walk";result.target.name=str(s.system_catalog.fishing.waters[str(at.water)].name)
	var record: Dictionary=s.fishing.records.get(id,{})
	result.records="亲自捕获 %d · 垂钓 %d · 收笼 %d · 放流 %d\n最大 %.1f 厘米 · 最高%s" % [int(record.get("count",0)),int(record.get("rod",0)),int(record.get("trap",0)),int(record.get("released",0)),float(record.get("best",0)),["普通","优质","上品","珍品"][clampi(int(record.get("grade",0)),0,3)]]
	if float(record.get("manualBest",0))>0:result.records+="\n手动最佳稳定率：%.1f%%" % (float(record.manualBest)*100.0)
	if known:
		var bait_names: Array[String]=[]
		for bait: Dictionary in s.system_catalog.fishing.baits.values():
			if bait.get("targets",[]).has(id):bait_names.append(str(bait.name))
		result.detail+="\n出没："+hours(fish.times)+(" · 天气："+"、".join(fish.weather) if not fish.weather.is_empty() else " · 各种天气")+"\n行为："+str(fish.behavior)+" · 体长 %.1f～%.1f 厘米" % [float(fish.sizeMin),float(fish.sizeMax)]+"\n偏好饵料："+("、".join(bait_names) if not bait_names.is_empty() else "常规饵料")
		result.detail+="\n"+str(fish.uses)

static func _recipe_source(s: Node, recipe: Dictionary) -> String:
	var source:=str(recipe.get("source","known"))
	if source=="known":return "家常基础菜谱"
	if source=="market":return "集市学习菜谱"
	for npc: Dictionary in s.npc_catalog:
		if str(npc.id)==source:return "向"+str(npc.name)+"学习"
	return source
static func _house(s: Node, term: String) -> Dictionary:
	var aliases: Array={"seed":["种子互助屋","种子","互助","合作社"],"kitchen":["禾溪小灶","食堂"],"workshop":["农具间","竹木工坊"],"market":["许婶杂货","合作社"],"home":["爷爷的老屋"]}.get(term,[term])
	for alias: Variant in aliases:
		for house: Dictionary in s.world_village.get("houses",[]):
			if str(house.get("name","")).contains(str(alias)):
				var target: Dictionary=house.get("door",{}).duplicate(true);target.name=str(house.name);target.id=str(house.id);return target
	return {}
static func _item_target(s: Node, id: String) -> Dictionary:
	for at: Dictionary in s.atlas_catalog.get("foragePoints",[]):
		if str(at.get("item",""))==id:return at.duplicate(true)
	for crop: Dictionary in s.crop_catalog.values():
		if str(crop.get("seed",""))==id:return _house(s,"seed")
	for animal: Dictionary in s.system_catalog.ranch.species.values():
		if str(animal.get("product",""))==id:return s.house_data(str(s.system_catalog.ranch.barns[str(animal.home)].house)).get("door",{}).duplicate(true)
	return _house(s,"market")

static func matches(s: Node, key: String, filter: int) -> bool:
	if filter==0:return true
	var row:=state(s,key)
	if filter==1:return not bool(row.get("researched",false))
	var description:=describe(s,key)
	if filter==2:return bool(description.get("seasonal",true))
	if filter==3:return bool(description.get("available",true))
	return not row.is_empty() and not bool(row.get("researched",false)) and s.museum_research_reason(key)==""

static func picture(s: Node, key: String, silhouette: bool=false) -> Texture2D:
	if silhouette and _silhouettes.has(key):return _silhouettes[key]
	var entry: Dictionary=s.museum_entries.get(key,{})
	var texture: Texture2D
	if _pictures.has(key):texture=_pictures[key]
	else:
		var type:=str(entry.get("type",""));var id:=str(entry.get("id",""))
		if type in ["item","archive"]:texture=preload("res://scripts/item_art.gd").texture_for(id,"items" if type=="item" else "archives")
		elif type in ["animal","pet","wild"]:
			var art_key: String=("animals/" if type=="animal" else "pets/" if type=="pet" else "wildlife/")+id
			var spec: Dictionary=preload("res://scripts/world_art.gd").entries().get(art_key,{})
			var sheet: Texture2D=preload("res://scripts/character_art.gd").texture(str(spec.get("path","res://art/world/"+art_key+".png")))
			if sheet!=null:
				var atlas:=AtlasTexture.new();atlas.atlas=sheet;var frame: Array=spec.get("frameSize",[sheet.get_width(),sheet.get_height()]);atlas.region=Rect2(0,0,float(frame[0]),float(frame[1]));texture=atlas
		elif type=="npc":
			var actor: Dictionary=preload("res://scripts/character_art.gd").data().get("actors",{}).get(id,{})
			var clip: Dictionary=actor.get("clips",{}).get("idle",{})
			var sheet: Texture2D=preload("res://scripts/character_art.gd").texture(str(clip.get("path","")))
			if sheet!=null:
				var atlas:=AtlasTexture.new();atlas.atlas=sheet;var frame: Array=clip.get("frameSize",[128,128]);atlas.region=Rect2(0,0,float(frame[0]),float(frame[1]));texture=atlas
		elif type=="region":
			for region: Dictionary in s.atlas_catalog.get("regions",[]):
				if str(region.get("region",region.get("id","")))==id:
					for house: Dictionary in s.world_village.get("houses",[]):
						if str(house.get("region",""))==id:
							var spec: Dictionary=preload("res://scripts/world_art.gd").entries().get("buildings/"+str(house.id),{})
							texture=preload("res://scripts/character_art.gd").texture(str(spec.get("path","")));break
		elif type=="festival":texture=preload("res://scripts/item_art.gd").texture_for(["flowerbed","lantern","teaTable","pot"][clampi(int(id),0,3)],"furniture")
		if texture!=null:_pictures[key]=texture
	if silhouette and texture!=null:
		var image:=texture.get_image()
		var ratio:=minf(1.0,128.0/maxf(image.get_width(),image.get_height()))
		if ratio<1.0:image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel:=image.get_pixel(x,y);image.set_pixel(x,y,Color(0.28,0.33,0.27,pixel.a*0.65))
		var result:=ImageTexture.create_from_image(image);_silhouettes[key]=result;return result
	return texture

static func source_target(s: Node, key: String) -> Dictionary:
	var info:=describe(s,key)
	var target: Dictionary=info.get("target",{}).duplicate(true)
	if target.is_empty() or not target.has("x") or not target.has("y"):return {}
	var nav: RefCounted=s.npc_movement.navigation
	nav.refresh(s)
	var x:=float(target.x);var y:=float(target.y)
	var candidates: Array[Vector2]=[Vector2(x,y)]
	for radius: float in [24.0,48.0,72.0,96.0]:
		for index: int in range(8):candidates.append(Vector2(x,y)+Vector2.from_angle(index*TAU/8)*radius)
	for at: Vector2 in candidates:
		if nav.blocked(s,"",at.x,at.y):continue
		var point: Dictionary={"id":null,"kind":"walk","name":target.get("name",info.title),"x":at.x,"y":at.y}
		var route: Dictionary=s.atlas_preview(point)
		if bool(route.get("reachable",false)):return point
	return {}
