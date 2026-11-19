extends Control
class_name CommunityPanel

var card_list: VBoxContainer
var close_button: Button
var content_scroll: ScrollContainer
var tab_buttons: Dictionary = {}
var achievement_buttons: Dictionary = {}
var transaction_buttons: Dictionary = {}
var tabs := ["projects", "orders", "favors", "gatherings", "records", "journal", "archives", "year"]
var tab_labels := {"projects": "公共项目", "orders": "邻里委托", "favors": "顺路帮忙", "gatherings": "随时共作", "records": "四季记事", "journal": "生活日志", "archives": "旧物柜", "year": "年度回顾"}
var active_tab := "projects"
var growth_quantities:Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.12, 0.14, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -295
	panel.offset_bottom = 295
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c3d3e")
	style.border_color = Color("b9b99a")
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
	title.text = "乡里共作簿 · 一起把日子过好"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("eee8cb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "合上 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var book_button:=Button.new();book_button.text="禾溪邻里簿"
	book_button.tooltip_text="行踪、约定与对话记录"
	book_button.pressed.connect(func():close();get_parent().show_neighbor_book())
	header.add_child(book_button)
	var tab_row := GridContainer.new()
	tab_row.columns = 4
	tab_row.add_theme_constant_override("separation", 6)
	column.add_child(tab_row)
	for tab_id in tabs:
		var button := Button.new()
		button.text = str(tab_labels[tab_id])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		tab_buttons[tab_id] = button
		button.pressed.connect(_select_tab.bind(str(tab_id)))
		tab_row.add_child(button)
	content_scroll = ScrollContainer.new()
	var scroll := content_scroll
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	card_list = VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 9)
	scroll.add_child(card_list)
	GameState.changed.connect(refresh)
	visible = false

func open_panel(tab_id: String = "") -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	if tab_id in tabs:
		active_tab = tab_id
		content_scroll.scroll_vertical = 0
	visible = true
	GameState.ui_open = true
	refresh()
	close_button.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _select_tab(tab_id: String) -> void:
	active_tab = tab_id
	content_scroll.scroll_vertical = 0
	refresh()

func _items_text(needs: Dictionary) -> String:
	if needs.is_empty(): return "不需要额外材料。"
	var rows: Array[String] = []
	for item_id in needs:
		rows.append("%s ×%d（背包 %d）" % [str(GameState.item_catalog.get(str(item_id), {}).get("name", item_id)), int(needs[item_id]), int(GameState.inventory.get(str(item_id), 0))])
	return "所需：" + "、".join(rows)

func _add_card(title: String, description: String, action_label: String = "", disabled: bool = false, action: Callable = Callable(), icon_key: String = "") -> Button:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3a5049")
	style.border_color = Color("778d72")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	card_list.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	card.add_child(body)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color("f1e6c8"))
	var illustration := preload("res://scripts/item_art.gd").texture_for(icon_key) if icon_key != "" else null
	if illustration != null:
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 10)
		body.add_child(header)
		var art := TextureRect.new()
		art.texture = illustration
		art.custom_minimum_size = Vector2(56, 56)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_meta("item_art_key", icon_key)
		header.add_child(art)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(heading)
	else:
		body.add_child(heading)
	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", Color("d8e4d6"))
	body.add_child(detail)
	if action_label != "":
		var button := Button.new()
		button.text = action_label
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = disabled
		if action.is_valid(): button.pressed.connect(action)
		body.add_child(button)
		return button
	return null

func refresh() -> void:
	if not visible or not is_instance_valid(card_list): return
	var focus_owner := get_viewport().gui_get_focus_owner()
	var focus_key:String="";var scroll_value:int=content_scroll.scroll_vertical
	for key:String in transaction_buttons:
		if transaction_buttons[key]==focus_owner:focus_key=key;break
	achievement_buttons.clear();transaction_buttons.clear()
	var restore_focus := focus_owner != null and card_list.is_ancestor_of(focus_owner)
	for tab_id in tab_buttons: tab_buttons[tab_id].set_pressed_no_signal(tab_id == active_tab)
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()
	match active_tab:
		"projects": _show_projects()
		"orders": _show_orders()
		"favors": _show_favors()
		"gatherings": _show_gatherings()
		"records": _show_records()
		"journal": _show_journal()
		"archives": _show_archives()
		"year": _show_year()
	if restore_focus and focus_key!="":_restore_transaction_focus.call_deferred(focus_key,scroll_value,GameState.day,GameState.current_interior)
	elif restore_focus and tab_buttons.has(active_tab):tab_buttons[active_tab].grab_focus()
	content_scroll.set_deferred("scroll_vertical",scroll_value)

func _show_projects()->void:
	var growth:Script=preload("res://scripts/village_growth.gd")
	for id:String in growth.ORDER:
		var data:Dictionary=GameState.content.projects[id];var q:Dictionary=growth.quote(GameState,id)
		var phase:String=str(q.phase);var actions:Array={"survey":["survey"],"materials":["contribute","procure"],"collaborate":["collaborate"],"firstUse":["use"],"complete":[]}[phase]
		var text:String=str(data.change)+"\n"+{"survey":"先到现场勘察，再分次筹料。","materials":"已交建材留在现场，支持分次提交。","collaborate":"材料齐备，等待乡亲按真实路线到场。","firstUse":"施工完成，第一次使用后记下改变。","complete":"已经完成与体验。"}[phase]
		_add_card(str(data.name),text+"\n"+_items_text(q.remaining))
		for op:String in actions:
			var quote:Dictionary=growth.quote(GameState,id,op)
			var label:String={"survey":"现场勘察 · 5 分钟","contribute":"提交当前可用建材","procure":"委托筹料 · %d 元"%int(quote.money),"collaborate":"现场协作 · 10 分钟 / 4 体力","use":"体验新设施"}[op]
			var quantities:Dictionary=growth_quantities.get_or_add(id,{})
			var detail:String=str(quote.reason) if not quote.ready else "确认后办理；失败不结算。"
			if op=="procure" and quote.ready:detail="支付 %d 元，补齐现场缺口。建材不会发到背包。"%int(quote.money)
			if op=="contribute" and quote.ready:detail="只扣下方选中的未保护建材；其余留在背包。"
			var button:Button=_add_card(label,detail,label,not bool(quote.ready),_begin_growth.bind(id,op,quantities))
			transaction_buttons["growth:"+id+":"+op]=button
			if op=="contribute" and quote.ready:
				var fields:=HBoxContainer.new();button.get_parent().add_child(fields);button.get_parent().move_child(fields,button.get_index())
				for item:String in quote.contribution:
					var maximum:int=int(quote.contribution[item]);quantities[item]=clampi(int(quantities.get(item,maximum)),0,maximum)
					var name:=Label.new();name.text=str(GameState.item_catalog[item].name);fields.add_child(name)
					var amount:=SpinBox.new();amount.min_value=0;amount.max_value=maximum;amount.step=1;amount.value=int(quantities[item]);amount.custom_minimum_size.x=90;fields.add_child(amount)
					amount.value_changed.connect(func(value:float):quantities[item]=int(value))
					transaction_buttons["quantity:"+id+":"+item]=amount.get_line_edit()

func _show_orders() -> void:
	for order in GameState.content.get("orders", []):
		var order_id := str(order.get("id", ""))
		var done := bool(GameState.flags.get(order_id, false))
		var npc_id := str(order.get("npc", ""))
		var enough := true
		for item_id in order.get("needs", {}):
			if int(GameState.inventory.get(str(item_id), 0)) < int(order.needs[item_id]) or GameState.economy.get("locked", []).has(str(item_id)): enough = false
		var reward_rows: Array[String] = []
		for item_id in order.get("reward", {}): reward_rows.append("%s ×%d" % [str(GameState.item_catalog.get(str(item_id), {}).get("name", item_id)), int(order.reward[item_id])])
		var detail := "%s\n%s\n回礼：%d 元 · %s\n%s" % [str(order.get("text", "")), _items_text(order.get("needs", {})), int(order.get("money", 0)), "、".join(reward_rows), "已经送达。" if done else "备好料理即可提交，没有期限。"]
		transaction_buttons["deliver:" + order_id] = _add_card(str(order.get("title", order_id)), detail, "已送达" if done else "送去料理", done or not enough, _begin_transaction.bind("deliver", order_id))

	var repaired := bool(GameState.flags.get("bridge",false))
	var bridge_needs := {"wood":8,"bamboo":6}
	var bridge_detail := "换下旧木板，添一张长椅。让老人孩子都能安心在河边歇脚。\n" + _items_text(bridge_needs)
	if not bool(GameState.flags.get("firstDish",false)): bridge_detail += "\n先给林阿婆送一道家常菜。她会把你介绍给大家。"
	var unavailable := not bool(GameState.flags.get("firstDish",false)) or not GameState._building_has(bridge_needs)
	transaction_buttons["repair:"] = _add_card("一起修缮村口河埠" + (" · 已经完成" if repaired else ""),bridge_detail,"去河边看看" if repaired else "和乡亲们动工",not repaired and unavailable,_go_gathering.bind("river") if repaired else _begin_transaction.bind("repair",""))

func _show_favors() -> void:
	for favor in GameState.content.get("favors", []):
		var favor_id := int(favor.get("id", -1))
		var done := bool(GameState.season_events.get("favor-%d" % favor_id, false))
		var reward_rows: Array[String] = []
		for item_id in favor.get("reward", {}): reward_rows.append("%s ×%d" % [str(GameState.item_catalog.get(str(item_id), {}).get("name", item_id)), int(favor.reward[item_id])])
		var detail := "%s\n%s\n回礼：%d 元 · %s" % [str(favor.get("text", "")), _items_text(favor.get("needs", {})), int(favor.get("money", 0)), "、".join(reward_rows)]
		transaction_buttons["e-favor:" + str(favor_id)] = _add_card(str(favor.get("title", "邻里帮忙")), detail, "已记下" if done else "交付材料并帮忙", done, _begin_transaction.bind("e-favor", str(favor_id)))

func _begin_transaction(action_id: String, item_id: String, choice: int = -1) -> void:
	if action_id in ["deliver","repair","e-project","e-favor"]:
		var id: String="wish:"+item_id if action_id=="deliver" else "favor:"+item_id if action_id=="e-favor" else "project:"+("bridge" if action_id=="repair" else item_id)
		if not GameState.quests.entries.has(id):GameState.quest_accept(id)
		get_parent().life_plan_panel.open_panel(id,"active")
		return
	if GameState.action_busy(): return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var saved_tab := active_tab
	var saved_scroll := content_scroll.scroll_vertical
	var key := action_id + ":" + item_id + (":" + str(choice) if choice >= 0 else "")
	var button: Button = transaction_buttons.get(key)
	if not is_instance_valid(button): return
	var action := GameState.ACTION_RULES.ui(action_id, button.text)
	if item_id != "": action.item = item_id
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		active_tab = saved_tab
		refresh()
		_restore_transaction_focus.call_deferred(key, saved_scroll, starting_day, starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		match action_id:
			"e-project": GameState.confirm_operation(GameState.complete_community_project(item_id))
			"repair":
				GameState.confirm_operation(GameState.repair_community_bridge())
			"e-favor": GameState.confirm_operation(GameState.complete_neighbor_favor(int(item_id)))
			"deliver": GameState.confirm_operation(GameState.fulfill_legacy_order(item_id))
			"e-chapter": GameState.confirm_operation(GameState.record_legacy_chapter(int(item_id), choice))
			"e-small-event": GameState.confirm_operation(GameState.attend_small_gathering(item_id))
			"e-year-plan": GameState.confirm_operation(GameState.record_year_plan(int(item_id)))
		restore.call()
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action, {"kind": "ui", "x": position.x, "y": position.y}, commit, restore): restore.call()

func _restore_transaction_focus(key: String, scroll_value: int, starting_day: int, starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	var button: Control = transaction_buttons.get(key)
	if is_instance_valid(button) and (not button is BaseButton or not button.disabled): button.grab_focus()
	elif tab_buttons.has(active_tab): tab_buttons[active_tab].grab_focus()
	content_scroll.scroll_vertical = scroll_value

func _show_gatherings() -> void:
	var growth:Script=preload("res://scripts/village_growth.gd")
	var observation:Dictionary=growth.activity_quote(GameState,"observe")
	_add_card("来源观察",str(observation.reason) if not observation.ready else "观察眼前的田块或钓点 · 5 分钟 · 不耗材料", "记录眼前的来源",not observation.ready,func():GameState.village_activity("observe"))
	for person:Dictionary in GameState.npc_catalog:
		if not GameState.npc_is_near(str(person.id)):continue
		for kind:String in ["meal","share"]:
			var q:Dictionary=growth.activity_quote(GameState,kind,str(person.id))
			_add_card(GameState.npc_name(str(person.id))+" · "+("分享家常菜" if kind=="meal" else "聊聊生活见闻"),str(q.reason) if not q.ready else "10 分钟 · "+("实际用掉一份 "+str(GameState.item_catalog[q.item].name) if q.item!="" else "无材料费用")+" · 不重复奖励关系与物品", "一起坐一会儿",not q.ready,func():GameState.village_activity(kind,str(person.id)))
	var names := {"tea": "山间茶桌", "repair": "修理摊边的小聚", "stage": "戏台上的小调", "lost": "河边的小画本"}
	var details := {"tea": "周远烧好热水，欢迎坐下来讲讲这一周。", "repair": "宋伯摆出旧工具，大家讲讲修好继续用的东西。", "stage": "戏台修好后，江桂珍每周招呼大家来听一段。", "lost": "小岚请大家陪她找一找落在长椅边的画本。"}
	var regions := {"tea": "mountain", "repair": "town", "stage": "town", "lost": "river"}
	for kind in ["tea", "repair", "stage", "lost"]:
		var region := str(regions[kind])
		var nearby := GameState.atlas_region_id(GameState.player_position) == region
		transaction_buttons["e-small-event:" + kind] = _add_card(str(names[kind]), str(details[kind]) + " · " + str(GameState.world_village.offsets[region].get("name", region)), "参加一会儿" if nearby else "去附近看看", false, _begin_transaction.bind("e-small-event", kind) if nearby else _go_gathering.bind(region))

func _go_gathering(region_id: String) -> void:
	var target: Dictionary = GameState.world_village.get("regionDestinations", {}).get(region_id, {}).duplicate(true)
	if target.is_empty(): return
	# Travel uses the original village destination, independently of atlas marker IDs.
	target.source_destination = true
	var actor := get_tree().get_first_node_in_group("player")
	if actor != null and bool(actor.call("walk_to", target)): close()

func _show_records() -> void:
	var chapters: Array = GameState.content.get("seasonChapters", [])
	var current_year := int(GameState.day / 112) + 1
	for season in range(chapters.size()):
		var chapter: Dictionary = chapters[season]
		var key := "%d-%d" % [current_year, season]
		var recorded := GameState.legacy_chapters.has(key)
		var choices: Array = chapter.get("choices", [])
		for choice in range(choices.size()):
			var season_name := str(GameState.content.get("seasons", ["春", "夏", "秋", "冬"])[season])
			var is_selected := recorded and int(GameState.legacy_chapters[key]) == choice
			var future := posmod(GameState.day, 112) < season * 28
			var description := "%s\n%s" % [str(chapter.get("text", "")), str(chapter.get("goal", ""))]
			if recorded: description += "\n今年已经记下另一种回应。"
			transaction_buttons["e-chapter:%d:%d" % [season, choice]] = _add_card("%s · %s%s" % [season_name, str(chapter.get("title", "时令随笔（可选）")), " · 已选" if is_selected else ""], description + "\n" + str(choices[choice]), "已记下" if recorded else "选择这段回应", recorded or future, _begin_transaction.bind("e-chapter", str(season), choice))
	_show_achievements()

func _show_achievements() -> void:
	for achievement in GameState.content.get("achievements", []):
		var achievement_id := str(achievement.get("id", ""))
		var status := GameState.achievement_status(achievement_id)
		var reward_id := str(achievement.get("reward", ""))
		var reward_name := str(GameState.content.get("furniture", {}).get(reward_id, {}).get("name", reward_id))
		var progress := "%d / %d" % [int(status.current), int(status.target)]
		achievement_buttons[achievement_id] = _add_card(str(achievement.get("name", achievement_id)), "%s\n记录：%s\n纪念物：%s" % [str(achievement.get("desc", "")), progress, reward_name], "已领取" if bool(status.claimed) else "领取纪念物", not bool(status.ready), _claim_achievement.bind(achievement_id), "achievements/" + achievement_id)

func _claim_achievement(achievement_id: String) -> void:
	if GameState.action_busy(): return
	var starting_day := GameState.day
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room == "" else GameState.interior_position
	var saved_tab := active_tab
	var saved_scroll := content_scroll.scroll_vertical
	var restore := func():
		if not is_instance_valid(self) or GameState.day != starting_day or GameState.current_interior != starting_room: return
		visible = true
		GameState.ui_open = true
		active_tab = saved_tab
		refresh()
		_restore_achievement_focus.call_deferred(achievement_id, saved_scroll, starting_day, starting_room)
	var commit := func():
		if GameState.day != starting_day or GameState.current_interior != starting_room: return
		GameState.confirm_operation(GameState.claim_legacy_achievement(achievement_id))
		restore.call()
	var action := GameState.ACTION_RULES.ui("e-achievement", "领取纪念物")
	action.item = achievement_id
	close()
	GameState.cancel_farm_queue()
	GameState.cancel_ranch_queue()
	GameState.kitchen_task.clear()
	GameState.building_task.clear()
	GameState.museum_task.clear()
	GameState.npc_task.clear()
	GameState.walking_target.clear()
	if not GameState.begin_action(action, {"kind": "ui", "x": position.x, "y": position.y}, commit, restore): restore.call()

func _restore_achievement_focus(achievement_id: String, scroll_value: int, starting_day: int, starting_room: String) -> void:
	if not visible or GameState.day != starting_day or GameState.current_interior != starting_room: return
	var button: Button = achievement_buttons.get(achievement_id)
	if is_instance_valid(button) and not button.disabled: button.grab_focus()
	elif tab_buttons.has(active_tab): tab_buttons[active_tab].grab_focus()
	content_scroll.scroll_vertical = scroll_value


func _show_archives() -> void:
	_add_card("爷爷的旧物柜，村庄的新记录。", "不收奇珍，只留生活。收集不会锁住年度结局。")
	for entry in GameState.content.get("archives", []):
		var owned := GameState.archives.has(str(entry.get("id", "")))
		_add_card(str(entry.get("title", "")) if owned else "还没有收好的记录", str(entry.get("text", "")) if owned else "线索：" + str(entry.get("source", "")), "", false, Callable(), "archives/" + str(entry.get("id", "")) if owned else "")
	_show_achievements()

func _show_journal() -> void:
	_add_card("日子里的来往，都记得。", "重要事件另有线索页与回看入口；这份日志负责把经历好好收起来。", "打开旧物柜", false, _select_tab.bind("archives"))
	var entries := GameState.journal_entries()
	for row in entries:
		var entry_day := maxi(0, int(row.get("day", 0)))
		_add_card("第 %d 年 · %s %d 日" % [entry_day / 112 + 1, str(GameState.content.get("seasons", ["春", "夏", "秋", "冬"])[entry_day % 112 / 28]), entry_day % 28 + 1], str(row.get("text", "")))
	if entries.is_empty(): _add_card("这一页还空着。", "收成、相聚和屋里的旧物，会慢慢留下记录。")

func _show_year() -> void:
	if GameState.day < 112:
		_add_card("一年，把日子过成自己的模样。", "走完四季后，这里会留下年度回顾。未完成的故事仍会等你，不按钱或全收集给日子评分。")
		return
	_add_card("春耕 · 夏雨 · 秋收 · 冬灯", "四季已经走完，未完成的故事仍会等你。\n\n" + "\n\n".join(GameState.year_summary()))
	var plan_key := str(int(GameState.day / 112))
	var choices := ["继续照看小院，也常与邻居来往", "分享手艺，摆开更多饭桌", "出门看看，也保留回家的路"]
	if GameState.year_plans.has(plan_key):
		var choice := clampi(int(GameState.year_plans[plan_key]), 0, 2)
		_add_card("来年的安排已经写好", choices[choice] + "。继续自由生活，所有未完成故事仍会等你。")
	else:
		for choice in range(choices.size()):
			transaction_buttons["e-year-plan:" + str(choice)] = _add_card("来年，你想给什么多留一点时间？", choices[choice], "记下这个想法", false, _begin_transaction.bind("e-year-plan", str(choice)))
	_add_card("继续新一年的生活", "回到小院或翻看个人故事。", "翻看个人故事", false, _open_stories)

func _open_stories() -> void:
	close()
	get_parent().call("show_neighbors")

func _begin_growth(id:String,op:String,quantities:Dictionary)->void:
	if GameState.start_growth_action(id,op,quantities.duplicate(true) if op=="contribute" else {}):close()
