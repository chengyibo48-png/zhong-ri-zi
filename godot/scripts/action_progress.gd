extends Control

var title: Label
var phase: Label
var progress: ProgressBar
var cancel_button: Button
var card: PanelContainer
var activity_icon: TextureRect
var _icon_phase := 0.0

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 # Only the card intercepts pointer input, matching the source positioned HUD.
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 card = PanelContainer.new()
 card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 card.set_meta("compact_hud",true)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("304232")
 style.border_color = Color("beaa75")
 style.set_border_width_all(2)
 style.set_corner_radius_all(8)
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 8
 style.content_margin_bottom = 8
 card.add_theme_stylebox_override("panel",style)
 add_child(card)
 var rows := VBoxContainer.new()
 rows.add_theme_constant_override("separation",4)
 card.add_child(rows)
 var heading := HBoxContainer.new()
 heading.add_theme_constant_override("separation",8)
 rows.add_child(heading)
 activity_icon=TextureRect.new();activity_icon.texture=preload("res://scripts/detail_art.gd").texture("ui/loading")
 activity_icon.custom_minimum_size=Vector2(16,16);activity_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;activity_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;activity_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 heading.add_child(activity_icon)
 title = Label.new()
 title.add_theme_font_size_override("font_size",16)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 title.clip_text = true
 title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 heading.add_child(title)
 cancel_button = Button.new()
 cancel_button.text = "取消 · Esc / B"
 cancel_button.pressed.connect(GameState.cancel_player_action)
 heading.add_child(cancel_button)
 phase = Label.new()
 phase.add_theme_font_size_override("font_size",14)
 phase.clip_text = true
 rows.add_child(phase)
 progress = ProgressBar.new()
 progress.max_value = 1.0
 progress.show_percentage = false
 progress.custom_minimum_size.y = 8
 rows.add_child(progress)
 get_viewport().size_changed.connect(_layout_card)
 _layout_card()
 GameState.action_sequence_changed.connect(refresh)
 GameState.input_mode_changed.connect(func(_mode:String):refresh(GameState.action_snapshot()))
 refresh(GameState.action_snapshot())

func refresh(snapshot: Dictionary) -> void:
 var opening := not visible and not snapshot.is_empty()
 visible = not snapshot.is_empty()
 if not visible:return
 cancel_button.text="停下 · "+GameState.cancel_input_label()
 _layout_card()
 card.visible=str(snapshot.get("kind",""))!="fish"
 if opening and card.visible:cancel_button.grab_focus()
 title.text = str(snapshot.get("label","正在忙碌"))
 title.tooltip_text = title.text
 phase.text = str(snapshot.get("phase","准备")) + " · 完成后结算"
 progress.value = float(snapshot.get("progress",0.0))


func _input(event: InputEvent) -> void:
 if not visible:return
 # Capture before focused underlying buttons receive keyboard or controller input.
 if event is InputEventKey:
  if event.pressed and event.keycode==KEY_ESCAPE:GameState.cancel_player_action()
  elif event.pressed and not event.echo and event.keycode==KEY_SPACE and GameState.fishing_active():GameState.toggle_fishing_reel()
  get_viewport().set_input_as_handled()
 elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
  # Button edges and cancellation are owned by the source frame sampler.
  get_viewport().set_input_as_handled()

func _layout_card() -> void:
 if not is_inside_tree() or not is_instance_valid(card): return
 var view := get_viewport_rect().size
 var width := minf(420.0,maxf(1.0,view.x-40.0))
 var bottom := -preload("res://scripts/hud_dock.gd").reserve(self)
 card.anchor_left=0.5;card.anchor_right=0.5;card.anchor_top=1.0;card.anchor_bottom=1.0
 card.offset_left=-width*0.5;card.offset_right=width*0.5
 card.offset_bottom=bottom
 card.offset_top=bottom-maxf(100,card.get_combined_minimum_size().y)

func _process(delta: float) -> void:
 if not visible or not is_instance_valid(activity_icon): return
 _icon_phase += delta if str(GameState.visual_fx.get("motion", "full")) == "full" and not GameState.simulation_hidden() else 0.0
 activity_icon.pivot_offset=activity_icon.size*0.5
 activity_icon.rotation=_icon_phase*1.6 if str(GameState.visual_fx.get("motion", "full"))=="full" else 0.0
