extends RefCounted
## Read-only explanations, shared by the planner, world prompts and settlement.
const REGROW := {"tomato": 3, "cucumber": 2, "eggplant": 3, "pepper": 3, "okra": 2, "leek": 2}
const GRADES := ["普通", "优质", "上品", "珍品"]

static func harvest(s: Node, plot: Dictionary, crop: String = "", kind: String = "", companion: bool = false) -> Dictionary:
	var id := str(plot.get("crop", "")) if crop.is_empty() else crop
	if not s.crop_catalog.has(id): return {}
	var seed_kind := str(plot.get("seed_kind", "normal")) if kind.is_empty() else kind
	var score := clampf(float(plot.get("condition", 75)) * 0.65 + float(plot.get("health", 100)) * 0.25 + float(plot.get("fertility", 50)) * 0.1 + (4.0 if str(plot.get("soil_type", "loam")) == str(s.crop_profile(id).preferred) else 0.0) - float(plot.get("penalty", 0)) - (0.0 if companion else maxf(0.0, float(plot.get("ripe_days", 0)) - 3.0) * 4.0), 0.0, 100.0)
	var cap := int(s.system_catalog.get("farming", {}).get("kinds", {}).get(seed_kind, {}).get("cap", 2))
	var grade := mini(cap, 3 if score >= 92 else 2 if score >= 78 else 1 if score >= 58 else 0)
	if str(s.skills.get("farming", {}).get("choice", "")) == "care": grade = mini(cap, maxi(1, grade))
	var qty := 1 if companion else maxi(1, (2 if float(plot.get("fertility", 0)) >= 60 else 1) + (1 if str(plot.get("density", "balanced")) == "dense" and float(plot.get("health", 0)) >= 70 else 0) - (1 if float(plot.get("pests", 0)) + float(plot.get("disease", 0)) >= 100 else 0))
	return {"score": score, "grade": grade, "qty": qty, "seed": s.seed_variant_id(id, "heirloom" if float(plot.get("health", 0)) >= 75 and grade >= 2 else seed_kind)}

static func sow_reason(s: Node, index: int, crop: String, kind: String, density: String) -> String:
	if index < 0 or index >= s.plots.size() or not s.crop_catalog.has(crop) or not s.system_catalog.get("farming", {}).get("kinds", {}).has(kind) or density not in ["sparse", "balanced", "dense"]: return "请选择有效田块、种子和株距。"
	var p: Dictionary = s.plots[index]
	if not bool(p.get("tilled", false)) or bool(p.get("removed", false)): return "先开垦或修复这块地。"
	if not str(p.get("crop", "")).is_empty() or not p.get("companion", {}).is_empty(): return "这里已有作物，请先收获。"
	if bool(p.get("fallow", false)): return "这块田正在休耕，先结束休耕再播种。"
	if not s.crop_in_season(crop) and not (kind != "seasonal" and s.farm_facility_coverage(index, "greenhouse")): return "当前非适种季节；普通种与乡传良种可在小暖棚内播种。"
	return ""

static func sow_plan(s: Node, index: int) -> Dictionary:
	var id := str(s.selected_seed)
	var c: Dictionary = s.crop_data(id)
	if c.is_empty() or index < 0 or index >= s.plots.size(): return {}
	var p: Dictionary = s.plots[index]
	var kind := str(s.farm.get("seedKind", "normal"))
	var density := str(s.farm.get("density", "balanced"))
	var rate := float(s.system_catalog.farming.kinds.get(kind, {}).get("rate", 1.0))
	if str(p.get("soil_type", "loam")) == str(s.crop_profile(id).preferred): rate *= 1.08
	rate *= 0.94 if density == "dense" else 1.05 if density == "sparse" else 1.0
	if s.farm_facility_coverage(index, "trellis") and bool(s.crop_profile(id).climber): rate *= 1.15
	var days := ceili(float(s.crop_days(id)) / maxf(0.08, rate))
	var crosses := false
	if not s.farm_facility_coverage(index, "greenhouse"):
		for offset in range(days + 1):
			var season := int(posmod(s.day + offset, 112) / 28)
			if not c.get("seasons", []).any(func(value): return int(value) == season): crosses = true
	var qty := 2 + (1 if density == "dense" else 0)
	var seed: String = s.seed_variant_id(id, kind)
	var cost := int(s.item_catalog.get(seed, {}).get("cost", c.get("cost", 0))) * (2 if density == "dense" else 1)
	return {"days": days, "season_days": 28 - posmod(s.day, 28), "crosses": crosses, "qty": qty, "cost": cost, "net": qty * int(c.get("price", 0)) - cost, "regrow": int(REGROW.get(id, 0)), "reason": sow_reason(s, index, id, kind, density)}

static func advice(s: Node, index: int) -> Array[String]:
	var out: Array[String] = []
	var p: Dictionary = s.plots[index]
	var id := str(p.get("crop", ""))
	if bool(p.get("removed", false)) or not bool(p.get("tilled", false)): return ["先用锄头开垦，水土会保留。"]
	if bool(p.get("fallow", false)): return ["休耕正在恢复地力；结束休耕后再播种。"]
	var profile: Dictionary = s.crop_profile(id) if not id.is_empty() else {"low": 35, "high": 85}
	if not id.is_empty() and float(p.growth) >= s.crop_days(id): out.append("可以采收；成熟前三天品质最稳，晚收仍有收成。")
	if float(p.get("moisture", 45)) < float(profile.low) and not id.is_empty(): out.append("根部缺水，先补一壶；下雨和喷灌也能补水。")
	elif float(p.get("moisture", 45)) > float(profile.high): out.append("根部偏涝，疏沟排水，暂缓再浇。")
	if float(p.get("disease", 0)) >= 15: out.append("叶斑需要草本护苗，人工捉虫不能治病。")
	if float(p.get("pests", 0)) >= 15: out.append("发现虫害，可人工捉虫或使用草本护苗液。")
	if float(p.get("health", 100)) < 40: out.append("植株仍可救回：先调水分，再处理病虫。")
	if float(p.get("weeds", 0)) > 35: out.append("拔草能减少争肥，不必天天清理。")
	if float(p.get("fertility", 100)) < 40: out.append("肥力偏低，可施堆肥、轮作豆科或休耕。")
	if not id.is_empty() and not s.crop_in_season(id) and not s.farm_facility_coverage(index, "greenhouse"): out.append("当前非适季，露地会减速；暖棚可延季。")
	if int(p.get("regrow_days", 0)) > 0: out.append("采后保留根株继续结果；成熟时选择留种可结束本茬、腾地轮作。")
	if out.is_empty(): out.append("长势安稳，可以放心去村里走走。")
	return out

static func overview(s: Node) -> String:
	return "今日田况  成熟 %d · 缺水 %d · 风险 %d\n今日%s · 明日%s · 距换季 %d 天" % [s.farm_filtered_indices("ready").size(), s.farm_filtered_indices("dry").size(), s.farm_filtered_indices("risk").size(), s.weather_for(s.day), s.weather_for(s.day + 1), 28 - posmod(s.day, 28)]
