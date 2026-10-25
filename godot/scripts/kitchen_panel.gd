extends Control
class_name KitchenPanel

var mode := "cook"
var can_work := false
var preferred_station := ""
var entry_ids: Array[String] = []
var selected_id := ""
var title_label: Label
var list: ItemList
var detail_label: Label
var quantity_box: SpinBox
var substitute_button: CheckButton
var manual_button: Button
var action_button: Button
var clean_button: Button
var cold_button: Button
var research_row: HBoxContainer
var first_box: OptionButton
var second_box: OptionButton
var mode_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.10, 0.07, 0.06, 0.87)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -260
	panel.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color("46382f")
	style.border_color = Color("cfb48a")
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
	title_label = Label.new()
	title_label.text = "禾溪小灶 · 家常加工"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("f4dfbb"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for option in [["cook", "菜谱"], ["process", "加工"], ["jobs", "待收"], ["pantry", "食橱"], ["research", "试配"], ["tools", "工位"]]:
		var button := Button.new()
		button.text = str(option[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_mode.bind(str(option[0])))
		tabs.add_child(button)
		mode_buttons[str(option[0])] = button
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(290, 340)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_choose_entry)
	body.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 195
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", Color("f0e2ca"))
	right.add_child(detail_label)
	var quantity_row := HBoxContainer.new()
	right.add_child(quantity_row)
	var quantity_label := Label.new()
	quantity_label.text = "本批份数"
	quantity_row.add_child(quantity_label)
	quantity_box = SpinBox.new()
	quantity_box.min_value = 1
	quantity_box.max_value = 20
	quantity_box.value = 1
	quantity_box.value_changed.connect(_quantity_changed)
	quantity_row.add_child(quantity_box)
	substitute_button = CheckButton.new()
	substitute_button.text = "允许家常替代食材"
	substitute_button.toggled.connect(func(_pressed: bool): _refresh_detail())
	right.add_child(substitute_button)
	action_button = Button.new()
	action_button.custom_minimum_size.y = 42
	action_button.pressed.connect(_act)
	right.add_child(action_button)
	manual_button = Button.new()
	manual_button.text = "亲手掌火"
	manual_button.custom_minimum_size.y = 38
	manual_button.pressed.connect(_manual)
	right.add_child(manual_button)
	clean_button = Button.new()
	clean_button.text = "擦洗所选工位 · 2 体力"
	clean_button.pressed.connect(_clean)
	right.add_child(clean_button)
	cold_button = Button.new()
	cold_button.text = "添置阴凉食橱 · 150 元 / 竹材 6"
	cold_button.pressed.connect(_build_cold)
	right.add_child(cold_button)
	research_row = HBoxContainer.new()
	research_row.add_theme_constant_override("separation", 8)
	right.add_child(research_row)
	first_box = OptionButton.new()
	first_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_row.add_child(first_box)
	second_box = OptionButton.new()
	second_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_row.add_child(second_box)
	var hint := Label.new()
	hint.text = "工位按游戏时间排队，成品需主动收取；试配可领会菜谱。靠近小灶按 E 开工，K 可查阅。"
	hint.add_theme_color_override("font_color", Color("d2c3a9"))
	column.add_child(hint)
	GameState.changed.connect(refresh)
	visible = false

func open_panel(work_allowed: bool = false, start_mode: String = "cook", station_filter: String = "") -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	can_work = work_allowed
	mode = start_mode if ["cook", "process", "jobs", "pantry", "research", "tools"].has(start_mode) else "cook"
	preferred_station = station_filter if mode == "process" else ""
	selected_id = ""
	substitute_button.set_pressed_no_signal(false)
	visible = true
	GameState.ui_open = true
	refresh()
	list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _choose_mode(next_mode: String) -> void:
	mode = next_mode
	selected_id = ""
	substitute_button.set_pressed_no_signal(false)
	refresh()
	list.grab_focus()

func _choose_entry(index: int) -> void:
	if index >= 0 and index < entry_ids.size():
		selected_id = entry_ids[index]
		_refresh_detail()

func _quantity_changed(_value: float) -> void:
	_refresh_detail()


func _needs_text(needs: Dictionary, multiplier: int = 1) -> String:
	var parts: Array[String] = []
	for item_id in needs:
		var required := int(needs[item_id]) * multiplier
		parts.append("%s %d/%d" % [str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), int(GameState.inventory.get(item_id, 0)), required])
	return "、".join(parts)

func _find_job(key: int) -> Dictionary:
	for job in GameState.kitchen.get("jobs", []):
		if int(job.get("key", -1)) == key:
			return job
	return {}

func refresh() -> void:
	if not visible or not is_instance_valid(list):
		return
	for key in mode_buttons:
		mode_buttons[key].disabled = key == mode
	var titles := {"cook": "家常菜谱", "process": "加工工位", "jobs": "待收成品", "pantry": "食橱保鲜", "research": "自由试配", "tools": "工位改良"}
	var title := str(titles.get(mode, "四季食记"))
	if mode == "process" and preferred_station != "":
		title = "%s · %s" % [title, str(GameState.system_catalog.get("kitchen", {}).get("stations", {}).get(preferred_station, {}).get("name", preferred_station))]
	title_label.text = "禾溪小灶 · %s" % title
	entry_ids.clear()
	list.clear()
	if mode == "cook":
		for recipe in GameState.content.get("recipes", []):
			var recipe_id := str(recipe.get("id", ""))
			if not GameState.known_recipes.has(recipe_id):
				continue
			entry_ids.append(recipe_id)
			list.add_item(str(GameState.item_catalog.get(recipe_id, {}).get("name", recipe_id)))
	elif mode == "process":
		for recipe in GameState.system_catalog.get("kitchen", {}).get("processing", []):
			if preferred_station != "" and str(recipe.get("stationId", "stove")) != preferred_station:
				continue
			entry_ids.append(str(recipe.get("id", "")))
			list.add_item(str(recipe.get("name", recipe.get("id", "加工"))))
	elif mode == "jobs":
		for job in GameState.kitchen.get("jobs", []):
			entry_ids.append(str(job.get("key", "")))
			var remaining := ceili(maxf(0.0, float(job.get("ready", 0)) - GameState._kitchen_now()))
			list.add_item("%s ×%d · %s" % [str(GameState.item_catalog.get(str(job.get("id", "")), {}).get("name", job.get("id", ""))), int(job.get("qty", 0)), "可收" if remaining == 0 else "还需 %d 分钟" % remaining])
		for index in range(GameState.legacy_processing.size()):
			var job: Dictionary = GameState.legacy_processing[index]
			var remaining_days := maxi(0, int(job.get("readyDay", GameState.day)) - GameState.day)
			entry_ids.append("legacy:%d" % index)
			list.add_item("旧工序 · %s ×%d · %s" % [str(GameState.item_catalog.get(str(job.get("id", "")), {}).get("name", job.get("id", ""))), int(job.get("qty", 0)), "明早入袋" if remaining_days <= 1 else "%d 天后完成" % remaining_days])
	elif mode == "pantry":
		for side in ["bag", "storage"]:
			var holdings: Dictionary = GameState.inventory if side == "bag" else GameState.storage
			for item_id in holdings:
				if int(holdings[item_id]) <= 0 or not GameState._is_food(str(item_id)):
					continue
				entry_ids.append("%s:%s" % [side, item_id])
				list.add_item("%s · %s ×%d" % ["随身" if side == "bag" else "食橱", str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), int(holdings[item_id])])
	elif mode == "research":
		for signature in GameState.kitchen.get("experiments", []):
			entry_ids.append(str(signature))
			var parts: Array = str(signature).split("+")
			list.add_item("%s ＋ %s" % [str(GameState.item_catalog.get(parts[0], {}).get("name", parts[0])), str(GameState.item_catalog.get(parts[1], {}).get("name", parts[1]))])
	elif mode == "tools":
		for station_id in GameState.system_catalog.get("kitchen", {}).get("stations", {}):
			entry_ids.append(str(station_id))
			list.add_item(str(GameState.system_catalog.kitchen.stations[station_id].get("name", station_id)))
	preload("res://scripts/item_art.gd").fit_list(list)
	for icon_index in range(entry_ids.size()):
		var art_id: String = entry_ids[icon_index]
		if mode == "pantry": art_id = art_id.get_slice(":", 1)
		elif mode == "process":
			for recipe in GameState.system_catalog.get("kitchen", {}).get("processing", []):
				if str(recipe.get("id", "")) == art_id: art_id = str(recipe.get("out", art_id)); break
		elif mode == "jobs":
			if art_id.begins_with("legacy:"):
				art_id = str(GameState.legacy_processing[int(art_id.trim_prefix("legacy:"))].get("id", ""))
			else:
				var job := _find_job(int(art_id))
				art_id = str(job.get("id", ""))
		elif mode == "research": art_id = art_id.get_slice("+", 0)
		list.set_item_icon(icon_index, preload("res://scripts/item_art.gd").texture_for(art_id, "stations" if mode == "tools" else "items"))
	if mode == "research":
		_refresh_research_options()
	if entry_ids.is_empty():
		selected_id = ""
		list.add_item("这里还没有记录")
		list.set_item_disabled(0, true)
	elif not entry_ids.has(selected_id):
		selected_id = entry_ids[0]
	if selected_id != "":
		list.select(entry_ids.find(selected_id))
	_refresh_detail()

func _refresh_research_options() -> void:
	var first_id := str(first_box.get_item_metadata(first_box.selected)) if first_box.selected >= 0 else ""
	var second_id := str(second_box.get_item_metadata(second_box.selected)) if second_box.selected >= 0 else ""
	first_box.clear()
	second_box.clear()
	for item_id in GameState.inventory:
		if int(GameState.inventory[item_id]) <= 0 or not GameState._is_food(str(item_id)) or str(GameState.item_catalog.get(item_id, {}).get("kind", "")) == "料理":
			continue
		var title := "%s ×%d" % [str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), int(GameState.inventory[item_id])]
		for box in [first_box, second_box]:
			box.add_icon_item(preload("res://scripts/item_art.gd").texture_for(str(item_id)), title)
			box.set_item_metadata(box.item_count - 1, str(item_id))
	for box in [first_box, second_box]:
		var desired := first_id if box == first_box else second_id
		for index in range(box.item_count):
			if str(box.get_item_metadata(index)) == desired:
				box.select(index)
				break

func _refresh_detail() -> void:
	if not is_instance_valid(detail_label):
		return
	quantity_box.visible = mode in ["cook", "process", "pantry"]
	substitute_button.visible = mode == "cook"
	manual_button.visible = mode == "cook"
	manual_button.disabled = selected_id == "" or GameState.kitchen_station_for_recipe(selected_id) in ["dry","pickle"]
	clean_button.visible = mode in ["process", "pantry", "tools"]
	cold_button.visible = mode == "pantry"
	cold_button.disabled = not can_work or bool(GameState.kitchen.get("cold", false))
	cold_button.text = "阴凉食橱已备好" if bool(GameState.kitchen.get("cold", false)) else "添置阴凉食橱 · 150 元 / 竹材 6"
	research_row.visible = mode == "research"
	var can_request := can_work or mode in ["cook","process","jobs","research","tools"]
	action_button.disabled = selected_id == "" or not can_request
	if selected_id == "":
		detail_label.text = "选择两种食材，匹配已知配方可领会做法并保留食材；新的搭配会煮成田园汤。" if mode == "research" else "掌握菜谱、备齐食材后，在小灶旁动手。"
		action_button.text = "试配两种食材" if mode == "research" else "暂无可操作项"
		action_button.disabled = not can_request or mode != "research" or first_box.item_count == 0
		return
	if mode == "cook":
		var recipe := GameState.recipe_data(selected_id)
		var base_needs: Dictionary = recipe.get("ingredients", {})
		var quantity := int(quantity_box.value)
		var needs := GameState.kitchen_recipe_needs(recipe, substitute_button.button_pressed, quantity)
		var alternate_needs := GameState.kitchen_recipe_needs(recipe, true, quantity)
		var substitutions: Array[String] = []
		for item_id in base_needs:
			if int(alternate_needs.get(item_id, 0)) < int(base_needs[item_id]):
				var alternate_id := ""
				for candidate in alternate_needs:
					if candidate != item_id and int(alternate_needs[candidate]) > int(base_needs.get(candidate, 0)):
						alternate_id = str(candidate)
						break
				if alternate_id != "": substitutions.append("%s→%s" % [str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), str(GameState.item_catalog.get(alternate_id, {}).get("name", alternate_id))])
		var substitution_hint := "\n家常替代：" + "、".join(substitutions) if not substitutions.is_empty() else ""
		var season_hint := " · 节令限定" if recipe.has("season") else ""
		detail_label.text = "%s%s\n所需：%s%s\n%s\n火候恰好可提高品质；新鲜食材和熟练度也有影响。" % [str(GameState.item_catalog.get(selected_id, {}).get("name", selected_id)), season_hint, _needs_text(needs, quantity), substitution_hint, str(recipe.get("story", "家常做法"))]
		action_button.text = ("家常替代开火" if substitute_button.button_pressed and not substitutions.is_empty() else "开火制作") if can_work else "走到工位制作"
		clean_button.disabled = true
	elif mode == "process":
		var recipe := GameState._processing_recipe(selected_id)
		var station_id := str(recipe.get("stationId", "stove"))
		var station: Dictionary = GameState.system_catalog.get("kitchen", {}).get("stations", {}).get(station_id, {})
		var equipment: Dictionary = GameState.kitchen.get("equipment", {}).get(station_id, {})
		var capacity := 5 + int(equipment.get("level", 0)) * 5
		quantity_box.max_value = capacity
		detail_label.text = "%s · %s\n所需：%s\n产出：%s ×%d\n每批最多 %d 份原料；设备清洁度 %d/100。" % [str(recipe.get("name", selected_id)), str(station.get("name", "工位")), _needs_text(recipe.get("needs", {}), int(quantity_box.value)), str(GameState.item_catalog.get(str(recipe.get("out", selected_id)), {}).get("name", recipe.get("out", selected_id))), int(recipe.get("qty", 1)) * int(quantity_box.value), capacity, int(equipment.get("clean", 100))]
		action_button.text = "投入加工队列" if can_work else "走到工位投料"
		clean_button.disabled = not can_request or int(equipment.get("clean", 100)) >= 100
	elif mode == "jobs":
		if selected_id.begins_with("legacy:"):
			var index := int(selected_id.get_slice(":", 1))
			if index < 0 or index >= GameState.legacy_processing.size():
				detail_label.text = "这项旧工序已经完成。"
				action_button.text = "已自动入袋"
				action_button.disabled = true
			else:
				var job: Dictionary = GameState.legacy_processing[index]
				var remaining_days := maxi(0, int(job.get("readyDay", GameState.day)) - GameState.day)
				var grade := int(job.get("farmGrade", 0))
				detail_label.text = "%s ×%d\n旧版工序 · %s\n%s\n到期后会自动放入背包%s。" % [str(GameState.item_catalog.get(str(job.get("id", "")), {}).get("name", job.get("id", ""))), int(job.get("qty", 0)), str(job.get("station", "腌菜坛")), "明早完成" if remaining_days <= 1 else "%d 天后完成" % remaining_days, " · " + ["普通", "优质", "上品"][clampi(grade, 1, 3) - 1] if grade > 0 else ""]
				action_button.text = "到期自动入袋"
				action_button.disabled = true
			clean_button.disabled = true
		else:
			var job := _find_job(int(selected_id))
			var remaining := ceili(maxf(0.0, float(job.get("ready", 0)) - GameState._kitchen_now()))
			detail_label.text = "%s ×%d · %s\n工位：%s\n%s\n成品从收取时开始保鲜。" % [str(GameState.item_catalog.get(str(job.get("id", "")), {}).get("name", job.get("id", ""))), int(job.get("qty", 0)), ["普通", "优质", "上品", "珍品"][clampi(int(job.get("grade", 0)), 0, 3)], str(job.get("station", "")), "已完成，可收取" if remaining == 0 else "还需 %d 游戏分钟" % remaining]
			action_button.text = "收取成品" if remaining == 0 else "尚未完成"
			action_button.disabled = remaining > 0
	elif mode == "pantry":
		var parts := selected_id.split(":")
		var side := str(parts[0])
		var item_id := str(parts[1])
		var amount := int((GameState.inventory if side == "bag" else GameState.storage).get(item_id, 0))
		var fresh := GameState.food_freshness(item_id, 1, side)
		quantity_box.max_value = maxi(1, amount)
		detail_label.text = "%s · %s ×%d\n%s · 约余 %d 保鲜日\n随身与食橱分别按批次记录新鲜度。阴凉食橱可减缓储藏陈放。" % [str(GameState.item_catalog.get(item_id, {}).get("name", item_id)), "随身" if side == "bag" else "食橱", amount, str(fresh.label), int(fresh.days)]
		action_button.text = "存入食橱" if side == "bag" else "取回背包"
		clean_button.text = "吃 1 份 · 回复体力"
		clean_button.disabled = not can_work or side != "bag" or int(GameState.item_catalog.get(item_id, {}).get("energy", 0)) <= 0 or GameState.stamina >= 100
	elif mode == "research":
		detail_label.text = "搭配手札：%s\n已记下 %d 种新组合；可在右侧重新选料试配。" % [selected_id.replace("+", " ＋ "), GameState.kitchen.get("experiments", []).size()]
		action_button.text = "试配两种食材"
		action_button.disabled = not can_request or first_box.item_count == 0
	else:
		var station: Dictionary = GameState.system_catalog.get("kitchen", {}).get("stations", {}).get(selected_id, {})
		var equipment: Dictionary = GameState.kitchen.get("equipment", {}).get(selected_id, {})
		var level := int(equipment.get("level", 0))
		var available := GameState.kitchen_station_available(selected_id)
		detail_label.text = "%s · %d 级\n清洁度 %d/100 · 每批容量 %d · 队列槽 %d\n%s" % [str(station.get("name", selected_id)), level, int(equipment.get("clean", 100)), 5 + level * 5, 2 + level, "升级需 %d 元、木料 %d、竹材 4。" % [90 + level * 110, 6 + level * 4] if level < 2 else "已经是最顺手的工位。"]
		action_button.text = "改良工位" if available else "先添置设备"
		action_button.disabled = not can_request or not available or level >= 2
		clean_button.text = "擦洗所选工位 · 2 体力"
		clean_button.disabled = not can_request or not available or int(equipment.get("clean", 100)) >= 100

func _manual() -> void:
	if selected_id != "" and not manual_button.disabled:
		GameState.queue_kitchen_task({"op":"manual","id":selected_id,"n":1})

func _act() -> void:
	var task: Dictionary = {}
	if mode == "cook":
		task = {"op":"sub" if substitute_button.button_pressed else "make","id":selected_id,"n":int(quantity_box.value)}
	elif mode == "process":
		task = {"op":"process","id":selected_id,"n":int(quantity_box.value)}
	elif mode == "jobs" and selected_id != "" and not selected_id.begins_with("legacy:"):
		task = {"op":"collect","id":selected_id}
	elif mode == "pantry" and selected_id != "" and can_work:
		var parts := selected_id.split(":")
		GameState.confirm_operation(GameState.transfer_storage(str(parts[1]),int(quantity_box.value),str(parts[0]) == "bag"))
	elif mode == "research" and first_box.item_count > 0:
		task = {"op":"experiment","id":str(first_box.get_selected_metadata()),"second":str(second_box.get_selected_metadata()),"station":"stove"}
	elif mode == "tools" and selected_id != "":
		task = {"op":"upgrade","id":selected_id}
	if not task.is_empty(): GameState.queue_kitchen_task(task)
	refresh()

func _clean() -> void:
	if selected_id == "": return
	if mode == "process":
		var recipe := GameState._processing_recipe(selected_id)
		GameState.queue_kitchen_task({"op":"clean","id":str(recipe.get("stationId","stove"))})
	elif mode == "tools":
		GameState.queue_kitchen_task({"op":"clean","id":selected_id})
	elif mode == "pantry" and can_work:
		var parts := selected_id.split(":")
		if str(parts[0])=="bag":
			var food_id:=str(parts[1])
			var saved_id:=selected_id
			var restore:=func():
				if is_instance_valid(self):
					visible=true
					GameState.ui_open=true
					mode="pantry"
					selected_id=saved_id
					refresh()
			close()
			if not GameState.begin_eating(food_id,clean_button.text,restore):restore.call()
	refresh()

func _build_cold() -> void:
	if can_work:
		GameState.confirm_operation(GameState.build_cold_pantry())
		refresh()
