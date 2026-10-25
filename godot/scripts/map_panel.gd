extends Control
class_name MapPanel

const MAP_CANVAS_SCRIPT := preload("res://scripts/map_canvas.gd")
const REGION_FILTERS := [
	["全部区域", ""], ["茶山", "mountain"], ["老街", "town"], ["河岸", "river"],
	["竹坞", "bamboo"], ["农场", "farm"], ["牧场", "pasture"]
]
const TYPE_FILTERS := [["全部目标", "all"], ["居民住所", "homes"], ["屋舍与地标", "services"], ["村民", "neighbors"], ["成熟田块", "harvest"], ["今日采集", "resources"], ["待补水田", "water"], ["家畜", "animals"], ["手绘标记", "pins"]]

var map_hint_label: Label
var map_canvas: Control
var region_option: OptionButton
var type_option: OptionButton
var search_box: LineEdit
var _pin_default: Variant = ""
var _pin_edited := false
var pin_name_box: LineEdit
var target_list: ItemList
var detail_label: RichTextLabel
var track_button: Button
var go_button: Button
var stop_button: Button
var custom_target: Dictionary = {}
var clear_button: Button
var pin_button: Button
var remove_pin_button: Button
var minimap_button: Button
var targets: Array[Dictionary] = []
var selected_id := ""
var region_filter := ""
var type_filter := ""
var search_text := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.07, 0.06, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -270
	panel.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = Color("293b31")
	style.border_color = Color("c5ab76")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "禾溪手绘地图"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("f3e5c4"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var book_button:=Button.new();book_button.text="禾溪邻里簿"
	book_button.tooltip_text="行踪、约定与对话记录"
	book_button.pressed.connect(func():close();get_parent().show_neighbor_book())
	header.add_child(book_button)
	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	column.add_child(content_row)
	var map_column := VBoxContainer.new()
	map_column.custom_minimum_size = Vector2(340, 0)
	map_column.add_theme_constant_override("separation", 6)
	content_row.add_child(map_column)
	map_canvas = Control.new()
	map_canvas.set_script(MAP_CANVAS_SCRIPT)
	map_canvas.custom_minimum_size = Vector2(340, 340)
	map_column.add_child(map_canvas)
	map_canvas.connect("point_selected", _map_point_selected)
	var map_hint := Label.new()
	map_hint_label=map_hint
	map_hint.text = "点击地图或地点预览路线，再选择出发。方向键 / Esc 可停止带路。"
	map_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_hint.add_theme_color_override("font_color", Color("d9cea9"))
	map_column.add_child(map_hint)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 7)
	content_row.add_child(right)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	right.add_child(filters)
	region_option = OptionButton.new()
	region_option.custom_minimum_size.x = 125
	for entry in REGION_FILTERS:
		region_option.add_item(str(entry[0]))
		region_option.set_item_metadata(region_option.item_count - 1, str(entry[1]))
	region_option.item_selected.connect(_region_changed)
	filters.add_child(region_option)
	type_option = OptionButton.new()
	type_option.custom_minimum_size.x = 125
	for entry in TYPE_FILTERS:
		type_option.add_item(str(entry[0]))
		type_option.set_item_metadata(type_option.item_count - 1, str(entry[1]))
	type_option.item_selected.connect(_type_changed)
	filters.add_child(type_option)
	type_filter = str(GameState.atlas.get("layer", "all"))
	for filter_index in range(type_option.item_count):
		if str(type_option.get_item_metadata(filter_index)) == type_filter:
			type_option.select(filter_index)
			break
	search_box = LineEdit.new()
	search_box.placeholder_text = "搜索地点或村民"
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_search_changed)
	filters.add_child(search_box)
	target_list = ItemList.new()
	target_list.custom_minimum_size = Vector2(430, 150)
	target_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_list.item_selected.connect(_target_selected)
	right.add_child(target_list)
	detail_label = RichTextLabel.new()
	detail_label.fit_content = false
	detail_label.scroll_active = true
	detail_label.custom_minimum_size = Vector2(430, 112)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("default_color", Color("eee5d2"))
	right.add_child(detail_label)
	var travel_buttons := HBoxContainer.new()
	right.add_child(travel_buttons)
	go_button = _button("沿这条路出发", travel_buttons, _go_target)
	stop_button = _button("停止带路", travel_buttons, GameState.stop_walking)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	right.add_child(buttons)
	track_button = _button("设为方向目标", buttons, _track_target)
	clear_button = _button("清除指引", buttons, _clear_target)
	pin_button = _button("标记这个地点", buttons, _pin_here)
	remove_pin_button = _button("擦除图钉", buttons, _remove_pin)
	var pin_row := HBoxContainer.new()
	column.add_child(pin_row)
	pin_name_box = LineEdit.new()
	pin_name_box.placeholder_text = "图钉名称（可留空）"
	pin_name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin_name_box.max_length = 18
	pin_name_box.text_changed.connect(_pin_text_changed)
	pin_row.add_child(pin_name_box)
	minimap_button = _button("", pin_row, _toggle_minimap)
	GameState.changed.connect(refresh)
	visible = false

func _button(text_value: String, parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	if custom_target.is_empty() and selected_id == "" and GameState.atlas.get("tracking") is Dictionary:
		custom_target = GameState.atlas.tracking.duplicate(true)
		selected_id = str(custom_target.get("id","")) if custom_target.get("id") != null else ""
	refresh()
	target_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _region_changed(index: int) -> void:
	region_filter = str(region_option.get_item_metadata(index)) if index >= 0 else ""
	_refresh_targets()

func _type_changed(index: int) -> void:
	type_filter = str(type_option.get_item_metadata(index)) if index >= 0 else "all"
	GameState.atlas.layer = type_filter
	GameState.save_game(GameState.SAVE_PATH,true)
	GameState.changed.emit()
	_refresh_targets()

func _search_changed(value: String) -> void:
	search_text = value.strip_edges().to_lower()
	_refresh_targets()

func _target_selected(index: int) -> void:
	if index < 0 or index >= targets.size(): return
	custom_target.clear()
	selected_id = str(targets[index].get("id", ""))
	_refresh_detail()

func refresh() -> void:
	if not visible or not is_instance_valid(target_list): return
	_refresh_targets()
	map_hint_label.text="已走访 %d / 6 区 · 图钉 %d / 12\n点选地点预览路线，再选择出发。\n方向键 / Esc 可停止带路。" % [GameState.atlas.get("visited",[]).size(),GameState.atlas.get("pins",[]).size()]
	minimap_button.text = "隐藏小地图" if bool(GameState.atlas.get("minimap", true)) else "显示小地图"
	map_canvas.queue_redraw()
	queue_redraw()

func _refresh_targets() -> void:
	target_list.clear()
	targets.clear()
	for target in GameState.atlas_targets():
		if region_filter != "" and str(target.get("region", "")) != region_filter: continue
		if type_filter != "all" and str(target.get("type", "")) != type_filter: continue
		var title := str(target.get("name", "地点"))
		var region: Dictionary = GameState.world_village.get("offsets", {}).get(str(target.get("region", "")), {})
		var region_name := str(region.get("name", "村外"))
		if search_text != "" and not (title + region_name + str(target.get("detail", ""))).to_lower().contains(search_text): continue
		targets.append(target)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	for target in targets:
		var region: Dictionary = GameState.world_village.get("offsets", {}).get(str(target.get("region", "")), {})
		var region_name := str(region.get("name", "村外"))
		target_list.add_item("%s · %s" % [str(target.get("name", "地点")), region_name])
		if str(target.get("id", "")) == selected_id:
			target_list.select(target_list.item_count - 1)
	if custom_target.is_empty() and selected_id != "" and not targets.any(func(target: Dictionary) -> bool: return str(target.get("id", "")) == selected_id): selected_id = ""
	_refresh_detail()
	map_canvas.queue_redraw()

func _selected_target() -> Dictionary:
	if not custom_target.is_empty(): return GameState.atlas_resolve(custom_target)
	for target in targets:
		if str(target.get("id", "")) == selected_id: return GameState.atlas_resolve(target)
	return {}

func _refresh_detail() -> void:
	var target := _selected_target()
	map_canvas.set("preview_target", target.duplicate(true))
	map_canvas.queue_redraw()
	stop_button.disabled = GameState.walking_target.is_empty()
	go_button.disabled = target.is_empty()
	var tracking: Dictionary = GameState.atlas.get("tracking", {}) if GameState.atlas.get("tracking", {}) is Dictionary else {}
	var has_tracking := not tracking.is_empty()
	clear_button.disabled = not has_tracking
	pin_button.disabled = target.is_empty()
	remove_pin_button.visible = str(target.get("type", "")) == "pins"
	_pin_default = preload("res://scripts/js_string.gd").html_input_default(target.get("name",""),18)
	_pin_edited = false
	pin_name_box.text = str(_pin_default)
	if target.is_empty():
		detail_label.text = "走过的地区会记入图册。选择地点后可设置方向指引；标记上限 12 个。"
		track_button.disabled = true
		return
	var origin := GameState.interior_return_position if GameState.current_interior != "" else GameState.player_position
	var destination := Vector2(float(target.get("x", 0)), float(target.get("y", 0)))
	var actor := get_tree().get_first_node_in_group("player")
	var route: Dictionary = actor.call("preview_walk", target) if actor != null else GameState.atlas_preview(target)
	go_button.disabled = not bool(route.get("reachable", false)) or bool(route.get("here", false))
	go_button.text = "已在屋里" if bool(route.get("here", false)) else "沿这条路出发"
	var next_point: Vector2 = route.get("next", destination)
	var delta := next_point - origin
	var direction := "正北" if absf(delta.y) > absf(delta.x) and delta.y < 0 else "正南" if absf(delta.y) > absf(delta.x) else "正东" if delta.x > 0 else "正西"
	var seconds := int(route.get("seconds",0))
	var route_description := "沿路约 %d 秒 · 先向%s" % [seconds, direction] if bool(route.get("reachable", false)) else "当前布局无法通行"
	if GameState.current_interior != "" and not bool(route.get("here", false)): route_description += " · 先由原门出屋"
	var region: Dictionary = GameState.world_village.get("offsets", {}).get(str(target.get("region", "")), {})
	detail_label.text = "%s · %s
%s
%s（绕开建筑与水域）" % [str(target.get("name", "地点")), str(region.get("name", "村外")), str(target.get("detail", "村庄里的地点")), route_description]
	track_button.disabled = false
	track_button.text = "已在指引中" if str(tracking.get("id", "")) == selected_id else "设为方向目标"
	remove_pin_button.disabled = str(target.get("type", "")) != "pins"

func _map_point_selected(point: Vector2) -> void:
	custom_target = GameState.atlas_click_point(float(point.x),float(point.y),type_filter)
	selected_id = str(custom_target.get("id","")) if custom_target.get("id") != null else ""
	_refresh_detail()

func _go_target() -> void:
	var actor := get_tree().get_first_node_in_group("player")
	var target := _selected_target()
	if actor == null or target.is_empty(): return
	if GameState.atlas_track(target):
		GameState.save_game(GameState.SAVE_PATH,true)
		if bool(actor.call("walk_to", target)): close()

func _track_target() -> void:
	var target := _selected_target()
	if not target.is_empty():
		GameState.atlas_track(target)
		GameState.save_game(GameState.SAVE_PATH,true)
	refresh()

func _clear_target() -> void:
	custom_target.clear()
	selected_id = ""
	GameState.atlas_clear_tracking()
	GameState.save_game(GameState.SAVE_PATH,true)
	refresh()

func _pin_here() -> void:
	var target := _selected_target()
	if not target.is_empty():
		GameState.atlas_pin_coordinates(float(target.get("x",0)),float(target.get("y",0)),p_in_name())
		GameState.save_game(GameState.SAVE_PATH,true)
	refresh()

func _pin_text_changed(value: String) -> void:
	_pin_edited = true
	var js = preload("res://scripts/js_string.gd")
	var units: PackedInt32Array = js.units(value)
	if units.size()>18:
		units=units.slice(0,18)
		if units.size()>0 and units[-1]>=0xd800 and units[-1]<=0xdbff: units.resize(units.size()-1)
		pin_name_box.text=str(js.from_units(units))

func p_in_name() -> Variant:
	return _pin_default if not _pin_edited and pin_name_box.text==str(_pin_default) else pin_name_box.text

func _toggle_minimap() -> void:
	hud_minimap_toggle()
	refresh()

func hud_minimap_toggle() -> void:
	var hud := get_parent()
	hud.call("set_minimap_visible", not bool(GameState.atlas.get("minimap", true)))

func _remove_pin() -> void:
	if str(_selected_target().get("type", "")) == "pins":
		var pin_id := selected_id
		custom_target.clear()
		selected_id = ""
		GameState.atlas_remove_pin(pin_id)
		GameState.save_game(GameState.SAVE_PATH,true)
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event is not InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

