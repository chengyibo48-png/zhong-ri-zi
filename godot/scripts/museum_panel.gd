extends Control
class_name MuseumPanel

const KNOWLEDGE=preload("res://scripts/knowledge_catalog.gd")
var availability: OptionButton
var entry_picture: TextureRect
var source_button: Button
var related: OptionButton
var related_keys: Array[String]=[]

const CHARACTER_PORTRAIT_SCRIPT := preload("res://scripts/character_portrait.gd")

var donation_confirmation: ConfirmationDialog
var pending_donation: Dictionary = {}
var mode := "catalog"
var can_work := false
var selected_key := ""
var selected_bundle := ""
var category_filter := "全部"
var search_text := ""
var selected_donation_mode := ""
var item_keys: Array[String] = []
var category_option: OptionButton
var search_box: LineEdit
var item_list: ItemList
var detail_label: Label
var character_portrait: Control
var mode_option: OptionButton
var grade_option: OptionButton
var research_button: Button
var observe_button: Button
var donate_button: Button
var feature_button: Button
var badge_observer_button: Button
var badge_researcher_button: Button
var claim_button: Button
var track_button: Button
var upgrade_button: Button
var status_label: Label

const CATEGORIES := ["全部", "作物", "动物", "鱼类", "物品与料理", "人物", "地区与民俗"]
const MODES := ["sample", "record", "copy"]
const MODE_NAMES := {"sample": "实物样品", "record": "观察 / 口述记录", "copy": "旧物副本"}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.075, 0.065, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.anchor_left=0.035;panel.anchor_right=0.965;panel.anchor_top=0.035;panel.anchor_bottom=0.965
	panel.offset_left=0;panel.offset_right=0;panel.offset_top=0;panel.offset_bottom=0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a3b33")
	style.border_color = Color("c5b27e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
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
	title.text = "禾溪发现册 · 村史馆"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("f3e6c5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for entry in [["catalog", "个人图鉴"], ["donate", "捐赠登记"], ["bundles", "主题收集包"], ["history", "村史札记"]]:
		var tab := Button.new()
		tab.text = str(entry[1])
		tab.pressed.connect(_choose_mode.bind(str(entry[0])))
		header.add_child(tab)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	status_label = Label.new()
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("d7dcb9"))
	column.add_child(status_label)
	var summary := HBoxContainer.new()
	column.add_child(summary)
	badge_observer_button = Button.new()
	badge_observer_button.text = "领取：禾溪观察者"
	badge_observer_button.pressed.connect(_claim_badge.bind("observer"))
	summary.add_child(badge_observer_button)
	badge_researcher_button = Button.new()
	badge_researcher_button.text = "领取：四时研习者"
	badge_researcher_button.pressed.connect(_claim_badge.bind("researcher"))
	summary.add_child(badge_researcher_button)
	var filter_row := HBoxContainer.new()
	column.add_child(filter_row)
	category_option = OptionButton.new()
	for category in CATEGORIES: category_option.add_item(category)
	category_option.item_selected.connect(_category_changed)
	filter_row.add_child(category_option)
	availability=OptionButton.new()
	for label: String in ["全部状态","未完成","本季可得","当前可得","可研究"]:availability.add_item(label)
	availability.item_selected.connect(func(_index: int):refresh())
	filter_row.add_child(availability)
	search_box = LineEdit.new()
	search_box.placeholder_text = "搜索已发现条目或线索"
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_search_changed)
	filter_row.add_child(search_box)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(310, 210)
	item_list.max_columns=3
	item_list.same_column_width=true
	item_list.fixed_column_width=100
	item_list.icon_mode=ItemList.ICON_MODE_TOP
	item_list.max_text_lines=2
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_item_selected)
	body.add_child(item_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 7)
	body.add_child(right)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 8)
	var detail_scroll:=ScrollContainer.new()
	detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(detail_scroll)
	detail_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_row)
	character_portrait = Control.new()
	character_portrait.set_script(CHARACTER_PORTRAIT_SCRIPT)
	character_portrait.custom_minimum_size = Vector2(96, 120)
	character_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	character_portrait.visible = false
	detail_row.add_child(character_portrait)
	entry_picture=TextureRect.new()
	entry_picture.custom_minimum_size=Vector2(86,90)
	entry_picture.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	entry_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	entry_picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_row.add_child(entry_picture)
	detail_label = Label.new()
	detail_label.custom_minimum_size = Vector2(250, 210)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_label.add_theme_color_override("font_color", Color("eee7d5"))
	detail_row.add_child(detail_label)
	var links_row:=HFlowContainer.new()
	right.add_child(links_row)
	source_button=_button("在地图追踪来源",links_row,_track_source)
	related=OptionButton.new()
	related.item_selected.connect(_open_related)
	links_row.add_child(related)
	var donate_row := HBoxContainer.new()
	right.add_child(donate_row)
	mode_option = OptionButton.new()
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	donate_row.add_child(mode_option)
	grade_option = OptionButton.new()
	for grade in ["普通", "优质", "上品", "珍品"]: grade_option.add_item(grade)
	mode_option.item_selected.connect(_donation_mode_changed)
	grade_option.item_selected.connect(func(_index: int): _refresh_actions())
	donate_row.add_child(grade_option)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	right.add_child(action_grid)
	research_button = _button("研读用途笔记", action_grid, _research)
	observe_button = _button("观察野生伙伴", action_grid, _observe)
	donate_button = _button("办理登记", action_grid, _donate)
	feature_button = _button("设为常设展品", action_grid, _feature)
	claim_button = _button("领取主题陈设", action_grid, _claim_bundle)
	track_button = _button("追踪此收集包", action_grid, _track_bundle)
	upgrade_button = _button("修缮村史馆", action_grid, _upgrade)
	var hint := Label.new()
	hint.text = "记录会留在个人册页；捐赠样品会交给馆方，鱼获记录、旧物副本和生态观察不会拿走原件或活物。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("c8cfb0"))
	column.add_child(hint)
	donation_confirmation=ConfirmationDialog.new()
	donation_confirmation.title="核对馆藏登记"
	donation_confirmation.ok_button_text="确认登记"
	donation_confirmation.cancel_button_text="取消，继续保留"
	donation_confirmation.confirmed.connect(_confirm_donation)
	donation_confirmation.canceled.connect(func():pending_donation.clear())
	add_child(donation_confirmation)
	GameState.changed.connect(refresh)
	visible = false

func _button(text_value: String, parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open_panel(next_mode: String = "catalog", focus_key: String = "") -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	mode = next_mode
	if focus_key != "":
		selected_key = focus_key
		category_filter = "全部"
		search_text = ""
		search_box.clear()
		category_option.select(0)
	can_work = GameState.museum_near()
	visible = true
	GameState.ui_open = true
	refresh()
	if focus_key != "" and mode in ["catalog", "donate"]:
		var focused_index := item_keys.find(selected_key)
		if focused_index >= 0:
			item_list.select(focused_index)
			item_list.call_deferred("ensure_current_is_visible")
	item_list.grab_focus()

func close() -> void:
	if donation_confirmation!=null:donation_confirmation.hide()
	pending_donation.clear()
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _choose_mode(next_mode: String) -> void:
	mode = next_mode
	refresh()
	item_list.grab_focus()

func _category_changed(index: int) -> void:
	category_filter = CATEGORIES[index] if index >= 0 and index < CATEGORIES.size() else "全部"
	refresh()

func _search_changed(value: String) -> void:
	search_text = value.strip_edges().to_lower()
	refresh()

func _item_selected(index: int) -> void:
	if mode in ["catalog", "donate"] and index >= 0 and index < item_keys.size():
		selected_key = item_keys[index]
		selected_donation_mode = ""
	elif mode == "bundles":
		var bundles: Array = GameState.system_catalog.get("museum", {}).get("bundles", [])
		if index >= 0 and index < bundles.size(): selected_bundle = str(bundles[index].get("id", ""))
	refresh()

func refresh() -> void:
	if not visible or not is_instance_valid(detail_label): return
	can_work = GameState.museum_near()
	var progress := GameState.museum_progress()
	var donated_count: int = GameState.collection.get("donated", {}).size()
	status_label.text = "发现 %d / %d · 已获得 %d · 已研究 %d · 馆藏 %d · %s%s" % [int(progress.seen), int(progress.total), int(progress.acquired), int(progress.researched), donated_count, str(_level_name()), " · 登记桌可用" if can_work else " · 登记与布展需走到村史馆内登记桌前"]
	badge_observer_button.disabled = GameState.collection.get("badges", []).has("observer") or int(progress.seen) < 15
	badge_researcher_button.disabled = GameState.collection.get("badges", []).has("researcher") or int(progress.researched) < 10
	category_option.visible = mode in ["catalog", "donate"]
	search_box.visible = mode in ["catalog", "donate"]
	preload("res://scripts/item_art.gd").fit_list(item_list)
	item_list.fixed_icon_size=Vector2i(58,52)
	availability.visible=mode=="catalog"
	source_button.visible=mode=="catalog"
	related.visible=mode=="catalog"
	item_list.clear()
	item_keys.clear()
	var selected_index := -1
	if mode in ["catalog", "donate"]:
		for entry in GameState.system_catalog.get("museum", {}).get("entries", []):
			if category_filter != "全部" and str(entry.get("category", "")) != category_filter: continue
			var key := str(entry.get("key", ""))
			if mode=="catalog" and not KNOWLEDGE.matches(GameState,key,availability.selected):continue
			var name := str(entry.get("name", ""))
			var haystack := (name + " " + str(entry.get("hint", "")) + " " + key).to_lower()
			if search_text != "" and not haystack.contains(search_text): continue
			var row: Dictionary = GameState.collection.get("entries", {}).get(key, {})
			var label := name if not row.is_empty() else "尚待发现"
			label += " · " + str(entry.get("category", ""))
			if row.get("researched", false): label += " · 已研究"
			elif row.get("acquired", false): label += " · 已获得"
			elif not row.is_empty(): label += " · 已发现"
			if GameState.collection.get("donated", {}).has(key): label += " · 已入馆"
			var illustration: Texture2D=KNOWLEDGE.picture(GameState,key,row.is_empty())
			label=(name if not row.is_empty() else "尚待发现")+(" ✓" if bool(row.get("researched",false)) else "")
			item_list.add_item(label, illustration)
			item_keys.append(key)
			if key == selected_key: selected_index = item_keys.size() - 1
		if selected_index < 0 and not item_keys.is_empty():
			selected_index = 0
			selected_key = item_keys[0]
		if selected_index >= 0: item_list.select(selected_index)
		_refresh_entry_detail()
	elif mode == "bundles":
		var bundles: Array = GameState.system_catalog.get("museum", {}).get("bundles", [])
		for bundle in bundles:
			var id := str(bundle.get("id", ""))
			var complete_count := 0
			for key in bundle.get("keys", []):
				if GameState.collection.get("donated", {}).has(str(key)): complete_count += 1
			item_list.add_item("%s · %d / %d%s" % [str(bundle.get("name", id)), complete_count, bundle.get("keys", []).size(), " · 已领奖" if GameState.collection.get("claimed", []).has(id) else ""])
			if selected_bundle == id: selected_index = item_list.item_count - 1
		if selected_index < 0 and not bundles.is_empty():
			selected_index = 0
			selected_bundle = str(bundles[0].get("id", ""))
		if selected_index >= 0: item_list.select(selected_index)
		_refresh_bundle_detail()
	else:
		var archives: Array = GameState.content.get("archives", [])
		for archive in archives:
			var known := GameState.archives.has(str(archive.get("id", "")))
			item_list.add_item(str(archive.get("title", "旧物线索")) if known else "待寻：" + str(archive.get("source", "村庄里的旧记录")))
		_refresh_history_detail()
	_refresh_actions()

func _level_name() -> String:
	var levels: Array = GameState.system_catalog.get("museum", {}).get("levels", [])
	var level := clampi(int(GameState.collection.get("level", 0)), 0, maxi(0, levels.size() - 1))
	return str(levels[level].get("name", "旧屋小展")) if not levels.is_empty() else "旧屋小展"

func _refresh_entry_detail() -> void:
	character_portrait.visible=false
	var entry: Dictionary=GameState._museum_entry(selected_key)
	if entry.is_empty():detail_label.text="选择一张图卡，翻看禾溪的生活记录。";entry_picture.hide();return
	var row:=KNOWLEDGE.state(GameState,selected_key)
	var info:=KNOWLEDGE.describe(GameState,selected_key)
	entry_picture.texture=KNOWLEDGE.picture(GameState,selected_key,row.is_empty());entry_picture.visible=entry_picture.texture!=null
	var text:=str(info.title)+" · "+str(entry.category)+"\n\n来源线索："+str(info.source)
	if not str(info.reason).is_empty():text+="\n"+str(info.reason)
	if not row.is_empty():
		text+="\n\n"+str(info.detail)
		text+="\n\n首次记录：第 %d 天 · %s" % [int(row.get("first",0))+1,"已研究" if bool(row.get("researched",false)) else "已获得" if bool(row.get("acquired",false)) else "已发现"]
		if not info.uses.is_empty():text+="\n用途："+"、".join(info.uses)
	else:text+="\n\n亲自发现后展开完整资料。"
	if not str(info.records).is_empty():text+="\n\n"+str(info.records)
	text+="\n\n研究："+GameState.museum_research_reason(selected_key)
	detail_label.text=text
	source_button.disabled=info.target.is_empty()
	related.clear();related_keys.clear();related.add_item("关联食材与用途")
	for key: String in info.links:
		if not GameState.museum_entries.has(key) or related_keys.has(key):continue
		related_keys.append(key)
		var linked: Dictionary=GameState.museum_entries[key]
		related.add_item(str(linked.name) if not KNOWLEDGE.state(GameState,key).is_empty() else "相关条目 · "+str(linked.category))
	if str(entry.type)=="npc" and not row.is_empty():
		for person: Dictionary in GameState.npc_catalog:
			if str(person.id)==str(entry.id):character_portrait.configure(str(entry.id),person);character_portrait.show();entry_picture.hide()

func _track_source() -> void:
	var target:=KNOWLEDGE.source_target(GameState,selected_key)
	if not target.is_empty():GameState.atlas_track(target)
	else:GameState.message="当前来源没有可通行的站位，请先完成相关条件或调整障碍。";GameState.changed.emit()

func _open_related(index: int) -> void:
	if index<1 or index>related_keys.size():return
	selected_key=related_keys[index-1];category_filter="全部";category_option.select(0);refresh()

func _refresh_bundle_detail() -> void:
	var bundle := GameState._museum_bundle(selected_bundle)
	if bundle.is_empty():
		detail_label.text = "完成一组真实馆藏，领取能放进庭院的纪念陈设。"
		return
	var lines: Array[String] = [str(bundle.get("name", "主题收集包")), str(bundle.get("story", "")), "", "需要登记："]
	for key in bundle.get("keys", []):
		var entry := GameState._museum_entry(str(key))
		lines.append("%s %s" % ["✓" if GameState.collection.get("donated", {}).has(str(key)) else "○", str(entry.get("name", key))])
	lines.append("\n奖励：%s ×1" % str(bundle.get("rewardName", bundle.get("reward", "纪念陈设"))))
	detail_label.text = "\n".join(lines)

func _refresh_history_detail() -> void:
	var levels: Array = GameState.system_catalog.get("museum", {}).get("levels", [])
	var current := clampi(int(GameState.collection.get("level", 0)), 0, maxi(0, levels.size() - 1))
	var text := "村史札记 · %s\n%s\n\n" % [str(levels[current].get("name", "旧屋小展")), str(levels[current].get("desc", ""))] if not levels.is_empty() else "村史札记\n\n"
	text += "项目记录与乡亲故事，会随着个人经历逐步收录。未完成的章节仍可慢慢继续。\n\n已取得的旧物：%d 件\n常设展品：" % GameState.archives.size()
	var featured: Dictionary = GameState.collection.get("featured", {})
	for group in featured:
		text += "\n%s：%s" % [str(group), str(GameState._museum_entry(str(featured[group])).get("name", featured[group]))]
	detail_label.text = text

func _refresh_actions() -> void:
	var entry := GameState._museum_entry(selected_key)
	var row: Dictionary = GameState.collection.get("entries", {}).get(selected_key, {})
	var donation := GameState._museum_donation(selected_key)
	var available_modes: Array[String] = []
	for raw_mode in donation.get("modes", []): available_modes.append(str(raw_mode))
	mode_option.clear()
	for donation_mode in available_modes: mode_option.add_item(str(MODE_NAMES.get(donation_mode, donation_mode)))
	if not available_modes.is_empty():
		var mode_index := available_modes.find(selected_donation_mode)
		if mode_index < 0: mode_index = 0
		mode_option.select(mode_index)
		selected_donation_mode = available_modes[mode_index]
	if grade_option.selected < 0: grade_option.select(0)
	mode_option.visible = mode in ["donate"] and not available_modes.is_empty()
	grade_option.visible = mode == "donate" and not available_modes.is_empty() and available_modes.has("sample") and mode_option.selected >= 0 and available_modes[mode_option.selected] == "sample"
	research_button.visible = mode == "catalog" and not row.is_empty() and not bool(row.get("researched", false))
	research_button.disabled = not GameState.museum_research_reason(selected_key).is_empty()
	observe_button.visible = mode == "catalog" and str(entry.get("type", "")) == "wild"
	observe_button.disabled = not can_work and false
	donate_button.visible = mode == "donate" and not donation.is_empty()
	var donate_mode := available_modes[mode_option.selected] if mode_option.selected >= 0 and mode_option.selected < available_modes.size() else ""
	var grade := grade_option.selected
	donate_button.text = "登记" + str(MODE_NAMES.get(donate_mode, "馆藏"))
	donate_button.disabled = not can_work or GameState.museum_donation_reason(selected_key, donate_mode, grade) != ""
	feature_button.visible = mode == "donate" and GameState.collection.get("donated", {}).has(selected_key)
	feature_button.disabled = not can_work
	claim_button.visible = mode == "bundles"
	claim_button.disabled = not can_work or not GameState.museum_bundle_complete(selected_bundle) or GameState.collection.get("claimed", []).has(selected_bundle)
	track_button.visible = mode == "bundles"
	track_button.text = "取消追踪" if str(GameState.collection.get("tracked", "")) == selected_bundle else "追踪此收集包"
	upgrade_button.visible = mode in ["bundles", "history"]
	upgrade_button.disabled = not can_work or GameState.museum_upgrade_reason() != ""

func _selected_donation_mode() -> String:
	var donation := GameState._museum_donation(selected_key)
	var available_modes: Array = donation.get("modes", [])
	return str(available_modes[mode_option.selected]) if mode_option.selected >= 0 and mode_option.selected < available_modes.size() else ""

func _donation_mode_changed(index: int) -> void:
	var modes: Array = GameState._museum_donation(selected_key).get("modes", [])
	if index >= 0 and index < modes.size(): selected_donation_mode = str(modes[index])
	_refresh_actions()

func _research() -> void:
	GameState.museum_research(selected_key)
	refresh()

func _observe() -> void:
	GameState.observe_wildlife(str(GameState._museum_entry(selected_key).get("id", "")))
	refresh()

func _donate() -> void:
	var selected_mode:=_selected_donation_mode()
	var grade:=grade_option.selected if selected_mode=="sample" else 0
	var reason:=GameState.museum_donation_reason(selected_key,selected_mode,grade)
	if reason!="" or not GameState.museum_near():return
	pending_donation={"id":selected_key,"mode":selected_mode,"grade":grade}
	var entry:=GameState._museum_entry(selected_key)
	var grades:=["普通","优质","上品","珍品"]
	donation_confirmation.dialog_text=("将从随身背包永久扣除 %s %s ×1，作为馆藏保存，不能取回。剩余 %d 份。"%[grades[grade],str(entry.name),maxi(0,int(GameState.inventory.get(str(entry.id),0))-1)] if selected_mode=="sample" else "提交"+("旧物副本" if selected_mode=="copy" else "观察 / 口述记录")+"，不消耗原件、不交出活物。")+"\n\n个人图鉴记录保留；首次登记计入对应收集包，并可设置为常设展品。"
	donation_confirmation.ok_button_text="交出这1份实物" if selected_mode=="sample" else "登记这份资料"
	donation_confirmation.popup_centered(Vector2i(560,230))

func _confirm_donation() -> void:
	if pending_donation.is_empty():return
	var task:=pending_donation.duplicate(true)
	GameState.queue_museum_task("donate",str(task.id),str(task.mode),int(task.grade))

func _feature() -> void:
	GameState.queue_museum_task("feature",selected_key)
	refresh()

func _claim_bundle() -> void:
	GameState.queue_museum_task("claim",selected_bundle)
	refresh()

func _track_bundle() -> void:
	GameState.collection.tracked = null if str(GameState.collection.get("tracked", "")) == selected_bundle else selected_bundle
	GameState.message = "已更新主题收集包追踪。"
	GameState.changed.emit()
	refresh()

func _upgrade() -> void:
	GameState.queue_museum_task("upgrade")
	refresh()

func _claim_badge(badge_id: String) -> void:
	GameState.museum_badge(badge_id)
	refresh()
