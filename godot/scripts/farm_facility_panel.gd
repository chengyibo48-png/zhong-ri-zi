extends Control
class_name FarmFacilityPanel

const FACILITY_IDS := ["sprinkler", "greenhouse", "scarecrow", "shade", "fence", "trellis", "drain"]
var can_work := false
var selected_type := "sprinkler"
var selected_facility := -1
var type_list: ItemList
var facility_list: ItemList
var anchor_box: SpinBox
var target_box: SpinBox
var detail_label: Label
var build_button: Button
var repair_button: Button
var toggle_button: Button
var upgrade_button: Button
var move_button: Button
var recover_button: Button
var fill_button: Button

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
	panel.offset_left = -405
	panel.offset_right = 405
	panel.offset_top = -270
	panel.offset_bottom = 270
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
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "田间设施簿"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	var type_column := VBoxContainer.new()
	type_column.custom_minimum_size.x = 215
	body.add_child(type_column)
	var type_title := Label.new()
	type_title.text = "可建造设施"
	type_column.add_child(type_title)
	type_list = ItemList.new()
	type_list.custom_minimum_size.y = 190
	type_list.item_selected.connect(_choose_type)
	type_column.add_child(type_list)
	var placed_title := Label.new()
	placed_title.text = "已放置设施 / 收纳库存"
	type_column.add_child(placed_title)
	facility_list = ItemList.new()
	facility_list.custom_minimum_size.y = 120
	facility_list.item_selected.connect(_choose_facility)
	type_column.add_child(facility_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 145
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_label)
	var anchor_row := HBoxContainer.new()
	right.add_child(anchor_row)
	var anchor_label := Label.new()
	anchor_label.text = "放置田块"
	anchor_row.add_child(anchor_label)
	anchor_box = _spinbox(1, GameState.plots.size(), 1)
	anchor_row.add_child(anchor_box)
	var target_row := HBoxContainer.new()
	right.add_child(target_row)
	var target_label := Label.new()
	target_label.text = "搬迁目标"
	target_row.add_child(target_label)
	target_box = _spinbox(1, GameState.plots.size(), 1)
	target_row.add_child(target_box)
	build_button = _button("建造 / 放回", _build)
	right.add_child(build_button)
	var actions := GridContainer.new()
	actions.columns = 2
	right.add_child(actions)
	repair_button = _button("维修", _repair)
	actions.add_child(repair_button)
	toggle_button = _button("启用 / 暂停", _toggle)
	actions.add_child(toggle_button)
	upgrade_button = _button("加固", _upgrade)
	actions.add_child(upgrade_button)
	move_button = _button("搬迁", _move)
	actions.add_child(move_button)
	recover_button = _button("收纳", _recover)
	actions.add_child(recover_button)
	fill_button = _button("补满储水（6 金币）", GameState.fill_farm_water)
	right.add_child(fill_button)
	var hint := Label.new()
	hint.text = "I 查看设施 · 站在田边再打开可操作 · 喷灌消耗储水 · 耐久归零后停止工作"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	GameState.changed.connect(refresh)
	visible = false

func _spinbox(minimum: int, maximum: int, value: int) -> SpinBox:
	var result := SpinBox.new()
	result.min_value = minimum
	result.max_value = maximum
	result.value = value
	result.step = 1
	result.custom_minimum_size.x = 100
	return result

func _button(label: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = label
	result.pressed.connect(action)
	return result

func open_panel(work_allowed: bool = false, plot_index: int = 0) -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	can_work = work_allowed
	anchor_box.value = clampi(plot_index + 1, 1, GameState.plots.size())
	visible = true
	GameState.ui_open = true
	refresh()
	type_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or not is_instance_valid(type_list):
		return
	preload("res://scripts/item_art.gd").fit_list(type_list)
	preload("res://scripts/item_art.gd").fit_list(facility_list)
	type_list.clear()
	for type in FACILITY_IDS:
		var definition := GameState.farm_facility_definition(type)
		type_list.add_item(str(definition.get("name", type)), preload("res://scripts/item_art.gd").texture_for(str(type), "facilities"))
		type_list.set_item_metadata(type_list.item_count - 1, type)
	type_list.select(FACILITY_IDS.find(selected_type))
	facility_list.clear()
	var placed: Array = GameState.farm.get("facilities", [])
	for i in range(placed.size()):
		var facility: Dictionary = placed[i]
		var definition := GameState.farm_facility_definition(str(facility.get("type", "")))
		facility_list.add_item("%s · %d号 · %s · 耐久%d%%" % [definition.get("name", facility.get("type", "?")), int(facility.get("anchor", 0)) + 1, GameState.farm_facility_status(facility), roundi(float(facility.get("durability", 0.0)))], preload("res://scripts/item_art.gd").texture_for(str(facility.get("type", "")), "facilities"))
		facility_list.set_item_metadata(i, i)
	var stock: Array = GameState.farm.get("stock", [])
	for item in stock:
		var definition := GameState.farm_facility_definition(str(item.get("type", "")))
		facility_list.add_item("收纳：%s · %d阶" % [definition.get("name", item.get("type", "?")), int(item.get("level", 0))], preload("res://scripts/item_art.gd").texture_for(str(item.get("type", "")), "facilities"))
		facility_list.set_item_metadata(facility_list.item_count - 1, -1)
	if selected_facility >= placed.size():
		selected_facility = -1
	if selected_facility >= 0:
		facility_list.select(selected_facility)
	_refresh_detail()

func _choose_type(index: int) -> void:
	if index >= 0 and index < FACILITY_IDS.size():
		selected_type = FACILITY_IDS[index]
		selected_facility = -1
		_refresh_detail()

func _choose_facility(index: int) -> void:
	var metadata = facility_list.get_item_metadata(index)
	selected_facility = int(metadata) if int(metadata) >= 0 else -1
	if selected_facility >= 0:
		var facility: Dictionary = GameState.farm.facilities[selected_facility]
		selected_type = str(facility.get("type", selected_type))
		anchor_box.value = int(facility.get("anchor", 0)) + 1
	else:
		var stock_index: int = index - GameState.farm.facilities.size()
		var stock: Array = GameState.farm.get("stock", [])
		if stock_index >= 0 and stock_index < stock.size():
			selected_type = str(stock[stock_index].get("type", selected_type))
	_refresh_detail()

func _refresh_detail() -> void:
	var definition := GameState.farm_facility_definition(selected_type)
	var needs: Dictionary = definition.get("needs", {})
	var materials: Array[String] = []
	for item_id in needs:
		materials.append("%s %d/%d" % [GameState.item_catalog.get(item_id, {}).get("name", item_id), GameState.inventory.get(item_id, 0), int(needs[item_id])])
	var facility: Dictionary = GameState.farm.facilities[selected_facility] if selected_facility >= 0 and selected_facility < GameState.farm.facilities.size() else {}
	var status := "尚未放置"
	var coverage := 0
	if not facility.is_empty():
		status = GameState.farm_facility_status(facility)
		coverage = GameState.farm_facility_indices(int(facility.get("anchor", 0)), selected_type).size()
	detail_label.text = "%s\n%s\n建造：%d 金币 · %s\n当前：%s%s" % [definition.get("name", selected_type), definition.get("description", ""), int(definition.get("cost", 0)), "、".join(materials), status, " · 覆盖 %d 格 · %d阶" % [coverage, int(facility.get("level", 0))] if not facility.is_empty() else ""]
	build_button.disabled = not can_work
	var manageable := can_work and not facility.is_empty()
	repair_button.disabled = not manageable or float(facility.get("durability", 100.0)) >= 100.0
	toggle_button.disabled = not manageable
	upgrade_button.disabled = not manageable or int(facility.get("level", 0)) >= 1
	move_button.disabled = not manageable
	recover_button.disabled = not manageable
	fill_button.disabled = not can_work or int(GameState.farm.get("water", 0)) >= 120

func _anchor() -> int:
	return int(anchor_box.value) - 1

func _build() -> void:
	GameState.manage_farm_facility(_anchor(), selected_type, "build")

func _repair() -> void:
	GameState.manage_farm_facility(_anchor(), selected_type, "repair")

func _toggle() -> void:
	GameState.manage_farm_facility(_anchor(), selected_type, "toggle")

func _upgrade() -> void:
	GameState.manage_farm_facility(_anchor(), selected_type, "upgrade")

func _move() -> void:
	GameState.manage_farm_facility(_anchor(), selected_type, "move", int(target_box.value) - 1)

func _recover() -> void:
	GameState.manage_farm_facility(_anchor(), selected_type, "recover")
