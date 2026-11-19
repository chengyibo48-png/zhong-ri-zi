extends RefCounted
## Pure content migration. Validate before applying the returned copy.
static func prepare(value:Dictionary)->Dictionary:
	if int(value.get("version",0)) not in [34,35]:return value
	var result:Dictionary=value.duplicate(true)
	if not result.get("ranch") is Dictionary or not result.ranch.get("barns") is Dictionary:return value
	var initial:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/initial_state.json"))
	for id:String in ["horseStable","alpacaShelter"]:
		if not result.ranch.barns.has(id):result.ranch.barns[id]=initial.ranch.barns[id].duplicate(true)
	for animal:Variant in result.get("animals",[]):
		if animal is Dictionary:preload("res://scripts/animal_species.gd").ensure_animal(animal)
	for row:Variant in result.ranch.get("rehomed",[]):
		if row is Dictionary and row.get("animal") is Dictionary:preload("res://scripts/animal_species.gd").ensure_animal(row.animal)
	result.version=36
	return result
