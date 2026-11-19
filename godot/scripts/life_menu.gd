extends Control
signal selected(entry: String)
const GROUPS={"随身":[["bag","随身背包","品质、鲜度与物品保护"],["storage","储物柜","整理收成与材料"],["map","村庄地图","站位、路线与行踪"],["calendar","节气日历","天气与聚会安排"]],"经营":[["farmcare","农田照料","种植、土壤与水分"],["animals","牧场名册","动物、伙伴与养育"],["fishing","水畔垂钓","钓具、捕笼与鱼获"],["recipes","家常菜谱","材料、工位与烹饪"],["processing","家常加工","保存收成与手艺"],["economy","物产经营","交易、订单与账本"],["tools","工具设施","改良与自动照料"],["build","修缮小院","工程与实际施工"],["decor","庭院布置","摆放与移动"]],"乡里":[["relations","乡里乡亲","认识、行踪与来往"],["neighbors","邻里簿","约定与对话记录"],["home","家与饭桌","待客、家人与宠物"],["gatherings","邻里小聚","本周活动与地点"],["projects","公共事务","一起修缮村庄"]],"手记":[["plans","任务手记","当前步骤与下一处目的地"],["catalog","物产图鉴","物产知识与新发现"],["stories","四季故事","已解锁的章节与回看"],["mail","乡间来信","来信与近况"],["journal","生活日志","收下每一点变化"],["archive","旧物柜","保存生活的痕迹"]],"系统":[["save","保存与读档","把日子好好记住"],["settings","生活设置","显示、声音与操作"],["appearance","我的样子","衣服、发型与名字"],["help","生活指南","查找玩法与按键"]]}
var buttons: Dictionary={}
var expansion_buttons: Dictionary={}
var home_button: Button
var content_scroll: ScrollContainer
var grid: GridContainer
var group_buttons: Dictionary={}
var active_group: String="随身"
var remembered_focus: Dictionary={}
var group_scroll: Dictionary={}
var split: BoxContainer
var categories: BoxContainer
var section_title: Label
var section_hint: Label
var paper: PanelContainer
const DESCRIPTIONS={"随身":"带好工具，出门走走。","经营":"照顾田园，也给自己留些闲暇。","乡里":"拜访邻居，把日子过在一起。","手记":"眼下的打算，和已经留下的故事。","系统":"保存进度，调整适合自己的玩法。"}

func _ready() -> void:
	set_meta("ui_managed_layout",true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	paper=PanelContainer.new();paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);paper.offset_left=24;paper.offset_right=-24;paper.offset_top=24;paper.offset_bottom=-24;add_child(paper)
	var margin:=MarginContainer.new()
	for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	paper.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",18);margin.add_child(column)
	set_meta("notification_column",column);set_meta("notification_index",2)
	var head:=HBoxContainer.new();column.add_child(head)
	var title:=Label.new();title.text="生活菜单";title.set_meta("ui_role","title");title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	var back:=Button.new();back.text="回到村庄";back.set_meta("ui_role","quiet");back.pressed.connect(close);head.add_child(back);buttons.close=back
	column.add_child(HSeparator.new())
	split=BoxContainer.new();split.add_theme_constant_override("separation",24);split.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(split)
	categories=BoxContainer.new();categories.vertical=true;categories.add_theme_constant_override("separation",6);split.add_child(categories)
	for id: String in GROUPS:
		var button:=Button.new();button.text=id;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size=Vector2(132,44);button.pressed.connect(_group.bind(id));categories.add_child(button);group_buttons[id]=button
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);split.add_child(content)
	section_title=Label.new();section_title.set_meta("ui_role","heading");content.add_child(section_title)
	section_hint=Label.new();section_hint.set_meta("ui_role","caption");section_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(section_hint)
	content_scroll=ScrollContainer.new();content_scroll.follow_focus=true;content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(content_scroll)
	grid=GridContainer.new();grid.columns=2;grid.set_meta("ui_responsive_grid",true);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);content_scroll.add_child(grid)
	for id: String in GROUPS:
		for entry: Array in GROUPS[id]:
			var button:=Button.new();button.text=str(entry[1]);button.set_meta("ui_role","quiet");button.custom_minimum_size=Vector2(0,92);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.set_meta("menu_group",id);button.tooltip_text=str(entry[1])+" · "+str(entry[2]);button.pressed.connect(_choose.bind(str(entry[0])));grid.add_child(button)
			# Independent labels give the title and description separate hierarchy.
			button.add_theme_color_override("font_color",Color.TRANSPARENT)
			var labels:=VBoxContainer.new();labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);labels.offset_left=14;labels.offset_right=-14;labels.offset_top=12;labels.offset_bottom=-12;labels.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(labels)
			var name_label:=Label.new();name_label.text=str(entry[1]);name_label.set_meta("ui_role","heading");name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;labels.add_child(name_label)
			var description:=Label.new();description.text=str(entry[2]);description.set_meta("ui_role","caption");description.mouse_filter=Control.MOUSE_FILTER_IGNORE;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;labels.add_child(description)
			button.set_meta("ui_label_content",true)
			buttons[str(entry[0])]=button;expansion_buttons[str(entry[0])]=button
	home_button=buttons.home
	var footer:=Label.new();footer.text="背包 B    地图 M    任务 J    ·    Esc / 手柄 B 返回";footer.set_meta("ui_role","caption");footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(footer)
	get_viewport().size_changed.connect(_layout);_group(active_group);hide()

func _layout() -> void:
	if not is_instance_valid(grid):return
	var view:Vector2=get_viewport_rect().size
	var large:float=float(GameState.player_settings.get("textScale",1))
	var narrow:bool=view.x<860 or view.x<1100 and large>1.25
	split.vertical=narrow;categories.vertical=not narrow
	for id:String in group_buttons:
		group_buttons[id].custom_minimum_size.x=0 if narrow else 132
		group_buttons[id].size_flags_horizontal=Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	grid.columns=1 if narrow else 2
	for id:String in expansion_buttons:expansion_buttons[id].custom_minimum_size.y=92*large

func _group(id: String) -> void:
	if is_instance_valid(content_scroll):group_scroll[active_group]=content_scroll.scroll_vertical
	active_group=id
	for entry: String in buttons:
		if buttons[entry].has_meta("menu_group"):buttons[entry].visible=str(buttons[entry].get_meta("menu_group"))==id
	for group: String in group_buttons:group_buttons[group].set_meta("ui_role","selected" if group==id else "tab")
	section_title.text=id;section_hint.text=str(DESCRIPTIONS[id])
	_layout();content_scroll.set_deferred("scroll_vertical",int(group_scroll.get(id,0)))
	if is_inside_tree():UIArtService.apply_subtree(self)
	if visible:
		var entry: String=str(remembered_focus.get(id,GROUPS[id][0][0]));buttons[entry].grab_focus.call_deferred()
func open_panel() -> void:
	if GameState.action_busy():return
	GameState._interrupt_navigation_for_ui();GameState.ui_open=true;show();_group(active_group)
func close() -> void:hide();GameState.ui_open=false
func is_open() -> bool:return visible
func _choose(entry: String) -> void:
	remembered_focus[active_group]=entry
	if entry=="close":close()
	else:selected.emit(entry)
