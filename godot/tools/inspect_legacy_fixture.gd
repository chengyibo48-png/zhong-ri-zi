extends RefCounted
func _legacy_fixture(version: int, world_revision: int, scene: String, x: float, y: float, include_discovered: bool) -> Dictionary:
	var plots: Array = []
	for index in range(24):
		plots.append({"tilled": index < 8, "crop": "cabbage" if index == 0 else null, "growth": 4.0 if index == 0 else 0.0, "watered": index == 0, "soil": 2, "lastGroup": "叶菜" if index == 0 else null, "repeats": 2 if index == 0 else 0})
	var source := {
		"version": version,
		"name": "迁移测试",
		"gender": "女",
		"day": 18,
		"minutes": 720,
		"stamina": 61,
		"money": 4321,
		"scene": scene,
		"player": {"x": x, "y": y, "direction": "left"},
		"seed": "bean",
		"bag": {"cabbage_seed": 7, "rice": 4, "wood": 3},
		"plots": plots,
		"animals": [{"id": "hen", "name": "点点", "ready": 3, "fed": false, "bond": 16}],
		"relations": {"granny": {"points": 42, "talked": 17, "gifted": 16, "returnGift": true}},
		"flags": {"bridge": true, "firstDish": true},
		"upgrades": {"greenhouse": true},
		"stats": {"harvested": 8, "fish": 3, "earned": 980},
		"collected": {"bamboo-1": 4},
		"festivals": ["1-0"],
		"processing": [{"id": "pickles", "qty": 2, "readyDay": 19}],
		"toolUpgrades": {"hoe": true},
		"buffs": {"laborDay": 16},
		"waterReserve": 2,
		"greenhouse": true,
		"animalCare": {"hen-pet": 12},
		"resourcePressure": {"bamboo": {"day": 18, "count": 3}},
		"marketDays": [{"day": 15, "demand": {"rice": 5}}],
		"eventLog": [{"day": 17, "text": "旧版生活记录"}]
	}
	if world_revision > 1:
		source["worldRevision"] = world_revision
	if include_discovered:
		source["discovered"] = ["cabbage_seed", "wildHerb"]
	return source

