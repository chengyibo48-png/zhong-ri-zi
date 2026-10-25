extends Control
class_name FarmPlannerPanel

const KIND_IDS := ["normal", "heirloom", "seasonal"]
const DENSITY_IDS := ["sparse", "balanced", "dense"]
const SOIL_IDS := ["loam", "sand", "clay", "humus", "wetland"]
const FIELD_ACTIONS := ["fertilizer", "slow", "green", "drain", "deep", "fallow", "remove", "weed", "manual", "bio", "agent"]
const FIELD_ACTION_NAMES := {"fertilizer": "施堆肥", "drain": "排水", "deep": "深翻松土", "fallow": "休耕 / 结束休耕", "remove": "撤去田垄", "weed": "拔草", "manual": "人工捉虫", "bio": "草本护苗", "agent": "速效护苗", "slow": "施缓释肥", "green": "翻埋豆科绿肥"}
var summary_label: Label
var crop_search: LineEdit
var crop_filter: OptionButton
var sow_button: Button
var care_button: Button
var harvest_button: Button
var details_label: Label
var control_scroll: ScrollContainer
var batch_filter: OptionButton
var batch_region: OptionButton
var batch_crop: OptionButton
var batch_action: OptionButton
var batch_label: Label
var batch_button: Button
var can_work := false
var crop_ids: Array[String] = []
var crop_list: ItemList
var detail_label: Label
var kind_option: OptionButton
var density_option: OptionButton
var soil_option: OptionButton
var plot_box: SpinBox
var auto_seed: CheckButton
var soil_button: Button
var field_action: OptionButton
var field_action_button: Button
var companion_button: Button
var companion_harvest_button: Button
var seed_save_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.10, 0.08, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -275
	panel.offset_bottom = 275
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e3b30")
	style.border_color = Color("b0b886")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "四时农事 · 种子与田况"
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var batch_shortcut := Button.new()
	batch_shortcut.text = "批量安排"
	batch_shortcut.pressed.connect(func(): batch_filter.grab_focus(); _reveal_control(batch_filter))
	header.add_child(batch_shortcut)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var seed_column := VBoxContainer.new()
	seed_column.custom_minimum_size.x = 220
	body.add_child(seed_column)
	crop_search = LineEdit.new()
	crop_search.placeholder_text = "搜索作物"
	crop_search.text_changed.connect(func(_value): _refresh_crop_list())
	seed_column.add_child(crop_search)
	crop_filter = OptionButton.new()
	for text in ["全部作物", "只看当季", "只看持有种子"]: crop_filter.add_item(text)
	crop_filter.item_selected.connect(func(_value): _refresh_crop_list())
	seed_column.add_child(crop_filter)
	crop_list = ItemList.new()
	crop_list.custom_minimum_size = Vector2(220, 180)
	crop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crop_list.item_selected.connect(_choose_crop)
	seed_column.add_child(crop_list)
	control_scroll = ScrollContainer.new()
	control_scroll.follow_focus = true
	control_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(control_scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 9)
	control_scroll.add_child(controls)
	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 78
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(detail_label)
	controls.add_child(_label("种子类型"))
	kind_option = OptionButton.new()
	for kind in KIND_IDS:
		kind_option.add_item(str(GameState.system_catalog.get("farming", {}).get("kinds", {}).get(kind, {}).get("name", kind)))
	kind_option.item_selected.connect(_set_kind)
	controls.add_child(kind_option)
	controls.add_child(_label("株距"))
	density_option = OptionButton.new()
	for density in DENSITY_IDS:
		density_option.add_item({"sparse": "疏植（少耗肥）", "balanced": "标准", "dense": "密植（多耗种肥，增产）"}[density])
	density_option.item_selected.connect(_set_density)
	controls.add_child(density_option)
	auto_seed = CheckButton.new()
	auto_seed.text = "收获后自动留下同类种子 ×1"
	auto_seed.toggled.connect(_set_auto_seed)
	controls.add_child(auto_seed)
	var soil_row := HBoxContainer.new()
	soil_row.add_child(_label("目标田块"))
	plot_box = SpinBox.new()
	plot_box.min_value = 1
	plot_box.max_value = GameState.plots.size()
	plot_box.step = 1
	plot_box.value = 1
	plot_box.value_changed.connect(func(_value): _refresh_plot_detail())
	soil_row.add_child(plot_box)
	controls.add_child(soil_row)
	sow_button = Button.new()
	sow_button.text = "给这块田播种 · 2 体力"
	sow_button.pressed.connect(func(): GameState.queue_farm_tasks(GameState.farm_batch_plan([int(plot_box.value)-1],"sow")))
	controls.add_child(sow_button)
	care_button = Button.new()
	care_button.text = "按田况照料 · 补水 / 排水 / 护苗 / 拔草"
	care_button.pressed.connect(func(): GameState.queue_farm_tasks(GameState.farm_batch_plan([int(plot_box.value)-1],"care")))
	controls.add_child(care_button)
	harvest_button = Button.new()
	harvest_button.text = "收下这块成熟作物"
	harvest_button.pressed.connect(func(): GameState.queue_farm_tasks(GameState.farm_batch_plan([int(plot_box.value)-1],"harvest")))
	controls.add_child(harvest_button)
	soil_option = OptionButton.new()
	for soil_id in SOIL_IDS:
		soil_option.add_item(str(GameState.system_catalog.get("farming", {}).get("soils", {}).get(soil_id, {}).get("name", soil_id)))
	controls.add_child(soil_option)
	soil_button = Button.new()
	soil_button.text = "换成所选土质（堆肥 ×2 · 20 金币）"
	soil_button.pressed.connect(_apply_soil)
	controls.add_child(soil_button)
	companion_button = Button.new()
	companion_button.text = "在目标田块套种所选作物"
	companion_button.pressed.connect(_plant_companion)
	controls.add_child(companion_button)
	companion_harvest_button = Button.new()
	companion_harvest_button.text = "单独收取成熟套种"
	companion_harvest_button.pressed.connect(_harvest_companion)
	controls.add_child(companion_harvest_button)
	seed_save_button = Button.new()
	seed_save_button.text = "保存主作物种子"
	seed_save_button.pressed.connect(_save_seeds)
	controls.add_child(seed_save_button)
	controls.add_child(_label("更多田间管理"))
	field_action = OptionButton.new()
	for action in FIELD_ACTIONS:
		field_action.add_item(str(FIELD_ACTION_NAMES[action]))
		field_action.set_item_metadata(field_action.item_count - 1, action)
	controls.add_child(field_action)
	field_action_button = Button.new()
	field_action_button.text = "对目标田块执行"
	field_action_button.pressed.connect(_apply_field_action)
	controls.add_child(field_action_button)
	controls.add_child(_label("筛选与批量安排"))
	batch_filter = _batch_option([["all","全部田块"],["ready","成熟"],["dry","缺水"],["risk","病虫 / 健康风险"],["empty","空田"]])
	batch_region = _batch_option([["all","全部区域"],["home","小院 7×7 · 01—49"],["slope","东坡 50—97"]])
	var crops: Array = [["all","全部作物"]]
	for id in GameState.crop_catalog: crops.append([str(id),GameState.crop_name(str(id))])
	batch_crop = _batch_option(crops)
	batch_action = _batch_option([["water","补水"],["fertilize","堆肥"],["sow","播种"],["harvest","采收"],["care","按田况照料"],["companionHarvest","收套种"]])
	batch_action.select(0)
	for option in [batch_filter,batch_region,batch_crop,batch_action]: controls.add_child(option)
	batch_label = Label.new()
	batch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(batch_label)
	batch_button = Button.new()
	batch_button.text = "开始这一批 · 逐块走近执行"
	batch_button.pressed.connect(_start_batch)
	controls.add_child(batch_button)
	var hint := Label.new()
	hint.text = "P 农事簿 · 点选田号后走近作业 · 金色菱形可收，蓝色水滴缺水 · 途中可取消，保留已完成成果。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	# Keep the target and daily actions above the optional agronomy explanation.
	controls.move_child(soil_row,1)
	controls.move_child(sow_button,2)
	controls.move_child(care_button,3)
	controls.move_child(harvest_button,4)
	var disclosure := CheckButton.new()
	disclosure.text = "查看播种预估与照料建议"
	controls.add_child(disclosure)
	controls.move_child(disclosure,5)
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.visible = false
	controls.add_child(details_label)
	controls.move_child(details_label,6)
	disclosure.toggled.connect(func(expanded): details_label.visible = expanded)
	for focus_control in controls.find_children("*", "Control", true, false):
		if focus_control.focus_mode != Control.FOCUS_NONE:
			focus_control.focus_entered.connect(_reveal_control.bind(focus_control))
	GameState.changed.connect(refresh)
	visible = false

func _reveal_control(control: Control) -> void:
	# Container layout may settle after focus moves; reveal on the next frame.
	await get_tree().process_frame
	if visible and is_instance_valid(control) and control.has_focus():
		control_scroll.ensure_control_visible(control)

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label

func open_panel(work_allowed: bool = false, plot_index: int = 0) -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	can_work = work_allowed
	plot_box.value = clampi(plot_index + 1, 1, GameState.plots.size())
	visible = true
	GameState.ui_open = true
	refresh()
	crop_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	_refresh_batch()
	if not visible or not is_instance_valid(crop_list):
		return
	summary_label.text = preload("res://scripts/farm_insights.gd").overview(GameState)
	_refresh_crop_list()
	kind_option.select(maxi(0, KIND_IDS.find(str(GameState.farm.get("seedKind", "normal")))))
	density_option.select(maxi(0, DENSITY_IDS.find(str(GameState.farm.get("density", "balanced")))))
	soil_option.select(maxi(0, SOIL_IDS.find(str(GameState.farm.get("selectedSoil", "loam")))))
	auto_seed.button_pressed = bool(GameState.farm.get("autoSeed", false))
	_refresh_plot_detail()

func _refresh_crop_list() -> void:
	crop_ids.clear()
	crop_list.clear()
	var keys := GameState.crop_catalog.keys()
	keys.sort_custom(func(a, b): return str(GameState.crop_catalog[a].get("name", a)) < str(GameState.crop_catalog[b].get("name", b)))
	for raw_id in keys:
		var crop_id := str(raw_id)
		if not crop_search.text.strip_edges().is_empty() and not GameState.crop_name(crop_id).contains(crop_search.text.strip_edges()): continue
		if crop_filter.selected == 1 and not GameState.crop_in_season(crop_id): continue
		if crop_filter.selected == 2 and int(GameState.inventory.get(GameState.seed_variant_id(crop_id),0)) <= 0: continue
		crop_ids.append(crop_id)
		crop_list.add_item("%s · %s ×%d" % [GameState.crop_name(crop_id), "当季" if GameState.crop_in_season(crop_id) else "反季", int(GameState.inventory.get(GameState.seed_variant_id(crop_id), 0))])
	var selected_index := crop_ids.find(GameState.selected_seed)
	if selected_index >= 0:
		crop_list.select(selected_index)
		crop_list.ensure_current_is_visible()

func _refresh_plot_detail() -> void:
	if not is_instance_valid(detail_label) or GameState.plots.is_empty():
		return
	var index := int(plot_box.value) - 1
	var plot: Dictionary = GameState.plots[index]
	var profile := GameState.crop_profile(GameState.selected_seed)
	var seed_id := GameState.seed_variant_id(GameState.selected_seed)
	detail_label.text = "%s · %s\n种子：%s ×%d · %s · %s\n田块 %d：%s · 肥力 %d · 湿度 %d\n适种土：%s · 适湿 %d–%d · 土壤蒸发 %d" % [GameState.crop_name(GameState.selected_seed), GameState.season_name(), GameState.item_catalog.get(seed_id, {}).get("name", seed_id), int(GameState.inventory.get(seed_id, 0)), str(GameState.system_catalog.get("farming", {}).get("kinds", {}).get(str(GameState.farm.get("seedKind", "normal")), {}).get("name", "普通种")), {"sparse": "疏植", "balanced": "标准株距", "dense": "密植"}.get(str(GameState.farm.get("density", "balanced")), "标准"), index + 1, GameState.system_catalog.get("farming", {}).get("soils", {}).get(str(plot.get("soil_type", "loam")), {}).get("name", "壤土"), int(plot.get("fertility", 0)), int(plot.get("moisture", 0)), GameState.system_catalog.get("farming", {}).get("soils", {}).get(str(profile.preferred), {}).get("name", "壤土"), int(profile.low), int(profile.high), int(GameState.system_catalog.get("farming", {}).get("soils", {}).get(str(plot.get("soil_type", "loam")), {}).get("evap", 15))]
	var crop_id := str(plot.get("crop", ""))
	var crop_label := "空田" if crop_id == "" else "%s · %d/%d 天" % [GameState.crop_name(crop_id), roundi(float(plot.get("growth", 0.0))), GameState.crop_days(crop_id)]
	var companion: Dictionary = plot.get("companion", {})
	var companion_label := "无套种" if companion.is_empty() else "%s · %d/%d 天" % [GameState.crop_name(str(companion.get("crop", ""))), roundi(float(companion.get("growth", 0.0))), GameState.crop_days(str(companion.get("crop", "")))]
	var last_group := str(plot.get("last_group", ""))
	var rotation_label := "尚无连作压力" if int(plot.get("repeats", 0)) == 0 else "前茬 %s · 同科连作 %d 茬" % [last_group, int(plot.get("repeats", 0))]
	var status := "已撤垄" if bool(plot.get("removed", false)) else "休耕养地" if bool(plot.get("fallow", false)) else "缓释肥剩 %d 天" % int(plot.get("slow", 0)) if int(plot.get("slow", 0)) > 0 else "正常管理"
	detail_label.text += "\n作物：%s · %s\n套种：%s · 虫 %d / 病 %d / 草 %d · %s" % [crop_label, rotation_label, companion_label, int(plot.get("pests", 0)), int(plot.get("disease", 0)), int(plot.get("weeds", 0)), status]

	var insights := preload("res://scripts/farm_insights.gd")
	var plan: Dictionary = insights.sow_plan(GameState,index)
	if not plan.is_empty():
		detail_label.text += "\n\n播种参考：水肥正常时首收约 %d 天；天气、病虫会延后。" % int(plan.days)
		if bool(plan.crosses): detail_label.text += "\n注意：首收将跨入非适季，露地减速，可换短周期作物或使用暖棚。"
		if int(plan.regrow) > 0: detail_label.text += "\n新播主作物采后再长约 %d 生长日；不用重新买种。" % int(plan.regrow)
		detail_label.text += "\n首茬普通品质、肥力充足时约 %d 份，种子成本 %d，基础售价减种钱 %d 金币（未计水肥、人工及行情）。" % [int(plan.qty),int(plan.cost),int(plan.net)]
	if not crop_id.is_empty():
		var preview: Dictionary = insights.harvest(GameState,plot)
		detail_label.text += "\n\n本田长势 %d%% · 健康 %d · 当前品质参考 %s ×%d" % [mini(100,roundi(float(plot.growth)/maxi(1,GameState.crop_days(crop_id))*100)),roundi(float(plot.health)),insights.GRADES[int(preview.grade)],int(preview.qty)]
		if int(plot.get("regrow_days",0)) > 0: detail_label.text += "\n已采 %d 次 · 根株会继续结果" % int(plot.get("harvest_count",0))
	detail_label.text += "\n\n今天先做：\n" + "\n".join(insights.advice(GameState,index))
	details_label.text = detail_label.text
	detail_label.text = "所选：%s · %s\n田块 %d：%s · 健康 %d\n肥力 %d · 水分 %d · 虫 %d / 病 %d" % [GameState.crop_name(GameState.selected_seed),GameState.season_name(),index+1,crop_label,roundi(float(plot.health)),roundi(float(plot.fertility)),roundi(float(plot.moisture)),roundi(float(plot.pests)),roundi(float(plot.disease))]
	sow_button.disabled = not str(plan.get("reason","")).is_empty() or int(GameState.inventory.get(seed_id,0)) < (2 if str(GameState.farm.get("density","balanced")) == "dense" else 1)
	sow_button.tooltip_text = str(plan.get("reason",""))
	care_button.disabled = GameState.farm_batch_plan([index],"care").is_empty()
	harvest_button.disabled = crop_id.is_empty() or float(plot.growth) < GameState.crop_days(crop_id)
	soil_button.disabled = not crop_id.is_empty() or not companion.is_empty() or not bool(plot.tilled) or bool(plot.get("removed",false))
	companion_button.disabled = crop_id.is_empty() or not companion.is_empty() or GameState.crop_compatibility(crop_id,GameState.selected_seed) < 0
	companion_harvest_button.disabled = companion.is_empty() or float(companion.get("growth",0)) < GameState.crop_days(str(companion.get("crop","")))
	seed_save_button.disabled = harvest_button.disabled
	seed_save_button.text = "留种并结束这茬 · 腾地轮作" if int(plot.get("regrow_days",0)) > 0 else "保存主作物种子"

func _choose_crop(index: int) -> void:
	if index < 0 or index >= crop_ids.size():
		return
	GameState.selected_seed = crop_ids[index]
	GameState.selected_tool = "seed"
	GameState.message = "种子袋选好了%s。" % GameState.crop_name(GameState.selected_seed)
	GameState.changed.emit()

func _set_kind(index: int) -> void:
	if index >= 0 and index < KIND_IDS.size():
		GameState.set_farm_seed_kind(KIND_IDS[index])

func _set_density(index: int) -> void:
	if index >= 0 and index < DENSITY_IDS.size():
		GameState.set_farm_density(DENSITY_IDS[index])

func _set_auto_seed(enabled: bool) -> void:
	GameState.farm.autoSeed = enabled
	GameState.changed.emit()

func _apply_soil() -> void:
	var index := int(plot_box.value) - 1
	GameState.queue_farm_tasks([{"index":index,"action":"soil","arg":SOIL_IDS[soil_option.selected]}])

func _plant_companion() -> void:
	GameState.queue_farm_tasks([{"index":int(plot_box.value)-1,"action":"companion","arg":{"crop":GameState.selected_seed,"kind":str(GameState.farm.get("seedKind","normal")),"density":str(GameState.farm.get("density","balanced"))}}])

func _harvest_companion() -> void:
	GameState.queue_farm_tasks([{"index":int(plot_box.value)-1,"action":"companionHarvest"}])

func _save_seeds() -> void:
	GameState.queue_farm_tasks([{"index":int(plot_box.value)-1,"action":"seedSave"}])

func _batch_option(rows: Array) -> OptionButton:
	var option := OptionButton.new()
	for row in rows:
		option.add_item(str(row[1]))
		option.set_item_metadata(option.item_count-1,str(row[0]))
	option.item_selected.connect(func(_index): _refresh_batch())
	return option

func _batch_tasks() -> Array:
	var indices := GameState.farm_filtered_indices(str(batch_filter.get_selected_metadata()),str(batch_region.get_selected_metadata()),str(batch_crop.get_selected_metadata()))
	return GameState.farm_batch_plan(indices,str(batch_action.get_selected_metadata()))

func _refresh_batch() -> void:
	if not is_instance_valid(batch_label): return
	var tasks := _batch_tasks()
	var action := str(batch_action.get_selected_metadata())
	var materials := "无需材料"
	if action == "fertilize": materials = "熟堆肥 ×%d" % tasks.size()
	elif action == "sow": materials = "%s ×%d" % [GameState.item_catalog.get(GameState.seed_variant_id(GameState.selected_seed,str(GameState.farm.get("seedKind","normal"))),{}).get("name","种子"),tasks.size() * (2 if str(GameState.farm.get("density","balanced")) == "dense" else 1)]
	batch_label.text = preload("res://scripts/work_preview.gd").describe(GameState,tasks)
	batch_button.disabled = tasks.is_empty()

func _start_batch() -> void:
	GameState.queue_farm_tasks(_batch_tasks())

func _apply_field_action() -> void:
	if field_action.selected >= 0:
		GameState.queue_farm_tasks([{"index":int(plot_box.value)-1,"action":str(field_action.get_item_metadata(field_action.selected))}])
