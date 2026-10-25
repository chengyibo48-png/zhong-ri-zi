extends PanelContainer
var header: Button
var collapse: Button
var rows: VBoxContainer
var hud: Node
var last_signature: String=""
func _ready() -> void:
	set_meta("compact_hud",true);custom_minimum_size.x=270
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);add_child(column)
	var heading:=HBoxContainer.new();column.add_child(heading)
	header=Button.new();header.text="任务手记 · J";header.set_meta("compact_hud",true);header.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.pressed.connect(func():hud.life_plan_panel.open_panel());heading.add_child(header)
	collapse=Button.new();collapse.text="收起";collapse.set_meta("compact_hud",true);collapse.pressed.connect(func():GameState.quests.collapsed=not bool(GameState.quests.collapsed);GameState.changed.emit());heading.add_child(collapse)
	rows=VBoxContainer.new();rows.add_theme_constant_override("separation",8);column.add_child(rows)
func refresh(owner: Node) -> void:
	hud=owner
	if not is_instance_valid(rows):return
	rows.visible=not bool(GameState.quests.get("collapsed",false));collapse.text="展开" if not rows.visible else "收起"
	var selected: Array=[];var all: Array=GameState.quest_snapshot()
	var rewards:=0;var handoffs:=0
	for row: Dictionary in all:
		rewards+=int(str(row.status)=="reward");handoffs+=int(str(row.status)=="ready")
	header.text="任务手记 · J"+(" · 可领 %d" % rewards if rewards>0 else " · 可交 %d" % handoffs if handoffs>0 else "")
	for id: String in GameState.quests.pins:
		for row: Dictionary in all:
			if str(row.id)==id and str(row.status) not in ["completed","expired","abandoned"]:selected.append(row)
	if selected.is_empty():
		for row: Dictionary in all:
			if str(row.kind)=="guide" and str(row.status) in ["active","reward"]:selected.append(row);break
	var signature:=str(selected)+str(GameState.day)
	if signature==last_signature:return
	last_signature=signature
	for child: Node in rows.get_children():rows.remove_child(child);child.queue_free()
	if selected.is_empty():
		var empty:=Label.new();empty.text="今天想做些什么？\n打开手记看看新的心愿。";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;empty.set_meta("compact_hud",true);rows.add_child(empty)
	for row: Dictionary in selected.slice(0,2):
		var b:=Button.new();b.set_meta("compact_hud",true);b.text=str(row.title)+"\n"+("可以记下完成" if str(row.status)=="reward" else "备齐了 · 到现场交付" if str(row.status)=="ready" else "进度 %d / %d" % [mini(int(row.current),int(row.required)),int(row.required)]);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.pressed.connect(func():hud.life_plan_panel.open_panel(str(row.id)));rows.add_child(b)
		if int(row.deadline)>=0:
			var time:=Label.new();time.text="剩 %d 天（含今天）" % maxi(0,int(row.deadline)-GameState.day);time.set_meta("compact_hud",true);rows.add_child(time)
