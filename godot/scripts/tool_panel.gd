extends Control
class_name ToolPanel

const TOOL_IDS := ["hoe", "water", "sickle", "axe", "rod", "care"]

var can_work := false
var selected_id := "hoe"
var tool_list: ItemList
var detail_label: Label
var upgrade_button: Button
var branch_button: Button
var shape_button: Button

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
	panel.offset_left = -365
	panel.offset_right = 365
	panel.offset_top = -245
	panel.offset_bottom = 245
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
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "农具与改良"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	tool_list = ItemList.new()
	tool_list.custom_minimum_size = Vector2(225, 305)
	tool_list.item_selected.connect(_select)
	body.add_child(tool_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 11)
	body.add_child(right)
	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 165
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_label)
	upgrade_button = Button.new()
	upgrade_button.pressed.connect(_upgrade)
	right.add_child(upgrade_button)
	branch_button = Button.new()
	branch_button.pressed.connect(_switch_branch)
	right.add_child(branch_button)
	shape_button = Button.new()
	shape_button.pressed.connect(_switch_shape)
	right.add_child(shape_button)
	var hint := Label.new()
	hint.text = "U 查看工具 · 选择改良后沿路去农具间 · 作业范围与专长可随时调整"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	GameState.changed.connect(refresh)
	visible = false

func open_panel(work_allowed: bool = false) -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	can_work = work_allowed
	visible = true
	GameState.ui_open = true
	refresh()
	tool_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _select(index: int) -> void:
	if index >= 0 and index < TOOL_IDS.size():
		selected_id = TOOL_IDS[index]
		_refresh_detail()

func refresh() -> void:
	if not visible or not is_instance_valid(tool_list):
		return
	preload("res://scripts/item_art.gd").fit_list(tool_list)
	tool_list.clear()
	for tool_id in TOOL_IDS:
		var definition := GameState.tool_definition(tool_id)
		var state := GameState.tool_data(tool_id)
		tool_list.add_item("%s  %d 阶 · 熟练 %d" % [definition.get("name", tool_id), int(state.get("level", 0)), int(state.get("xp", 0))], preload("res://scripts/item_art.gd").texture_for(tool_id, "tools"))
	tool_list.select(TOOL_IDS.find(selected_id))
	_refresh_detail()

func _refresh_detail() -> void:
	var definition := GameState.tool_definition(selected_id)
	var state := GameState.tool_data(selected_id)
	var level := int(state.get("level", 0))
	var quote := GameState.tool_quote(selected_id)
	var needs: Dictionary = quote.get("needs", {})
	var parts: Array[String] = []
	for item_id in needs:
		parts.append("%s %d/%d" % [GameState.item_catalog.get(item_id, {}).get("name", item_id), GameState.inventory.get(item_id, 0), int(needs[item_id])])
	var branch_index := 1 if str(state.get("branch", "broad")) == "care" else 0
	var branch: Array = definition.get("branches", [])[branch_index]
	detail_label.text = "%s · %s\n%s：%s\n\n当前：%d 阶 · %s范围\n下一阶：%s" % [definition.get("name", selected_id), definition.get("category", ""), branch[1], branch[2], level, {"single": "单格", "row": "横排", "cross": "十字"}.get(str(state.get("shape", "single")), "单格"), "已满阶" if quote.is_empty() else "%d 金币，%s%s" % [int(quote.get("money", 0)), "、".join(parts), "；进村一周、熟练 8 次或改良农具间均可解锁" if bool(quote.get("locked", false)) else ""]]
	upgrade_button.text = "改良工具"
	upgrade_button.disabled = quote.is_empty() or bool(quote.get("locked", false))
	branch_button.text = "切换专长：%s" % ("广作" if str(state.get("branch", "broad")) == "care" else "细作")
	branch_button.disabled = level < 2
	shape_button.text = "切换范围"
	shape_button.disabled = selected_id not in ["hoe", "water", "sickle"] or level < 1

func _upgrade() -> void:
	GameState.queue_building_task({"op":"tool","id":selected_id})

func _switch_branch() -> void:
	var branch := "care" if str(GameState.tool_data(selected_id).get("branch", "broad")) == "broad" else "broad"
	_configure("branch", branch)

func _switch_shape() -> void:
	var state := GameState.tool_data(selected_id)
	var shapes := ["single", "row"]
	if int(state.get("level", 0)) >= 2 and str(state.get("branch", "broad")) == "broad":
		shapes.append("cross")
	var current := shapes.find(str(state.get("shape", "single")))
	_configure("shape", str(shapes[(current + 1) % shapes.size()]))

func _configure(field: String, value: String) -> void:
	if GameState.action_busy(): return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var tool_id := selected_id
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		selected_id = tool_id
		visible = true
		GameState.ui_open = true
		refresh()
		var button: Button = branch_button if field == "branch" else shape_button
		if not button.disabled: button.grab_focus()
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		var success: bool = GameState.configure_tool(tool_id, field, value)
		GameState.confirm_operation(success)
		restore.call()
	var action := GameState.ACTION_RULES.ui("t-" + field, branch_button.text if field == "branch" else shape_button.text)
	action.item = tool_id
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action, {"kind":"ui","x":position.x,"y":position.y}, commit, restore): restore.call()
