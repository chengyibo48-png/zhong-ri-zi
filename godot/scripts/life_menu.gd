extends Control
signal selected(entry: String)
const GROUPS={"随身":[["bag","随身背包","品质、鲜度与物品保护"],["storage","储物柜","整理收成与材料"],["map","村庄地图","站位、路线与行踪"],["calendar","节气日历","天气与聚会安排"]],"经营":[["farmcare","农田照料","种植、土壤与水分"],["animals","牧场名册","七种伙伴与畜舍"],["fishing","水畔垂钓","钓具、捕笼与鱼获"],["recipes","家常菜谱","材料、工位与烹饪"],["processing","家常加工","保存收成与手艺"],["economy","物产经营","交易、订单与账本"],["tools","工具设施","改良与自动照料"],["build","修缮小院","工程与实际施工"],["decor","庭院布置","摆放与移动"]],"乡里":[["relations","乡里乡亲","认识、行踪与来往"],["neighbors","邻里簿","约定与对话记录"],["home","家与饭桌","待客、家人与宠物"],["gatherings","邻里小聚","本周活动与地点"],["projects","公共事务","四季一起做的事"]],"手记":[["plans","任务手记","当前步骤与下一处目的地"],["catalog","物产图鉴","266 条知识与发现"],["stories","四季故事","已解锁的章节与回看"],["mail","乡间来信","来信与近况"],["journal","生活日志","收下每一点变化"],["archive","旧物柜","保存生活的痕迹"]],"系统":[["save","保存与读档","把日子好好记住"],["settings","生活设置","显示、声音与操作"],["appearance","我的样子","衣服、发型与名字"],["help","生活指南","查找玩法与按键"]]}
var buttons: Dictionary={}
var expansion_buttons: Dictionary={}
var home_button: Button
var content_scroll: ScrollContainer
var grid: GridContainer
var group_buttons: Dictionary={}
var active_group: String="随身"
var remembered_focus: Dictionary={}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var paper:=PanelContainer.new();paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);paper.offset_left=24;paper.offset_right=-24;paper.offset_top=24;paper.offset_bottom=-24;add_child(paper)
	var margin:=MarginContainer.new()
	for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	paper.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);margin.add_child(column)
	set_meta("notification_column",column);set_meta("notification_index",2)
	var head:=HBoxContainer.new();column.add_child(head)
	var title:=Label.new();title.text="在禾溪，好好生活。";title.add_theme_font_size_override("font_size",28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	var back:=Button.new();back.text="回到村庄";back.pressed.connect(close);head.add_child(back);buttons.close=back
	var categories:=HFlowContainer.new();column.add_child(categories)
	for id: String in GROUPS:
		var b:=Button.new();b.text=id;b.custom_minimum_size.x=100;b.pressed.connect(_group.bind(id));categories.add_child(b);group_buttons[id]=b
	var summary:=Label.new();summary.text="背包 B · 地图 M · 任务 J；页面内按 Esc / 手柄 B 返回上一页。";summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
	content_scroll=ScrollContainer.new();content_scroll.follow_focus=true;content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(content_scroll)
	grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",14);content_scroll.add_child(grid)
	for id: String in GROUPS:
		for entry: Array in GROUPS[id]:
			var button:=Button.new();button.text=str(entry[1])+"\n"+str(entry[2]);button.custom_minimum_size=Vector2(220,94);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.set_meta("menu_group",id);button.pressed.connect(_choose.bind(str(entry[0])));grid.add_child(button);buttons[str(entry[0])]=button;expansion_buttons[str(entry[0])]=button
	home_button=buttons.home
	get_viewport().size_changed.connect(_layout);hide()
func _layout() -> void:grid.columns=3 if get_viewport_rect().size.x>=1100 else 2
func _group(id: String) -> void:
	active_group=id
	for entry: String in buttons:
		if buttons[entry].has_meta("menu_group"):buttons[entry].visible=str(buttons[entry].get_meta("menu_group"))==id
	for group: String in group_buttons:group_buttons[group].disabled=group==id
	_layout()
	if visible:
		var focus: String=str(remembered_focus.get(id,GROUPS[id][0][0]));buttons[focus].grab_focus()
func open_panel() -> void:
	if GameState.action_busy():return
	GameState._interrupt_navigation_for_ui();GameState.ui_open=true;show();_group(active_group)
func close() -> void:hide();GameState.ui_open=false
func is_open() -> bool:return visible
func _choose(entry: String) -> void:
	remembered_focus[active_group]=entry
	if entry=="close":close()
	else:selected.emit(entry)
