extends Control
class_name RanchPanel

const ANIMAL_ACTIONS := ["feed", "collect", "pet", "clean", "treat", "vet", "rest", "rescue"]
const ANIMAL_ACTION_NAMES := {"feed": "添饲料", "collect": "收产物", "pet": "抚摸", "clean": "梳洗", "treat": "用药治疗", "vet": "请兽医", "rest": "留舍/放牧", "rescue": "带回畜舍"}
const FEED_IDS := ["feed", "hay", "grainFeed", "healthFeed", "bedding"]
const RECIPE_IDS := ["hay", "grain", "health", "bedding", "compost", "cream", "yogurt", "yarn", "cloth", "goatCheese", "fineYarn"]
const BARN_ACTIONS := ["build", "space", "comfort", "protection", "efficiency", "clean", "bedding", "repair", "autoFeed", "autoClean", "autoCollect"]
const BARN_ACTION_NAMES := {"build": "建造", "space": "扩容", "comfort": "舒适巢床", "protection": "围护排水", "efficiency": "收集工位", "clean": "清扫", "bedding": "铺垫草", "repair": "修缮", "autoFeed": "自动添料", "autoClean": "自动换垫草", "autoCollect": "自动收产物"}

var action_buttons: Dictionary = {}
var box_buttons: Dictionary = {}
var pages: TabContainer
var today_detail: Label
var animal_numbers: Label
var batch_action: OptionButton
var animal_filter: OptionButton
var batch_label: Label
var batch_button: Button
var control_scroll: ScrollContainer
var animal_list: ItemList
var rehomed_list: ItemList
var animal_detail: Label
var animal_name: LineEdit
var selected_animal_id := ""
var selected_barn_id := "poultry"
var barn_list: ItemList
var barn_detail: Label
var barn_action: OptionButton
var buy_species: OptionButton
var buy_breed: OptionButton
var buy_sex: OptionButton
var buy_young: CheckBox
var mother_option: OptionButton
var father_option: OptionButton
var incubation_species: OptionButton
var store_item: OptionButton
var store_amount: SpinBox
var recipe_option: OptionButton
var recipe_amount: SpinBox
var pet_detail: Label
var birth_detail: Label
var store_summary: Label
var notice_summary: Label
var feed_preference: OptionButton
var policy_option: OptionButton
var zone_option: OptionButton
var confirm_rehome: ConfirmationDialog
var remember_schedule: Button
var handbook_button: Button
var handbook_overlay: Control
var handbook_content: VBoxContainer
var handbook_scroll: ScrollContainer
var handbook_close: Button
var handbook_blocks: Array = []
var schedule_dirty := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.10, 0.08, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -465; panel.offset_right = 465
	panel.offset_top = -290; panel.offset_bottom = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e3b30")
	style.border_color = Color("b0b886")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "牧场名册与畜舍"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	handbook_button = _button("牧场手册", open_handbook)
	header.add_child(handbook_button)
	var close_button := _button("关闭 Esc", close)
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var animals_title := Label.new(); animals_title.text = "在牧伙伴 / 状态"
	left.add_child(animals_title)
	animal_filter = OptionButton.new()
	for row in [["all","全部伙伴"],["ready","可收产物"],["care","需要照料"],["hen","鸡"],["duck","鸭"],["cow","牛"],["sheep","羊"],["pig","猪"],["goat","山羊"],["rabbit","兔子"]]:
		animal_filter.add_item(str(row[1]))
		animal_filter.set_item_metadata(animal_filter.item_count-1,str(row[0]))
	animal_filter.item_selected.connect(func(_index): refresh())
	left.add_child(animal_filter)
	animal_list = ItemList.new()
	animal_list.custom_minimum_size = Vector2(245, 190)
	animal_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animal_list.item_selected.connect(_select_animal)
	left.add_child(animal_list)
	var rehomed_title := Label.new(); rehomed_title.text = "送养记录 · 可按原补贴接回"
	left.add_child(rehomed_title)
	rehomed_list = ItemList.new()
	rehomed_list.custom_minimum_size = Vector2(245, 70)
	rehomed_list.item_selected.connect(_select_rehomed)
	left.add_child(rehomed_list)
	var adopt_button := _button("接回选中的伙伴", _adopt_selected)
	left.add_child(adopt_button)
	pages = TabContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pages)
	var today := _page("今日")
	var companions := _page("伙伴")
	var barns := _page("畜舍与放牧")
	var products := _page("产物与加工")
	var right: VBoxContainer = today
	today_detail = _label(right,95)
	right.add_child(_button("按今日需要安排照料",_smart_care))
	_add_section(right, "筛选后的批量照料")
	batch_action = OptionButton.new()
	for row in [["feed","添料"],["collect","收取"],["clean","梳洗"],["treat","治疗"]]:
		batch_action.add_item(str(row[1]))
		batch_action.set_item_metadata(batch_action.item_count-1,str(row[0]))
	batch_action.item_selected.connect(func(_index): _refresh_batch())
	right.add_child(batch_action)
	batch_label = _label(right,55)
	batch_button = _button("开始这批照料 · 逐只走近",_start_batch)
	right.add_child(batch_button)
	right = companions
	_add_section(right, "伙伴照料")
	animal_detail = _label(right, 64)
	var details := CheckButton.new();details.text = "查看详细状态数值"
	right.add_child(details)
	animal_numbers = _label(right,60);animal_numbers.hide()
	details.toggled.connect(func(on:bool):animal_numbers.visible=on)
	var action_grid := GridContainer.new(); action_grid.columns = 4
	right.add_child(action_grid)
	for action in ANIMAL_ACTIONS:
		var key := str(action)
		var button := _button(str(ANIMAL_ACTION_NAMES[key]), func() -> void: _animal_action(key))
		action_grid.add_child(button);action_buttons[key]=button
	var name_row := HBoxContainer.new(); right.add_child(name_row)
	animal_name = LineEdit.new(); animal_name.placeholder_text = "给选中的伙伴取名（最多 12 字）"; animal_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(animal_name)
	name_row.add_child(_button("记下名字", _rename_animal))
	var management_row := HBoxContainer.new(); right.add_child(management_row)
	management_row.add_child(_button("退休 / 恢复生产", _toggle_retirement))
	management_row.add_child(_button("送养…", _request_rehome))
	_add_section(right, "配种与孵化")
	var pair_row := HBoxContainer.new(); right.add_child(pair_row)
	mother_option = OptionButton.new(); mother_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pair_row.add_child(mother_option)
	father_option = OptionButton.new(); father_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pair_row.add_child(father_option)
	pair_row.add_child(_button("安排繁育", _breed_selected))
	var hatch_row := HBoxContainer.new(); right.add_child(hatch_row)
	incubation_species = OptionButton.new(); hatch_row.add_child(incubation_species)
	hatch_row.add_child(_button("把受精蛋放入巢箱", _incubate_selected))
	birth_detail = _label(right, 42)
	_add_section(right, "迎接新伙伴")
	var buy_row := HBoxContainer.new(); right.add_child(buy_row)
	buy_species = OptionButton.new(); buy_species.size_flags_horizontal = Control.SIZE_EXPAND_FILL; buy_row.add_child(buy_species)
	buy_breed = OptionButton.new(); buy_breed.size_flags_horizontal = Control.SIZE_EXPAND_FILL; buy_row.add_child(buy_breed)
	buy_sex = OptionButton.new(); buy_sex.add_item("母"); buy_sex.set_item_metadata(0, "female"); buy_sex.add_item("公"); buy_sex.set_item_metadata(1, "male"); buy_row.add_child(buy_sex)
	buy_young = CheckBox.new(); buy_young.text = "幼崽价七折"; buy_young.button_pressed = true; buy_row.add_child(buy_young)
	right.add_child(_button("购买并安置", _buy_animal))
	right = barns
	_add_section(right, "畜舍建造与照料")
	barn_list = ItemList.new(); barn_list.custom_minimum_size.y = 86; barn_list.item_selected.connect(_select_barn); right.add_child(barn_list)
	barn_detail = _label(right, 56)
	var barn_row := HBoxContainer.new(); right.add_child(barn_row)
	barn_action = OptionButton.new(); barn_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL; barn_row.add_child(barn_action)
	for action in BARN_ACTIONS: barn_action.add_item(str(BARN_ACTION_NAMES[action])); barn_action.set_item_metadata(barn_action.item_count - 1, action)
	barn_row.add_child(_button("执行畜舍操作", _run_barn_action))
	_add_section(right, "散养、轮牧与饲料")
	var policy_row := HBoxContainer.new(); right.add_child(policy_row)
	policy_row.add_child(_label_text("放牧策略"))
	policy_option = OptionButton.new(); policy_option.add_item("晴好日放牧"); policy_option.set_item_metadata(0, "safe"); policy_option.add_item("白日放牧（雨天也出舍）"); policy_option.set_item_metadata(1, "day"); policy_option.add_item("留舍照料"); policy_option.set_item_metadata(2, "inside"); policy_option.item_selected.connect(_policy_changed); policy_row.add_child(policy_option)
	policy_row.add_child(_label_text("轮牧草圈"))
	zone_option = OptionButton.new(); zone_option.item_selected.connect(_zone_changed); policy_row.add_child(zone_option)
	var feed_row := HBoxContainer.new(); right.add_child(feed_row)
	feed_row.add_child(_label_text("默认饲料"))
	feed_preference = OptionButton.new(); feed_preference.item_selected.connect(_feed_changed); feed_row.add_child(feed_preference)
	remember_schedule = _button("记住照料安排", _remember_schedule)
	right.add_child(remember_schedule)
	_add_section(right, "牧场料仓")
	var store_row := HBoxContainer.new(); right.add_child(store_row)
	store_item = OptionButton.new(); store_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL; store_row.add_child(store_item)
	store_amount = _spinbox(1, 100, 5); store_row.add_child(store_amount)
	store_row.add_child(_button("存入", func() -> void: _store(false)))
	store_row.add_child(_button("取回", func() -> void: _store(true)))
	store_summary = _label(right, 38)
	right = products
	_add_section(right,"各舍收集箱")
	for home: String in GameState.system_catalog.ranch.barns:
		var id := home
		var button := _button("前往"+str(GameState.system_catalog.ranch.barns[id].name)+"收集箱",func(): _visit_box(id))
		right.add_child(button);box_buttons[id]=button
	_add_section(right, "饲料与畜产品加工")
	var craft_row := HBoxContainer.new(); right.add_child(craft_row)
	recipe_option = OptionButton.new(); recipe_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL; craft_row.add_child(recipe_option)
	recipe_amount = _spinbox(1, 20, 1); craft_row.add_child(recipe_amount)
	craft_row.add_child(_button("制作配方", _craft_recipe))
	right = companions
	_add_section(right, "猫狗伙伴")
	pet_detail = _label(right, 54)
	var pet_grid := GridContainer.new(); pet_grid.columns = 4; right.add_child(pet_grid)
	for action in ["feed", "train", "play", "home", "follow", "patrol", "switch_pet"]:
		var key := str(action)
		var names := {"feed": "喂食", "train": "训练", "play": "陪它玩一会", "home": "回家", "follow": "跟随", "patrol": "牧场巡看", "switch_pet": "切换猫 / 狗"}
		pet_grid.add_child(_button(str(names[key]), func() -> void: _pet_action(key)))
	notice_summary = _label(today, 58)
	var hint := Label.new(); hint.text = "O 打开牧场名册 · E 靠近动物照料 · Shift+R 换手动饲料 · 繁育会预留畜舍床位。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	confirm_rehome = ConfirmationDialog.new()
	confirm_rehome.title = "确认送养"
	confirm_rehome.dialog_text = "这位伙伴将移居邻村牧场，并保留在接回名册。确认送养吗？"
	confirm_rehome.confirmed.connect(_confirm_rehome)
	add_child(confirm_rehome)
	for focus_control in pages.find_children("*","Control",true,false):
		if focus_control.focus_mode != Control.FOCUS_NONE:
			focus_control.focus_entered.connect(_reveal_control.bind(focus_control))
	_build_handbook()
	GameState.changed.connect(refresh)
	visible = false

func _button(label: String, action: Callable) -> Button:
	var result := Button.new(); result.custom_minimum_size.y=34; result.text = label; result.pressed.connect(action); return result

func _label(parent: Node, height: float = 54.0) -> Label:
	var result := Label.new(); result.custom_minimum_size.y = height; result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(result); return result

func _label_text(text: String) -> Label:
	var result := Label.new(); result.text = text; result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; return result

func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new(); label.text = "— " + text + " —"; label.add_theme_color_override("font_color", Color("dfcfaa")); label.add_theme_font_size_override("font_size", 17); parent.add_child(label)

func _spinbox(minimum: int, maximum: int, value: int) -> SpinBox:
	var result := SpinBox.new(); result.min_value = minimum; result.max_value = maximum; result.value = value; result.step = 1; result.custom_minimum_size.x = 72; return result

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	schedule_dirty = false
	handbook_overlay.hide()
	visible = true
	GameState.ui_open = true
	refresh()
	animal_list.grab_focus()

func close() -> void:
	handbook_overlay.hide()
	schedule_dirty = false
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _metadata(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 and option.item_count > 0 else ""

func _select_meta(option: OptionButton, id: String) -> void:
	for i in range(option.item_count):
		if str(option.get_item_metadata(i)) == id: option.select(i); return

func refresh() -> void:
	if not visible or not is_instance_valid(animal_list): return
	var previous_animal := selected_animal_id
	animal_list.clear()
	var filtered_ids := GameState.ranch_filtered_ids(_metadata(animal_filter))
	for animal in GameState.animals:
		if str(animal.id) not in filtered_ids: continue
		var product := str(GameState.item_catalog.get(str(animal.get("product", "")), {}).get("name", animal.get("product", "產物")))
		var state: String = preload("res://scripts/ranch_care.gd").status(GameState,animal)
		animal_list.add_item("%s · %s · %s" % [str(animal.get("name", "伙伴")), str(animal.get("species", "动物")), state])
		animal_list.set_item_metadata(animal_list.item_count - 1, str(animal.get("id", "")))
	selected_animal_id = previous_animal
	var selected_index := _animal_index(selected_animal_id)
	if selected_animal_id not in filtered_ids:
		selected_animal_id = str(filtered_ids[0]) if not filtered_ids.is_empty() else ""
		selected_index = _animal_index(selected_animal_id)
	if selected_index >= 0:
		animal_list.select(filtered_ids.find(selected_animal_id))
		_show_animal(selected_index)
	else:
		animal_detail.text = "牧场里还没有伙伴。先修建畜舍，再迎接新动物。"
		animal_name.text = ""
	_refresh_today()
	_refresh_batch()
	_fill_pair_options()
	_fill_species_options()
	_fill_barn_list()
	if not schedule_dirty: _fill_feed_options()
	if handbook_overlay.visible: _fill_handbook()
	_fill_store()
	_fill_recipes()
	_fill_pet()
	_fill_rehomed()
	var births: Array = GameState.ranch.get("births", [])
	birth_detail.text = "孕育中：" + ("、".join(births.map(func(birth: Dictionary) -> String: return "%s %d/%d 天" % [str(GameState.system_catalog.get("ranch", {}).get("species", {}).get(str(birth.get("type", "")), {}).get("name", "幼崽")), int(birth.get("total", 1)) - int(birth.get("remaining", 0)), int(birth.get("total", 1))])) if not births.is_empty() else "暂无孕育安排。")
	var pieces: Array[String] = []
	for item_id in FEED_IDS: pieces.append("%s %d" % [str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), int(GameState.ranch.get("stores", {}).get(item_id, 0))])
	store_summary.text = " · ".join(pieces)
	var notices: Array = GameState.ranch.get("notices", [])
	notice_summary.text = "牧场近况：" + (str(notices[0].get("text", "")) if not notices.is_empty() else "暂时没有需要提醒的事。")

func _animal_index(animal_id: String) -> int:
	for i in range(GameState.animals.size()):
		if str(GameState.animals[i].get("id", "")) == animal_id: return i
	return -1

func _select_animal(index: int) -> void:
	if index < 0 or index >= animal_list.item_count: return
	selected_animal_id = str(animal_list.get_item_metadata(index))
	_show_animal(_animal_index(selected_animal_id))
	_fill_pair_options()

func _show_animal(index: int) -> void:
	if index < 0 or index >= GameState.animals.size(): return
	var animal: Dictionary = GameState.animals[index]
	var catalog: Dictionary = GameState.system_catalog.get("ranch", {})
	var spec: Dictionary = catalog.get("species", {}).get(str(animal.get("type", "hen")), {})
	var barn: Dictionary = GameState.ranch.get("barns", {}).get(str(spec.get("home", "")), {})
	var stage := GameState.ranch_life_stage(animal)
	var breed: Dictionary = catalog.get("breeds", {}).get(str(animal.get("breed", "local")), {})
	var warnings: Array[String] = []
	if bool(animal.get("lost", false)): warnings.append("迷路，去南坡標記處帶回")
	if int(animal.get("illness", 0)) >= 20: warnings.append("不适%d" % int(animal.illness))
	if int(animal.get("hunger", 0)) < 40: warnings.append("饲料不足")
	if int(animal.get("clean", 0)) < 45 or int(barn.get("clean", 0)) < 45: warnings.append("需要清洁")
	if bool(animal.get("rest", false)): warnings.append("留舍休养")
	var position: Dictionary = animal.get("position", {})
	animal_numbers.text = "%s · %s · %s · %s\n%s / %s · 第 %d 天 · 好感 %d · 饱食 %d · 健康 %d · 心情 %d\n清洁 %d · 压力 %d · 不适 %d · 待收 %s ×%d · 羽毛 %d\n%s" % [str(animal.get("name", "伙伴")), str(spec.get("name", "动物")), stage, str(breed.get("name", "乡土种")), "母畜" if str(animal.get("sex", "female")) == "female" else "公畜", str(catalog.get("traits", {}).get(str(animal.get("trait", "friendly")), "亲人")), int(animal.get("age", 0)), int(animal.get("bond", 0)), int(animal.get("hunger", 0)), int(animal.get("health", 0)), int(animal.get("mood", 0)), int(animal.get("clean", 0)), int(animal.get("stress", 0)), int(animal.get("illness", 0)), str(GameState.item_catalog.get(str(animal.get("product", "")), {}).get("name", "产物")), int(animal.get("ready", 0)), int(animal.get("feathers", 0)), "；".join(warnings) if not warnings.is_empty() else "状态安稳 · 畜舍清洁 %d · %s" % [int(barn.get("clean", 0)), "已退休" if bool(animal.get("retired", false)) else "日常生产中"]]
	animal_detail.text = str(animal.name)+" · "+str(spec.name)+" · "+stage+"\n"+preload("res://scripts/ranch_care.gd").status(GameState,animal)
	for action: String in action_buttons:
		var button: Button = action_buttons[action]
		button.text = str(ANIMAL_ACTION_NAMES[action]); button.disabled = false
		match action:
			"pet":
				button.disabled = int(animal.care.pet)==GameState.day
				if button.disabled: button.text="已亲近"
			"feed":
				button.disabled = preload("res://scripts/ranch_care.gd").needed(GameState,animal,GameState.day)==0
				if button.disabled:button.text="已吃饱"
			"collect":button.text=str(spec.get("harvestVerb","收取"));button.disabled=int(animal.ready)==0 and int(animal.feathers)==0
			"rescue":button.disabled=not bool(animal.lost)
			"treat","vet":button.disabled=float(animal.health)>=95 and float(animal.illness)<1
			"clean":button.disabled=float(animal.clean)>=95 or int(animal.care.clean)==GameState.day
	animal_name.text = str(animal.get("name", ""))

func _reveal_control(control: Control) -> void:
	await get_tree().process_frame
	if visible and is_instance_valid(control) and control.has_focus():
		var ancestor: Node = control.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(control); break
			ancestor = ancestor.get_parent()

func _batch_tasks() -> Array:
	return GameState.ranch_batch_plan(GameState.ranch_filtered_ids(_metadata(animal_filter)),_metadata(batch_action))

func _refresh_batch() -> void:
	if not is_instance_valid(batch_label): return
	var tasks := _batch_tasks()
	var action := _metadata(batch_action)
	var needs := 0
	if action == "feed":
		for task in tasks:
			var index := GameState.ranch_animal_index(str(task.animalId))
			var a: Dictionary = GameState.animals[index]
			var spec: Dictionary = GameState.system_catalog.ranch.species[str(a.type)]
			var breed: Dictionary = GameState.system_catalog.ranch.breeds[str(a.breed)]
			needs += ceili(float(spec.feed)*float(breed.feed))
	elif action == "treat": needs = tasks.size()
	var material := str(GameState.item_catalog.get(str(GameState.ranch.get("feed","feed")) if action == "feed" else "animalMedicine",{}).get("name","材料"))
	batch_label.text = preload("res://scripts/work_preview.gd").describe(GameState,tasks,true)
	batch_button.disabled = tasks.is_empty()

func _start_batch() -> void:
	GameState.queue_ranch_tasks(_batch_tasks())

func _pet_action(action: String) -> void:
	if action in ["home","follow","patrol","switch_pet"]: GameState.confirm_operation(GameState.ranch_pet_action(action))
	else: GameState.queue_ranch_tasks([{"pet":true,"action":action}])

func _animal_action(action: String) -> void:
	var index := _animal_index(selected_animal_id)
	if index >= 0: GameState.queue_ranch_tasks([{"animalId":selected_animal_id,"action":action,"arg":str(GameState.ranch.get("feed","feed"))}])

func _rename_animal() -> void:
	if selected_animal_id != "": GameState.confirm_operation(GameState.ranch_rename_animal(selected_animal_id, animal_name.text))

func _toggle_retirement() -> void:
	if selected_animal_id != "": _animal_action("retire")

func _request_rehome() -> void:
	if selected_animal_id != "": confirm_rehome.popup_centered()

func _confirm_rehome() -> void:
	if selected_animal_id != "": GameState.confirm_operation(GameState.ranch_rehome(selected_animal_id, true))

func _fill_pair_options() -> void:
	mother_option.clear(); father_option.clear()
	mother_option.add_item("选择母畜"); mother_option.set_item_metadata(0, "")
	father_option.add_item("选择公畜"); father_option.set_item_metadata(0, "")
	for animal in GameState.animals:
		var spec: Dictionary = GameState.system_catalog.get("ranch", {}).get("species", {}).get(str(animal.get("type", "")), {})
		if int(animal.get("age", 0)) < int(spec.get("adult", 999999)): continue
		var id := str(animal.get("id", ""))
		var label := "%s · %s" % [str(animal.get("name", "伙伴")), str(spec.get("name", "动物"))]
		if str(animal.get("sex", "")) == "female": mother_option.add_item(label); mother_option.set_item_metadata(mother_option.item_count - 1, id)
		if str(animal.get("sex", "")) == "male": father_option.add_item(label); father_option.set_item_metadata(father_option.item_count - 1, id)
	var chosen_index := _animal_index(selected_animal_id)
	if chosen_index >= 0:
		var chosen: Dictionary = GameState.animals[chosen_index]
		if str(chosen.get("sex", "")) == "female": _select_meta(mother_option, selected_animal_id)
		if str(chosen.get("sex", "")) == "male": _select_meta(father_option, selected_animal_id)

func _breed_selected() -> void:
	var mother := _metadata(mother_option)
	var index := _animal_index(mother)
	if index >= 0:
		GameState.queue_ranch_tasks([{"barnId":GameState._ranch_home_for(str(GameState.animals[index].type)),"action":"breed","arg":[mother,_metadata(father_option)]}])

func _fill_species_options() -> void:
	var species: Dictionary = GameState.system_catalog.get("ranch", {}).get("species", {})
	var breeds: Dictionary = GameState.system_catalog.get("ranch", {}).get("breeds", {})
	var selected_type := _metadata(buy_species)	if buy_species.item_count > 0 else "hen"
	var selected_breed := _metadata(buy_breed) if buy_breed.item_count > 0 else "local"
	buy_species.clear()
	for type_id in species:
		buy_species.add_item(str(species[type_id].get("name", type_id)) + " · " + str(species[type_id].get("cost", 0)) + " 元起")
		buy_species.set_item_metadata(buy_species.item_count - 1, str(type_id))
	_select_meta(buy_species, selected_type)
	buy_breed.clear()
	for breed_id in breeds:
		buy_breed.add_item(str(breeds[breed_id].get("name", breed_id)))
		buy_breed.set_item_metadata(buy_breed.item_count - 1, str(breed_id))
	_select_meta(buy_breed, selected_breed)
	incubation_species.clear()
	incubation_species.add_item("鸡蛋 · 4 天")
	incubation_species.set_item_metadata(0, "hen")
	incubation_species.add_item("鸭蛋 · 5 天")
	incubation_species.set_item_metadata(1, "duck")

func _buy_animal() -> void:
	GameState.queue_ranch_tasks([{"barnId":GameState._ranch_home_for(_metadata(buy_species)),"action":"purchase","arg":[_metadata(buy_species),_metadata(buy_sex),_metadata(buy_breed),buy_young.button_pressed]}])

func _incubate_selected() -> void:
	GameState.queue_ranch_tasks([{"barnId":"poultry","action":"incubate","arg":_metadata(incubation_species)}])

func _fill_barn_list() -> void:
	barn_list.clear()
	var definitions: Dictionary = GameState.system_catalog.get("ranch", {}).get("barns", {})
	for barn_id in definitions:
		var definition: Dictionary = definitions[barn_id]
		var barn: Dictionary = GameState.ranch.get("barns", {}).get(str(barn_id), {})
		var capacity := GameState.ranch_barn_capacity(str(barn_id))
		barn_list.add_item("%s · %s · %d 床 · 清洁 %d" % [str(definition.get("name", barn_id)), "已开放" if bool(barn.get("built", false)) else "未修", capacity, int(barn.get("clean", 0))])
		barn_list.set_item_metadata(barn_list.item_count - 1, str(barn_id))
	var index := -1
	for i in range(barn_list.item_count):
		if str(barn_list.get_item_metadata(i)) == selected_barn_id: index = i; break
	if index < 0 and barn_list.item_count > 0: index = 0; selected_barn_id = str(barn_list.get_item_metadata(0))
	if index >= 0: barn_list.select(index); _show_barn()

func _select_barn(index: int) -> void:
	if index < 0: return
	selected_barn_id = str(barn_list.get_item_metadata(index))
	_show_barn()

func _show_barn() -> void:
	var definition: Dictionary = GameState.system_catalog.get("ranch", {}).get("barns", {}).get(selected_barn_id, {})
	var barn: Dictionary = GameState.ranch.get("barns", {}).get(selected_barn_id, {})
	var occupants := 0
	for animal in GameState.animals:
		if GameState._ranch_home_for(str(animal.get("type", ""))) == selected_barn_id: occupants += 1
	var total_capacity := GameState.ranch_barn_capacity(selected_barn_id)
	barn_detail.text = "%s · %s\n床位 %d / %d（含孕育预留）· 清洁 %d · 耐久 %d · 圈肥 %d\n空间 %d · 舒适 %d · 防护 %d · 收集 %d\n自动添料 %s · 自动换草 %s · 自动收取 %s" % [str(definition.get("name", selected_barn_id)), "已修好" if bool(barn.get("built", false)) else "尚未修建", occupants + _reserved_count(selected_barn_id), total_capacity, int(barn.get("clean", 0)), int(barn.get("durability", 0)), int(barn.get("waste", 0)), int(barn.get("space", 0)), int(barn.get("comfort", 0)), int(barn.get("protection", 0)), int(barn.get("efficiency", 0)), "开" if bool(barn.get("autoFeed", false)) else "关", "开" if bool(barn.get("autoClean", false)) else "关", "开" if bool(barn.get("autoCollect", false)) else "关"]

	barn_detail.text += "\n料槽 %s · 收集箱 %d/%d\n添料：%s\n换草：%s\n收集：%s" % [_trough_text(barn.get("trough",{})),preload("res://scripts/ranch_products.gd").box_count(GameState,selected_barn_id),int(definition.get("boxCapacity",48)),str(barn.get("feedStatus","手动 · 背包或料仓")),str(barn.get("cleanStatus","手动 · 垫草")),str(barn.get("collectStatus","手工收取"))]

func _reserved_count(barn_id: String) -> int:
	var count := 0
	for birth in GameState.ranch.get("births", []):
		if GameState._ranch_home_for(str(birth.get("type", ""))) == barn_id: count += 1
	return count

func _run_barn_action() -> void:
	GameState.queue_ranch_tasks([{"barnId":selected_barn_id,"action":_metadata(barn_action)}])

func _fill_feed_options() -> void:
	var current := str(GameState.ranch.get("feed", "feed"))
	feed_preference.clear()
	for feed_id in ["feed", "hay", "grainFeed", "healthFeed"]:
		feed_preference.add_item(str(GameState.system_catalog.get("ranch", {}).get("feedKinds", {}).get(feed_id, {}).get("name", feed_id)))
		feed_preference.set_item_metadata(feed_preference.item_count - 1, feed_id)
	_select_meta(feed_preference, current)
	var policies := ["safe", "day", "inside"]
	_select_meta(policy_option, str(GameState.ranch.get("policy", "safe")))
	var zones: Array = GameState.system_catalog.get("ranch", {}).get("zones", [])
	zone_option.clear()
	for i in range(zones.size()): zone_option.add_item(str(zones[i].get("name", "草圈")) + " · 草量 " + str(roundi(float(GameState.ranch.grass[i])))); zone_option.set_item_metadata(i, i)
	if zone_option.item_count > 0: zone_option.select(clampi(int(GameState.ranch.get("zone", 0)), 0, zone_option.item_count - 1))
	for i in range(policy_option.item_count):
		if str(policy_option.get_item_metadata(i)) not in policies: continue

func _feed_changed(_index: int) -> void:
	schedule_dirty = true

func _policy_changed(_index: int) -> void:
	schedule_dirty = true

func _zone_changed(_index: int) -> void:
	schedule_dirty = true

func _remember_schedule() -> void:
	var policy := _metadata(policy_option)
	var food := _metadata(feed_preference)
	var zone := int(zone_option.get_item_metadata(zone_option.selected))
	schedule_dirty = false
	GameState.confirm_operation(GameState.ranch_set_schedule(policy, zone, food))

func _build_handbook() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ranch_handbook.json"))
	if data is Dictionary: handbook_blocks = data.get("blocks", [])
	handbook_overlay = Control.new()
	handbook_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	handbook_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(handbook_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.05, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	handbook_overlay.add_child(dim)
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 40; paper.offset_right = -40
	paper.offset_top = 35; paper.offset_bottom = -35
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e3b30")
	style.border_color = Color("b0b886")
	style.set_border_width_all(3)
	style.set_content_margin_all(18)
	paper.add_theme_stylebox_override("panel", style)
	handbook_overlay.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	paper.add_child(column)
	var title := Label.new()
	title.text = "东坡 · 牧场手册"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	handbook_scroll = ScrollContainer.new()
	handbook_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	handbook_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	handbook_scroll.focus_mode = Control.FOCUS_ALL
	column.add_child(handbook_scroll)
	handbook_content = VBoxContainer.new()
	handbook_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	handbook_content.add_theme_constant_override("separation", 12)
	handbook_scroll.add_child(handbook_content)
	handbook_close = _button("返回牧场名册", close_handbook)
	column.add_child(handbook_close)
	handbook_close.focus_next = handbook_scroll.get_path()
	handbook_close.focus_previous = handbook_scroll.get_path()
	handbook_scroll.focus_next = handbook_close.get_path()
	handbook_scroll.focus_previous = handbook_close.get_path()
	handbook_overlay.hide()

func _fill_handbook() -> void:
	for child in handbook_content.get_children():
		handbook_content.remove_child(child)
		child.queue_free()
	for block in handbook_blocks:
		var label := Label.new()
		label.text = str(block.text)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if str(block.kind) == "heading":
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color("dfcfaa"))
		handbook_content.add_child(label)
	for notice in GameState.ranch.notices:
		var label := Label.new()
		label.text = "第 %d 天 · %s" % [int(notice.day) + 1, str(notice.text)]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		handbook_content.add_child(label)

func open_handbook() -> void:
	_fill_handbook()
	handbook_scroll.scroll_vertical = 0
	handbook_overlay.show()
	handbook_close.grab_focus()

func close_handbook() -> void:
	handbook_overlay.hide()
	handbook_button.grab_focus()

func handbook_open() -> bool:
	return handbook_overlay.visible

func _fill_store() -> void:
	var selected := _metadata(store_item) if store_item.item_count > 0 else "feed"
	store_item.clear()
	for item_id in FEED_IDS:
		store_item.add_item(str(GameState.item_catalog.get(item_id, {}).get("name", item_id)))
		store_item.set_item_metadata(store_item.item_count - 1, item_id)
	_select_meta(store_item, selected)

func _store(withdraw: bool) -> void:
	GameState.confirm_operation(GameState.ranch_store(_metadata(store_item), int(store_amount.value), withdraw))

func _fill_recipes() -> void:
	var selected := _metadata(recipe_option) if recipe_option.item_count > 0 else "hay"
	recipe_option.clear()
	var recipes: Dictionary = GameState.system_catalog.get("ranch", {}).get("recipes", {})
	for recipe_id in RECIPE_IDS:
		if not recipes.has(recipe_id): continue
		var recipe: Dictionary = recipes[recipe_id]
		recipe_option.add_item("%s → %s ×%d" % [str(recipe.get("name", recipe_id)), str(GameState.item_catalog.get(str(recipe.get("out", "")), {}).get("name", recipe.get("out", "成品"))), int(recipe.get("qty", 1))])
		recipe_option.set_item_metadata(recipe_option.item_count - 1, recipe_id)
	_select_meta(recipe_option, selected)

func _craft_recipe() -> void:
	var id := _metadata(recipe_option)
	if id in ["cream", "yogurt"]:
		GameState.queue_kitchen_task({"op":"process","id":id,"n":int(recipe_amount.value),"station":"dairy"})
	else:
		GameState.queue_ranch_tasks([{"barnId":"cattle","action":"craft","arg":id,"quantity":int(recipe_amount.value)}])

func _fill_pet() -> void:
	var pet: Dictionary = GameState.ranch.get("pet", {})
	var companion: Dictionary = GameState.pet_state
	pet_detail.text = "%s「%s」· 好感 %d · 饥饿 %d · 精力 %d · 训练 %d\n当前模式：%s · %s" % ["小狗" if str(companion.get("type", "cat")) == "dog" else "小猫", str(companion.get("name", "小团")), int(companion.get("bond", 0)), int(pet.get("hunger", 0)), int(pet.get("energy", 0)), int(pet.get("training", 0)), str({"home": "在家", "follow": "跟随", "patrol": "巡看"}.get(str(pet.get("mode", "home")), "在家")), "已达成牧场协助条件" if int(pet.get("training", 0)) >= 20 and int(pet.get("hunger", 0)) >= 35 else "训练到 20、保持饱足后可协助"]

func _fill_rehomed() -> void:
	rehomed_list.clear()
	for record in GameState.ranch.get("rehomed", []):
		var animal: Dictionary = record.get("animal", {})
		rehomed_list.add_item("%s · %s · 接回 %d 元" % [str(animal.get("name", "伙伴")), str(animal.get("species", "动物")), int(record.get("fee", 0))])
		rehomed_list.set_item_metadata(rehomed_list.item_count - 1, str(animal.get("id", "")))

func _select_rehomed(_index: int) -> void:
	pass

func _adopt_selected() -> void:
	var index := rehomed_list.get_selected_items()
	if index.is_empty(): return
	GameState.confirm_operation(GameState.ranch_adopt(str(rehomed_list.get_item_metadata(index[0]))))

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.name = title; scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(scroll)
	if control_scroll == null: control_scroll = scroll
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10); scroll.add_child(column)
	return column

func _refresh_today() -> void:
	for home: String in box_buttons:
		var count: int = preload("res://scripts/ranch_products.gd").box_count(GameState,home)
		var button: Button = box_buttons[home]
		button.text = "%s · 收集箱 %d/48 · 前往领取" % [str(GameState.system_catalog.ranch.barns[home].name),count]
		button.disabled = count==0 or not bool(GameState.ranch.barns[home].built)
	var ready := 0
	for row: Dictionary in GameState.ranch.get("products",[]): ready += int(row.qty)
	var help: int = GameState.ranch_filtered_ids("care").size()
	var demand := 0
	for a: Dictionary in GameState.animals:
		demand += ceili(float(GameState.system_catalog.ranch.species[str(a.type)].feed)*float(GameState.system_catalog.ranch.breeds[str(a.breed)].feed))
	var portions := 0
	for item: String in ["feed","grainFeed","healthFeed"]: portions += int(GameState.ranch.stores.get(item,0))
	today_detail.text = "待收产物 %d 份  ·  需要帮助 %d 位\n料仓通用饲料 %d 份 · 约 %.1f 天（不含背包与草场）\n孕育 %d 窝 · 草圈 %d%% / %d%%" % [ready,help,portions,float(portions)/maxi(1,demand),GameState.ranch.births.size(),int(GameState.ranch.grass[0]),int(GameState.ranch.grass[1])]

	if not GameState.ranch.births.is_empty():
		today_detail.text += "\n"+"、".join(GameState.ranch.births.map(func(birth:Dictionary):return str(GameState.system_catalog.ranch.species[str(birth.type)].name)+"还需 "+str(birth.remaining)+" 天"))

func _smart_care() -> void:
	var tasks: Array = []
	for a: Dictionary in GameState.animals:
		var action: String = GameState.ranch_default_action(GameState.ranch_animal_index(str(a.id)))
		if action == "pet" and int(a.care.pet) == GameState.day: continue
		tasks.append({"animalId":str(a.id),"action":action,"arg":str(GameState.ranch.feed)})
	GameState.queue_ranch_tasks(tasks)

func _visit_box(home: String) -> void:
	GameState.queue_ranch_tasks([{"barnId":home,"action":"claimBox"}])

func _trough_text(trough: Dictionary) -> String:
	var parts: Array[String] = []
	for item: String in trough:
		if int(trough[item])>0:parts.append(str(GameState.item_catalog.get(item,{}).get("name",item))+" "+str(trough[item]))
	return "、".join(parts) if not parts.is_empty() else "暂空"
