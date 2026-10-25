extends RefCounted
## Soil, moisture and nutrition requirements without a scene dependency.
static func profile(crop_id: String, crop: Dictionary) -> Dictionary:
	var wet := crop_id in ["rice", "lotus", "taro"]
	var category := str(crop.get("group", ""))
	var preferred := "wetland" if wet else "sand" if category == "根菜" else "humus" if category == "叶菜" else "loam"
	return {"wet": wet, "preferred": preferred, "low": 55 if wet else 28 if category == "根菜" else 35, "high": 95 if wet else 78, "feed": -2 if category == "豆类" else 6 if category == "果实" else 4, "climber": crop_id in ["bean", "pea", "broadbean", "cucumber", "pumpkin", "wintermelon"]}
