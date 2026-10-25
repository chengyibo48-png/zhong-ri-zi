extends Control
class_name MarketPanel

signal seed_picker_requested

const ITEM_ICON_SCRIPT := preload("res://scripts/item_icon.gd")

var cart: Array = []
var cart_selection := -1
var cart_controls: VBoxContainer
var cart_list: ItemList
var cart_add: Button
var cart_remove: Button
var cart_submit: Button
var inventory_side := "bag"
var inventory_options: HFlowContainer
var category_box: OptionButton
var sort_box: OptionButton
var inventory_page := 0
var page_label: Label
var previous_page: Button
var next_page: Button
var transfer_button: Button
var tidy_button: Button
var mode := "inventory"
var trading_allowed := false
var trade_venue := "shop"
var item_ids: Array[String] = []
var selected_id := ""
var title_label: Label
var balance_label: Label
var search_box: LineEdit
var item_list: ItemList
var detail_label: Label
var detail_icon: Control
var quantity_box: SpinBox
var quantity_row: HBoxContainer
var special_offer_button: CheckButton
var trade_options: HBoxContainer
var grade_box: OptionButton
var channel_box: OptionButton
var theme_box: OptionButton
var action_button: Button
var lock_button: Button
var pin_button: Button
var pins_row: HFlowContainer
var pins_hint: Label
var pin_shortcuts: Array[Button] = []
var mode_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.1, 0.08, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -280
	panel.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color("293b31")
	style.border_color = Color("c5ab76")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.text = "禾溪柜台"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("f3e4bf"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	balance_label = Label.new()
	balance_label.add_theme_color_override("font_color", Color("e6d4a7"))
	header.add_child(balance_label)
	var catalog_button := Button.new()
	catalog_button.text = "物品图录"
	catalog_button.pressed.connect(func(): get_parent().call("show_item_catalog"))
	header.add_child(catalog_button)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for entry in [["inventory", "背包"], ["buy", "购买"], ["sell", "出售"], ["buyback", "回购"], ["business", "合作与订单"], ["ledger", "交易流水"]]:
		var tab := Button.new()
		tab.text = str(entry[1])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_choose_mode.bind(str(entry[0])))
		tabs.add_child(tab)
		mode_buttons[str(entry[0])] = tab
	search_box = LineEdit.new()
	search_box.placeholder_text = "搜索物品名称"
	search_box.text_changed.connect(_on_search)
	column.add_child(search_box)
	inventory_options = HFlowContainer.new()
	column.add_child(inventory_options)
	for entry in [["bag","随身物品"],["storage","储物柜"]]:
		var side_button := Button.new()
		side_button.text = str(entry[1])
		side_button.pressed.connect(_choose_inventory_side.bind(str(entry[0])))
		inventory_options.add_child(side_button)
	category_box = OptionButton.new()
	for category in ["全部","种子","鲜蔬谷果","鱼蛋奶肉","料理","加工物","农资","材料"]: category_box.add_item(category)
	category_box.item_selected.connect(func(_index: int): inventory_page = 0; refresh())
	inventory_options.add_child(category_box)
	sort_box = OptionButton.new()
	for label in ["名称","数量","价值","先用食材"]: sort_box.add_item(label)
	sort_box.item_selected.connect(func(_index: int): inventory_page = 0; refresh())
	inventory_options.add_child(sort_box)
	previous_page = Button.new()
	previous_page.text = "‹"
	previous_page.pressed.connect(_change_inventory_page.bind(-1))
	inventory_options.add_child(previous_page)
	page_label = Label.new()
	inventory_options.add_child(page_label)
	next_page = Button.new()
	next_page.text = "›"
	next_page.pressed.connect(_change_inventory_page.bind(1))
	inventory_options.add_child(next_page)
	tidy_button = Button.new()
	tidy_button.pressed.connect(_begin_storage_transfer.bind(true))
	inventory_options.add_child(tidy_button)
	pins_row = HFlowContainer.new()
	pins_row.add_theme_constant_override("h_separation", 6)
	column.add_child(pins_row)
	var pins_title := Label.new()
	pins_title.text = "常用篮"
	pins_row.add_child(pins_title)
	pins_hint = Label.new()
	pins_hint.text = "选物品加入，最多六样，耗尽也不换位。"
	pins_row.add_child(pins_hint)
	for index in range(6):
		var shortcut := Button.new()
		shortcut.pressed.connect(_select_pin.bind(index))
		pins_row.add_child(shortcut)
		pin_shortcuts.append(shortcut)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 15)
	column.add_child(body)
	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(250, 190)
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_selected)
	body.add_child(item_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)
	detail_scroll.add_child(right)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 8)
	right.add_child(detail_row)
	detail_icon = Control.new()
	detail_icon.set_script(ITEM_ICON_SCRIPT)
	detail_icon.custom_minimum_size = Vector2(64, 64)
	detail_row.add_child(detail_icon)
	detail_label = Label.new()
	detail_label.custom_minimum_size = Vector2(200, 150)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.add_theme_color_override("font_color", Color("e8e1ce"))
	detail_row.add_child(detail_label)
	quantity_row = HBoxContainer.new()
	right.add_child(quantity_row)
	var quantity_label := Label.new()
	quantity_label.text = "数量"
	quantity_row.add_child(quantity_label)
	quantity_box = SpinBox.new()
	quantity_box.min_value = 1
	quantity_box.max_value = 99
	quantity_box.step = 1
	quantity_box.value = 1
	quantity_box.value_changed.connect(_on_quantity_changed)
	quantity_row.add_child(quantity_box)
	special_offer_button = CheckButton.new()
	special_offer_button.text = "使用今日特价"
	special_offer_button.toggled.connect(_on_special_offer_toggled)
	right.add_child(special_offer_button)
	trade_options = HBoxContainer.new()
	trade_options.add_theme_constant_override("separation", 5)
	right.add_child(trade_options)
	grade_box = OptionButton.new()
	grade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade_box.add_item("不限 · 普通优先")
	grade_box.set_item_metadata(0, -1)
	for grade in ["普通", "优质", "上品", "珍品"]:
		grade_box.add_item(grade)
		grade_box.set_item_metadata(grade_box.item_count - 1, grade_box.item_count - 2)
	grade_box.select(0)
	grade_box.item_selected.connect(_trade_option_changed)
	trade_options.add_child(grade_box)
	channel_box = OptionButton.new()
	channel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [["instant", "柜台现售"], ["stall", "主题摊位"], ["coop", "合作社"]]:
		channel_box.add_item(str(entry[1]))
		channel_box.set_item_metadata(channel_box.item_count - 1, str(entry[0]))
	channel_box.select(0)
	channel_box.item_selected.connect(_trade_option_changed)
	trade_options.add_child(channel_box)
	theme_box = OptionButton.new()
	theme_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for theme_id in ["breakfast", "orchard", "pantry"]:
		var themes: Dictionary = GameState.system_catalog.get("economy", {}).get("themes", {})
		theme_box.add_item(str(themes.get(theme_id, theme_id)))
		theme_box.set_item_metadata(theme_box.item_count - 1, theme_id)
	theme_box.select(0)
	theme_box.item_selected.connect(_trade_option_changed)
	trade_options.add_child(theme_box)
	transfer_button = Button.new()
	transfer_button.pressed.connect(_begin_storage_transfer.bind(false))
	right.add_child(transfer_button)
	action_button = Button.new()
	action_button.custom_minimum_size.y = 42
	action_button.pressed.connect(_on_action)
	right.add_child(action_button)
	var marks_line := HBoxContainer.new()
	right.add_child(marks_line)
	lock_button = Button.new()
	lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_button.text = "锁定物品"
	lock_button.pressed.connect(_on_lock)
	marks_line.add_child(lock_button)
	pin_button = Button.new()
	pin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin_button.text = "加入常用篮"
	pin_button.pressed.connect(_on_pin)
	marks_line.add_child(pin_button)
	_build_cart(right)
	_bind_scroll_focus(self)
	var hint := Label.new()
	hint.text = "↑↓ 选择 · Tab 切换 · 滚轮浏览 · Esc 返回。交易会先走到对应柜台。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("c4cbaa"))
	column.add_child(hint)
	GameState.changed.connect(refresh)
	visible = false

func open_panel(next_mode: String = "inventory", can_trade: bool = false, venue: String = "shop") -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	trading_allowed = can_trade
	trade_venue = venue
	mode = next_mode if ["inventory", "buy", "sell", "buyback", "business", "ledger"].has(next_mode) else "inventory"
	selected_id = ""
	special_offer_button.set_pressed_no_signal(false)
	search_box.clear()
	visible = true
	GameState.ui_open = true
	refresh()
	item_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _choose_mode(next_mode: String) -> void:
	mode = next_mode
	selected_id = ""
	special_offer_button.set_pressed_no_signal(false)
	quantity_box.value = 1
	refresh()
	item_list.grab_focus()

func _on_search(_value: String) -> void:
	inventory_page = 0
	_refresh_items()

func _on_selected(index: int) -> void:
	if index >= 0 and index < item_ids.size():
		selected_id = item_ids[index]
		special_offer_button.set_pressed_no_signal(false)
		_refresh_details()

func _on_special_offer_toggled(pressed: bool) -> void:
	if pressed and GameState.daily_offers().has(selected_id):
		var bought: Dictionary = GameState.economy.get("daily", {}).get("bought", {})
		var remaining := maxi(0, 5 - int(bought.get(selected_id, 0)))
		if remaining > 0:
			quantity_box.max_value = remaining
		else:
			special_offer_button.set_pressed_no_signal(false)
	_refresh_details()

func _on_quantity_changed(_value: float) -> void:
	_refresh_details()

func _trade_option_changed(_index: int) -> void:
	_refresh_details()

func refresh() -> void:
	if cart_controls!=null: _refresh_cart()
	if not visible or not is_instance_valid(item_list):
		return
	title_label.text = ("禾溪合作社" if trade_venue == "coop" else "老街货摊" if trade_venue == "stall" else "禾溪柜台") if mode!="inventory" else ("我的储物柜" if inventory_side == "storage" else "我的背包")
	balance_label.text = "金币 %d    " % GameState.money
	for key in mode_buttons:
		var tab: Button = mode_buttons[key]
		tab.visible = true
		tab.disabled = key == mode
	_refresh_pins()
	_refresh_items()
	_refresh_cart()

func _refresh_items() -> void:
	if mode=="buy": GameState._refresh_economy_day(true)
	preload("res://scripts/item_art.gd").fit_list(item_list)
	item_list.clear()
	item_ids.clear()
	var candidates: Array[String] = []
	if mode == "inventory":
		var order: String = ["name","count","value","fresh"][sort_box.selected]
		var matched := GameState.inventory_item_ids(inventory_side,category_box.get_item_text(category_box.selected),search_box.text,order)
		var max_page := maxi(0,ceili(float(matched.size())/18.0)-1)
		inventory_page = clampi(inventory_page,0,max_page)
		page_label.text = "%d类 %d/%d" % [matched.size(),inventory_page+1,max_page+1]
		previous_page.disabled = inventory_page == 0
		next_page.disabled = inventory_page >= max_page
		candidates.assign(matched.slice(inventory_page*18,(inventory_page+1)*18))
	elif mode == "business":
		for job in GameState.economy.get("jobs", []): candidates.append("job:%d" % int(job.get("key", 0)))
		for order in GameState.economy_weekly_orders(): candidates.append("order:%s" % str(order.get("key", "")))
	elif mode == "ledger":
		for index in range(GameState.economy.get("ledger", []).size()): candidates.append("ledger:%d" % index)
	elif mode == "buyback":
		for receipt in GameState.economy.get("receipts", []):
			if GameState.day-int(receipt.get("day",0))>2: continue
			candidates.append(str(receipt.get("key", "")))
	elif mode not in ["business", "ledger"]:
		for item_id in GameState.item_catalog:
			var normalized := str(item_id)
			if mode == "buy" and GameState.shop_price(normalized) <= 0:
				continue
			var holdings: Dictionary = GameState.storage if mode == "inventory" and inventory_side == "storage" else GameState.inventory
			if mode == "inventory" and category_box.selected > 0 and GameState.economy_category(normalized) != category_box.get_item_text(category_box.selected): continue
			if mode != "buy" and int(holdings.get(normalized, 0)) <= 0:
				continue
			candidates.append(normalized)
		candidates.sort_custom(func(a, b): return str(GameState.item_catalog[a].get("name", a)) < str(GameState.item_catalog[b].get("name", b)))
	for candidate in candidates:
		var name := ""
		if mode == "ledger" and candidate.begins_with("ledger:"):
			var ledger_index := int(candidate.trim_prefix("ledger:"))
			var ledger: Array = GameState.economy.get("ledger", [])
			if ledger_index >= 0 and ledger_index < ledger.size():
				var row: Dictionary = ledger[ledger_index]
				name = "第 %d 天 · %s · %s ×%d" % [int(row.get("day", 0)) + 1, str(row.get("kind", "交易")), GameState.item_catalog.get(str(row.get("id", "")), {}).get("name", row.get("id", "物品")), int(row.get("qty", 0))]
		elif mode == "business" and candidate.begins_with("job:"):
			var job_key := int(candidate.trim_prefix("job:"))
			for job in GameState.economy.get("jobs", []):
				if int(job.get("key", -1)) != job_key: continue
				var ready := float(job.get("ready", 0)) <= GameState._kitchen_now()
				var channel_name := "合作社代销" if str(job.get("channel", "")) == "coop" else "主题摊位"
				name = "%s · %s ×%d · %s" % [channel_name, GameState.item_catalog.get(str(job.id), {}).get("name", job.id), int(job.qty), "待领取" if ready else "办理中"]
				break
		elif mode == "business" and candidate.begins_with("order:"):
			var order_key := candidate.trim_prefix("order:")
			for order in GameState.economy_weekly_orders():
				if str(order.get("key", "")) == order_key:
					name = "%s · %s ×%d" % [str(order.title), GameState.item_catalog.get(str(order.id), {}).get("name", order.id), int(order.qty)]
					break
		elif mode == "buyback":
			for receipt in GameState.economy.get("receipts", []):
				if str(receipt.get("key", "")) == candidate:
					name = "%s ×%d · %d 元" % [GameState.item_catalog.get(str(receipt.id), {}).get("name", receipt.id), int(receipt.qty), int(receipt.price)]
					break
		elif mode not in ["business", "ledger"]:
			name = str(GameState.item_catalog[candidate].get("name", candidate))
			if mode == "buy":
				name += "  %d 元" % GameState.shop_price(candidate)
				if GameState.daily_offers().has(candidate):
					name = "★ " + name
			else:
				name += "  ×%d" % int((GameState.storage if mode == "inventory" and inventory_side == "storage" else GameState.inventory).get(candidate, 0))
		if mode != "inventory" and search_box.text.strip_edges() != "" and not name.containsn(search_box.text.strip_edges()):
			continue
		item_ids.append(candidate)
		item_list.add_item(name, preload("res://scripts/item_art.gd").texture_for(_illustration_id(candidate)))
	if mode == "inventory" and GameState.item_catalog.has(selected_id) and not item_ids.has(selected_id):
		item_list.deselect_all()
		_refresh_details()
		return
	if item_ids.is_empty():
		selected_id = ""
		_refresh_details()
		return
	var index := item_ids.find(selected_id)
	if index < 0:
		index = 0
		selected_id = item_ids[0]
	item_list.select(index)
	_refresh_details()

func _refresh_details() -> void:
	detail_icon.call("configure", selected_id if GameState.item_catalog.has(selected_id) else "")
	action_button.disabled = selected_id == ""
	lock_button.visible = mode == "inventory" or mode == "sell"
	lock_button.disabled = not GameState.item_catalog.has(selected_id)
	pin_button.visible = mode == "inventory"
	pin_button.disabled = not GameState.item_catalog.has(selected_id)
	pin_button.text = "移出常用篮" if GameState.economy.get("pinned", []).has(selected_id) else "加入常用篮"
	inventory_options.visible = mode == "inventory"
	tidy_button.text = "本类存余量 · 留 5 份" if inventory_side == "bag" else "本类补给 · 补到 5 份"
	tidy_button.disabled = not bool(GameState.upgrades.get("storage", false))
	transfer_button.visible = mode == "inventory"
	transfer_button.text = "存入储物柜" if inventory_side == "bag" else "取回随身"
	transfer_button.disabled = not bool(GameState.upgrades.get("storage", false)) or not GameState.item_catalog.has(selected_id)
	quantity_row.visible = mode in ["buy", "sell", "inventory"]
	quantity_box.visible = quantity_row.visible
	special_offer_button.visible = mode == "buy" and selected_id != "" and GameState.daily_offers().has(selected_id)
	var bought: Dictionary = GameState.economy.get("daily", {}).get("bought", {})
	var offer_remaining := maxi(0, 5 - int(bought.get(selected_id, 0))) if special_offer_button.visible else 0
	special_offer_button.disabled = offer_remaining <= 0
	special_offer_button.text = "今日特价已售罄" if offer_remaining <= 0 else "使用今日特价（余 %d 份）" % offer_remaining
	if not special_offer_button.visible or offer_remaining <= 0:
		special_offer_button.set_pressed_no_signal(false)
	quantity_box.max_value = 999999 if mode in ["sell","inventory"] else maxi(1, offer_remaining) if special_offer_button.button_pressed else 99
	trade_options.visible = mode in ["sell","inventory"]
	grade_box.visible = mode in ["sell","inventory"]
	channel_box.visible = mode == "sell"
	theme_box.visible = mode == "sell" and str(channel_box.get_item_metadata(channel_box.selected)) == "stall"
	if mode == "business":
		_refresh_business_details()
		return
	if mode == "ledger":
		_refresh_ledger_details()
		return
	if selected_id == "":
		detail_label.text = "当前没有符合条件的物品。"
		action_button.text = "暂无可操作项目"
		return
	if mode == "buyback":
		for receipt in GameState.economy.get("receipts", []):
			if str(receipt.get("key", "")) == selected_id:
				var cost := int(receipt.price) + maxi(1, ceili(float(receipt.price) * 0.05))
				detail_label.text = "%s ×%d\n原售 %d 元 · 回购 %d 元\n品质原样保留；售出后两天内可取回。" % [GameState.item_catalog.get(str(receipt.id), {}).get("name", receipt.id), int(receipt.qty), int(receipt.price), cost]
				action_button.text = "回购 %d 元" % cost
				action_button.disabled = GameState.money < cost
				return
		return
	var data: Dictionary = GameState.item_catalog.get(selected_id, {})
	var from_storage := mode == "inventory" and inventory_side == "storage"
	var amount := int((GameState.storage if from_storage else GameState.inventory).get(selected_id, 0))
	var grade_counts: Array[int] = GameState._storage_quality_counts(selected_id) if from_storage else GameState._quality_counts(selected_id)
	var grades := "普通 %d · 优质 %d · 上品 %d · 珍品 %d" % [grade_counts[0], grade_counts[1], grade_counts[2], grade_counts[3]]
	detail_label.text = "%s\n%s\n背包 %d 份\n%s" % [data.get("name", selected_id), data.get("kind", "物品"), amount, grades]
	if from_storage: detail_label.text = detail_label.text.replace("背包 ", "储物柜 ")
	var quantity := int(quantity_box.value)
	if mode == "inventory":
		var meta: Dictionary = GameState.inventory_metadata.get(selected_id,{})
		detail_label.text += "\n来源：" + str(meta.get("sources",""))
		var uses: Array = meta.get("uses",[])
		detail_label.text += "\n常用去向：" + ("、".join(uses) if not uses.is_empty() else "自用、交易或赠送")
		var likes: Array = meta.get("likes",[])
		if not likes.is_empty(): detail_label.text += "\n喜欢这份心意：" + "、".join(likes)
		var chosen_grade := int(grade_box.get_item_metadata(grade_box.selected)) if grade_box.selected >= 0 else -1
		var available := 0
		for tier in range(4):
			if chosen_grade < 0 or chosen_grade == tier: available += grade_counts[tier]
		transfer_button.disabled = transfer_button.disabled or quantity > available
		detail_label.text += "\n" + ("所选数量可用" if quantity <= available else "所选品质 / 数量不足")
		if GameState._is_food(selected_id):
			var fresh: Dictionary = GameState.food_freshness(selected_id, maxi(1,mini(quantity,amount)), "storage" if from_storage else "bag")
			detail_label.text += "\n%s · 这批平均陈放 %.1f 天" % [str(fresh.label),float(fresh.age)]
	if mode == "buy":
		var regular_unit := GameState.shop_price(selected_id)
		var is_offer := GameState.daily_offers().has(selected_id)
		var special_unit := maxi(ceili(float(data.get("price", 0)) * 1.85), floori(float(regular_unit) * 0.9))
		var use_special := is_offer and special_offer_button.button_pressed
		var unit_price := special_unit if use_special else regular_unit
		var price := unit_price * quantity
		if is_offer:
			detail_label.text += "\n今日特价 %d 元/份 · 剩余 %d/5 份；普通货架 %d 元/份。" % [special_unit, offer_remaining, regular_unit]
		else:
			detail_label.text += "\n普通货架 %d 元/份。" % regular_unit
		action_button.text = ("按特价购买 %d 份 · %d 元" if use_special else "按常价购买 %d 份 · %d 元") % [quantity, price]
		action_button.disabled = GameState.money < price or (use_special and (quantity > offer_remaining or quantity > 5))
	elif mode == "sell":
		var grade := int(grade_box.get_item_metadata(grade_box.selected)) if grade_box.selected >= 0 else -1
		var channel := str(channel_box.get_item_metadata(channel_box.selected)) if channel_box.selected >= 0 else "instant"
		var theme := str(theme_box.get_item_metadata(theme_box.selected)) if theme_box.selected >= 0 else "breakfast"
		var quote := GameState.economy_quote(selected_id, quantity, grade, channel, theme)
		var channel_names := {"instant": "柜台现售", "stall": "主题摊位", "coop": "合作社代销"}
		detail_label.text += "\n%s · 预计 %d 元 · 品质折算 ×%.2f · 新鲜度 %.0f%%" % [str(channel_names.get(channel, channel)), int(quote.get("money", 0)), float(quote.get("quality", 1.0)), float(quote.get("freshness", 1.0)) * 100.0]
		if channel == "stall": detail_label.text += "\n%s；布摊耗 3 体力，90 分钟后结算。" % ("契合摊位主题，溢价 12%" if GameState._economy_theme_matches(selected_id, theme) else "普通陈列，溢价 4%")
		elif channel == "coop": detail_label.text += "\n合作社锁价加 8%，次日 6:30 后领取，单批最多 99 份。"
		action_button.text = "出售 %d 份" % quantity if channel == "instant" else "摆上主题摊位" if channel == "stall" else "交合作社代销"
		action_button.disabled = not bool(quote.get("available", false)) or GameState.economy.get("locked", []).has(selected_id) or (channel == "stall" and quantity > 12) or (channel == "coop" and quantity > 99)
	else:
		if int(data.get("energy", 0)) > 0:
			action_button.text = "吃一份 · 体力 +%d" % int(data.energy)
		elif str(data.get("kind", "")) == "种子":
			action_button.text = "选为播种"
		else:
			action_button.text = "查看物品"
		action_button.disabled = amount <= 0 or from_storage or (GameState.economy.get("locked", []).has(selected_id) and (int(data.get("energy",0)) > 0 or str(data.get("kind","")) == "种子"))
	if mode in ["inventory", "sell"]:
		lock_button.text = "解除锁定" if GameState.economy.get("locked", []).has(selected_id) else "锁定物品"

func _refresh_ledger_details() -> void:
	lock_button.visible = false
	quantity_box.visible = false
	trade_options.visible = false
	if selected_id == "":
		detail_label.text = "还没有交易记录。"
		action_button.text = "暂无流水"
		action_button.disabled = true
		return
	var ledger_index := int(selected_id.trim_prefix("ledger:")) if selected_id.begins_with("ledger:") else -1
	var ledger: Array = GameState.economy.get("ledger", [])
	if ledger_index < 0 or ledger_index >= ledger.size():
		detail_label.text = "这条流水已经不在最近 80 笔记录中。"
		action_button.text = "记录已滚出"
		action_button.disabled = true
		return
	var row: Dictionary = ledger[ledger_index]
	var amount := int(row.get("money", 0))
	var item_id := str(row.get("id", ""))
	detail_label.text = "第 %d 天 · %s\n%s ×%d\n%s\n账目变化：%s%d 元\n最近交易保留 80 笔。" % [int(row.get("day", 0)) + 1, str(row.get("kind", "交易")), GameState.item_catalog.get(item_id, {}).get("name", item_id), int(row.get("qty", 0)), str(GameState.item_catalog.get(item_id, {}).get("kind", "物品")), "+" if amount > 0 else "", amount]
	action_button.text = "查看流水"
	action_button.disabled = true

func _refresh_business_details() -> void:
	lock_button.visible = false
	if selected_id == "":
		detail_label.text = "没有在途货单或本周供货单。\n供货信用 %d · 信用满 20 后，货单上限由 4 张提高到 8 张。" % int(GameState.economy.get("rep", 0))
		action_button.text = "暂无业务"
		action_button.disabled = true
		return
	if selected_id.begins_with("job:"):
		var job_key := int(selected_id.trim_prefix("job:"))
		for job in GameState.economy.get("jobs", []):
			if int(job.get("key", -1)) != job_key: continue
			var channel := str(job.get("channel", ""))
			var ready := float(job.get("ready", 0)) <= GameState._kitchen_now()
			detail_label.text = "%s · %s ×%d\n锁定货款 %d 元\n%s\n%s" % ["合作社代销" if channel == "coop" else "主题摊位", GameState.item_catalog.get(str(job.id), {}).get("name", job.id), int(job.qty), int(job.price), "可以领取" if ready else "还需 %d 游戏分钟" % ceili(maxf(0.0, float(job.ready) - GameState._kitchen_now())), "可领取或撤回，撤回会按已陈放天数恢复食材新鲜度。"]
			action_button.text = "领取货款 · %d 元" % int(job.price)
			action_button.disabled = not ready
			lock_button.visible = true
			lock_button.text = "撤回原货"
			lock_button.disabled = false
			return
	if selected_id.begins_with("order:"):
		var order_key := selected_id.trim_prefix("order:")
		for order in GameState.economy_weekly_orders():
			if str(order.get("key", "")) != order_key: continue
			var item_id := str(order.id)
			var available := 0
			var counts := GameState._quality_counts(item_id)
			for grade in range(int(order.grade), 4): available += counts[grade]
			var done: Array = GameState.economy.get("claimed", [])
			var claimed := done.has(order_key)
			detail_label.text = "%s\n%s ×%d · %s及以上\n当前可交 %d 份 · 完成回礼 %d 元 + 15%% 品质溢价\n供货信用 +3；每周可交一次。" % [str(order.title), GameState.item_catalog.get(item_id, {}).get("name", item_id), int(order.qty), ["普通", "优质", "上品", "珍品"][int(order.grade)], available, int(order.bonus)]
			action_button.text = "本周已交付" if claimed else "查看已接订单" if GameState.quests.entries.has("weekly:"+order_key) else "查看并接取供货单"
			action_button.disabled = claimed
			return
	detail_label.text = "这张货单不存在或已经换周。"
	action_button.text = "已结束"
	action_button.disabled = true

func _on_action() -> void:
	match mode:
		"buy": GameState.queue_building_task({"op":"economy-buy","id":selected_id,"n":int(quantity_box.value),"special":special_offer_button.button_pressed})
		"sell":
			var grade := int(grade_box.get_item_metadata(grade_box.selected)) if grade_box.selected >= 0 else -1
			var channel := str(channel_box.get_item_metadata(channel_box.selected)) if channel_box.selected >= 0 else "instant"
			var theme := str(theme_box.get_item_metadata(theme_box.selected)) if theme_box.selected >= 0 else "breakfast"
			if channel == "instant": GameState.queue_building_task({"op":"economy-sell","id":selected_id,"n":int(quantity_box.value),"grade":grade})
			else: GameState.queue_building_task({"op":"economy-send","id":selected_id,"n":int(quantity_box.value),"grade":grade,"channel":channel,"theme":theme})
		"buyback": GameState.queue_building_task({"op":"economy-buyback","key":int(selected_id)})
		"business":
			if selected_id.begins_with("job:"): GameState.queue_building_task({"op":"economy-collect","key":int(selected_id.trim_prefix("job:"))})
			elif selected_id.begins_with("order:"):
				var quest_id: String="weekly:"+selected_id.trim_prefix("order:")
				get_parent().life_plan_panel.open_panel(quest_id,"active" if GameState.quests.entries.has(quest_id) else "available")
		"inventory":
			var item: Dictionary = GameState.item_catalog.get(selected_id, {})
			if int(item.get("energy", 0)) > 0:
				var food_id:=selected_id
				var saved_mode:=mode
				var restore:=func():
					if is_instance_valid(self):
						visible=true
						GameState.ui_open=true
						mode=saved_mode
						selected_id=food_id
						refresh()
				close()
				if not GameState.begin_eating(food_id,action_button.text,restore):restore.call()
			elif str(item.get("kind", "")) == "种子" and int(GameState.inventory.get(selected_id, 0)) > 0:
				var crop_id := ""
				for candidate in GameState.crop_catalog:
					if GameState.seed_item_id(str(candidate)) == selected_id:
						crop_id = str(candidate)
						break
				if crop_id == "":
					close()
					seed_picker_requested.emit()
				elif GameState.choose_normal_seed(crop_id, false):
					close()
			else:
				GameState.message = "背包里有%s ×%d。" % [item.get("name", selected_id), int(GameState.inventory.get(selected_id, 0))]
	refresh()

func _on_lock() -> void:
	if mode == "business" and selected_id.begins_with("job:"):
		GameState.queue_building_task({"op":"economy-collect","key":int(selected_id.trim_prefix("job:")),"cancel":true})
	else:
		_begin_inventory_mark(false)

func _change_inventory_page(delta: int) -> void:
	inventory_page += delta
	refresh()

func _choose_inventory_side(side: String) -> void:
	inventory_page = 0
	inventory_side = side
	selected_id = ""
	quantity_box.value = 1
	refresh()
	item_list.grab_focus()

func _begin_storage_transfer(tidy: bool) -> void:
	if GameState.action_busy(): return
	var id := selected_id
	var side := inventory_side
	var amount := int(quantity_box.value)
	var grade_index := grade_box.selected
	var grade := int(grade_box.get_item_metadata(grade_index)) if grade_index >= 0 else -1
	var category_index := category_box.selected
	var category := category_box.get_item_text(category_index)
	var search := search_box.text
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		mode = "inventory"
		inventory_side = side
		selected_id = id
		search_box.text = search
		category_box.select(category_index)
		quantity_box.value = amount
		grade_box.select(grade_index)
		refresh()
		var focus_button := tidy_button if tidy else transfer_button
		if focus_button.disabled: grade_box.grab_focus()
		else: focus_button.grab_focus()
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		if tidy: GameState.confirm_operation(GameState.economy_tidy(category, side == "bag"))
		else: GameState.confirm_operation(GameState.economy_transfer(id, amount, side == "bag", grade))
		restore.call()
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	var action := GameState.ACTION_RULES.ui("ec-tidy" if tidy else "ec-transfer", (tidy_button if tidy else transfer_button).text)
	action.item = id
	if not GameState.begin_action(action, {"kind":"ui","x":position.x,"y":position.y},commit,restore): restore.call()

func _refresh_pins() -> void:
	pins_row.visible = mode == "inventory"
	var pinned: Array = GameState.economy.get("pinned", [])
	pins_hint.visible = pinned.is_empty()
	for index in range(pin_shortcuts.size()):
		var button := pin_shortcuts[index]
		button.visible = index < pinned.size()
		if index < pinned.size():
			var id := str(pinned[index])
			button.text = "%s ×%d" % [str(GameState.item_catalog.get(id, {}).get("name", id)), int(GameState.inventory.get(id, 0))]

func _select_pin(index: int) -> void:
	var pinned: Array = GameState.economy.get("pinned", [])
	if index < 0 or index >= pinned.size(): return
	selected_id = str(pinned[index])
	search_box.clear()
	_refresh_items()
	pin_button.grab_focus()

func _on_pin() -> void:
	_begin_inventory_mark(true)

func _begin_inventory_mark(pin: bool) -> void:
	if GameState.action_busy() or not GameState.item_catalog.has(selected_id): return
	var item_id := selected_id
	var saved_mode := mode
	var saved_search := search_box.text
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var button := pin_button if pin else lock_button
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		mode = saved_mode
		selected_id = item_id
		search_box.text = saved_search
		refresh()
		if button.disabled: item_list.grab_focus()
		else: button.grab_focus()
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		if pin: GameState.confirm_operation(GameState.toggle_item_pin(item_id))
		else: GameState.confirm_operation(GameState.toggle_item_lock(item_id))
		restore.call()
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	var spec := GameState.ACTION_RULES.ui("ec-pin" if pin else "ec-lock", button.text)
	spec.item = item_id
	if not GameState.begin_action(spec, {"kind": "ui", "id": item_id, "x": position.x, "y": position.y}, commit, restore): restore.call()

func _bind_scroll_focus(node: Node) -> void:
	if node is Control:
		node.focus_entered.connect(func():
			var parent: Node = node.get_parent()
			while parent!=null:
				if parent is ScrollContainer:
					_scroll_to_focus(parent,node)
					break
				parent = parent.get_parent())
	for child in node.get_children(): _bind_scroll_focus(child)

func _scroll_to_focus(scroll: ScrollContainer,control: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(control): scroll.ensure_control_visible(control)

func _build_cart(parent: Control) -> void:
	cart_controls = VBoxContainer.new()
	parent.add_child(cart_controls)
	cart_add = Button.new()
	cart_add.text = "把本批放进售货篮"
	cart_add.pressed.connect(_add_cart)
	cart_controls.add_child(cart_add)
	cart_list = ItemList.new()
	cart_list.custom_minimum_size.y = 105
	cart_list.item_selected.connect(func(index: int): cart_selection=index; _refresh_cart())
	cart_controls.add_child(cart_list)
	var row := HBoxContainer.new()
	cart_controls.add_child(row)
	cart_remove = Button.new()
	cart_remove.text = "移出所选"
	cart_remove.pressed.connect(func():
		if cart_selection>=0 and cart_selection<cart.size(): cart.remove_at(cart_selection)
		cart_selection = -1
		_refresh_cart())
	row.add_child(cart_remove)
	var clear := Button.new()
	clear.text = "清空售货篮"
	clear.pressed.connect(func(): cart.clear();cart_selection=-1;_refresh_cart())
	row.add_child(clear)
	cart_submit = Button.new()
	cart_submit.pressed.connect(func(): GameState.queue_building_task({"op":"economy-batch","lines":cart.duplicate(true)}))
	cart_controls.add_child(cart_submit)
	var hint := Label.new()
	hint.text = "整篮到达柜台后重新核对；任一货签不足或已锁定，整篮拒绝结算。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cart_controls.add_child(hint)

func _refresh_cart() -> void:
	cart_controls.visible = mode=="sell"
	cart_list.clear()
	for line in cart:
		cart_list.add_item("%s ×%d · %s"%[str(GameState.item_catalog.get(str(line.id),{}).get("name",line.id)),int(line.n),"普通优先" if int(line.grade)<0 else ["普通","优质","上品","珍品"][int(line.grade)]])
	if cart_selection>=0 and cart_selection<cart_list.item_count: cart_list.select(cart_selection)
	cart_remove.disabled = cart_selection<0 or cart_selection>=cart.size()
	cart_submit.disabled = cart.is_empty()
	cart_submit.text = "走去整篮出售 · %d / 12 条"%cart.size()
	cart_add.disabled = selected_id=="" or cart.size()>=12

func _add_cart() -> void:
	var grade := int(grade_box.get_item_metadata(grade_box.selected)) if grade_box.selected>=0 else -1
	var quantity := int(quantity_box.value)
	if cart.size()>=12 or not bool(GameState.economy_quote(selected_id,quantity,grade).get("available",false)) or GameState.economy.get("locked",[]).has(selected_id):
		GameState.message = "售货篮最多十二条，请确认数量、品质和保护状态。"
		GameState.changed.emit()
		return
	cart.append({"id":selected_id,"n":quantity,"grade":grade})
	_refresh_cart()

func _illustration_id(candidate: String) -> String:
	if GameState.item_catalog.has(candidate): return candidate
	if candidate.begins_with("ledger:"):
		var index := int(candidate.trim_prefix("ledger:"))
		var rows: Array = GameState.economy.get("ledger", [])
		return str(rows[index].get("id", "")) if index >= 0 and index < rows.size() else ""
	var rows: Array = GameState.economy_weekly_orders() if candidate.begins_with("order:") else GameState.economy.get("jobs", []) if candidate.begins_with("job:") else GameState.economy.get("receipts", [])
	var key := candidate.get_slice(":", 1) if candidate.contains(":") else candidate
	for row in rows:
		if str(row.get("key", "")) == key: return str(row.get("id", ""))
	return ""
