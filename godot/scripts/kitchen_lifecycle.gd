extends RefCounted
## Advance freshness in place, after GameState reconciles stock and lots.
static func age_lots(all_lots: Dictionary, cold: bool, mean_temperature: int) -> Dictionary:
	for side: String in ["bag", "storage"]:
		var side_lots: Dictionary = all_lots.get(side,{})
		var factor := 0.25 if side == "storage" and cold else (0.5 if side == "storage" else 1.0) * (1.25 if mean_temperature >= 33 else 0.75 if mean_temperature <= 5 else 1.0)
		for item_id: Variant in side_lots:
			for lot: Dictionary in side_lots[item_id]: lot.age = minf(3650.0,float(lot.get("age",0.0))+factor)
		all_lots[side] = side_lots
	return all_lots
