extends Control
class_name FishingPanel
signal world_fishing_changed(water_id: String, spot_id: String, state: String, value: float)
const SERVICE=preload("res://scripts/fishing_service.gd")
const KNOWLEDGE=preload("res://scripts/knowledge_catalog.gd")
var water_id: String=""
var spot_id: String=""
var page: int=0
var tabs: TabContainer
var water_label: Label
var options_label: Label
var records_label: Label
var bait_button: Button
var mode_button: Button
var style_button: Button
var depth_button: Button
var cast_button: Button
var gear_rows: VBoxContainer
var trap_rows: VBoxContainer
var live_panel: PanelContainer
var phase_label: Label
var status_label: Label
var reel_button: Button
var fishing_cancel_button: Button
var meter: Control
var result_panel: PanelContainer
var result_label: Label
var result_icon: TextureRect
var last_world_state: String="idle"
var active: bool:
	get:return GameState.fishing_active()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.color=Color(0.07,0.13,0.12,0.7);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",_paper());panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=42;panel.offset_top=35;panel.offset_right=-42;panel.offset_bottom=-35;add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",9);panel.add_child(column)
	var head:=HBoxContainer.new();column.add_child(head)
	var title:=Label.new();title.text="水畔垂钓手记";title.add_theme_font_size_override("font_size",23);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	_button("收好手记 · Esc",head,close)
	water_label=_label(column,"")
	tabs=TabContainer.new();tabs.add_theme_stylebox_override("panel",_paper());tabs.add_theme_stylebox_override("tab_selected",_paper());tabs.add_theme_stylebox_override("tab_unselected",_paper());tabs.add_theme_color_override("font_selected_color",Color("354537"));tabs.add_theme_color_override("font_unselected_color",Color("6c6957"));tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	var prepare:=_page("准备与钓具")
	var choices:=HFlowContainer.new();prepare.add_child(choices)
	bait_button=_button("",choices,_cycle_bait)
	mode_button=_button("",choices,func():GameState.set_fishing_option("mode","standard" if str(GameState.fishing.mode)=="relaxed" else "relaxed"))
	style_button=_button("",choices,func():GameState.set_fishing_option("inputStyle","toggle" if str(GameState.fishing.get("inputStyle","hold"))=="hold" else "hold"))
	depth_button=_button("",choices,func():GameState.set_fishing_option("depth",(int(GameState.fishing.get("depth",1))+1)%3))
	options_label=_label(prepare,"")
	cast_button=_button("在这处水岸抛竿",prepare,start_cast)
	_label(prepare,"先选近、中、远落点；按住再松开可蓄力调整。轻松辅助自动提竿，仍由你追踪鱼影。")
	gear_rows=VBoxContainer.new();prepare.add_child(gear_rows)
	var traps:=_page("岸边捕笼")
	var bulk:=HFlowContainer.new();traps.add_child(bulk)
	_button("沿路收取待领产物",bulk,_bulk.bind("take"))
	_button("沿路给空笼补饵",bulk,_bulk.bind("bait"))
	_label(traps,"捕笼需一份制成的鱼饵，次日查看；最多同时部署 8 个。未收取时停止继续生产。")
	trap_rows=VBoxContainer.new();traps.add_child(trap_rows)
	var book:=_page("水产手记")
	records_label=_label(book,"")
	_button("打开完整水产图鉴",book,func():var hud: Node=get_parent();hud.show_museum("catalog");hud.museum_panel.category_filter="鱼类";hud.museum_panel.category_option.select(3);hud.museum_panel.refresh())
	live_panel=PanelContainer.new();live_panel.set_meta("compact_hud",true);live_panel.add_theme_stylebox_override("panel",_paper());live_panel.name="FishingActivity";get_parent().add_child.call_deferred(live_panel)
	live_panel.anchor_left=1;live_panel.anchor_right=1;live_panel.offset_left=-246;live_panel.offset_right=-16;live_panel.offset_top=82 if preload("res://scripts/performance_policy.gd").touch_device() else 90
	var live:=VBoxContainer.new();live_panel.add_child(live)
	phase_label=_label(live,"")
	meter=Control.new();meter.set_script(preload("res://scripts/fishing_meter.gd"));live.add_child(meter)
	status_label=_label(live,"");status_label.custom_minimum_size.x=190
	reel_button=_button("按住 / 松开",live,func():pass)
	reel_button.button_down.connect(func():GameState.fishing_input("press"))
	reel_button.button_up.connect(func():GameState.fishing_input("release"))
	var secondary:=HBoxContainer.new();live.add_child(secondary)
	_button("暂停／设置",secondary,_pause_settings)
	fishing_cancel_button=_button("收竿取消",secondary,GameState.cancel_player_action)
	live_panel.hide()
	result_panel=PanelContainer.new();result_panel.add_theme_stylebox_override("panel",_paper());result_panel.name="FishingResult";get_parent().add_child.call_deferred(result_panel)
	result_panel.anchor_left=0.5;result_panel.anchor_right=0.5;result_panel.anchor_top=0.5;result_panel.anchor_bottom=0.5;result_panel.offset_left=-225;result_panel.offset_right=225;result_panel.offset_top=-145;result_panel.offset_bottom=145
	var result_column:=VBoxContainer.new();result_panel.add_child(result_column)
	result_icon=TextureRect.new();result_icon.custom_minimum_size=Vector2(120,96);result_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;result_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;result_column.add_child(result_icon)
	result_label=_label(result_column,"")
	var decisions:=HBoxContainer.new();result_column.add_child(decisions)
	_button("留在鱼篓",decisions,_resolve.bind(false));_button("轻轻放流并记录",decisions,_resolve.bind(true))
	result_panel.hide()
	GameState.changed.connect(refresh);GameState.fishing_session_changed.connect(_on_session_changed)
	visible=false
	call_deferred("refresh")

func _paper() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("f2e8d2");style.border_color=Color("a98b63");style.set_border_width_all(1);style.set_content_margin_all(12);style.set_corner_radius_all(7);return style

func _page(title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",10);scroll.add_child(column);return column
func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=40;button.pressed.connect(callback);parent.add_child(button);return button
func _label(parent: Node, text: String) -> Label:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func open_panel(next_water_id: String="", next_spot_id: String="") -> void:
	if active:return
	water_id=next_water_id;spot_id=next_spot_id
	if water_id=="":
		var best:=INF
		for at: Dictionary in GameState.system_catalog.fishing.spots:
			var distance: float=GameState.player_position.distance_to(Vector2(float(at.x),float(at.y)))
			if distance<best:best=distance;spot_id=str(at.id);water_id=str(at.water)
	visible=true;GameState.ui_open=true;tabs.current_tab=page;refresh();cast_button.grab_focus()
func close() -> void:
	page=tabs.current_tab;hide();GameState.ui_open=not GameState.fishing.get("pending",{}).is_empty()
func is_open() -> bool:return visible
func _cycle_bait() -> void:
	var ids: Array=GameState.system_catalog.fishing.baits.keys();var index:=ids.find(str(GameState.fishing.bait));GameState.set_fishing_option("bait",str(ids[(index+1)%ids.size()]))
func refresh() -> void:
	if result_panel==null:return
	var pending: Dictionary=GameState.fishing.get("pending",{})
	result_panel.visible=not pending.is_empty()
	if not pending.is_empty():
		GameState.ui_open=true
		result_icon.texture=preload("res://scripts/item_art.gd").texture_for(str(pending.fish),"items")
		result_label.text="%s · %.1f 厘米 · %s\n%s%s" % [str(pending.name),float(pending.length),["普通","优质","上品","珍品"][int(pending.grade)],"初次发现！ " if bool(pending.get("new",false)) else "","体长新纪录！" if bool(pending.get("best",false)) else ""]
	if not visible:return
	var f: Dictionary=GameState.system_catalog.fishing
	water_label.text=str(f.waters.get(water_id,{}).get("name","水岸"))+" · "+str(f.waters.get(water_id,{}).get("tip",""))
	var bait: Dictionary=f.baits[str(GameState.fishing.bait)]
	bait_button.text="鱼饵："+str(bait.name)+(" · 免费" if str(GameState.fishing.bait)=="plain" else " ×"+str(GameState.inventory.get(str(bait.get("item","")),0)))
	mode_button.text="轻松辅助" if str(GameState.fishing.mode)=="relaxed" else "手动追踪 · 可获珍品"
	style_button.text="操作：按住／松开" if str(GameState.fishing.get("inputStyle","hold"))=="hold" else "操作：按一次切换"
	depth_button.text="落点："+["近岸","中段","远水"][int(GameState.fishing.get("depth",1))]
	options_label.text=str(bait.tip)+"\n当前钓具槽 %d / %d · 熟练 %d · %s" % [GameState.fishing.get("tackles",[]).size(),int(GameState.tool_data("rod").get("level",0)),int(GameState.fishing.get("xp",0)),"鱼饵可用" if GameState.fishing_has_bait(str(GameState.fishing.bait)) else "饵料不足，可制作或改用素饵"]
	cast_button.disabled=spot_id=="" or active or not pending.is_empty()
	for container: Node in [gear_rows,trap_rows]:
		for child in container.get_children():container.remove_child(child);child.queue_free()
	for id: String in f.crafts:
		var recipe: Dictionary=f.crafts[id]
		var row:=HFlowContainer.new();gear_rows.add_child(row)
		var icon:=TextureRect.new();icon.texture=preload("res://scripts/item_art.gd").texture_for(id,"items");icon.custom_minimum_size=Vector2(34,34);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
		_label(row,str(recipe.name)+" ×"+str(int(recipe.qty))+" · 材料："+KNOWLEDGE.needs(GameState,recipe.needs))
		if f.tackles.has(id):_label(row,str(f.tackles[id].tip))
		_button("制作",row,_craft.bind(id))
		if f.tackles.has(id):_button("卸下" if GameState.fishing.get("tackles",[]).has(id) else "装配",row,GameState.fishing_equip.bind(id))
	var nearby_slots: Array=f.trapSlots.duplicate()
	nearby_slots.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.water)==water_id and str(b.water)!=water_id)
	for at: Dictionary in nearby_slots:
		var row:=HFlowContainer.new();trap_rows.add_child(row)
		_label(row,str(at.name)+" · "+SERVICE.trap_status(GameState,str(at.id)))
		var trapped: Dictionary=GameState.fishing.traps.get(str(at.id),{})
		if trapped.is_empty():_button("沿路放置",row,_task.bind(str(at.id),"place"))
		else:
			if not trapped.get("product",{}).is_empty():
				_label(row,str(GameState.item_catalog[str(trapped.product.fish)].name)+" · 第 %d 天产出" % (int(trapped.product.producedDay)+1))
				_button("收取",row,_task.bind(str(at.id),"take"));_button("放流",row,_task.bind(str(at.id),"release"))
			elif int(trapped.get("baitedDay",-1))<0:
				_button("补饵",row,_task.bind(str(at.id),"bait"));_button("拆回空笼",row,_task.bind(str(at.id),"remove"))
	var lines: Array[String]=[]
	for id: String in f.species:
		var info: Dictionary=KNOWLEDGE.describe(GameState,"item:"+id)
		lines.append(str(info.title)+" · "+str(info.source)+"\n"+str(info.records))
	records_label.text="\n\n".join(lines)
func start_cast() -> void:
	if GameState.begin_fishing(spot_id):hide();GameState.ui_open=false
func _pause_settings() -> void:
	GameState.fishing_input("clear");live_panel.hide();get_parent().show_settings()

func toggle_reel() -> void:GameState.toggle_fishing_reel()
func _craft(id: String) -> void:
	GameState.begin_action({"kind":"pack","label":"制作钓鱼用品","duration":0.8},{"x":GameState.player_position.x,"y":GameState.player_position.y},GameState.fishing_craft.bind(id))
func _task(id: String, op: String) -> void:
	if GameState.queue_fishing_tasks([{"id":id,"op":op,"bait":str(GameState.fishing.bait)}]):hide()
func _bulk(op: String) -> void:
	var tasks: Array=[]
	for id: String in GameState.fishing.traps:
		var row: Dictionary=GameState.fishing.traps[id]
		if op=="take" and not row.get("product",{}).is_empty() or op=="bait" and row.get("product",{}).is_empty() and int(row.get("baitedDay",-1))<0:tasks.append({"id":id,"op":op,"bait":str(GameState.fishing.bait)})
	if GameState.queue_fishing_tasks(tasks):hide()
func _resolve(released: bool) -> void:
	if GameState.fishing_resolve(released):
		result_panel.hide();GameState.ui_open=visible
		last_world_state="idle";world_fishing_changed.emit(water_id,spot_id,"idle",0.0)
func _on_session_changed(game: Dictionary) -> void:
	live_panel.visible=not game.is_empty() and not GameState.ui_open
	if game.is_empty():
		if last_world_state!="caught":world_fishing_changed.emit(water_id,spot_id,"idle",0.0)
		refresh();return
	var p: Dictionary=game.plan;water_id=str(p.water);spot_id=str(game.p.id)
	phase_label.text=str(GameState.fishing_phase())+("" if preload("res://scripts/input_hints.gd").touch() else " · A" if GameState.source_input_mode=="pad" else " · 空格 / "+GameState.interaction_input_label())
	meter.update_session(game)
	var stage:=str(game.stage)
	status_label.text={"charge":"按住蓄力，松开抛竿；也可使用预选落点。","cast":"浮漂轻轻落水。","wait":"留意浮漂和咬钩声。","bite":"咬钩了！按下提竿。","fight":"按住上升，松开下降。保持鱼影在绿色范围内。","caught":"托住鱼身，准备抄起。","miss":str(game.get("reason","鱼游走了"))}.get(stage,"")
	if bool(game.get("warn",false)):status_label.text="鱼正在蓄力，留意下一次突进。"
	reel_button.text="提竿" if stage=="bite" else "按一次切换" if str(p.get("inputStyle","hold"))=="toggle" else "按住上升 · 松开下降"
	var visual:=str({"charge":"cast","cast":"cast","wait":"waiting","bite":"bite","fight":"fight","caught":"caught","miss":"miss"}.get(stage,"idle"))
	last_world_state=visual;world_fishing_changed.emit(water_id,spot_id,visual,float(game.get("tension",0))/100.0)
