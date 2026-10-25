extends RefCounted
## Allocates mutually exclusive information docks at every viewport size.
var hud: Node
var fishing_context:=false
func setup(owner: Node) -> void:
	hud=owner
	hud.get_viewport().size_changed.connect(refresh)
	GameState.quest_changed.connect(refresh)
	GameState.fishing_session_changed.connect(_fishing_changed)
	GameState.input_mode_changed.connect(func(_mode: String):refresh())
	refresh.call_deferred()
func _fishing_changed(_snapshot: Dictionary) -> void:
	if GameState.fishing_active()!=fishing_context:refresh()

func refresh() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(hud.date_card):return
	var view: Vector2=hud.get_viewport().get_visible_rect().size
	var safe: Vector2=preload("res://scripts/hud_dock.gd").safe_margins(hud.ambient_hud)
	var touch: bool=preload("res://scripts/performance_policy.gd").touch_device()
	var left:=maxf(16,safe.x);var top:=maxf(12,safe.y)
	hud.date_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud.date_card.offset_left=-240-left;hud.date_card.offset_right=-left;hud.date_card.offset_top=top;hud.date_card.offset_bottom=top+150
	hud.date_card.custom_minimum_size=Vector2(240,0)
	hud.date_button.text="第 %d 年 · %s %d 日" % [int(GameState.day/112)+1,["春","夏","秋","冬"][GameState.season_index()],posmod(GameState.day,28)+1]
	hud.date_button.tooltip_text="查看节气与天气"
	var weather: Dictionary=GameState.weather_profile()
	hud.info_label.text="%s · %s %d°C\n零钱 %d 元%s" % [GameState.time_text(),str(weather.label),int(weather.temperature),GameState.money," · 体力 %d" % int(GameState.stamina) if touch else ""]
	hud.info_label.set_meta("compact_hud",true)
	var quick: Control=hud.quick_buttons.map.get_parent()
	quick.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	quick.offset_left=left+286;quick.offset_right=left+466;quick.offset_top=top;quick.offset_bottom=top+42
	hud.quick_buttons.save.hide();hud.quick_buttons.fullscreen.hide()
	hud.help_label.hide();hud.onboarding_panel.hide()
	hud.quest_tracker.position=Vector2(left,top);hud.quest_tracker.size=Vector2(270,0);hud.quest_tracker.refresh(hud)
	var map_on: bool=bool(GameState.atlas.get("minimap",false))
	hud.minimap_panel.position=Vector2(left,top+44);hud.minimap_panel.visible=map_on and not GameState.ui_open
	hud.quest_tracker.visible=not map_on and not GameState.ui_open
	hud.toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud.toolbar.offset_left=-244;hud.toolbar.offset_right=244;hud.toolbar.offset_top=-76;hud.toolbar.offset_bottom=-12
	hud.toolbar.custom_minimum_size=Vector2.ZERO
	for id: String in hud.toolbar_buttons:
		var button: Button=hud.toolbar_buttons[id];button.custom_minimum_size=Vector2(54,60);button.set_meta("compact_hud",true)
	var tools: Control=hud.bag_button.get_parent()
	tools.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tools.offset_left=-244;tools.offset_right=244;tools.offset_top=-122;tools.offset_bottom=-82;tools.visible=not touch
	hud.player_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.player_card.offset_left=left;hud.player_card.offset_right=left+180;hud.player_card.offset_top=-116;hud.player_card.offset_bottom=-12;hud.player_card.custom_minimum_size=Vector2(180,0);hud.player_card.visible=not touch
	if is_instance_valid(hud.fishing_panel.live_panel):
		hud.fishing_panel.live_panel.offset_top=top+hud.date_card.size.y+12
		var available: float=view.y-float(hud.fishing_panel.live_panel.offset_top)-safe.y-12
		hud.fishing_panel.meter.custom_minimum_size.y=clampf(available-210.0*float(GameState.player_settings.get("textScale",1)),100,120 if touch else 205)
	fishing_context=GameState.fishing_active()
	hud.toolbar.visible=not fishing_context
	if GameState.fishing_active():
		hud.quest_tracker.hide();hud.minimap_panel.hide();tools.hide();hud.player_card.hide()
	if GameState.ui_open:hud.ambient_hud.hide()
	else:hud.ambient_hud.visible=GameState.ui_hud_visible
