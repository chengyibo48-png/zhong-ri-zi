extends RefCounted
## One owner for modal visibility, back navigation and safe panel envelopes.
var hud: Node
var panels: Array[Control]=[]
var frames: Array[Dictionary]=[]
var muting: bool=false
var settling: bool=false
var suspended: bool=false
func setup(owner: Node, registered: Array) -> void:
	hud=owner
	for p: Control in registered:
		panels.append(p)
		p.visibility_changed.connect(_visibility.bind(p))
		p.set_meta("ui_shell",true)
	hud.get_viewport().size_changed.connect(layout)
	layout.call_deferred()
func _visibility(panel: Control) -> void:
	if muting:return
	if panel.visible:
		if suspended and not frames.any(func(frame: Dictionary):return frame.panel==panel):frames.clear()
		suspended=false
		for i: int in range(frames.size()-1,-1,-1):
			if bool(frames[i].get("closed",false)) and frames[i].panel!=panel:frames.remove_at(i)
		var focus: Control=hud.get_viewport().gui_get_focus_owner()
		var existing: int=-1
		for i: int in range(frames.size()):
			if frames[i].panel==panel:existing=i
		if existing>=0:frames.resize(existing+1);frames[existing].closed=false
		else:
			if not frames.is_empty():
				frames[-1].focus=focus
				frames[-1].focus_text=focus.text if focus is BaseButton else ""
			frames.append({"panel":panel,"focus":null,"closed":false})
		muting=true
		for p: Control in panels:
			if p!=panel and p.visible:p.hide()
		muting=false
		GameState.ui_open=true
		GameState.source_keyboard.clear()
		if GameState.fishing_active():GameState.fishing_input("clear")
		_visit(panel)
		fit.call_deferred(panel)
		_late_fit(panel)
	else:
		for frame: Dictionary in frames:
			if frame.panel==panel:frame.closed=true
	if not settling:
		settling=true
		_settle.call_deferred()
func _visit(panel: Control) -> void:
	var names: Dictionary={"market_panel":"bag","map_panel":"map","help_panel":"help","ranch_panel":"ranch","fishing_panel":"fishing","museum_panel":"catalog","weather_panel":"calendar","life_plan_panel":"tasks"}
	for property: String in names:
		if hud.get(property)==panel:GameState.quest_event("visit:"+str(names[property]));break
	if hud.get("museum_panel")==panel and preload("res://scripts/quest_service.gd").metric(GameState,"rodCatch")+preload("res://scripts/quest_service.gd").metric(GameState,"trapCatch")>0:GameState.quest_event("fishRecord")
	if hud.get("market_panel")==panel:
		for id: String in GameState.inventory:
			if int(GameState.inventory[id])>0 and GameState._is_food(id):GameState.quest_event("freshCheck");break
	if hud.get("community_panel")==panel and str(panel.get("active_tab"))=="year":GameState.quest_event("visit:year")
	GameState._refresh_quests()
func _settle() -> void:
	settling=false
	if GameState.action_busy() and active()==null:
		suspended=true;GameState.ui_open=false;return
	while not frames.is_empty() and (not is_instance_valid(frames[-1].panel) or bool(frames[-1].get("closed",false))):frames.pop_back()
	if not frames.is_empty() and not frames[-1].panel.visible:
		muting=true;frames[-1].panel.show();muting=false
		if frames[-1].panel.has_method("refresh"):frames[-1].panel.refresh()
		if is_instance_valid(frames[-1].focus) and frames[-1].focus.is_visible_in_tree():frames[-1].focus.grab_focus()
		else:
			var restored:=false
			for button: Node in frames[-1].panel.find_children("*","BaseButton",true,false):
				if button.is_visible_in_tree() and not button.disabled and str(button.text)==str(frames[-1].get("focus_text","")):button.grab_focus();restored=true;break
			if not restored:
				for list: Node in frames[-1].panel.find_children("*","ItemList",true,false):
					if list.is_visible_in_tree():list.grab_focus();break
	GameState.ui_open=active()!=null
	hud.layout_manager.refresh()
func active() -> Control:
	for i: int in range(frames.size()-1,-1,-1):
		if is_instance_valid(frames[i].panel) and frames[i].panel.visible:return frames[i].panel
	return null
func back() -> bool:
	var panel:=active()
	if panel==null:return false
	if panel.has_method("close"):panel.close()
	else:panel.hide()
	return true
func leave() -> void:
	muting=true
	for panel: Control in panels:panel.hide()
	muting=false;frames.clear();suspended=false;GameState.ui_open=false
func layout() -> void:
	for panel: Control in panels:
		if panel.visible:fit(panel)
func fit(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree():return
	var view: Vector2=panel.get_viewport_rect().size
	var safe: Vector2=preload("res://scripts/hud_dock.gd").safe_margins(panel)
	var margin:=Vector2(maxf(16,safe.x),maxf(16,safe.y))
	for child: Node in panel.get_children():
		if not child is PanelContainer:continue
		var paper: PanelContainer=child
		# Root panels get a safe bounded viewport; their existing content remains intact.
		paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		paper.offset_left=margin.x;paper.offset_right=-margin.x;paper.offset_top=margin.y;paper.offset_bottom=-margin.y
		paper.custom_minimum_size=Vector2.ZERO
		if not paper.has_meta("shell_scroll") and paper.get_child_count()==1:
			var body: Control=paper.get_child(0)
			if not body is ScrollContainer:
				paper.remove_child(body)
				var sc:=ScrollContainer.new();sc.name="SafePanelScroll";sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sc.follow_focus=true;sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;paper.add_child(sc)
				body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_EXPAND_FILL
				body.custom_minimum_size.x=0;sc.add_child(body);paper.set_meta("shell_scroll",sc)
		if paper.has_meta("shell_scroll"):
			var sc: ScrollContainer=paper.get_meta("shell_scroll")
			if sc.get_child_count()>0:sc.get_child(0).custom_minimum_size.y=maxf(80,view.y-margin.y*2-32)
		_resize_children(paper,maxf(200,view.x-margin.x*2-40))
func _resize_children(node: Control, available: float) -> void:
	if node.size.x>80 and not (node is ScrollContainer or node is ItemList):available=minf(available,node.size.x)
	if node is ScrollContainer:
		node.custom_minimum_size.x=minf(node.custom_minimum_size.x,available)
	elif node is ItemList:
		if not node.has_meta("shell_list_width"):node.set_meta("shell_list_width",node.custom_minimum_size.x)
		node.custom_minimum_size.x=minf(maxf(220,float(node.get_meta("shell_list_width"))),maxf(220,available*.3))
	elif node is GridContainer:
		var min_cell:=190.0
		node.columns=mini(node.columns,maxi(1,int(available/min_cell)))
	elif node is Button:
		if not node.has_meta("shell_min_width"):node.set_meta("shell_min_width",node.custom_minimum_size.x)
		var base: float=float(node.get_meta("shell_min_width"))
		if base<=0:
			var measured:=0.0
			for line: String in node.text.split("\n"):measured=maxf(measured,node.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x+30)
			node.custom_minimum_size.x=minf(available,clampf(measured,78,280))
		else:node.custom_minimum_size.x=minf(base,available)

	if not node is ItemList:node.custom_minimum_size.x=minf(node.custom_minimum_size.x,available)
	for child: Node in node.get_children():
		if child is Control:_resize_children(child,available)

func _late_fit(panel: Control) -> void:
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if is_instance_valid(panel) and panel.visible:fit(panel)
