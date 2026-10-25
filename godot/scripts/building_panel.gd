extends Control
class_name BuildingPanel

const PROJECT_IDS := ["house", "orchard", "granary", "workshop", "well", "nursery"]

var near_sites: Dictionary = {}
var at_home := false
var tab := "projects"
var project_id := "house"
var storage_category := "food"
var furniture_id := "bench"
var zone_id := "court"
var selected_cell := -1
var selected_piece_key := 0
var furniture_rotation := 0
var draft: Array = []
var draft_revision := 0
var draft_epoch := 0
var legacy_layout_rows:VBoxContainer
var project_list: ItemList
var project_details: Label
var project_start: Button
var mode_option: OptionButton
var yard_button: Button
var jobs_label: Label
var milestone_buttons: Dictionary = {}
var furniture_list: ItemList
var furniture_details: Label
var craft_one: Button
var craft_three: Button
var zone_option: OptionButton
var furniture_option: OptionButton
var style_option: OptionButton
var room_use_option: OptionButton
var showcase_option: OptionButton
var cell_spin: SpinBox
var rotation_label: Label
var grid: GridContainer
var layout_details: Label
var place_button: Button
var remove_button: Button
var legacy_tab: ScrollContainer
var legacy_buttons: Dictionary = {}
var close_button: Button
var storage_tab: VBoxContainer
var storage_details: Label
var storage_category_buttons: Dictionary = {}
var storage_store_button: Button
var storage_withdraw_button: Button

const STORAGE_CATEGORIES := {"food": "食材与料理", "seed": "种子", "material": "建设材料", "feed": "牧场补给"}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.10, 0.08, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -270
	panel.offset_bottom = 270
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("2e3b30")
	skin.border_color = Color("b0b886")
	skin.set_border_width_all(3)
	skin.set_corner_radius_all(8)
	skin.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", skin)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "禾溪营造簿"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = _add_button(header, "关闭 Esc", close)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	_add_button(tabs,"修缮扩建",func(): _set_tab("projects"))
	_add_button(tabs,"基础修缮",func(): _set_tab("legacy"))
	_add_button(tabs,"家具手作",func(): _set_tab("craft"))
	_add_button(tabs,"庭院布局",func(): _set_tab("layout"))
	_add_button(tabs,"粮仓周转",func(): _set_tab("storage"))
	var separator := HSeparator.new()
	column.add_child(separator)
	_build_projects(column)
	_build_craft(column)
	_build_layout(column)
	_build_storage(column)
	_build_legacy(column)
	GameState.changed.connect(refresh)
	_bind_scroll_focus(self)
	visible = false

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

func _build_legacy(parent: VBoxContainer) -> void:
	legacy_tab = ScrollContainer.new()
	legacy_tab.name = "LegacyTab"
	legacy_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legacy_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(legacy_tab)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	legacy_tab.add_child(list)
	for key in GameState.content.get("upgrades",{}):
		var id := str(key)
		var definition: Dictionary = GameState.content.upgrades[id]
		var materials: Array[String] = []
		for item in definition.get("materials",{}): materials.append(str(GameState.item_catalog.get(str(item),{}).get("name",item))+" ×"+str(int(definition.materials[item])))
		var text := _label(list,str(definition.name)+" · "+str(int(definition.cost))+" 金币 · "+"、".join(materials)+"\n"+str(definition.get("description","")),15)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		legacy_buttons[id] = _add_button(list,"一起动工",_begin_legacy_upgrade.bind(id))

func _begin_legacy_upgrade(id: String) -> void:
	if GameState.action_busy(): return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var previous_tab := tab
	var scroll_value := legacy_tab.scroll_vertical
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var button: Button = legacy_buttons.get(id)
	if not is_instance_valid(button): return
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		tab = previous_tab
		refresh()
		_restore_legacy_focus.call_deferred(button,scroll_value,starting_day,starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		GameState.confirm_operation(GameState.perform_legacy_upgrade(id))
		restore.call()
	var action := GameState.ACTION_RULES.ui("upgrade",button.text)
	action.item = id
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action,{"kind":"ui","x":position.x,"y":position.y},commit,restore): restore.call()

func _restore_legacy_focus(button: Button,scroll_value: int,starting_day: int,starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	if button.is_visible_in_tree() and not button.disabled: button.grab_focus()
	else: close_button.grab_focus()
	legacy_tab.scroll_vertical = scroll_value

func _build_projects(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.name = "ProjectsTab"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	parent.add_child(body)
	project_list = ItemList.new()
	project_list.custom_minimum_size = Vector2(240, 190)
	project_list.item_selected.connect(_choose_project)
	body.add_child(project_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	scroll.add_child(right)
	project_details = _label(right, "选择一项工程。", 17)
	project_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	project_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	project_start = _add_button(right, "走到工地并开工", _start_project)
	var mode_row := HBoxContainer.new()
	right.add_child(mode_row)
	_label(mode_row, "功能方向", 15)
	mode_option = OptionButton.new()
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.item_selected.connect(_choose_mode)
	mode_row.add_child(mode_option)
	yard_button = _add_button(right, "在老屋整理庭院", _restore_yard)
	jobs_label = _label(right, "", 15)
	jobs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var milestone_grid := GridContainer.new()
	milestone_grid.columns = 2
	right.add_child(milestone_grid)
	for id in ["home", "garden", "living", "collection"]:
		var milestone_id := str(id)
		var button := _add_button(milestone_grid, "", func(): GameState.confirm_operation(GameState.claim_building_milestone(milestone_id)))
		button.add_theme_font_size_override("font_size", 12)
		milestone_buttons[milestone_id] = button
	var hint := _label(right, "工程需到对应房屋门前开工，支付工钱、木材与竹材，并消耗少量体力。施工次日竣工。", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_craft(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.name = "CraftTab"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	parent.add_child(body)
	furniture_list = ItemList.new()
	preload("res://scripts/item_art.gd").fit_list(furniture_list)
	furniture_list.custom_minimum_size = Vector2(240, 190)
	furniture_list.item_selected.connect(_choose_furniture)
	body.add_child(furniture_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	scroll.add_child(right)
	furniture_details = _label(right, "選擇圖紙查看材料。", 18)
	furniture_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	furniture_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	craft_one = _add_button(right, "制作 1 件 · 竹木工坊", func(): _craft(1))
	craft_three = _add_button(right, "制作 3 件 · 竹木工坊", func(): _craft(3))
	var style_row := HBoxContainer.new()
	right.add_child(style_row)
	_label(style_row, "室内风格", 15)
	style_option = OptionButton.new()
	for pair in [["wood", "原木禾草"], ["blue", "靛蓝竹影"], ["plum", "梅色暖屋"]]:
		style_option.add_item(str(pair[1]))
		style_option.set_item_metadata(style_option.item_count - 1, str(pair[0]))
	style_option.item_selected.connect(func(index: int): GameState.confirm_operation(GameState.set_building_furniture_style(str(style_option.get_item_metadata(index)))))
	style_row.add_child(style_option)
	var room_row := HBoxContainer.new()
	right.add_child(room_row)
	_label(room_row, "三阶功能间", 15)
	room_use_option = OptionButton.new()
	for pair in [["display", "收成展示"], ["workshop", "工具手作"], ["nursery", "农事育苗"], ["storage", "食材储藏"]]:
		room_use_option.add_item(str(pair[1]))
		room_use_option.set_item_metadata(room_use_option.item_count - 1, str(pair[0]))
	room_use_option.item_selected.connect(func(index: int): GameState.confirm_operation(GameState.set_building_room_use(str(room_use_option.get_item_metadata(index)))))
	room_row.add_child(room_use_option)
	var showcase_row := HBoxContainer.new()
	right.add_child(showcase_row)
	_label(showcase_row, "展示物产", 15)
	showcase_option = OptionButton.new()
	showcase_option.item_selected.connect(func(index: int): GameState.confirm_operation(GameState.set_building_showcase(str(showcase_option.get_item_metadata(index)))))
	showcase_row.add_child(showcase_option)
	var hint := _label(right, "家具先做进库存，再到布局页放置。庭院类家具需先整理庭院；小温棚秋季开放。手作需要在竹木工坊进行。", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_layout(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.name = "LayoutTab"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	parent.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var controls := HBoxContainer.new()
	left.add_child(controls)
	zone_option = OptionButton.new()
	zone_option.add_item("东院晒场")
	zone_option.set_item_metadata(0, "court")
	zone_option.add_item("西院花园")
	zone_option.set_item_metadata(1, "orchard")
	zone_option.add_item("老屋室内")
	zone_option.set_item_metadata(2, "home")
	zone_option.item_selected.connect(_choose_zone)
	controls.add_child(zone_option)
	furniture_option = OptionButton.new()
	furniture_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	furniture_option.item_selected.connect(_choose_layout_furniture)
	controls.add_child(furniture_option)
	grid = GridContainer.new()
	grid.columns = 8
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	left.add_child(grid)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	scroll.add_child(right)
	layout_details = _label(right, "点选一个格子。灰色格是道路与门口。", 15)
	layout_details.custom_minimum_size.y = 140
	layout_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cell_row := HBoxContainer.new()
	_label(cell_row, "格位", 15)
	cell_spin = SpinBox.new()
	cell_spin.min_value = 1
	cell_spin.max_value = 40
	cell_spin.value = 1
	cell_spin.step = 1
	cell_spin.value_changed.connect(func(value: float): selected_cell = int(value) - 1; selected_piece_key = 0; refresh())
	cell_row.add_child(cell_spin)
	rotation_label = _label(cell_row, "朝向 0°", 15)
	_add_button(cell_row, "转向", _rotate)
	right.add_child(cell_row)
	place_button = _add_button(right, "放下 / 移动家具", _place)
	remove_button = _add_button(right, "从草图收回", _remove)
	var actions := HBoxContainer.new()
	left.add_child(actions)
	_add_button(actions, "丢弃草图", _discard_layout)
	_add_button(actions, "应用布局", _apply_layout)
	var hint := _label(right, "布局先放草图，最后一次应用。会检查库存、占地、道路、障碍物和步行通路；移动与收回会返还家具。", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy_layout_rows=VBoxContainer.new()
	legacy_layout_rows.name="LegacyFurnitureRows"
	right.add_child(legacy_layout_rows)

func _refresh_legacy_layout_rows() -> void:
	if legacy_layout_rows==null:return
	for child in legacy_layout_rows.get_children():
		legacy_layout_rows.remove_child(child);child.queue_free()
	var pieces:Array=GameState.legacy_furniture_slots()
	legacy_layout_rows.visible=not pieces.is_empty()
	if pieces.is_empty():return
	_label(legacy_layout_rows,"原庭院已有 %d 件家具"%pieces.size(),15)
	var hint:Label=_label(legacy_layout_rows,"旧摆设保留原地与效果；收回后可在新规划区重新布置。",13)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for piece in pieces:
		var row:=HBoxContainer.new()
		legacy_layout_rows.add_child(row)
		var label:Label=_label(row,"%s · 旧位置 %d"%[str(GameState.content.furniture[piece.id].name),int(piece.slot)+1],13)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var button:Button=_add_button(row,"完整收回",_recover_legacy_layout.bind(int(piece.slot)))
		button.name="RecoverLegacy%d"%int(piece.slot)

func _recover_legacy_layout(slot:int) -> void:
	if GameState.confirm_operation(GameState.recover_legacy_furniture(slot)):
		_begin_layout()
	refresh()

func _build_storage(parent: VBoxContainer) -> void:
	storage_tab = VBoxContainer.new()
	storage_tab.name = "StorageTab"
	storage_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	storage_tab.add_theme_constant_override("separation", 10)
	parent.add_child(storage_tab)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	storage_tab.add_child(body)
	var categories := VBoxContainer.new()
	categories.custom_minimum_size.x = 205
	categories.add_theme_constant_override("separation", 8)
	body.add_child(categories)
	for category_id in STORAGE_CATEGORIES:
		var id := str(category_id)
		var button := _add_button(categories, str(STORAGE_CATEGORIES[id]), func(): _choose_storage_category(id))
		button.custom_minimum_size.y = 44
		storage_category_buttons[id] = button
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	scroll.add_child(right)
	storage_details = _label(right, "选择一类物品查看可周转数量。", 15)
	storage_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	storage_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storage_store_button = _add_button(right, "存入这一类", _store_category)
	storage_withdraw_button = _add_button(right, "补足随身余量", _withdraw_category)
	var hint := _label(storage_tab, "粮仓一阶开放分类批量存取；二阶选择“周转补给”后，可一键补足随身常用量。每种留 5 份，不会搬空背包或粮仓。", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _label(parent: Node, text: String, size: int = 15) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override("font_color", Color("f1e8d1"))
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func _add_button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func open_panel(sites: Dictionary, home_nearby: bool) -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	near_sites = sites.duplicate(true)
	at_home = home_nearby
	tab = "projects"
	draft = GameState.building.get("layout", []).duplicate(true)
	draft_revision = int(GameState.building.get("revision", 0))
	draft_epoch = GameState.building_epoch
	selected_cell = -1
	selected_piece_key = 0
	visible = true
	GameState.ui_open = true
	refresh()
	project_start.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false
	GameState.changed.emit()

func is_open() -> bool:
	return visible

func _set_tab(next_tab: String) -> void:
	tab = next_tab
	if tab == "layout": _begin_layout()
	refresh()

func _begin_layout() -> void:
	draft = GameState.building.get("layout", []).duplicate(true)
	draft_revision = int(GameState.building.get("revision", 0))
	draft_epoch = GameState.building_epoch
	selected_cell = -1
	selected_piece_key = 0

func refresh() -> void:
	if not is_inside_tree(): return
	var projects_tab: Control = find_child("ProjectsTab",true,false)
	var craft_tab: Control = find_child("CraftTab",true,false)
	var layout_tab: Control = find_child("LayoutTab",true,false)
	if projects_tab == null: return
	projects_tab.visible = tab == "projects"
	craft_tab.visible = tab == "craft"
	layout_tab.visible = tab == "layout"
	storage_tab.visible = tab == "storage"
	legacy_tab.visible = tab == "legacy"
	for id in legacy_buttons:
		legacy_buttons[id].disabled = bool(GameState.upgrades.get(str(id),false))
		legacy_buttons[id].text = "已经修好" if legacy_buttons[id].disabled else "一起动工"
	_refresh_projects()
	_refresh_craft()
	_refresh_layout()
	_refresh_storage()

func _refresh_storage() -> void:
	if storage_details == null: return
	var title := str(STORAGE_CATEGORIES.get(storage_category, "物品"))
	for id in storage_category_buttons:
		storage_category_buttons[id].text = ("● " if str(id) == storage_category else "　") + str(STORAGE_CATEGORIES[id])
	var unlocked := GameState.building_level("granary") >= 1 and bool(GameState.upgrades.get("storage", false))
	var can_withdraw := GameState.building_level("granary") >= 2 and str(GameState.building.get("modes", {}).get("granary", "")) == "supply"
	var store_amount := _category_transfer_amount(GameState.inventory, GameState.storage, storage_category, false)
	var withdraw_amount := _category_transfer_amount(GameState.storage, GameState.inventory, storage_category, true)
	var listed: Array[String] = []
	if store_amount > 0: listed.append("可存入 %d 份" % store_amount)
	if withdraw_amount > 0: listed.append("可取回 %d 份" % withdraw_amount)
	var access_text := "" if unlocked else "\n尚未开放：先完成丰收粮仓一阶改良。"
	if can_withdraw and not unlocked: access_text = "\n尚未开放：先完成丰收粮仓改良。"
	if not can_withdraw and unlocked: access_text += "\n一键取回需粮仓二阶并选择“周转补给”。"
	storage_details.text = "%s\n\n背包：%d 份\n粮仓：%d 份\n\n%s%s" % [title, _category_total(GameState.inventory, storage_category), _category_total(GameState.storage, storage_category), " · ".join(listed) if not listed.is_empty() else "当前没有可周转的余量。", access_text]
	storage_store_button.disabled = not unlocked or store_amount <= 0
	storage_withdraw_button.disabled = not unlocked or not can_withdraw or withdraw_amount <= 0

func _category_total(holdings: Dictionary, category_id: String) -> int:
	var total := 0
	for raw_id in holdings:
		var item_id := str(raw_id)
		var kind := str(GameState.item_catalog.get(item_id, {}).get("kind", ""))
		var matches := GameState._is_food(item_id) if category_id == "food" else kind == "种子" if category_id == "seed" else kind == "材料" if category_id == "material" else item_id in ["feed", "hay", "grainFeed", "healthFeed", "bedding"]
		if matches: total += int(holdings[raw_id])
	return total

func _category_transfer_amount(source: Dictionary, destination: Dictionary, category_id: String, top_up: bool) -> int:
	var total := 0
	for raw_id in source:
		var item_id := str(raw_id)
		var kind := str(GameState.item_catalog.get(item_id, {}).get("kind", ""))
		var matches := GameState._is_food(item_id) if category_id == "food" else kind == "种子" if category_id == "seed" else kind == "材料" if category_id == "material" else item_id in ["feed", "hay", "grainFeed", "healthFeed", "bedding"]
		if not matches: continue
		var quantity := mini(int(source.get(item_id, 0)), maxi(0, 5 - int(destination.get(item_id, 0)))) if top_up else maxi(0, int(source.get(item_id, 0)) - 5)
		total += quantity
	return total

func _choose_storage_category(id: String) -> void:
	storage_category = id
	refresh()

func _store_category() -> void:
	_begin_storage_action(false)

func _withdraw_category() -> void:
	_begin_storage_action(true)

func _begin_storage_action(withdraw: bool) -> void:
	if GameState.action_busy(): return
	var category := storage_category
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var button := storage_withdraw_button if withdraw else storage_store_button
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		tab = "storage"
		storage_category = category
		refresh()
		if button.disabled: storage_category_buttons[category].grab_focus()
		else: button.grab_focus()
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		GameState.confirm_operation(GameState.sort_building_storage(category, withdraw))
		restore.call()
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	var action := GameState.ACTION_RULES.ui("b-withdraw" if withdraw else "b-store", button.text)
	if not GameState.begin_action(action, {"kind": "ui", "x": position.x, "y": position.y}, commit, restore): restore.call()

func _refresh_projects() -> void:
	var catalog: Dictionary = GameState.system_catalog.get("building", {}).get("projects", {})
	project_list.clear()
	var selected_index := 0
	for index in range(PROJECT_IDS.size()):
		var id: String = str(PROJECT_IDS[index])
		var project: Dictionary = catalog.get(id, {})
		var level := GameState.building_level(id)
		var active := false
		for job in GameState.building.get("jobs", []):
			if str(job.get("id", "")) == id: active = true
		project_list.add_item("%s · %d/%d%s" % [str(project.get("name", id)), level, int(project.get("max", 1)), " · 施工中" if active else ""])
		project_list.set_item_metadata(index, id)
		if id == project_id: selected_index = index
	if project_list.item_count > 0:
		project_list.select(selected_index)
	var project: Dictionary = catalog.get(project_id, {})
	var quote := GameState.building_quote(project_id)
	var near := bool(near_sites.get(str(project.get("house", "")), false))
	var job_text := ""
	for job in GameState.building.get("jobs", []):
		if str(job.get("id", "")) == project_id: job_text = "\n正在施工 · 明日竣工"
	var effects: Array = project.get("effects", [])
	var effect := str(effects[mini(GameState.building_level(project_id), effects.size() - 1)]) if not effects.is_empty() else ""
	var next_level := int(quote.get("level", 0))
	var cost := "已完成全部阶段。" if quote.is_empty() else "工钱 %d 金币 · 木材 ×%d · 竹材 ×%d" % [int(quote.money), int(quote.wood), int(quote.bamboo)]
	var site_text := "已在工地附近。" if near else "工地：%s。走近门口才能开工。" % str(project.get("house", "未指定"))
	project_details.text = "%s\n阶段 %d / %d\n\n%s\n\n下一阶段：%s\n%s%s" % [str(project.get("name", project_id)), GameState.building_level(project_id), int(project.get("max", 1)), effect, str(next_level) if next_level > 0 else "—", cost, "\n" + site_text + job_text]
	project_start.text = "安排施工" if near else "走到对应工地开工"
	project_start.disabled = quote.is_empty() or not job_text.is_empty()
	var modes: Array = GameState.system_catalog.get("building", {}).get("modes", {}).get(project_id, [])
	mode_option.clear()
	mode_option.visible = not modes.is_empty()
	for choice in modes:
		mode_option.add_item(str(choice[1]))
		mode_option.set_item_metadata(mode_option.item_count - 1, str(choice[0]))
	for index in range(mode_option.item_count):
		if str(mode_option.get_item_metadata(index)) == str(GameState.building.get("modes", {}).get(project_id, "")): mode_option.select(index)
	mode_option.disabled = GameState.building_level(project_id) < 1
	yard_button.visible = true
	yard_button.text = "整理庭院 · %d 金币，木材 ×6，竹材 ×5" % int(GameState.content.get("upgrades", {}).get("yard", {}).get("cost", 150))
	yard_button.disabled = bool(GameState.upgrades.get("yard", false))
	var jobs: Array[String] = []
	for job in GameState.building.get("jobs", []):
		var job_name := str(catalog.get(str(job.get("id", "")), {}).get("name", "工程"))
		jobs.append("%s · 第 %d 阶 · 次日竣工" % [job_name, int(job.get("level", 1))])
	jobs_label.text = "施工队列（最多 4 处）\n" + ("\n".join(jobs) if not jobs.is_empty() else "当前没有施工中的工程。")
	for id in milestone_buttons:
		var milestone: Dictionary = GameState.system_catalog.get("building", {}).get("milestones", {}).get(str(id), {})
		var claimed: Array = GameState.building.get("claimed", [])
		var ready := GameState.building_milestone_ready(str(id))
		milestone_buttons[id].text = ("✓ " if claimed.has(id) else "领 " if ready else "· ") + str(milestone.get("name", id))
		milestone_buttons[id].disabled = not ready

func _refresh_craft() -> void:
	var items: Dictionary = GameState.content.get("furniture", {})
	var ids: Array = items.keys()
	ids.sort()
	furniture_list.clear()
	var selected_index := 0
	for index in range(ids.size()):
		var id := str(ids[index])
		furniture_list.add_item("%s · 库存 %d" % [str(items[id].get("name", id)), int(GameState.furniture.get(id, 0))], preload("res://scripts/item_art.gd").texture_for(str(id), "furniture"))
		furniture_list.set_item_metadata(index, id)
		if id == furniture_id: selected_index = index
	if furniture_list.item_count > 0: furniture_list.select(selected_index)
	var item: Dictionary = items.get(furniture_id, {})
	var definition: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {}).get(furniture_id, {})
	var needs: Dictionary = item.get("needs", {})
	var costs: Array[String] = []
	for item_id in needs:
		costs.append("%s ×%d" % [str(GameState.item_catalog.get(str(item_id), {}).get("name", item_id)), int(needs[item_id])])
	var area: String = str({"yard": "庭院", "home": "室内", "both": "室内与庭院"}.get(str(definition.get("where", "both")), "家具"))
	furniture_details.text = "%s\n%s · 占地 %d × %d\n\n制作材料：%s\n当前库存：%d\n\n%s" % [str(item.get("name", furniture_id)), area, int(definition.get("w", 1)), int(definition.get("h", 1)), "、".join(costs), int(GameState.furniture.get(furniture_id, 0)), "小温棚图纸需到秋季（第 57 天）开放。" if furniture_id == "greenhouse" and GameState.day < 56 else "" ]
	craft_one.disabled = item.is_empty()
	craft_three.disabled = craft_one.disabled
	style_option.select({"wood": 0, "blue": 1, "plum": 2}.get(str(GameState.building.get("style", "wood")), 0))
	room_use_option.select({"display": 0, "workshop": 1, "nursery": 2, "storage": 3}.get(str(GameState.building.get("roomUse", "display")), 0))
	room_use_option.disabled = int(GameState.building.get("house", 0)) < 3
	showcase_option.clear()
	showcase_option.add_item("暂不展示")
	showcase_option.set_item_metadata(0, "")
	var collection_entries: Dictionary = GameState.collection.get("entries", {})
	for key in collection_entries:
		if not str(key).begins_with("item:") or not bool(collection_entries[key].get("acquired", false)): continue
		var item_id := str(key).substr(5)
		if not GameState.item_catalog.has(item_id): continue
		showcase_option.add_item(str(GameState.item_catalog[item_id].get("name", item_id)))
		showcase_option.set_item_metadata(showcase_option.item_count - 1, item_id)
	for index in range(showcase_option.item_count):
		if str(showcase_option.get_item_metadata(index)) == str(GameState.building.get("showcase", "")): showcase_option.select(index)

func _refresh_layout() -> void:
	_refresh_legacy_layout_rows()
	var zones: Dictionary = GameState.system_catalog.get("building", {}).get("zones", {})
	var zone: Dictionary = zones.get(zone_id, zones.get("court", {}))
	var cols := int(zone.get("cols", 8))
	var rows := int(zone.get("rows", 5))
	var definitions: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {})
	var catalog: Dictionary = GameState.content.get("furniture", {})
	furniture_option.clear()
	var furniture_ids: Array = catalog.keys()
	furniture_ids.sort()
	var selected_index := 0
	for index in range(furniture_ids.size()):
		var id := str(furniture_ids[index])
		furniture_option.add_item("%s · %d" % [str(catalog[id].get("name", id)), _furniture_balance(id)])
		furniture_option.set_item_metadata(index, id)
		if id == furniture_id: selected_index = index
	if furniture_option.item_count > 0: furniture_option.select(selected_index)
	grid.columns = cols
	for child in grid.get_children(): child.queue_free()
	var cells := cols * rows
	cell_spin.max_value = cells
	if selected_cell >= cells: selected_cell = cells - 1
	for cell in range(cells):
		var button := Button.new()
		button.custom_minimum_size = Vector2(23, 25) if cols > 8 else Vector2(42, 36)
		var piece := _piece_at(cell)
		var reason:String = GameState.BUILDING_GEOMETRY.reserved(GameState, zone_id, cell)
		var reserved:bool = reason != ""
		button.text = "路" if reserved else (str(catalog.get(str(piece.get("type", "")), {}).get("name", "物")).substr(0, 1) if not piece.is_empty() else "＋")
		if reserved: button.modulate = Color("8b9687")
		elif not piece.is_empty(): button.modulate = Color("d2b98f")
		if cell == selected_cell: button.add_theme_color_override("font_color", Color("f9dd80"))
		button.tooltip_text = reason if reserved else str(catalog.get(str(piece.get("type", "")), {}).get("name", "空地"))
		button.pressed.connect(_choose_cell.bind(cell))
		grid.add_child(button)
	selected_cell = clampi(selected_cell, -1, cells - 1)
	cell_spin.value = selected_cell + 1 if selected_cell >= 0 else 1
	rotation_label.text = "朝向 %d°" % (furniture_rotation * 90)
	var selected_piece := _draft_piece(selected_piece_key)
	var balances := _furniture_balance(furniture_id)
	var valid: Dictionary = {}
	if selected_cell >= 0:
		var candidate := {"key": selected_piece_key if selected_piece_key > 0 else int(GameState.building.get("nextId", 1)), "type": furniture_id, "zone": zone_id, "cell": selected_cell, "rotation": furniture_rotation}
		var others := draft.duplicate(true)
		if selected_piece_key > 0: others = others.filter(func(other): return int(other.get("key", 0)) != selected_piece_key)
		valid = GameState.building_placement_valid(candidate, others)
		layout_details.text = "選中：%s" % str(catalog.get(str(selected_piece.get("type", furniture_id)), {}).get("name", furniture_id)) if not selected_piece.is_empty() else "新放：%s" % str(catalog.get(furniture_id, {}).get("name", furniture_id))
		layout_details.text += "\n可用庫存：%d · 草圖：%d 件\n%s" % [balances, draft.size(), str(valid.get("message", ""))]
	else:
		layout_details.text = "點格子預覽家具位置。灰色道路格和最下排入口保持空出。\n草圖 %d 件，庫存要到“應用布局”時才會變動。" % draft.size()
	place_button.disabled = selected_cell < 0 or not bool(valid.get("ok", false)) or (selected_piece_key == 0 and balances <= 0)
	remove_button.disabled = selected_piece_key <= 0

func _piece_at(cell: int) -> Dictionary:
	var zone: Dictionary = GameState.system_catalog.get("building", {}).get("zones", {}).get(zone_id, {})
	var cols := int(zone.get("cols", 8))
	for piece in draft:
		if str(piece.get("zone", "")) != zone_id: continue
		var definition: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {}).get(str(piece.get("type", "")), {})
		var rotated := posmod(int(piece.get("rotation", 0)), 2) == 1
		var width := int(definition.get("h", 1)) if rotated else int(definition.get("w", 1))
		var height := int(definition.get("w", 1)) if rotated else int(definition.get("h", 1))
		var x := int(piece.cell) % cols
		var y := int(int(piece.cell) / cols)
		var target_x := cell % cols
		var target_y := int(cell / cols)
		if target_x >= x and target_x < x + width and target_y >= y and target_y < y + height: return piece
	return {}

func _draft_piece(key: int) -> Dictionary:
	for piece in draft:
		if int(piece.get("key", 0)) == key: return piece
	return {}

func _furniture_balance(id: String) -> int:
	var count := int(GameState.furniture.get(id, 0))
	for piece in GameState.building.get("layout", []):
		if str(piece.get("type", "")) == id: count += 1
	for piece in draft:
		if str(piece.get("type", "")) == id: count -= 1
	return count

func _choose_project(index: int) -> void:
	project_id = str(project_list.get_item_metadata(index))
	refresh()

func _choose_furniture(index: int) -> void:
	furniture_id = str(furniture_list.get_item_metadata(index))
	refresh()

func _choose_mode(index: int) -> void:
	if index >= 0: GameState.confirm_operation(GameState.set_building_mode(project_id, str(mode_option.get_item_metadata(index))))

func _choose_zone(index: int) -> void:
	zone_id = str(zone_option.get_item_metadata(index))
	selected_cell = -1
	selected_piece_key = 0
	refresh()

func _choose_layout_furniture(index: int) -> void:
	furniture_id = str(furniture_option.get_item_metadata(index))
	selected_piece_key = 0
	refresh()

func _choose_cell(cell: int) -> void:
	selected_cell = cell
	var piece := _piece_at(cell)
	if not piece.is_empty():
		selected_piece_key = int(piece.key)
		furniture_id = str(piece.type)
		furniture_rotation = int(piece.rotation)
	else:
		selected_piece_key = 0
	refresh()

func _start_project() -> void:
	GameState.queue_building_task({"op":"project","id":project_id})

func _restore_yard() -> void:
	GameState.queue_building_task({"op":"legacy","id":"yard"})

func _craft(quantity: int) -> void:
	GameState.queue_building_task({"op":"craft","id":furniture_id,"n":quantity})

func _place() -> void:
	if selected_cell < 0: return
	var key := selected_piece_key if selected_piece_key > 0 else int(GameState.building.get("nextId", 1))
	var candidate := {"key": key, "type": furniture_id, "zone": zone_id, "cell": selected_cell, "rotation": furniture_rotation}
	var next_layout: Array = draft.duplicate(true)
	if selected_piece_key > 0: next_layout = next_layout.filter(func(piece): return int(piece.get("key", 0)) != selected_piece_key)
	var validation := GameState.building_placement_valid(candidate, next_layout)
	if not bool(validation.get("ok", false)):
		layout_details.text = str(validation.get("message", "这个位置放不下。"))
		return
	if selected_piece_key == 0 and _furniture_balance(furniture_id) < 1:
		layout_details.text = "库存里没有这件家具，先到工坊制作。"
		return
	next_layout.append(candidate)
	draft = next_layout
	selected_piece_key = key
	refresh()

func _remove() -> void:
	if selected_piece_key <= 0: return
	draft = draft.filter(func(piece): return int(piece.get("key", 0)) != selected_piece_key)
	selected_piece_key = 0
	refresh()

func _rotate() -> void:
	furniture_rotation = (furniture_rotation + 1) % 4
	refresh()

func _discard_layout() -> void:
	_begin_layout()
	refresh()

func _apply_layout() -> void:
	if GameState.confirm_operation(GameState.apply_building_layout(draft, draft_revision, draft_epoch)): _begin_layout()
	refresh()
