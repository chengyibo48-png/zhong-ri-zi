extends RefCounted
## Content-driven species capabilities. No rendering or settlement side effects.
static var profiles:Dictionary={}
static func profile(type_id:String)->Dictionary:
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/animal_profiles_v2.json"))
	return profiles.get(type_id,{})
static func bird(s:Node,type_id:String)->bool:return str(s.system_catalog.ranch.species.get(type_id,{}).get("family","mammal"))=="bird"
static func egg(s:Node,type_id:String)->String:return str(s.system_catalog.ranch.species.get(type_id,{}).get("eggItem",""))
static func fertile(id:String)->bool:return id in ["fertileHenEgg","fertileDuckEgg","fertileGooseEgg"]
static func produces(s:Node,type_id:String)->bool:return bool(s.system_catalog.ranch.species.get(type_id,{}).get("productionEnabled",true))
static func breeds(s:Node,type_id:String)->Array:return s.system_catalog.ranch.species.get(type_id,{}).get("allowedBreeds",["local","hardy","productive"])
static func sheltered(s:Node,type_id:String)->bool:
	var spec:Dictionary=s.system_catalog.ranch.species.get(type_id,{})
	return str(s.system_catalog.ranch.barns.get(str(spec.get("home","")),{}).get("residence","barn"))=="shelter"
static func home(s:Node,type_id:String)->Dictionary:
	var spec:Dictionary=s.system_catalog.ranch.species.get(type_id,{});var barn:Dictionary=s.system_catalog.ranch.barns.get(str(spec.get("home","")),{})
	if str(barn.get("residence","barn"))=="shelter":
		var meadow:Script=load("res://scripts/ranch_meadow.gd");var index:int=int(barn.pen);var at:Vector2=meadow.pen(index).position+Vector2(300,125)
		return {"room":"ranch-meadow","pen":index,"bed":at,"feed":meadow.feeder(index)+Vector2(0,30),"water":meadow.water(index)+Vector2(0,29),"home":str(spec.home),"shelter":true}
	return {"room":str(barn.get("house","")),"bed":Vector2(480,510),"feed":Vector2(250,522),"water":Vector2(250,522),"home":str(spec.get("home","")),"shelter":false}
static func appearance(animal:Dictionary)->Dictionary:
	return {"version":2,"coat":str(animal.get("breed","local")),"marking":posmod(str(animal.get("id","pet")).hash(),3)}
static func ensure_animal(animal:Dictionary)->void:
	if not animal.has("appearance"):animal.appearance=appearance(animal)
static func appearance_error(animal:Dictionary)->String:
	if not animal.has("appearance"):return ""
	var value:Variant=animal.appearance
	if not value is Dictionary or value.get("version")!=2 or value.get("coat") not in ["local","hardy","productive"] or not preload("res://scripts/source_save_validation.gd").integer(value.get("marking"),0,2):return "动物外观记录无效。"
	return ""
