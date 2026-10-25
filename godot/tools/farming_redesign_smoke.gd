extends SceneTree
const INFO := preload("res://scripts/farm_insights.gd")
const FILES := preload("res://tools/smoke_files.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ",label)
	else: failed += 1; push_error(label)
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	var s = root.get_node("GameState")
	s.set_process(false)
	s.day = 28
	s.farm.facilities = []
	s.farm.autoSeed = true
	s.farm.seedKind = "normal"
	s.farm.density = "balanced"
	s.upgrades.irrigation = false
	s.skills.farming.choice = ""
	s.stamina = 100
	s.inventory.tomatoSeed = 20
	for i in s.plots.size(): s.plots[i] = s._new_plot()
	s.plots[0].tilled = true
	check(s._farm_plot_action_single(0,"seed",{"crop":"tomato","kind":"normal","density":"balanced"}),"新播番茄成功")
	check(s.plots[0].regrow_days == 3 and s.plots[0].harvest_count == 0,"新播记录再生周期")
	s.plots[0].growth = s.crop_days("tomato")
	s.plots[0].condition = 100
	s.plots[0].health = 100
	var seeds: int = s.inventory.tomatoSeed
	var preview: Dictionary = INFO.harvest(s,s.plots[0])
	var before: int = s.inventory.get("tomato",0)
	s._harvest_plot(0)
	check(s.inventory.tomato-before == int(preview.qty),"真实收成与预览数量相同")
	check(s.plots[0].crop == "tomato" and s.plots[0].growth == 2,"采后保留根株并进入再生阶段")
	check(s.plots[0].harvest_count == 1 and s.inventory.tomatoSeed == seeds+1,"首收自动留一份种子")
	var repeats: int = s.plots[0].repeats
	check(not s._farm_plot_action_single(0,"hand"),"不能重复收取尚未再生的作物")
	s.plots[0].growth = s.crop_days("tomato")
	s._harvest_plot(0)
	check(s.inventory.tomatoSeed == seeds+1 and s.plots[0].repeats == repeats,"多次采摘不刷种子也不误算轮作")
	check(s.plots[0].harvest_count == 2,"再生采摘次数递增")
	s.plots[0].growth = s.crop_days("tomato")
	s.plots[0].companion = {"crop":"bean","growth":2.25,"kind":"heirloom","condition":91.5,"ticks":3,"ripe_days":0}
	s.stamina = 100
	check(s.farm_special_action(0,"seedSave"),"成熟再生植株可留种并腾地")
	check(s.plots[0].crop == "bean" and s.plots[0].growth == 2.25 and s.plots[0].condition == 91.5,"主作物留种后套种接替并保留自身长势")
	check(s.plots[0].regrow_days == 0 and s.plots[0].harvest_count == 0,"接替不会继承主作物的再生记录")
	# Existing crops retain their original harvest contract.
	s.plots[1] = s._new_plot()
	s.plots[1].crop = "tomato"
	s.plots[1].growth = s.crop_days("tomato")
	s._harvest_plot(1)
	check(s.plots[1].crop == "","既有旧田块不会升级为再生作物")
	# Harvest specialization must be represented by the world preview.
	s.plots[2] = s._new_plot()
	s.plots[2].crop = "cabbage"
	s.plots[2].growth = 3
	s.plots[2].condition = 0
	s.plots[2].health = 10
	s.plots[2].fertility = 10
	s.skills.farming.choice = "care"
	preview = preload("res://scripts/interaction_description.gd").plot_preview(s,2)
	check(int(preview.grade) == 1,"预览包含精心照料专长的品质保底")
	var quality_before: int = s.quality.get("cabbage",[0,0,0])[0]
	s._harvest_plot(2)
	check(s.quality.cabbage[0] == quality_before+int(preview.qty),"专长预览与实际品质一致")
	s.skills.farming.choice = ""
	# A fine companion is not capped by an ordinary main crop or its late harvest.
	s.plots[3] = s._new_plot()
	s.plots[3].tilled = true
	s.plots[3].crop = "rice"
	s.plots[3].soil_type = "humus"
	s.plots[3].condition = 0
	s.plots[3].ripe_days = 99
	s.plots[3].seed_kind = "normal"
	s.plots[3].companion = {"crop":"cabbage","growth":3,"kind":"heirloom","condition":100,"ticks":4}
	quality_before = s.quality.get("cabbage",[0,0,0])[2]
	s.stamina = 100
	check(s.farm_special_action(3,"companionHarvest"),"套种独立收取")
	check(s.quality.cabbage[2] == quality_before+1,"套种按自身种子品质、土质与生长记录结算")
	# Invalid action arguments never spend inventory or energy.
	s.plots[4] = s._new_plot()
	s.plots[4].tilled = true
	s.stamina = 100
	for choices in [{"crop":"missing"},{"crop":"tomato","kind":"missing"},{"crop":"tomato","density":"missing"}]:
		check(not s._farm_plot_action_single(4,"seed",choices) and s.stamina == 100,"无效种子参数不扣物资")
	s.plots[4].fallow = true
	check(s.farm_batch_plan([4],"sow").is_empty(),"批量播种跳过休耕田")
	check(not s._farm_plot_action_single(4,"seed",{"crop":"tomato"}),"直接播种与规划共同保护休耕田")
	s.plots[4].fallow = false
	s.day = 0
	s.selected_seed = "tomato"
	check(s.farm_batch_plan([4],"sow").is_empty(),"无暖棚时批量跳过反季种子")
	s.farm.facilities = [{"type":"greenhouse","anchor":4,"enabled":true,"durability":100}]
	check(s.farm_batch_plan([4],"sow").size() == 1,"暖棚允许普通种反季安排")
	s.farm.seedKind = "seasonal"
	check(s.farm_batch_plan([4],"sow").is_empty(),"节令种在暖棚内仍遵守季节限制")
	s.farm.seedKind = "normal"
	s.farm.facilities = []
	s.selected_seed = "cucumber"
	s.day = 54
	check(bool(INFO.sow_plan(s,4).crosses),"播种前提示跨入非适种季节")
	s.selected_seed = "tomato"
	check(not bool(INFO.sow_plan(s,4).crosses),"跨季作物夏秋衔接无需虚假预警")
	# Smart work is selective and stable; materials reflect captured choices.
	s.plots[5] = s._new_plot()
	s.plots[5].tilled = true
	s.plots[5].crop = "cabbage"
	s.plots[5].moisture = 10
	s.plots[5].disease = 30
	s.plots[5].weeds = 50
	var tasks: Array = s.farm_batch_plan([5,5,-1,999],"care")
	check(tasks.size() == 3 and tasks[0].action == "water" and tasks[1].action == "bio" and tasks[2].action == "weed","按田况去重并安排水、病、草三项")
	var estimate: String = preload("res://scripts/work_preview.gd").describe(s,tasks)
	check(estimate.contains("草本护苗液") and estimate.contains("3 项农事") and estimate.contains("1 块田"),"混合照料显示正确材料与田块数")
	tasks = [{"index":4,"action":"sow","arg":{"crop":"cucumber","kind":"heirloom","density":"dense"}}]
	estimate = preload("res://scripts/work_preview.gd").describe(s,tasks)
	check(estimate.contains(s.item_catalog.cucumber_heirloom.name) and estimate.contains("/ 2"),"材料预览采用入队时保存的种子与密度")
	# Daily irrigation and companion growth use actual crop requirements.
	for i in s.plots.size(): s.plots[i] = s._new_plot()
	s.day = 29
	s.plots[0].tilled = true
	s.plots[0].crop = "rice"
	s.plots[0].moisture = 0
	s.farm.facilities = [{"type":"sprinkler","anchor":0,"enabled":true,"durability":100}]
	s.farm.water = 5
	s._advance_farm(28)
	check(s.plots[0].moisture == 75 and s.farm.water == 4,"喷灌按稻米需水量补水并准确扣一次储水")
	s.farm.facilities = []
	s.farm.water = 0
	s.plots[0].moisture = 0
	s.upgrades.irrigation = true
	s._advance_farm(28)
	check(s.plots[0].moisture >= 75 and s.farm.water == 0,"旧式灌溉设施实际补水")
	s.upgrades.irrigation = false
	s.plots[0].crop = "rice"
	s.plots[0].growth = 0
	s.plots[0].soil_type = "loam"
	s.plots[0].moisture = 60
	s.plots[0].companion = {"crop":"cabbage","growth":0,"kind":"seasonal"}
	s._advance_farm(28)
	check(float(s.plots[0].companion.growth) > float(s.plots[0].growth),"旱地套种不继承水生主作物的缺水减速")
	check(s.plots[0].companion.has("condition") and s.plots[0].companion.has("ticks"),"套种独立记录生长照料")
	# Native snapshots and the bed fallback both preserve new progress.
	s.plots[1] = s._new_plot()
	s.plots[1].tilled = true
	s.plots[1].crop = "tomato"
	s.plots[1].regrow_days = 3
	s.plots[1].harvest_count = 7
	s.plots[1].growth = 2.5
	var path := FILES.create_path("farming_redesign")
	check(s.save_game(path),"新增农事状态可正常保存")
	var copy = load("res://scripts/game_state.gd").new()
	copy._load_content(); copy._load_initial_state()
	check(copy.load_game(path) and copy.plots[1].regrow_days == 3 and copy.plots[1].harvest_count == 7 and copy.plots[1].growth == 2.5,"保存再读回保留再生进度")
	var snapshot: Dictionary = s._make_save_data()
	snapshot.plots[1].erase("regrow_days"); snapshot.plots[1].erase("harvest_count")
	check(copy.load_game_data(snapshot) and copy.plots[1].regrow_days == 3 and copy.plots[1].harvest_count == 7,"缺失字段从兼容田床备份恢复")
	snapshot.plots[1].regrow_days = "bad"
	check(not copy.load_game_data(snapshot),"损坏再生数值被存档验证拒绝")
	copy.free(); FILES.remove(path)
	print("Farming redesign: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
