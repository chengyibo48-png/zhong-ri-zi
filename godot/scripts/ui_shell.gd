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
		var role: String="management"
		for property: String in ["house_activity_panel","npc_dialogue","npc_story_panel","npc_history_panel","gift_panel","seed_picker","sleep_panel","separation_panel","wedding_panel","life_menu","map_panel"]:
			if hud.get(property)==p:
				role="dialogue" if property=="npc_dialogue" else "detail" if property in ["house_activity_panel","npc_story_panel","npc_history_panel","gift_panel","seed_picker"] else "confirmation" if property in ["sleep_panel","separation_panel"] else "management"
		p.set_meta("ui_layout_role",role)
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
	# A deferred visibility callback may belong to the scene that just left.
	if not is_instance_valid(hud) or not hud.is_inside_tree():return
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
	if is_instance_valid(hud) and hud.is_inside_tree() and is_instance_valid(hud.layout_manager.hud):hud.layout_manager.refresh()
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
		var role: String=str(panel.get_meta("ui_layout_role","management"))
		var cap:=Vector2(1180,840)
		if role=="detail":cap=Vector2(820,740)
		elif role=="dialogue":cap=Vector2(860,720)
		elif role=="confirmation":cap=Vector2(580,400)
		if hud.get("life_menu")==panel:cap=Vector2(1060,680)
		if view.y>view.x:cap.y=view.y-margin.y*2
		var envelope: Vector2=Vector2(minf(cap.x,view.x-margin.x*2),minf(cap.y,view.y-margin.y*2))
		if role in ["detail","dialogue","confirmation"] and paper.size.x>0:
			envelope.y=minf(envelope.y,maxf(280,_content_height(paper)+24))
		paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		paper.offset_left=-envelope.x/2;paper.offset_right=envelope.x/2
		paper.offset_top=-envelope.y/2;paper.offset_bottom=envelope.y/2
		paper.custom_minimum_size=Vector2.ZERO
		if not paper.has_meta("ui_window"):
			paper.set_meta("ui_window",true);hud.get_node("/root/UIArtService").apply_subtree(paper)
		if not bool(panel.get_meta("ui_managed_layout",false)) and not paper.has_meta("shell_scroll") and paper.get_child_count()==1:
			var body: Control=paper.get_child(0)
			if not body is ScrollContainer:
				paper.remove_child(body)
				var sc:=ScrollContainer.new();sc.name="SafePanelScroll";sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sc.follow_focus=true;sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;paper.add_child(sc)
				body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_EXPAND_FILL
				body.custom_minimum_size.x=0;sc.add_child(body);paper.set_meta("shell_scroll",sc)
		if paper.has_meta("shell_scroll"):
			var sc: ScrollContainer=paper.get_meta("shell_scroll")
			if sc.get_child_count()>0:sc.get_child(0).custom_minimum_size.y=maxf(80,envelope.y-40) if role=="management" else 0.0
		if not bool(panel.get_meta("ui_managed_layout",false)):_resize_children(paper,maxf(160,envelope.x-48))
func request_fit(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.visible or bool(panel.get_meta("ui_fit_pending",false)):return
	panel.set_meta("ui_fit_pending",true)
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if is_instance_valid(panel):
		panel.set_meta("ui_fit_pending",false)
		if panel.visible:fit(panel)

func _content_height(node: Control) -> float:
	# Ignore scroll view height when measuring a short dialog. Wrapped text uses
	# its measured minimum at the previous width; the late fit settles reflow.
	if node is ScrollContainer:
		return _content_height(node.get_child(0)) if node.get_child_count()>0 else 0.0
	var children: Array[Control]=[]
	for child:Node in node.get_children():
		if child is Control and child.visible:children.append(child)
	if node is VBoxContainer:
		var total:float=maxi(0,children.size()-1)*node.get_theme_constant("separation")
		for child:Control in children:total+=_content_height(child)
		return total
	if node is MarginContainer or node is PanelContainer:
		var height:float=0
		for child:Control in children:height=maxf(height,_content_height(child))
		if node is MarginContainer:height+=node.get_theme_constant("margin_top")+node.get_theme_constant("margin_bottom")
		else:height+=node.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)+node.get_theme_stylebox("panel").get_content_margin(SIDE_BOTTOM)
		return height
	return node.get_combined_minimum_size().y

func _resize_children(node: Control, available: float) -> void:
	# A spatial map must retain its authored cells, not reflow like action cards.
	if bool(node.get_meta("shell_preserve_layout", false)): return
	if node.size.x>80 and not (node is ScrollContainer or node is ItemList):available=minf(available,node.size.x)
	if node is ScrollContainer:
		node.custom_minimum_size.x=minf(node.custom_minimum_size.x,available)
	elif node is ItemList:
		if not node.has_meta("shell_list_width"):node.set_meta("shell_list_width",node.custom_minimum_size.x)
		node.custom_minimum_size.x=minf(maxf(220,float(node.get_meta("shell_list_width"))),maxf(220,available*.3))
	elif node is GridContainer:
		if not node.has_meta("shell_grid_columns"):node.set_meta("shell_grid_columns",node.columns)
		var min_cell:=190.0
		if not bool(node.get_meta("ui_responsive_grid",false)):node.columns=mini(int(node.get_meta("shell_grid_columns")),maxi(1,int(available/min_cell)))
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
	if not is_instance_valid(hud) or not hud.is_inside_tree():return
	var scene_tree := hud.get_tree()
	await scene_tree.process_frame
	await scene_tree.process_frame
	if not is_instance_valid(hud) or not hud.is_inside_tree():return
	if is_instance_valid(panel) and panel.visible:fit(panel)
