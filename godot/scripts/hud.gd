extends CanvasLayer
var ui_stack=preload("res://scripts/ui_shell.gd").new()
var layout_manager=preload("res://scripts/hud_layout.gd").new()
var quest_tracker: PanelContainer

const MINIMAP_SCRIPT := preload("res://scripts/minimap.gd")
const MAP_PANEL_SCRIPT := preload("res://scripts/map_panel.gd")
const MARKET_SCRIPT := preload("res://scripts/market_panel.gd")
const ITEM_CATALOG_SCRIPT := preload("res://scripts/item_catalog_panel.gd")
const WEATHER_PANEL_SCRIPT := preload("res://scripts/weather_panel.gd")
const WEATHER_OVERLAY_SCRIPT := preload("res://scripts/weather_overlay.gd")
const FORAGE_PANEL_SCRIPT := preload("res://scripts/forage_panel.gd")
const FISHING_PANEL_SCRIPT := preload("res://scripts/fishing_panel.gd")
const KITCHEN_PANEL_SCRIPT := preload("res://scripts/kitchen_panel.gd")
const TOOL_PANEL_SCRIPT := preload("res://scripts/tool_panel.gd")
const SKILLS_PANEL_SCRIPT := preload("res://scripts/skills_panel.gd")
const COMMUNITY_PANEL_SCRIPT := preload("res://scripts/community_panel.gd")
const FARM_FACILITY_PANEL_SCRIPT := preload("res://scripts/farm_facility_panel.gd")
const FARM_PLANNER_PANEL_SCRIPT := preload("res://scripts/farm_planner_panel.gd")
const NEIGHBOR_JOURNAL_SCRIPT := preload("res://scripts/neighbor_journal.gd")
const MUSEUM_PANEL_SCRIPT := preload("res://scripts/museum_panel.gd")
const FESTIVAL_PANEL_SCRIPT := preload("res://scripts/festival_panel.gd")
const BUILDING_PANEL_SCRIPT := preload("res://scripts/building_panel.gd")
const ACTION_PROGRESS_SCRIPT := preload("res://scripts/action_progress.gd")
const INTERACTION_PROMPT_SCRIPT := preload("res://scripts/interaction_prompt.gd")
const CONTEXT_ACTIONS_SCRIPT := preload("res://scripts/context_actions.gd")
const GIFT_PANEL_SCRIPT := preload("res://scripts/gift_panel.gd")
var context_actions: Control
var gift_panel: Control
const HOVER_CARD_SCRIPT := preload("res://scripts/hover_card.gd")
var hover_card: Control
var interaction_prompt: Control
var action_progress: Control
var scene_fade: ColorRect

const HOME_PANEL_SCRIPT := preload("res://scripts/home_panel.gd")
const RANCH_PANEL_SCRIPT := preload("res://scripts/ranch_panel.gd")
const SAVE_PANEL_SCRIPT := preload("res://scripts/save_panel.gd")
const SLEEP_PANEL_SCRIPT := preload("res://scripts/sleep_panel.gd")
const SETTINGS_PANEL_SCRIPT := preload("res://scripts/settings_panel.gd")
const MAIL_PANEL_SCRIPT := preload("res://scripts/mail_panel.gd")
const HELP_PANEL_SCRIPT := preload("res://scripts/help_panel.gd")
const ONBOARDING_PANEL_SCRIPT := preload("res://scripts/onboarding_panel.gd")
const FEEDBACK_PANEL_SCRIPT := preload("res://scripts/feedback_panel.gd")

const SEED_PICKER_SCRIPT := preload("res://scripts/seed_picker.gd")
var seed_picker: Control

const LIFE_MENU_SCRIPT := preload("res://scripts/life_menu.gd")
var life_menu: Control
var life_plan_panel: Control
var toolbar_buttons: Dictionary = {}
var toolbar_icons: Dictionary = {}
var ambient_hud: Control
var restore_hud_button: Button

var date_card: PanelContainer
var player_card: PanelContainer
var date_button: Button
var forecast_button: Button
var player_label: Label
var energy_bar: ProgressBar
var quick_buttons: Dictionary = {}
var bag_button: Button
var seed_button: Button
var tool_label: Label
var toolbar: HBoxContainer
var info_label: Label
var help_label: Label
var notification_origin:Control
var market_panel: Control
var item_catalog_panel: Control
var weather_panel: Control
var forage_panel: Control
var fishing_panel: Control
var kitchen_panel: Control
var tool_panel: Control
var skills_panel: Control
var community_panel: Control
var farm_facility_panel: Control
var farm_planner_panel: Control
var separation_panel: Control
var wedding_panel: Control
var npc_story_panel: Control
var npc_history_panel: Control
var npc_dialogue: Control
var relations_panel: Control
var neighbor_journal: Control
var museum_panel: Control
var festival_panel: Control
var building_panel: Control
var home_panel: Control
var ranch_panel: Control
var save_panel: Control
var sleep_panel: Control
var kitchen_heat_panel: Control
var settings_panel: Control
var mail_panel: Control
var help_panel: Control
var onboarding_panel: Control
var feedback_panel: Control
var map_panel: Control
var minimap_panel: Control
var notification_stack:Control
var hud_refresh_timer := 0.0
var last_text_scale := -1.0

func _ready() -> void:
	preload("res://scripts/performance_policy.gd").configure(get_tree().root)
	UIArtService.call("register_root", self)
	var weather_overlay := Control.new()
	weather_overlay.set_script(WEATHER_OVERLAY_SCRIPT)
	add_child(weather_overlay)
	ambient_hud = Control.new()
	ambient_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ambient_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ambient_hud)
	date_card = _hud_card(Vector2(12,12),Vector2(184,76))
	var date_box := VBoxContainer.new()
	date_box.add_theme_constant_override("separation",3)
	date_card.add_child(date_box)
	date_button = _hud_button("",show_calendar)
	date_button.clip_text = true
	date_box.add_child(date_button)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size",13)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	date_box.add_child(info_label)
	forecast_button = _hud_button("天气预报",show_weather)
	date_box.add_child(forecast_button)
	player_card = _hud_card(Vector2(12,-88),Vector2(184,76),true)
	var player_box := VBoxContainer.new()
	player_card.add_child(player_box)
	player_label = Label.new()
	player_label.add_theme_font_size_override("font_size",11)
	player_box.add_child(player_label)
	energy_bar = ProgressBar.new()
	energy_bar.max_value = 100
	energy_bar.show_percentage = false
	energy_bar.custom_minimum_size.y = 6
	energy_bar.set_meta("compact_hud", true)
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_box.add_child(energy_bar)
	var player_actions := HBoxContainer.new()
	player_box.add_child(player_actions)
	player_actions.add_child(_hud_button("今天的打算",func():life_plan_panel.open_panel()))
	player_actions.add_child(_hud_button("收起 H",toggle_hud))
	var quick_row := HBoxContainer.new()
	quick_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quick_row.offset_left = -236
	quick_row.offset_right = -12
	quick_row.offset_top = 12
	quick_row.offset_bottom = 40
	ambient_hud.add_child(quick_row)
	for entry in [["map","地图",show_map],["save","存档",show_saves],["fullscreen","全屏",toggle_fullscreen],["menu","菜单",show_life_menu]]:
		var button := _hud_button(str(entry[1]),entry[2])
		quick_row.add_child(button)
		quick_buttons[str(entry[0])] = button
	var tool_row := HBoxContainer.new()
	tool_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tool_row.offset_left = -426
	tool_row.offset_right = -18
	tool_row.offset_top = -86
	tool_row.offset_bottom = -62
	ambient_hud.add_child(tool_row)
	tool_label = Label.new()
	tool_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_label.add_theme_font_size_override("font_size",13)
	tool_row.add_child(tool_label)
	bag_button = _hud_button("背包 B",func(): show_market("inventory",false))
	tool_row.add_child(bag_button)
	seed_button = _hud_button("选种 Q",show_seed_picker)
	seed_button.clip_text = true
	seed_button.custom_minimum_size.x = 116
	tool_row.add_child(seed_button)
	help_label = Label.new()
	help_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	help_label.position = Vector2(210,14)
	help_label.size = Vector2(62,22)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size",12)
	help_label.mouse_filter = Control.MOUSE_FILTER_PASS
	ambient_hud.add_child(help_label)
	GameState.message_requested.connect(_show_message)
	kitchen_heat_panel = Control.new()
	kitchen_heat_panel.set_script(load("res://scripts/kitchen_heat_panel.gd"))
	add_child(kitchen_heat_panel)
	GameState.changed.connect(refresh)
	GameState.clock_changed.connect(refresh)
	GameState.input_mode_changed.connect(func(_mode: String): refresh())
	onboarding_panel = Control.new()
	onboarding_panel.set_script(ONBOARDING_PANEL_SCRIPT)
	ambient_hud.add_child(onboarding_panel)
	onboarding_panel.guide_requested.connect(show_help)
	minimap_panel = Control.new()
	minimap_panel.set_script(MINIMAP_SCRIPT)
	minimap_panel.position = Vector2(762, 68)
	minimap_panel.size = Vector2(180, 180)
	minimap_panel.visible = bool(GameState.atlas.get("minimap", true))
	ambient_hud.add_child(minimap_panel)
	toolbar = HBoxContainer.new()
	toolbar.anchor_left = 1.0
	toolbar.anchor_right = 1.0
	toolbar.anchor_top = 1.0
	toolbar.anchor_bottom = 1.0
	toolbar.offset_left = -426
	toolbar.offset_right = -18
	toolbar.offset_top = -56
	toolbar.offset_bottom = -12
	toolbar.add_theme_constant_override("separation", 4)
	ambient_hud.add_child(toolbar)
	for index in range(GameState.TOOLBAR_IDS.size()):
		var tool_id: String = GameState.TOOLBAR_IDS[index]
		var button := Button.new()
		button.set_meta("compact_hud", true)
		button.text = ""
		var contents := VBoxContainer.new()
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_top = 3
		contents.offset_bottom = -3
		contents.add_theme_constant_override("separation", 0)
		button.add_child(contents)
		var illustration := preload("res://scripts/item_icon.gd").new()
		illustration.custom_minimum_size = Vector2(24, 24)
		illustration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illustration.configure(tool_id)
		contents.add_child(illustration)
		toolbar_icons[tool_id] = illustration
		var caption := Label.new()
		caption.text = str(index + 1)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 11)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(caption)
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.tooltip_text = "%s · 数字键 %d / 手柄肩键" % [GameState.TOOLBAR_NAMES[tool_id], index + 1]
		button.pressed.connect(_choose_toolbar_tool.bind(tool_id))
		toolbar.add_child(button)
		toolbar_buttons[tool_id] = button

	restore_hud_button = Button.new()
	restore_hud_button.text = "显示界面 H"
	restore_hud_button.position = Vector2(18, 18)
	restore_hud_button.pressed.connect(toggle_hud)
	add_child(restore_hud_button)
	map_panel = Control.new()
	map_panel.set_script(MAP_PANEL_SCRIPT)
	add_child(map_panel)
	market_panel = Control.new()
	market_panel.set_script(MARKET_SCRIPT)
	add_child(market_panel)
	market_panel.seed_picker_requested.connect(show_seed_picker)
	item_catalog_panel = Control.new()
	item_catalog_panel.set_script(ITEM_CATALOG_SCRIPT)
	add_child(item_catalog_panel)
	weather_panel = Control.new()
	weather_panel.set_script(WEATHER_PANEL_SCRIPT)
	add_child(weather_panel)
	weather_panel.connect("festival_requested", _show_calendar_festival)
	forage_panel = Control.new()
	forage_panel.set_script(FORAGE_PANEL_SCRIPT)
	add_child(forage_panel)
	fishing_panel = Control.new()
	fishing_panel.set_script(FISHING_PANEL_SCRIPT)
	add_child(fishing_panel)
	kitchen_panel = Control.new()
	kitchen_panel.set_script(KITCHEN_PANEL_SCRIPT)
	add_child(kitchen_panel)
	tool_panel = Control.new()
	tool_panel.set_script(TOOL_PANEL_SCRIPT)
	add_child(tool_panel)
	skills_panel = Control.new()
	skills_panel.set_script(SKILLS_PANEL_SCRIPT)
	add_child(skills_panel)
	community_panel = Control.new()
	community_panel.set_script(COMMUNITY_PANEL_SCRIPT)
	add_child(community_panel)
	farm_facility_panel = Control.new()
	farm_facility_panel.set_script(FARM_FACILITY_PANEL_SCRIPT)
	add_child(farm_facility_panel)
	farm_planner_panel = Control.new()
	farm_planner_panel.set_script(FARM_PLANNER_PANEL_SCRIPT)
	add_child(farm_planner_panel)
	separation_panel = Control.new()
	separation_panel.set_script(preload("res://scripts/separation_panel.gd"))
	add_child(separation_panel)
	wedding_panel = Control.new()
	wedding_panel.set_script(preload("res://scripts/wedding_panel.gd"))
	add_child(wedding_panel)
	npc_story_panel = Control.new()
	npc_story_panel.set_script(preload("res://scripts/npc_story_panel.gd"))
	add_child(npc_story_panel)
	npc_history_panel = Control.new()
	npc_history_panel.set_script(preload("res://scripts/npc_history_panel.gd"))
	add_child(npc_history_panel)
	npc_dialogue = Control.new()
	npc_dialogue.set_script(preload("res://scripts/npc_dialogue.gd"))
	add_child(npc_dialogue)
	relations_panel = Control.new()
	relations_panel.set_script(preload("res://scripts/relations_panel.gd"))
	add_child(relations_panel)
	neighbor_journal = Control.new()
	neighbor_journal.set_script(NEIGHBOR_JOURNAL_SCRIPT)
	add_child(neighbor_journal)
	museum_panel = Control.new()
	museum_panel.set_script(MUSEUM_PANEL_SCRIPT)
	add_child(museum_panel)
	festival_panel = Control.new()
	festival_panel.set_script(FESTIVAL_PANEL_SCRIPT)
	add_child(festival_panel)
	building_panel = Control.new()
	building_panel.set_script(BUILDING_PANEL_SCRIPT)
	add_child(building_panel)
	home_panel = Control.new()
	home_panel.set_script(HOME_PANEL_SCRIPT)
	add_child(home_panel)
	ranch_panel = Control.new()
	ranch_panel.set_script(RANCH_PANEL_SCRIPT)
	add_child(ranch_panel)
	save_panel = Control.new()
	save_panel.set_script(SAVE_PANEL_SCRIPT)
	add_child(save_panel)
	sleep_panel = Control.new()
	sleep_panel.set_script(SLEEP_PANEL_SCRIPT)
	add_child(sleep_panel)
	seed_picker = SEED_PICKER_SCRIPT.new()
	add_child(seed_picker)
	life_plan_panel = preload("res://scripts/life_plan_panel.gd").new()
	add_child(life_plan_panel)
	life_menu = LIFE_MENU_SCRIPT.new()
	add_child(life_menu)
	life_menu.selected.connect(_select_life_menu)
	settings_panel = Control.new()
	settings_panel.set_script(SETTINGS_PANEL_SCRIPT)
	add_child(settings_panel)
	settings_panel.fullscreen_requested.connect(toggle_fullscreen)
	mail_panel = Control.new()
	mail_panel.set_script(MAIL_PANEL_SCRIPT)
	add_child(mail_panel)
	help_panel = Control.new()
	help_panel.set_script(HELP_PANEL_SCRIPT)
	add_child(help_panel)
	feedback_panel = Control.new()
	feedback_panel.set_script(FEEDBACK_PANEL_SCRIPT)
	add_child(feedback_panel)
	notification_stack=preload("res://scripts/notification_stack.gd").new()
	add_child(notification_stack)
	notification_stack.bind(GameState.notification_queue)
	notification_stack.feedback_requested.connect(show_feedback)
	GameState.feedback_toast_requested.connect(_show_feedback_toast)
	GameState.year_review_requested.connect(_show_pending_year_review)
	if GameState.year_review_pending: call_deferred("_show_pending_year_review")
	context_actions=CONTEXT_ACTIONS_SCRIPT.new()
	add_child(context_actions)
	gift_panel=GIFT_PANEL_SCRIPT.new()
	add_child(gift_panel)
	for modal_panel in [separation_panel,wedding_panel,npc_story_panel,npc_history_panel,npc_dialogue,gift_panel,life_plan_panel,life_menu,kitchen_heat_panel,seed_picker,map_panel,community_panel,skills_panel,help_panel,feedback_panel,sleep_panel,mail_panel,item_catalog_panel,settings_panel,save_panel,market_panel,weather_panel,forage_panel,fishing_panel,kitchen_panel,tool_panel,farm_facility_panel,farm_planner_panel,home_panel,relations_panel,neighbor_journal,museum_panel,festival_panel,building_panel,ranch_panel]:
		modal_panel.z_index=maxi(20,modal_panel.z_index)
	ui_stack.setup(self,[separation_panel,wedding_panel,npc_story_panel,npc_history_panel,npc_dialogue,gift_panel,life_plan_panel,life_menu,kitchen_heat_panel,seed_picker,map_panel,community_panel,skills_panel,help_panel,feedback_panel,sleep_panel,mail_panel,item_catalog_panel,settings_panel,save_panel,market_panel,weather_panel,forage_panel,fishing_panel,kitchen_panel,tool_panel,farm_facility_panel,farm_planner_panel,home_panel,relations_panel,neighbor_journal,museum_panel,festival_panel,building_panel,ranch_panel])
	quest_tracker=preload("res://scripts/quest_hud.gd").new()
	ambient_hud.add_child(quest_tracker)
	layout_manager.setup(self)
	interaction_prompt=INTERACTION_PROMPT_SCRIPT.new()
	add_child(interaction_prompt)
	hover_card=HOVER_CARD_SCRIPT.new()
	add_child(hover_card)
	var interaction_scheduler := preload("res://scripts/interaction_ui_scheduler.gd").new()
	interaction_scheduler.name = "InteractionUIRefresh"
	add_child(interaction_scheduler)
	scene_fade=ColorRect.new()
	scene_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_fade.color=Color("#253b36")
	add_child(scene_fade)
	GameState.scene_fade_changed.connect(_refresh_scene_fade)
	GameState.action_sequence_changed.connect(func(_snapshot: Dictionary):_refresh_scene_fade(GameState.action_darkness()))
	_refresh_scene_fade(GameState.action_darkness())
	action_progress = ACTION_PROGRESS_SCRIPT.new()
	add_child(action_progress)
	if preload("res://scripts/performance_policy.gd").touch_device():
		player_card.hide()
		help_label.hide()
		tool_label.hide()
		onboarding_panel.hide()
		bag_button.get_parent().hide()
		toolbar.anchor_left = 0.5
		toolbar.anchor_right = 0.5
		toolbar.offset_left = -270
		toolbar.offset_right = 270
		toolbar.offset_top = -80
		toolbar.offset_bottom = -12
		for button in toolbar_buttons.values():
			button.custom_minimum_size = Vector2(62, 64)
			button.text = ""
		var touch_controls := preload("res://scripts/mobile_controls.gd").new()
		touch_controls.name = "MobileControls"
		add_child(touch_controls)
	refresh()

func _refresh_scene_fade(alpha: float) -> void:
	if not is_instance_valid(scene_fade):return
	scene_fade.visible=alpha>0.0
	scene_fade.modulate.a=alpha

func _show_message(text: String) -> void:
	if not text.is_empty():show_notification(text)

func _show_feedback_toast(text: String, priority: int) -> void:
	if GameState.presenting_action_delta:
		var panel: Control = notification_origin if is_instance_valid(notification_origin) else _gamepad_panel()
		if panel != null:
			var status := panel.find_child("ModalStatus", true, false)
			if status != null and bool(status.get_meta("notification_error", false)): return
	show_notification(text,false,priority>0)

func show_notification(text:String,error:bool=false,important:bool=false)->void:
	if not is_inside_tree():return
	if error:GameState.record_notification_error(text)
	var prefs:Dictionary=GameState.feedback.get("prefs",{})
	if not error and not important and bool(prefs.get("quiet",false)):return
	var active_panel:Control=notification_origin if is_instance_valid(notification_origin) else _gamepad_panel()
	if active_panel!=null:
		if active_panel.has_method("show_status_message"):active_panel.show_status_message(text,error)
		elif active_panel.has_meta("notification_column"):
			preload("res://scripts/modal_status.gd").show_message(active_panel.get_meta("notification_column"),text,error,int(active_panel.get_meta("notification_index",1)))
		return
	GameState.notification_queue.append(text,error,important,float(prefs.get("seconds",5)),Time.get_ticks_msec()/1000.0)
	if is_instance_valid(notification_stack):notification_stack.refresh()

func _hud_card(at: Vector2, dimensions: Vector2, bottom: bool = false, right: bool = false) -> PanelContainer:
	var card := PanelContainer.new()
	card.set_meta("compact_hud", true)
	if bottom:
		card.anchor_top = 1
		card.anchor_bottom = 1
	if right:
		card.anchor_left = 1
		card.anchor_right = 1
	card.offset_left = at.x
	card.offset_right = at.x + dimensions.x
	card.offset_top = at.y
	card.offset_bottom = at.y + dimensions.y
	card.custom_minimum_size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16,0.20,0.17,0.90)
	style.border_color = Color("c7ad7c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel",style)
	ambient_hud.add_child(card)
	if bottom: card.minimum_size_changed.connect(_fit_bottom_card.bind(card,at.y + dimensions.y))
	return card

func _fit_bottom_card(card: PanelContainer, bottom_offset: float) -> void:
	card.offset_bottom = bottom_offset
	card.offset_top = bottom_offset - card.get_combined_minimum_size().y

func _hud_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.set_meta("compact_hud", true)
	button.add_theme_font_size_override("font_size",11)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button

func _process(_delta: float) -> void:
	# Clock and commands publish changes; no unconditional four-Hz rebuild.
	pass

func toggle_fullscreen() -> void:
	var window := get_window()
	if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		window.mode = GameState.ui_window_mode_before_fullscreen
	else:
		GameState.ui_window_mode_before_fullscreen = window.mode
		window.mode = Window.MODE_FULLSCREEN
	settings_panel.call("refresh")

func toggle_hud() -> void:
	GameState.ui_hud_visible = not GameState.ui_hud_visible
	refresh()

func show_kitchen_heat(task: Dictionary) -> void:
	kitchen_heat_panel.open_panel(task)

func show_calendar() -> void:
	show_weather()
	weather_panel.notebook.current_tab = 1

func _choose_toolbar_tool(tool_id: String) -> void:
	if GameState.ui_open or GameState.action_busy(): return
	GameState.select_toolbar_tool(tool_id)
	if tool_id == "build": show_build_layout()

func show_build_layout() -> void:
	_select_life_menu("build")
	if building_open(): building_panel.call("_set_tab", "layout")

func handle_source_key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_SPACE,GameState.bound_key("interact",KEY_E)] and GameState.fishing_active() and not GameState.ui_open:
		if not event.echo:GameState.fishing_input("press" if event.pressed else "release")
		get_viewport().set_input_as_handled();return true
	if not event.pressed:return false
	if settings_capture_active():
		capture_setting_event(event)
		get_viewport().set_input_as_handled()
		return true
	var focus:Control=get_viewport().gui_get_focus_owner()
	var text_focus:=focus is LineEdit or focus is TextEdit or focus is OptionButton
	var commands:Array[String]=GameState.source_keyboard.commands(event,GameState.player_settings.get("bindings",{}),GameState.ui_open,GameState.action_busy(),text_focus,focus is BaseButton)
	var world:=get_parent()
	for command in commands:
		if command.begins_with("tool:"):
			var tool_id:String=GameState.TOOLBAR_IDS[int(command.trim_prefix("tool:"))-1]
			GameState.select_toolbar_tool(tool_id)
			if tool_id=="build":show_build_layout()
			continue
		match command:
			"cancel":GameState.cancel_player_action()
			"close":close_top_panel()
			"menu":show_life_menu()
			"bag":show_market("inventory",false)
			"map":show_map()
			"journal":life_plan_panel.open_panel()
			"calendar":show_calendar()
			"seeds":show_seed_picker()
			"fullscreen":toggle_fullscreen()
			"hud":toggle_hud()
			"interact":
				if world.has_method("_interact"):world.call("_interact")
			"previous_target","next_target":
				var direction:=-1 if command=="previous_target" else 1
				if world.has_method("_cycle_world_target"):world.call("_cycle_world_target",direction)
				elif world.has_method("_cycle_room_target"):world.call("_cycle_room_target",direction)
	if commands.is_empty():return false
	get_viewport().set_input_as_handled()
	return true

func handle_toolbar_key(event: InputEventKey) -> bool:
	return handle_source_key(event)


func show_seed_picker() -> void:
	seed_picker.call("open_panel")

func handle_fixed_shortcut(event: InputEventKey) -> bool:
	return handle_source_key(event)


func gamepad_focus_node() -> Control:
	var focus:Control=get_viewport().gui_get_focus_owner()
	if focus is LineEdit and focus.get_parent() is SpinBox:return focus.get_parent()
	return focus

func gamepad_focus_kind() -> String:
	var focus:=gamepad_focus_node()
	if focus is OptionButton:return "select"
	if focus is SpinBox:return "number"
	if focus is Slider:return "range"
	if focus is BaseButton:return "button"
	return "none"

func _gamepad_panel() -> Control:
	for panel in [separation_panel,wedding_panel,npc_story_panel,npc_history_panel,npc_dialogue,gift_panel,life_plan_panel,life_menu,kitchen_heat_panel,seed_picker,map_panel,community_panel,skills_panel,help_panel,feedback_panel,sleep_panel,mail_panel,item_catalog_panel,settings_panel,save_panel,market_panel,weather_panel,forage_panel,fishing_panel,kitchen_panel,tool_panel,farm_facility_panel,farm_planner_panel,home_panel,relations_panel,neighbor_journal,museum_panel,festival_panel,building_panel,ranch_panel]:
		if is_instance_valid(panel) and panel.visible:return panel
	return null

func _gamepad_entries(node:Node,result:Array) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is Control and node.focus_mode!=Control.FOCUS_NONE:
		if node is ItemList:
			for i in range(node.item_count):
				if not node.is_item_disabled(i):result.append({"node":node,"item":i})
			return
		if node is SpinBox:
			result.append({"node":node})
			return
		if node is LineEdit or node is Slider or node is BaseButton and not node.disabled:
			result.append({"node":node})
			return
	for child in node.get_children():_gamepad_entries(child,result)

func _gamepad_move_focus(direction:int) -> void:
	var panel:=_gamepad_panel()
	if panel==null:return
	var entries:Array=[]
	_gamepad_entries(panel,entries)
	if entries.is_empty():return
	var focus:=gamepad_focus_node()
	var index:=-1
	for i in range(entries.size()):
		if entries[i].node==focus:
			if focus is ItemList:
				if entries[i].item not in focus.get_selected_items():continue
			index=i
			break
	var next:Dictionary=entries[posmod(index+direction,entries.size())]
	var node:Control=next.node
	if node is SpinBox:node.get_line_edit().grab_focus()
	else:node.grab_focus()
	if node is ItemList:
		node.select(int(next.item))
		if node.has_method("ensure_current_is_visible"):node.call("ensure_current_is_visible")
	var ancestor:=node.get_parent()
	while ancestor!=null and ancestor!=self:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(node)
		ancestor=ancestor.get_parent()

func apply_source_gamepad(command:Dictionary) -> void:
	var world:=get_parent()
	match str(command.kind):
		"tab":
			var panel: Control=ui_stack.active()
			if panel==life_plan_panel:
				var ids: Array=["active","available","done","today"];life_plan_panel._tab(str(ids[posmod(ids.find(life_plan_panel.active_tab)+int(command.value),ids.size())]))
			elif panel==life_menu:
				var groups: Array=life_menu.GROUPS.keys();life_menu._group(str(groups[posmod(groups.find(life_menu.active_group)+int(command.value),groups.size())]))
			elif panel!=null:
				for node: Node in panel.find_children("*","TabContainer",true,false):
					if node.is_visible_in_tree() and node.get_tab_count()>0:node.current_tab=posmod(node.current_tab+int(command.value),node.get_tab_count());break
		"close":close_top_panel()
		"menu":show_life_menu()
		"bag":show_market("inventory",false)
		"map":show_map()
		"journal":life_plan_panel.open_panel()
		"target":
			if world.has_method("_cycle_world_target"):world.call("_cycle_world_target",1)
			elif world.has_method("_cycle_room_target"):world.call("_cycle_room_target",1)
		"interact":
			if world.has_method("interact_from_gamepad"):world.call("interact_from_gamepad")
		"tool":
			var index:=GameState.TOOLBAR_IDS.find(GameState.selected_tool)
			var id:String=GameState.TOOLBAR_IDS[posmod(index+int(command.value),GameState.TOOLBAR_IDS.size())]
			GameState.select_toolbar_tool(id)
			if id=="build":show_build_layout()
		"horizontal":
			var focus:=gamepad_focus_node()
			if focus is OptionButton and focus.item_count>0:
				focus.select(posmod(focus.selected+int(command.value),focus.item_count))
				focus.item_selected.emit(focus.selected)
			elif focus is Slider or focus is SpinBox:
				var step:float=focus.step if focus.step!=0.0 else 1.0
				focus.value=clampf(focus.value+float(command.value)*step,focus.min_value,focus.max_value)
		"focus":_gamepad_move_focus(int(command.value))
		"activate":
			var focus:=gamepad_focus_node()
			if focus is BaseButton and not focus.disabled and focus is not OptionButton:
				if focus.toggle_mode:focus.button_pressed=not focus.button_pressed
				focus.pressed.emit()
			elif focus is ItemList:
				var selected:PackedInt32Array=focus.get_selected_items()
				if not selected.is_empty():focus.item_selected.emit(selected[0])

func close_top_panel() -> void:
	ui_stack.back()

func show_life_menu() -> void:
	life_menu.call("open_panel")

func handle_life_menu_key(event: InputEventKey) -> bool:
	return handle_source_key(event)

func _select_life_menu(entry: String) -> void:
	match entry:
		"plans":life_plan_panel.open_panel()
		"stories":community_panel.open_panel("records")
		"mail":show_mail()
		"processing":show_kitchen(false,"process")
		"farmcare":show_farm_planner(false,0)
		"animals":show_ranch()
		"storage":
			show_market("inventory",false)
			market_panel.call("_choose_inventory_side","storage")
		"projects":community_panel.open_panel("projects")
		"tools":show_tools(false)
		"decor":show_build_layout()
		"skills":show_skills()
		"catalog":show_museum("catalog")
		"archive":community_panel.open_panel("archives")
		"gatherings":community_panel.open_panel("gatherings")
		"appearance":show_settings()
		"economy":show_market("business",false,"coop")
		"item-icons":show_item_catalog()
		"bag": show_market("inventory", false)
		"map": show_map()
		"calendar": show_calendar()
		"orders": life_plan_panel.open_panel("","available")
		"recipes": show_kitchen(false)
		"relations": show_neighbors()
		"neighbors": show_neighbor_book()
		"home": show_home()
		"journal": community_panel.call("open_panel", "journal")
		"fishing":show_fishing()
		"build":
			var world := get_parent()
			if world.has_method("_open_building_book"): world.call("_open_building_book")
			elif world.has_method("_show_building"): world.call("_show_building")
		"save": show_saves()
		"settings": show_settings()
		"help": show_help()

func handle_bound_shortcut(event: InputEventKey) -> bool:
	return handle_source_key(event)

func show_map() -> void:
	map_panel.call("open_panel")

func close_map() -> void:
	map_panel.call("close")

func map_open() -> bool:
	return bool(map_panel.call("is_open"))

func set_minimap_visible(is_visible: bool) -> void:
	GameState.atlas.minimap = is_visible
	GameState.changed.emit()

func show_market(mode: String = "inventory", can_trade: bool = false, venue: String = "shop") -> void:
	market_panel.call("open_panel", mode, can_trade, venue)
	if mode=="inventory" and not GameState.action_busy():market_panel.call("_choose_inventory_side","bag")

func close_market() -> void:
	market_panel.call("close")

func market_open() -> bool:
	return bool(market_panel.call("is_open"))

func show_item_catalog() -> void:
	item_catalog_panel.call("open_panel")

func close_item_catalog() -> void:
	item_catalog_panel.call("close")

func item_catalog_open() -> bool:
	return bool(item_catalog_panel.call("is_open"))

func show_weather() -> void:
	weather_panel.call("open_panel")

func close_weather() -> void:
	weather_panel.call("close")

func weather_open() -> bool:
	return bool(weather_panel.call("is_open"))

func show_forage() -> void:
	forage_panel.call("open_panel")

func close_forage() -> void:
	forage_panel.call("close")

func forage_open() -> bool:
	return bool(forage_panel.call("is_open"))

func show_fishing(water_id: String = "", spot_id: String = "") -> void:
	fishing_panel.call("open_panel", water_id, spot_id)

func close_fishing() -> void:
	fishing_panel.call("close")

func fishing_open() -> bool:
	return bool(fishing_panel.call("is_open"))

func fishing_toggle_reel() -> void:
	fishing_panel.call("toggle_reel")

func show_kitchen(can_work: bool = false, start_mode: String = "cook", station_filter: String = "") -> void:
	kitchen_panel.call("open_panel", can_work, start_mode, station_filter)

func close_kitchen() -> void:
	kitchen_panel.call("close")

func kitchen_open() -> bool:
	return bool(kitchen_panel.call("is_open"))

func show_tools(can_work: bool = false) -> void:
	tool_panel.call("open_panel", can_work)

func close_tools() -> void:
	tool_panel.call("close")

func tools_open() -> bool:
	return bool(tool_panel.call("is_open"))

func show_skills() -> void:
	skills_panel.call("open_panel")

func close_skills() -> void:
	skills_panel.call("close")

func skills_open() -> bool:
	return bool(skills_panel.call("is_open"))

func show_community() -> void:
	community_panel.call("open_panel")

func close_community() -> void:
	community_panel.call("close")

func community_open() -> bool:
	return bool(community_panel.call("is_open"))

func show_farm_facilities(can_work: bool = false, plot_index: int = 0) -> void:
	farm_facility_panel.call("open_panel", can_work, plot_index)

func close_farm_facilities() -> void:
	farm_facility_panel.call("close")

func farm_facilities_open() -> bool:
	return bool(farm_facility_panel.call("is_open"))

func show_farm_planner(can_work: bool = false, plot_index: int = 0) -> void:
	farm_planner_panel.call("open_panel", can_work, plot_index)

func close_farm_planner() -> void:
	farm_planner_panel.call("close")

func farm_planner_open() -> bool:
	return bool(farm_planner_panel.call("is_open"))

func show_npc_story(npc_id: String) -> void:
	npc_story_panel.open_panel(npc_id)

func show_npc_dialogue(npc_id: String) -> void:
	npc_dialogue.open_panel(npc_id)

func show_neighbor_book(npc_id: String = "",tab: String = "people") -> void:
	if GameState.action_busy():return
	if npc_id!="":npc_history_panel.focus_person(npc_id,tab)
	npc_history_panel.open_panel()

func show_neighbors(focus_npc_id: String = "") -> void:
	if focus_npc_id == "":relations_panel.call("open_panel")
	else:neighbor_journal.call("open_panel", focus_npc_id)

func close_neighbors() -> void:
	relations_panel.call("close")
	neighbor_journal.call("close")

func neighbors_open() -> bool:
	return bool(relations_panel.call("is_open")) or bool(neighbor_journal.call("is_open"))

func show_museum(mode: String = "catalog", focus_key: String = "") -> void:
	museum_panel.call("open_panel", mode, focus_key)

func close_museum() -> void:
	museum_panel.call("close")

func museum_open() -> bool:
	return bool(museum_panel.call("is_open"))

func show_festival() -> void:
	festival_panel.call("open_panel")

func close_festival() -> void:
	festival_panel.call("close")

func festival_open() -> bool:
	return bool(festival_panel.call("is_open"))

func show_building(sites: Dictionary, home_nearby: bool) -> void:
	building_panel.call("open_panel", sites, home_nearby)

func close_building() -> void:
	building_panel.call("close")

func building_open() -> bool:
	return bool(building_panel.call("is_open"))

func show_home() -> void:
	home_panel.open_panel()

func close_home() -> void:
	home_panel.close()

func home_open() -> bool:
	return home_panel.is_open()

func show_ranch() -> void:
	ranch_panel.call("open_panel")

func close_ranch() -> void:
	if ranch_panel.call("handbook_open"): ranch_panel.call("close_handbook")
	else: ranch_panel.call("close")

func ranch_open() -> bool:
	return bool(ranch_panel.call("is_open"))

func show_saves() -> void:
	save_panel.call("open_panel")

func close_saves() -> void:
	save_panel.call("close")

func saves_open() -> bool:
	return bool(save_panel.call("is_open"))

func show_sleep() -> void:
	sleep_panel.call("open_panel")

func sleep_open() -> bool:
	return bool(sleep_panel.call("is_open"))

func close_sleep() -> void:
	sleep_panel.call("close")

func show_settings() -> void:
	settings_panel.call("open_panel")

func show_mail() -> void:
	mail_panel.call("open_panel")

func close_mail() -> void:
	mail_panel.call("close")

func mail_open() -> bool:
	return bool(mail_panel.call("is_open"))

func show_help() -> void:
	GameState.onboarding_mark("guide")
	help_panel.call("open_panel")

func close_help() -> void:
	help_panel.call("close")

func help_open() -> bool:
	return bool(help_panel.call("is_open"))

func show_feedback() -> void:
	feedback_panel.call("open_panel")

func close_feedback() -> void:
	feedback_panel.call("close")

func feedback_open() -> bool:
	return bool(feedback_panel.call("is_open"))

func toggle_onboarding() -> void:
	if bool(onboarding_panel.call("is_open")):
		GameState.onboarding_hide()
	else:
		onboarding_panel.call("open_panel")

func onboarding_open() -> bool:
	return bool(onboarding_panel.call("is_open"))

func close_settings() -> void:
	settings_panel.call("close")

func settings_open() -> bool:
	return bool(settings_panel.call("is_open"))

func settings_capture_active() -> bool:
	return bool(settings_panel.call("capture_active"))

func capture_setting_event(event: InputEventKey) -> bool:
	return bool(settings_panel.call("capture_event_key",event))

func capture_setting_key(keycode: int) -> bool:
	return bool(settings_panel.call("capture_key", keycode))

func refresh() -> void:
	if not is_instance_valid(info_label):
		return
	_apply_text_scale()
	if toolbar_icons.has("seed"):
		toolbar_icons.seed.configure(GameState.seed_variant_id(GameState.selected_seed))
	for tool_id in toolbar_buttons:
		toolbar_buttons[tool_id].set_pressed_no_signal(GameState.selected_tool == tool_id or (tool_id == "hand" and GameState.selected_tool == "harvest"))
	ambient_hud.visible = GameState.ui_hud_visible
	restore_hud_button.visible = not GameState.ui_hud_visible
	if is_instance_valid(minimap_panel): minimap_panel.visible = bool(GameState.atlas.get("minimap", true))
	var tool_names: Dictionary = GameState.TOOLBAR_NAMES.duplicate()
	tool_names.merge({"harvest": "双手", "fertilizer": "堆肥", "care": "田间护理"})
	var today: Dictionary = GameState.weather_profile()
	date_button.text = GameState.date_text()
	date_button.tooltip_text = "打开节气历 C"
	info_label.text = "%s · %s %d°C" % [GameState.time_text(),str(today.label),int(today.temperature)]
	forecast_button.text = "明日 · " + GameState.weather_for(GameState.day + 1)
	player_label.text = "%s · 体力 %d / 100" % [GameState.player_name,floori(GameState.stamina)]
	energy_bar.value = GameState.stamina
	tool_label.text = str(tool_names.get(GameState.selected_tool,"双手")) + (" · 骑车" if GameState.riding else "")
	bag_button.text = "背包 " + OS.get_keycode_string(GameState.bound_key("bag",KEY_B))
	seed_button.text = "%s ×%d · Q" % [GameState.crop_name(GameState.selected_seed),int(GameState.inventory.get(GameState.seed_variant_id(GameState.selected_seed),0))]
	seed_button.tooltip_text = "选择种子 Q · " + GameState.crop_name(GameState.selected_seed)
	quick_buttons.map.tooltip_text = "打开地图 " + OS.get_keycode_string(GameState.bound_key("map",KEY_M))
	quick_buttons.save.tooltip_text = "保存与读档"
	quick_buttons.fullscreen.tooltip_text = "全屏 F"
	quick_buttons.menu.tooltip_text = "生活菜单 Tab / Esc"
	help_label.tooltip_text = "%s%s%s%s 移动 · Shift 快走 · %s / Space 交互 · %s 地图 · %s 背包 · %s 任务手记\n1–8 工具 · 肩键切换 · [ / ] / L3 切换目标 · Q 选种 · C 日历 · F 全屏 · H 收起界面\nTab / Esc 生活菜单 · 页面内 Esc 合上 · 点击指南查看完整帮助" % [char(GameState.bound_key("up",KEY_W)),char(GameState.bound_key("left",KEY_A)),char(GameState.bound_key("down",KEY_S)),char(GameState.bound_key("right",KEY_D)),char(GameState.bound_key("interact",KEY_E)),char(GameState.bound_key("map",KEY_M)),char(GameState.bound_key("bag",KEY_B)),char(GameState.bound_key("journal",KEY_J))]
	help_label.text = "按键 · ?"
	help_label.visible = bool(GameState.player_settings.get("hints", true)) and not preload("res://scripts/performance_policy.gd").touch_device()
	if preload("res://scripts/input_hints.gd").touch():
		bag_button.text = "背包"
		seed_button.text = "%s ×%d" % [GameState.crop_name(GameState.selected_seed),int(GameState.inventory.get(GameState.seed_variant_id(GameState.selected_seed),0))]
		date_button.tooltip_text = "点按查看节气历"
	if is_instance_valid(quest_tracker):layout_manager.refresh()

func _apply_text_scale() -> void:
	var scale:=float(GameState.player_settings.get("textScale",1.0))
	if not is_equal_approx(scale,last_text_scale):
		last_text_scale=scale
		UIArtService.apply_all(true)
		ui_stack.layout.call_deferred()


func _show_calendar_festival(season: int) -> void:
	festival_panel.call("open_panel")
	festival_panel.get("season_option").select(season)
	festival_panel.call("refresh")


func _show_pending_year_review() -> void:
	if not GameState.year_review_pending: return
	GameState.year_review_pending = false
	community_panel.call("open_panel", "year")

func show_gifts(npc_id: String) -> void:
	gift_panel.open_panel(npc_id)

func show_wedding(npc_id: String) -> void:
	wedding_panel.open_panel(npc_id)

func begin_relationship_action(action_id: String,npc_id: String,origin: Control,button: Button) -> void:
	if GameState.action_busy() or action_id not in ["e-date","e-marry","e-separate"]:return
	var starting_room := GameState.current_interior
	var position := GameState.player_position if starting_room=="" else GameState.interior_position
	var focus: Control=button
	var restore := func():
		if not is_instance_valid(origin) or GameState.current_interior!=starting_room:return
		origin.show()
		GameState.ui_open=true
		if is_instance_valid(focus):focus.grab_focus()
	var commit := func():
		if GameState.current_interior!=starting_room:return
		notification_origin=origin
		var success:bool=GameState.confirm_operation(GameState.date_npc(npc_id)) if action_id=="e-date" else GameState.confirm_operation(GameState.marry_npc(npc_id)) if action_id=="e-marry" else GameState.confirm_operation(GameState.separate_from_partner())
		notification_origin=null
		if success:
			GameState.save_game(GameState.SAVE_PATH,true)
			if action_id=="e-date":show_npc_story(npc_id)
			else:show_home()
		else:
			restore.call()
			show_notification(GameState.message,true)
	var action := GameState.ACTION_RULES.ui(action_id,button.text)
	action.item=npc_id
	origin.close()
	GameState._interrupt_navigation_for_ui()
	if not GameState.begin_action(action,{"kind":"ui","x":position.x,"y":position.y},commit,restore):restore.call()

func show_separation() -> void:
	separation_panel.open_panel()
