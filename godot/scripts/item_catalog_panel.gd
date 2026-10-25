extends Control
class_name ItemCatalogPanel

const KNOWLEDGE=preload("res://scripts/knowledge_catalog.gd")
const ITEM_ICON_SCRIPT := preload("res://scripts/item_icon.gd")

var title_label: Label
var search_box: LineEdit
var category_box: OptionButton
var item_grid: GridContainer
var page_label: Label
var previous_button: Button
var next_button: Button
var detail_icon: Control
var detail_name: Label
var detail_status: Label
var detail_description: Label
var detail_source: Label
var detail_uses: Label
var detail_likes: Label
var tool_grid: GridContainer
var selected_id := "cabbage"
var search_text := ""
var category_filter := "全部"
var page := 0
var item_ids: Array[String] = []
var card_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.09, 0.08, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -458
	panel.offset_right = 458
	panel.offset_top = -282
	panel.offset_bottom = 282
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("293a34")
	panel_style.border_color = Color("c8b27d")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.text = "禾溪物品图录"
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color("f1e5c5"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var intro := Label.new()
	intro.text = "查看物产外观、品质、保鲜、来源与用途。图录展示完整目录，不代表已经获得。"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color("d5d7bb"))
	column.add_child(intro)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	column.add_child(filter_row)
	search_box = LineEdit.new()
	search_box.placeholder_text = "搜索物品名称或类别"
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_on_search_changed)
	filter_row.add_child(search_box)
	category_box = OptionButton.new()
	category_box.custom_minimum_size.x = 150
	var categories: Array = GameState.system_catalog.get("itemIcons", {}).get("categories", ["全部"])
	for value in categories: category_box.add_item(str(value))
	category_box.item_selected.connect(_on_category_changed)
	filter_row.add_child(category_box)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 450
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	item_grid = GridContainer.new()
	item_grid.columns = 6
	item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 4)
	item_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(item_grid)
	var pager := HBoxContainer.new()
	left.add_child(pager)
	previous_button = Button.new()
	previous_button.text = "上一页"
	previous_button.pressed.connect(_change_page.bind(-1))
	pager.add_child(previous_button)
	page_label = Label.new()
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pager.add_child(page_label)
	next_button = Button.new()
	next_button.text = "下一页"
	next_button.pressed.connect(_change_page.bind(1))
	pager.add_child(next_button)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color("22332e")
	detail_style.border_color = Color("758b73")
	detail_style.set_border_width_all(1)
	detail_style.set_content_margin_all(10)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	body.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail)
	var item_head := HBoxContainer.new()
	item_head.add_theme_constant_override("separation", 10)
	detail.add_child(item_head)
	detail_icon = Control.new()
	detail_icon.set_script(ITEM_ICON_SCRIPT)
	detail_icon.custom_minimum_size = Vector2(96, 96)
	item_head.add_child(detail_icon)
	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_head.add_child(name_column)
	detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 20)
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_name.add_theme_color_override("font_color", Color("f0dfb6"))
	name_column.add_child(detail_name)
	detail_status = Label.new()
	detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_status.add_theme_color_override("font_color", Color("d8d8b8"))
	name_column.add_child(detail_status)
	detail_description = _make_detail_label(Color("d8dabc"))
	detail.add_child(detail_description)
	detail_source = _make_detail_label(Color("c7d2b8"))
	detail.add_child(detail_source)
	detail_uses = _make_detail_label(Color("d6cfaa"))
	detail.add_child(detail_uses)
	detail_likes = _make_detail_label(Color("e2c59b"))
	detail.add_child(detail_likes)
	var tool_title := Label.new()
	tool_title.text = "随身工具 · 当前改良等级"
	tool_title.add_theme_color_override("font_color", Color("eee0b8"))
	detail.add_child(tool_title)
	tool_grid = GridContainer.new()
	tool_grid.columns = 3
	tool_grid.add_theme_constant_override("h_separation", 4)
	tool_grid.add_theme_constant_override("v_separation", 3)
	detail.add_child(tool_grid)
	var legend := Label.new()
	legend.text = "品质：普通 · 优质 · 上品 · 珍品　｜　◇ 表示当前持有品质　·　▣ 受保护　·　◷ 宜先用"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color("bdc5a7"))
	column.add_child(legend)
	GameState.changed.connect(refresh)
	visible = false
	refresh()

func _make_detail_label(color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	return label

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	refresh()
	search_box.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or not is_instance_valid(item_grid): return
	_refresh_items()
	_refresh_detail()
	_refresh_tools()

func _on_search_changed(value: String) -> void:
	search_text = value.strip_edges().to_lower()
	page = 0
	_refresh_items()
	_refresh_detail()

func _on_category_changed(index: int) -> void:
	var categories: Array = GameState.system_catalog.get("itemIcons", {}).get("categories", ["全部"])
	category_filter = str(categories[index]) if index >= 0 and index < categories.size() else "全部"
	page = 0
	_refresh_items()
	_refresh_detail()

func _change_page(amount: int) -> void:
	var max_page := maxi(0, int(ceil(float(item_ids.size()) / 24.0)) - 1)
	page = clampi(page + amount, 0, max_page)
	_refresh_items()

func _refresh_items() -> void:
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()
	item_ids.clear()
	card_buttons.clear()
	var details: Dictionary = GameState.system_catalog.get("itemIcons", {}).get("details", {})
	var all_ids: Array = GameState.item_catalog.keys()
	all_ids.sort_custom(func(a, b): return str(GameState.item_catalog[a].get("name", a)) < str(GameState.item_catalog[b].get("name", b)))
	for raw_id in all_ids:
		var id := str(raw_id)
		var item: Dictionary = GameState.item_catalog[id]
		var description: Dictionary = details.get(id, {})
		var category := str(description.get("category", item.get("kind", "其他")))
		if category_filter != "全部" and category != category_filter: continue
		var name := str(item.get("name", id))
		if search_text != "" and not (name + category + id).to_lower().contains(search_text): continue
		item_ids.append(id)
	var max_page := maxi(0, int(ceil(float(item_ids.size()) / 24.0)) - 1)
	page = clampi(page, 0, max_page)
	if not item_ids.has(selected_id) and not item_ids.is_empty(): selected_id = item_ids[0]
	var start := page * 24
	var stop := mini(item_ids.size(), start + 24)
	for index in range(start, stop):
		var id := item_ids[index]
		var item: Dictionary = GameState.item_catalog[id]
		var record: Dictionary = GameState.collection.get("entries", {}).get("item:"+id, {})
		var seen := not record.is_empty() or int(GameState.inventory.get(id, 0)) > 0 or int(GameState.storage.get(id, 0)) > 0
		var button := Button.new()
		button.custom_minimum_size = Vector2(70, 78)
		button.tooltip_text = str(item.get("name",id)) if seen else str(KNOWLEDGE.describe(GameState,"item:"+id).get("source","来源线索"))
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_item.bind(id))
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 1)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := Control.new()
		icon.set_script(ITEM_ICON_SCRIPT)
		icon.custom_minimum_size = Vector2(34, 34)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.call("configure", id)
		icon.set_meta("guide_texture",KNOWLEDGE.picture(GameState,"item:"+id,not seen))
		content.add_child(icon)
		var name_label := Label.new()
		name_label.text = str(item.get("name", id)) if seen else "尚待发现"
		name_label.custom_minimum_size.x = 64
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color("f1e7cc"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name_label)
		var state_label := Label.new()
		state_label.text = "已收录" if seen else "尚未发现"
		state_label.visible=false
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.add_theme_font_size_override("font_size", 8)
		state_label.add_theme_color_override("font_color", Color("aeca9c") if seen else Color("b8b7a0"))
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(state_label)
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=3;content.offset_top=5;content.offset_right=-3;content.offset_bottom=-3
		item_grid.add_child(button)
		card_buttons[id] = button
	if item_ids.is_empty():
		var empty := Label.new()
		empty.text = "没有符合条件的物品，试试其他名称或类别。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(410, 100)
		item_grid.add_child(empty)
	var total_pages := maxi(1, max_page + 1)
	page_label.text = "%d 件物品 · 第 %d / %d 页" % [item_ids.size(), page + 1, total_pages]
	previous_button.disabled = page <= 0
	next_button.disabled = page >= max_page
	if selected_id != "" and card_buttons.has(selected_id): (card_buttons[selected_id] as Button).add_theme_stylebox_override("normal", _selected_card_style())

func _selected_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("536449")
	style.border_color = Color("e1c982")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style

func _select_item(id: String) -> void:
	selected_id = id
	_refresh_items()
	_refresh_detail()

func _refresh_detail() -> void:
	if selected_id == "" or not GameState.item_catalog.has(selected_id):
		detail_name.text = "没有符合条件的物品"
		detail_status.text = "调整关键词或类别后继续查找。"
		detail_description.text = ""
		detail_source.text = ""
		detail_uses.text = ""
		detail_likes.text = ""
		return
	detail_icon.call("configure", selected_id)
	var item: Dictionary = GameState.item_catalog[selected_id]
	var rules: Dictionary = GameState.system_catalog.get("itemIcons", {})
	var description: Dictionary = rules.get("details", {}).get(selected_id, {})
	var category := str(description.get("category", item.get("kind", "物品")))
	var seed: Dictionary = rules.get("seedMap", {}).get(selected_id, {})
	if not seed.is_empty():
		var seed_kind := str(seed.get("kind", "normal"))
		category += " · " + str(GameState.system_catalog.get("farming", {}).get("kinds", {}).get(seed_kind, {}).get("name", seed_kind))
	var info:=KNOWLEDGE.describe(GameState,"item:"+selected_id)
	var discovered:=not KNOWLEDGE.state(GameState,selected_id).is_empty()
	detail_icon.set_meta("guide_texture",KNOWLEDGE.picture(GameState,"item:"+selected_id,not discovered))
	detail_name.text = str(info.get("title",item.get("name",selected_id)))
	var inventory_count := int(GameState.inventory.get(selected_id, 0))
	var storage_count := int(GameState.storage.get(selected_id, 0))
	var grade_names := ["普通", "优质", "上品", "珍品"]
	var counts: Array[int] = GameState._quality_counts(selected_id)
	var found_grades := PackedStringArray()
	for grade in range(counts.size()):
		if counts[grade] > 0: found_grades.append(grade_names[grade])
	var quality_text := "暂无库存品质" if found_grades.is_empty() else "混合品质" if found_grades.size() > 1 else found_grades[0]
	var locked: bool = GameState.economy.get("locked", []).has(selected_id)
	var status := "%s\n类别：%s\n随身 %d · 储藏 %d\n品质：%s%s" % [str(item.get("kind", "物品")), category, inventory_count, storage_count, quality_text, " · ▣ 已锁定" if locked else ""]
	var freshness_count := inventory_count if inventory_count > 0 else storage_count
	var freshness_side := "bag" if inventory_count > 0 else "storage"
	if freshness_count > 0 and GameState._is_food(selected_id):
		var freshness: Dictionary = GameState.food_freshness(selected_id, freshness_count, freshness_side)
		status += "\n保鲜：%s%s" % [str(freshness.get("label", "")), " · 宜先用" if float(freshness.get("ratio", 1.0)) <= 0.2 else ""]
	detail_status.text = status
	var uses: Array = description.get("uses", [])
	var likes: Array = description.get("likes", [])
	detail_description.text = str(info.get("detail","")) if discovered else "亲自发现后展开完整资料。"
	detail_source.text = "来源："+str(info.get("source",""))+("\n"+str(info.reason) if not str(info.get("reason","")).is_empty() else "")
	detail_uses.text = ("用途："+"、".join(info.get("uses",uses))) if discovered else ""
	detail_likes.text = ("喜欢它的乡亲："+"、".join(likes)) if discovered and not likes.is_empty() else ""

func _refresh_tools() -> void:
	for child in tool_grid.get_children():
		tool_grid.remove_child(child)
		child.queue_free()
	var definitions: Dictionary = GameState.system_catalog.get("tools", {}).get("defs", {})
	for tool_id in definitions:
		var definition: Dictionary = definitions[tool_id]
		var row := VBoxContainer.new()
		row.custom_minimum_size = Vector2(96, 54)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 1)
		var icon := Control.new()
		icon.set_script(ITEM_ICON_SCRIPT)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.call("configure", str(tool_id))
		row.add_child(icon)
		var caption := Label.new()
		caption.text = "%s · %d阶" % [str(definition.get("name", tool_id)), int(GameState.toolkit.get(str(tool_id), {}).get("level", 0))]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 9)
		caption.add_theme_color_override("font_color", Color("d8d2b3"))
		row.add_child(caption)
		tool_grid.add_child(row)

func _on_search_changed_deferred() -> void:
	_refresh_items()
	_refresh_detail()
