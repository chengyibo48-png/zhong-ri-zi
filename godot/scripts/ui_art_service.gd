extends Node

const PALETTES := {
	"paper": {"panel": "f2e8d2", "border": "a98b63", "backdrop": "29362cc7", "button": "e6dcc3", "hover": "d4dfbe", "pressed": "c3d1ae", "ink": "354537", "muted": "6c6957"},
	"porcelain": {"panel": "293b40", "border": "97c0c3", "backdrop": "071115e0", "button": "30474d", "hover": "42636a", "pressed": "20343a", "ink": "e3f1ee", "muted": "b5d1cf"},
	"timber": {"panel": "44392c", "border": "c5a06e", "backdrop": "120d08e0", "button": "55452f", "hover": "705a3b", "pressed": "3b2e20", "ink": "f4e3c6", "muted": "dcc39b"}
}

var paper_samples:Dictionary={}
var paper_textures:Dictionary={}
var shared_theme: Theme
var active_theme := ""
var active_high_contrast := false
var active_text_scale := -1.0
var theme_revision := 0
var applied_theme_revision := -1

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	GameState.changed.connect(apply_all)
	_rebuild_theme()
	call_deferred("apply_all")

func register_root(root: Node) -> void:
	if not root.is_in_group("ui_art_root"):
		root.add_to_group("ui_art_root")
	apply_all(true)

func apply_all(force: bool = false) -> void:
	var theme_key := str(GameState.ui_art.get("theme", "paper"))
	if theme_key not in PALETTES: theme_key = "paper"
	var high_contrast := bool(GameState.player_settings.get("contrast", false))
	if active_theme != theme_key or active_high_contrast != high_contrast or not is_equal_approx(active_text_scale,float(GameState.player_settings.get("textScale",1.0))): _rebuild_theme()
	if not force and applied_theme_revision == theme_revision: return
	applied_theme_revision = theme_revision
	for root in get_tree().get_nodes_in_group("ui_art_root"):
		for node in root.find_children("*", "Control", true, false):
			if node is Control: _apply_control(node, theme_key)
		if root is Control: _apply_control(root, theme_key)

func apply_subtree(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree(): return
	apply_all()
	_apply_control(root, active_theme)
	for node in root.find_children("*", "Control", true, false):
		if node is Control: _apply_control(node, active_theme)

func _on_node_added(node: Node) -> void:
	if not node is Control: return
	var parent := node.get_parent()
	while parent != null:
		if parent.is_in_group("ui_art_root"):
			# Set the inherited theme before children construct and measure text.
			if shared_theme == null: _rebuild_theme()
			node.theme = shared_theme
			call_deferred("_apply_pending_control", weakref(node))
			return
		parent = parent.get_parent()

func _apply_pending_control(reference: WeakRef) -> void:
	var node: Object = reference.get_ref()
	if node is Control and node.is_inside_tree(): _apply_control(node, active_theme)

func _rebuild_theme() -> void:
	theme_revision += 1
	active_text_scale=clampf(float(GameState.player_settings.get("textScale",1.0)),0.85,1.5)
	active_theme = str(GameState.ui_art.get("theme", "paper"))
	if active_theme not in PALETTES: active_theme = "paper"
	active_high_contrast = bool(GameState.player_settings.get("contrast", false))
	var palette := _effective_palette(active_theme)
	shared_theme = Theme.new()
	shared_theme.default_font_size=18
	shared_theme.set_stylebox("panel","PanelContainer",_flat_style(str(palette.panel),str(palette.border)))
	for kind: String in ["TabContainer","TabBar"]:
		shared_theme.set_stylebox("panel",kind,_flat_style(str(palette.panel),str(palette.border)))
		for tab_state: String in ["tab_unselected","tab_selected","tab_hovered","tab_disabled"]:shared_theme.set_stylebox(tab_state,kind,_button_style(str(palette.hover) if tab_state=="tab_selected" else str(palette.button),str(palette.border)))
		for role: String in ["font_selected_color","font_unselected_color","font_hovered_color","font_disabled_color"]:shared_theme.set_color(role,kind,Color(str(palette.ink)))
		shared_theme.set_font_size("font_size",kind,roundi(18*active_text_scale))
	shared_theme.default_font = preload("res://art/fonts/NotoSansCJKsc-Regular.otf")
	Input.set_custom_mouse_cursor(preload("res://scripts/detail_art.gd").texture("ui/cursor"), Input.CURSOR_ARROW, Vector2(4, 3))
	shared_theme.set_color("font_color", "Button", Color(str(palette.ink)))
	shared_theme.set_color("font_hover_color", "Button", Color(str(palette.ink)))
	shared_theme.set_color("font_pressed_color", "Button", Color(str(palette.ink)))
	shared_theme.set_color("font_color", "OptionButton", Color(str(palette.ink)))
	shared_theme.set_color("font_color", "CheckButton", Color(str(palette.ink)))
	shared_theme.set_color("font_color", "LineEdit", Color(str(palette.ink)))
	shared_theme.set_color("font_color", "Label", Color(str(palette.ink)))
	shared_theme.set_color("font_color", "RichTextLabel", Color(str(palette.ink)))
	shared_theme.set_color("font_color", "ItemList", Color(str(palette.ink)))
	shared_theme.set_color("font_selected_color", "ItemList", Color(str(palette.ink)))
	shared_theme.set_stylebox("panel", "ItemList", _button_style(str(palette.panel), str(palette.border)))
	shared_theme.set_stylebox("selected", "ItemList", _button_style(str(palette.hover), str(palette.border)))
	shared_theme.set_stylebox("selected_focus", "ItemList", _button_style(str(palette.hover), str(palette.border)))
	shared_theme.set_stylebox("normal", "LineEdit", _button_style(str(palette.panel), str(palette.border)))
	shared_theme.set_stylebox("read_only", "LineEdit", _button_style(str(palette.button), str(palette.border)))
	shared_theme.set_color("caret_color", "LineEdit", Color(str(palette.ink)))
	shared_theme.set_color("font_placeholder_color", "LineEdit", Color(str(palette.muted)))
	shared_theme.set_color("font_uneditable_color", "LineEdit", Color(str(palette.muted)))
	shared_theme.set_stylebox("panel", "PopupMenu", _button_style(str(palette.panel), str(palette.border)))
	shared_theme.set_stylebox("hover", "PopupMenu", _button_style(str(palette.hover), str(palette.border)))
	for type_name in ["PopupMenu", "TooltipLabel"]:
		shared_theme.set_color("font_color", type_name, Color(str(palette.ink)))
		shared_theme.set_color("font_hover_color", type_name, Color(str(palette.ink)))
		shared_theme.set_color("font_disabled_color", type_name, Color(str(palette.muted)))
		shared_theme.set_color("font_accelerator_color", type_name, Color(str(palette.muted)))
	var tooltip_style: StyleBox = _button_style(str(palette.panel), str(palette.border))
	if active_theme == "paper" and not active_high_contrast:
		var painted_tooltip := preload("res://scripts/detail_art.gd").panel("ui/tooltip")
		if painted_tooltip != null: tooltip_style = painted_tooltip
	shared_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	for type_name in ["VScrollBar", "HScrollBar"]:
		shared_theme.set_stylebox("scroll", type_name, _flat_style(str(palette.button), str(palette.border)))
		shared_theme.set_stylebox("grabber", type_name, _flat_style(str(palette.border), str(palette.border)))
		shared_theme.set_stylebox("grabber_highlight", type_name, _flat_style(str(palette.muted), str(palette.border)))
	for type_name in ["Button", "OptionButton"]:
		shared_theme.set_color("font_disabled_color", type_name, Color(str(palette.muted)))
		shared_theme.set_color("font_focus_color", type_name, Color(str(palette.ink)))
		shared_theme.set_color("icon_disabled_color", type_name, Color(1, 1, 1, 0.65))
		shared_theme.set_stylebox("normal", type_name, _button_style(str(palette.button), str(palette.border)))
		shared_theme.set_stylebox("hover", type_name, _button_style(str(palette.hover), str(palette.border)))
		shared_theme.set_stylebox("pressed", type_name, _button_style(str(palette.pressed), str(palette.border)))
		shared_theme.set_stylebox("focus", type_name, _focus_style(str(palette.button), str(palette.ink)))
		shared_theme.set_stylebox("disabled", type_name, _button_style(str(palette.pressed), str(palette.border)))

func _apply_control(control: Control, theme_key: String) -> void:
	_typography(control)
	if control is TabBar and preload("res://scripts/performance_policy.gd").touch_device():control.custom_minimum_size.y=maxf(48,control.custom_minimum_size.y)
	if control is Label or control is Button: control.text = preload("res://scripts/input_hints.gd").text(control.text)
	if control is BaseButton and preload("res://scripts/input_hints.gd").touch(): control.custom_minimum_size.y = maxf(control.custom_minimum_size.y,48.0)
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	if shared_theme == null: _rebuild_theme()
	if preload("res://scripts/performance_policy.gd").touch_device():
		if control is Button:
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 48)
			control.add_theme_font_size_override("font_size", maxi(control.get_theme_font_size("font_size"), 18))
	var palette := _effective_palette(theme_key)
	if control.theme != shared_theme: control.theme = shared_theme
	if bool(control.get_meta("preserve_notification_style",false)):return
	if bool(control.get_meta("compact_hud",false)):
		_apply_compact_hud(control)
		return
	# Coalesce the unchanged overrides into one theme/layout notification.
	control.begin_bulk_theme_override()
	if control is ColorRect:
		if not bool(control.get_meta("preserve_ui_color",false)): control.color = Color(str(palette.backdrop))
	elif control is PanelContainer:
		var existing: StyleBox = control.get_theme_stylebox("panel")
		if existing is StyleBoxFlat: control.set_meta("painted_panel_baseline",existing.duplicate())
		var baseline: Variant=control.get_meta("painted_panel_baseline") if control.has_meta("painted_panel_baseline") else null
		if baseline is StyleBoxFlat:
			var style: StyleBoxFlat=baseline.duplicate()
			style.bg_color=Color(str(palette.panel),style.bg_color.a)
			style.border_color=Color(str(palette.border),style.border_color.a)
			var painted:=_paper_skin("panel",style.bg_color)
			if painted!=null:
				for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:painted.set_content_margin(side,style.get_content_margin(side))
				control.add_theme_stylebox_override("panel",painted)
			else:control.add_theme_stylebox_override("panel",style)
	elif control is Button:
		control.add_theme_color_override("font_color", Color(str(palette.ink)))
		control.add_theme_color_override("font_hover_color", Color(str(palette.ink)))
		control.add_theme_color_override("font_pressed_color", Color(str(palette.ink)))
		control.add_theme_color_override("font_disabled_color", Color(str(palette.muted)))
		control.add_theme_color_override("font_focus_color", Color(str(palette.ink)))
		control.add_theme_stylebox_override("normal", _button_style(str(palette.button), str(palette.border)))
		control.add_theme_stylebox_override("hover", _button_style(str(palette.hover), str(palette.border)))
		control.add_theme_stylebox_override("pressed", _button_style(str(palette.pressed), str(palette.border)))
		control.add_theme_stylebox_override("focus", _focus_style(str(palette.button), str(palette.ink)))
	elif control is Label:
		control.add_theme_color_override("font_color", Color(str(palette.ink)))
	elif control is RichTextLabel:
		control.add_theme_color_override("default_color", Color(str(palette.ink)))
	elif control is ItemList:
		control.add_theme_color_override("font_color", Color(str(palette.ink)))
		control.add_theme_color_override("font_selected_color", Color(str(palette.ink)))
	elif control is OptionButton or control is CheckButton or control is LineEdit:
		control.add_theme_color_override("font_color", Color(str(palette.ink)))
	control.end_bulk_theme_override()

func _effective_palette(theme_key: String) -> Dictionary:
	var palette: Dictionary = PALETTES.get(theme_key, PALETTES.paper).duplicate(true)
	if bool(GameState.player_settings.get("contrast", false)):
		palette.merge({
			"panel": "fffdf1",
			"border": "465841",
			"backdrop": "08100bde",
			"button": "e4ebda",
			"hover": "d2dfc9",
			"pressed": "c0d0b4",
			"ink": "192a23",
			"muted": "304539"
		}, true)
	return palette

func _button_style(background: String, border: String) -> StyleBox:
	var painted:=_paper_skin("button",Color(background))
	if painted!=null:
		painted.set_content_margin_all(7)
		return painted
	return _flat_style(background,border)

func _flat_style(background: String, border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(7)
	return style

func _focus_style(background: String, border: String) -> StyleBox:
	if not active_high_contrast:
		var painted := preload("res://scripts/detail_art.gd").panel("ui/focus", 7.0)
		if painted != null:
			painted.draw_center = false
			return painted
	var style := _flat_style(background, border)
	style.bg_color.a = 0.0
	style.set_border_width_all(2)
	return style

func _paper_skin(kind:String,color:Color)->StyleBoxTexture:
	if active_theme!="paper" or active_high_contrast:return null
	var entry:Dictionary=preload("res://scripts/world_art.gd").entries().get("ui/"+kind,{})
	if not bool(entry.get("baseReady",false)):return null
	var texture:=preload("res://scripts/character_art.gd").texture(str(entry.get("path","")))
	if texture==null:return null
	if not paper_textures.has(kind):
		var image:Image=texture.get_image()
		var size:=128 if kind=="button" else 256
		image.resize(size,size,Image.INTERPOLATE_LANCZOS)
		paper_textures[kind]=ImageTexture.create_from_image(image)
		paper_samples[kind]=image.get_pixel(size/2,size/2)
	var sample:Color=paper_samples[kind]
	var style:=StyleBoxTexture.new();style.texture=paper_textures[kind]
	style.modulate_color=Color(color.r/maxf(sample.r,0.01),color.g/maxf(sample.g,0.01),color.b/maxf(sample.b,0.01),color.a/maxf(sample.a,0.01))
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,float(entry.get("nineSliceMargin",24))*style.texture.get_width()/texture.get_width())
	style.set_content_margin_all(7)
	return style

static func style_background(style:StyleBox)->Color:
	if style is StyleBoxFlat:return style.bg_color
	if style is StyleBoxTexture and style.texture!=null:
		var image:Image=style.texture.get_image()
		return image.get_pixel(image.get_width()/2,image.get_height()/2)*style.modulate_color
	return Color.TRANSPARENT


## Lightweight HUD surfaces keep decorative paper frames in full-screen pages.
func _compact_surface(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _apply_compact_hud(control: Control) -> void:
	var palette := _effective_palette(active_theme)
	var ink := Color(str(palette.ink))
	var paper := Color(str(palette.panel), 1.0 if active_high_contrast else 0.94)
	var border := Color(str(palette.border), 1.0 if active_high_contrast else 0.7)
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", _compact_surface(paper, border))
	elif control is Button:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var fill := Color(str(palette.button), 1.0 if active_high_contrast else 0.94)
			if state == "hover": fill = Color(str(palette.hover))
			if state == "pressed": fill = Color(str(palette.pressed))
			if state == "disabled": fill.a = 0.65
			var edge := ink if state in ["focus", "pressed"] else border
			if state == "focus": fill.a = 0.0
			var style: StyleBox = _compact_surface(fill, edge)
			if state == "focus" and not active_high_contrast:
				var focus := preload("res://scripts/detail_art.gd").panel("ui/focus", 7.0)
				if focus != null:
					focus.draw_center = false
					style = focus
			control.add_theme_stylebox_override(state, style)
		for role: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(role, ink)
		control.add_theme_color_override("font_disabled_color", Color(str(palette.muted)))
	elif control is ProgressBar:
		control.add_theme_stylebox_override("background", _compact_surface(Color(str(palette.border), 0.25), Color.TRANSPARENT))
		control.add_theme_stylebox_override("fill", _compact_surface(Color("#75966a"), Color.TRANSPARENT))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func _typography(control: Control) -> void:
	if not (control is Label or control is BaseButton or control is LineEdit or control is ItemList or control is RichTextLabel):return
	var compact:=false
	var owner: Node=control
	while owner!=null:
		if bool(owner.get_meta("compact_hud",false)):compact=true;break
		owner=owner.get_parent()
	if not control.has_meta("ui_base_font"):
		var original:=control.get_theme_font_size("font_size")
		control.set_meta("ui_base_font",maxi(14,mini(original,16)) if compact else maxi(16,original) if original<=16 else maxi(18,original))
	var font:=roundi(float(control.get_meta("ui_base_font"))*maxf(.85,active_text_scale))
	control.add_theme_font_size_override("font_size",font)
	if control is RichTextLabel:
		control.add_theme_font_size_override("normal_font_size",font);control.add_theme_font_size_override("bold_font_size",font)
	if control is BaseButton:
		control.custom_minimum_size.y=maxf(control.custom_minimum_size.y,48 if preload("res://scripts/performance_policy.gd").touch_device() else 36 if compact else 40)
	if control is LineEdit:control.custom_minimum_size.y=maxf(control.custom_minimum_size.y,44)
