extends RefCounted
## A read-only estimate. Execution still validates every stop and spends per result.
static func describe(state: Node, tasks: Array, animal: bool=false) -> String:
	var origin: Vector2 = state.interior_position if state.current_interior!="" else state.player_position
	var distance := 0.0
	var required: Dictionary = {}
	var capacity := tasks.size()
	var energy := 0
	var field_ids: Dictionary = {}
	var material_limits: Array[int] = []
	for task: Dictionary in tasks:
		var at := origin
		if animal:
			var destination: Dictionary = state.ranch_task_destination(task)
			if not destination.is_empty(): at=Vector2(float(destination.x),float(destination.y))
		else: at=state.farm_plot_position(int(task.get("index",0)))
		distance+=origin.distance_to(at);origin=at
		var action:=str(task.get("action",""))
		energy += 4 if action == "deep" else 3 if action in ["manual","hoe","restore"] else 2
		field_ids[int(task.get("index",0))] = true
		if action=="sow":
			var choices: Dictionary = task.get("arg",{})
			var seed: String=state.seed_variant_id(str(choices.get("crop",state.selected_seed)),str(choices.get("kind",state.farm.get("seedKind","normal"))))
			required[seed]=int(required.get(seed,0))+(2 if str(choices.get("density",state.farm.get("density","balanced")))=="dense" else 1)
		elif action=="bio": required["bioCare"]=int(required.get("bioCare",0))+1
		elif action=="fertilize": required["compost"]=int(required.get("compost",0))+1
		elif action=="treat": required["animalMedicine"]=int(required.get("animalMedicine",0))+1
		elif animal and action=="feed":
			var index: int=state.ranch_animal_index(str(task.get("animalId","")))
			if index>=0:
				var a: Dictionary=state.animals[index]
				var spec: Dictionary=state.system_catalog.ranch.species[str(a.type)]
				var breed: Dictionary=state.system_catalog.ranch.breeds[str(a.breed)]
				var food:=str(state.ranch.get("feed","feed"))
				required[food]=int(required.get(food,0))+preload("res://scripts/ranch_care.gd").needed(state,a,state.day)
	var materials: Array[String]=[]
	for id: String in required:
		var need:=int(required[id]);var available:=int(state.inventory.get(id,0))
		materials.append("%s %d / %d" % [str(state.item_catalog.get(id,{}).get("name",id)),available,need])
		if available<need: material_limits.append(available)
	var seconds:=ceili(distance/maxf(1,state.player_movement_speed()))
	return "%d %s · 体力最多 %d / 当前 %d · 作业约 %d 游戏分钟\n路程直线估计 %d 秒，绕路或进屋另计。%s\n%s取消会保留已完成成果，未执行的项目不扣材料。" % [capacity,"位可安排" if animal else "块可安排" if field_ids.size() == capacity else "项农事可安排（%d 块田）" % field_ids.size(),energy,floori(state.stamina),capacity*5,seconds,"无需材料" if materials.is_empty() else "材料现有 / 所需："+"；".join(materials),"材料不足，执行到不足处会停止。" if not material_limits.is_empty() else ""]
