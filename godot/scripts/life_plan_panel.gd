extends Control
const Q=preload("res://scripts/quest_service.gd")
const STATUS={"available":"可接取","active":"进行中","ready":"可交付","reward":"待领取","completed":"已完成","expired":"已过期","abandoned":"已放下","locked":"等待条件"}
var selected_id: String=""
var active_tab: String="active"
var category: String="全部"
var search: LineEdit
var category_option: OptionButton
var deadline_option: OptionButton
var task_list: ItemList
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var action_dock: HFlowContainer
var summary: Label
var tabs: Dictionary={}
var current_rows: Array=[]
var refresh_pending: bool=false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var paper:=PanelContainer.new();paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);paper.offset_left=20;paper.offset_right=-20;paper.offset_top=20;paper.offset_bottom=-20;add_child(paper)
	var margin:=MarginContainer.new()
	for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	paper.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
	set_meta("notification_column",column);set_meta("notification_index",2)
	var header:=HBoxContainer.new();column.add_child(header)
	var title:=Label.new();title.text="禾溪任务手记";title.add_theme_font_size_override("font_size",26);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	button(header,"合上手记",close)
	var tabrow:=HFlowContainer.new();column.add_child(tabrow)
	for pair: Array in [["active","进行中"],["available","可接取"],["done","已完成"],["today","今天的打算"]]:tabs[str(pair[0])]=button(tabrow,str(pair[1]),_tab.bind(str(pair[0])))
	var filters:=HFlowContainer.new();column.add_child(filters)
	search=LineEdit.new();search.placeholder_text="查找任务或线索";search.custom_minimum_size.x=220;filters.add_child(search);search.text_changed.connect(func(_text: String):refresh())
	category_option=OptionButton.new();filters.add_child(category_option)
	for text: String in ["全部","主线","人物","经营","委托"]:category_option.add_item(text)
	category_option.item_selected.connect(func(index: int):category=category_option.get_item_text(index);refresh())
	deadline_option=OptionButton.new();filters.add_child(deadline_option)
	for text: String in ["全部期限","长期无期限","限时订单"]:deadline_option.add_item(text)
	deadline_option.item_selected.connect(func(_index: int):refresh())
	summary=label(column,"");summary.add_theme_font_size_override("font_size",16)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",16);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	task_list=ItemList.new();task_list.custom_minimum_size=Vector2(260,260);task_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;task_list.item_selected.connect(_select);task_list.add_theme_constant_override("v_separation",12);body.add_child(task_list)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",10);body.add_child(right)
	detail_scroll=ScrollContainer.new();detail_scroll.follow_focus=true;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(detail_scroll)
	action_dock=HFlowContainer.new();action_dock.add_theme_constant_override("h_separation",6);action_dock.add_theme_constant_override("v_separation",6);right.add_child(action_dock)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",12);detail_scroll.add_child(detail)
	GameState.quest_changed.connect(_schedule_refresh);hide()
func label(parent: Node, text: String) -> Label:
	var result:=Label.new();result.text=text;result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(result);return result
func button(parent: Node, text: String, action: Callable) -> Button:
	var result:=Button.new();result.text=text;result.pressed.connect(action);parent.add_child(result);return result
func is_open() -> bool:return visible
func open_panel(focus_id: String="", tab: String="") -> void:
	if GameState.action_busy():return
	if focus_id!="":selected_id=focus_id
	if tab!="":active_tab=tab
	GameState._interrupt_navigation_for_ui();GameState.ui_open=true;show();refresh();task_list.grab_focus()
func close() -> void:hide();GameState.ui_open=false
func _schedule_refresh() -> void:
	if visible and not refresh_pending:refresh_pending=true;refresh.call_deferred()
func _tab(tab: String) -> void:active_tab=tab;refresh()
func refresh() -> void:
	refresh_pending=false
	if not visible or not is_instance_valid(task_list):return
	var focus: Control=get_viewport().gui_get_focus_owner()
	var focused_text: String=focus.text if focus is Button and (detail.is_ancestor_of(focus) or action_dock.is_ancestor_of(focus)) else ""
	var saved_scroll: int=detail_scroll.scroll_vertical
	var restore:=selected_id;current_rows=[]
	for row: Dictionary in GameState.quest_snapshot({"category":category,"search":search.text}):
		var state:=str(row.status);var keep:=state in ["active","ready","reward"] if active_tab=="active" else state in ["available","locked"] if active_tab=="available" else state in ["completed","expired","abandoned"] if active_tab=="done" else state in ["active","ready","reward","available"]
		if not keep:continue
		if deadline_option.selected==1 and int(row.deadline)>=0 or deadline_option.selected==2 and int(row.deadline)<0:continue
		current_rows.append(row)
	current_rows.sort_custom(func(a: Dictionary,b: Dictionary):return priority(a)<priority(b) if priority(a)!=priority(b) else str(a.id)<str(b.id))
	if active_tab=="today":current_rows=current_rows.slice(0,6)
	task_list.clear();var index:=0
	for i: int in range(current_rows.size()):
		var row: Dictionary=current_rows[i];task_list.add_item(("◆ " if bool(row.pinned) else "")+str({"reward":"[领] ","ready":"[交] ","available":"[接] ","completed":"[成] "}.get(str(row.status),""))+str(row.title));task_list.set_item_metadata(i,str(row.id));task_list.set_item_tooltip(i,str(row.title)+"\n"+str(STATUS.get(str(row.status),row.status))+"\n"+str(row.text))
		if str(row.id)==restore:index=i
	for id: String in tabs:tabs[id].disabled=id==active_tab
	summary.text="固定 %d / 2 项 · 长期任务没有期限；每天只做想做的事。" % GameState.quests.pins.size() if active_tab!="today" else "今天的建议可忽略：可交付、待领取与已固定任务优先，不设每日清空奖励。"
	if current_rows.is_empty():
		selected_id="";_clear_detail();label(detail,"这里暂时没有任务。");label(detail,"可到“可接取”看看新的心愿，或合上手记自由生活。")
	else:task_list.select(index);_select(index)
	if focused_text!="":
		for node: Node in detail.find_children("*","Button",true,false)+action_dock.find_children("*","Button",true,false):
			if node.text==focused_text:node.grab_focus();break
	if restore==selected_id:detail_scroll.set_deferred("scroll_vertical",saved_scroll)
func priority(row: Dictionary) -> int:
	return 0 if str(row.status)=="reward" else 1 if str(row.status)=="ready" else 2 if row.pinned else 3 if int(row.deadline)>=0 else 4
func _clear_detail() -> void:
	for parent: Control in [detail,action_dock]:
		for child: Node in parent.get_children():parent.remove_child(child);child.queue_free()
func _select(index: int) -> void:
	if index<0 or index>=current_rows.size():return
	var changed:=selected_id!=str(current_rows[index].id);selected_id=str(current_rows[index].id)
	if changed:detail_scroll.scroll_vertical=0
	_show_detail(current_rows[index])
func _show_detail(row: Dictionary) -> void:
	_clear_detail()
	var title:=label(detail,str(row.title));title.add_theme_font_size_override("font_size",24)
	label(detail,str(row.get("chainTitle",row.category))+" · "+str(STATUS.get(str(row.status),row.status)))
	if row.has("npc"):label(detail,"委托人："+GameState.npc_name(str(row.npc)))
	label(detail,str(row.text))
	label(detail,"期限：长期无期限" if int(row.deadline)<0 else "截止：第 %d 天结束 · %s" % [int(row.deadline),"已过期" if GameState.day>=int(row.deadline) else "还剩 %d 天（含今天）" % (int(row.deadline)-GameState.day)])
	label(detail,"办理地点："+Q.location_text(GameState,row))
	if str(row.kind)=="guide":
		label(detail,"当前目标：%d / %d" % [mini(int(row.current),int(row.required)),int(row.required)])
	else:
		for material: String in row.get("materials",[]):label(detail,"• "+material)
		if int(row.get("grade",0))>0:label(detail,"品质要求："+["普通","优质","上品","珍品"][int(row.grade)]+"及以上；食物须未变质。")
	if str(row.get("reason",""))!="":label(detail,"下一步："+str(row.reason))
	var rewards: Array[String]=[]
	for item: String in row.get("reward",{}):rewards.append(str(GameState.item_catalog.get(item,{}).get("name",item))+" ×"+str(int(row.reward[item])))
	if int(row.get("money",0))>0:rewards.append(str(int(row.money))+" 元")
	if str(row.kind)=="weekly":rewards.append("合格物品的订单货款＋%d 元订单补贴 · 信用 +3" % int(row.order.bonus))
	if str(row.get("unlock",""))!="":rewards.append("解锁菜谱："+str(GameState.item_catalog.get(str(row.unlock),{}).get("name",row.unlock)))
	label(detail,"回报："+("、".join(rewards) if not rewards.is_empty() else "留下生活记录，接续下一步。"))
	var actions: HFlowContainer=action_dock
	match str(row.status):
		"available":button(actions,"接下这件事",func():GameState.quest_accept(str(row.id)))
		"reward":button(actions,"领取回礼" if not row.get("reward",{}).is_empty() else "记下完成",_claim.bind(str(row.id)))
		"ready":
			if str(row.kind) in ["wish","favor","project","weekly"]:button(actions,"当面交付" if str(row.kind)!="project" else "在现场共同动工",_submit_id.bind(str(row.id)))
	if str(row.status) not in ["completed","expired","abandoned"]:
		button(actions,"取消固定" if row.pinned else "固定到画面",func():GameState.quest_pin(str(row.id)))
		button(actions,"在地图查看",_map)
		button(actions,"沿路去看看",_go)
		button(actions,"查看办理详情",_detail)
		if str(row.kind)=="weekly" and row.accepted:button(actions,"放下这张订单",func():GameState.quest_abandon(str(row.id)))
	var links:=HFlowContainer.new();detail.add_child(links)
	for item: String in row.get("needs",{}):button(links,"查来源 · "+str(GameState.item_catalog.get(item,{}).get("name",item)),_source.bind(item))
	if str(row.kind)=="guide" and str(row.get("metric","")).begins_with("inventory:"):button(links,"查食材来源",_source.bind(str(row.metric).split(":")[1]))
func _claim(id: String) -> void:
	if not GameState.quest_claim(id):return
	for next: Dictionary in Q.guides():
		if str(next.previous)==id:selected_id=str(next.id);break
func _submit() -> void:_submit_id(selected_id)
func _submit_id(id: String) -> void:
	if GameState.quest_submit(id):get_parent().ui_stack.leave()
func _map() -> void:
	var at: Dictionary=GameState.quest_track(selected_id)
	if at.is_empty():label(detail,"当前没有可达站位，请查看办理条件后再试。");return
	get_parent().show_map();get_parent().map_panel.custom_target=at;get_parent().map_panel.refresh()
func _go() -> void:
	var at: Dictionary=GameState.quest_track(selected_id)
	if at.is_empty():label(detail,"暂时无法抵达，请查看地点、时段和开放条件。");return
	get_parent().ui_stack.leave();get_parent().get_parent().player.walk_to(Q.walk_target(GameState,Q.definition(GameState,selected_id)))
func _source(item: String) -> void:get_parent().show_museum("catalog","item:"+item)
func _detail() -> void:
	var row:=Q.definition(GameState,selected_id)
	if str(row.kind)=="story":get_parent().show_npc_story(str(row.npc))
	elif str(row.kind)=="chapter":get_parent().community_panel.open_panel("records")
	elif str(row.get("page",""))=="year":get_parent().community_panel.open_panel("year")
	elif str(row.get("page",""))=="fishing":get_parent().show_fishing()
	elif str(row.get("page","")) in ["orders","projects"]:get_parent().community_panel.open_panel("orders" if str(row.page)=="orders" else "projects")
	elif str(row.get("page",""))!="plans":get_parent()._select_life_menu(str(row.page))
