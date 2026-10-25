extends PanelContainer
const DESCRIBE=preload("res://scripts/interaction_description.gd")
const HINT_RULES=preload("res://scripts/interaction_hint_rules.gd")
var presence_wanted:=false
var last_motion:=""
var visibility_tween:Tween
var fade_progress:=0.0
var fade_target:=0.0
var adjusted_start:=0.0
var reversing_factor:=1.0
var tween_duration:=0.14
var heading:Label
var input_label:Label
var description:Label
var available:=true
var screen_anchor:=Vector2.ZERO
var last_content:Dictionary={}
var layout_view := Vector2.ZERO
func _ready()->void:
 set_meta("compact_hud",true)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 focus_mode=Control.FOCUS_NONE
 var rows:=VBoxContainer.new()
 rows.mouse_filter=Control.MOUSE_FILTER_IGNORE
 rows.add_theme_constant_override("separation",3)
 add_child(rows)
 rows.minimum_size_changed.connect(func():call_deferred("_place_prompt"))
 var title_row:=HBoxContainer.new()
 title_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
 title_row.alignment=BoxContainer.ALIGNMENT_CENTER
 rows.add_child(title_row)
 input_label=Label.new()
 input_label.add_theme_font_size_override("font_size",16)
 input_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 title_row.add_child(input_label)
 heading=Label.new()
 heading.add_theme_font_size_override("font_size",16)
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title_row.add_child(heading)
 description=Label.new()
 description.add_theme_font_size_override("font_size",14)
 description.mouse_filter=Control.MOUSE_FILTER_IGNORE
 description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 rows.add_child(description)
 modulate.a=0
 hide()
 resized.connect(_place_prompt)
 get_viewport().size_changed.connect(_place_prompt)
func refresh_world()->void:
 var world:Node=get_parent().get_parent()
 if GameState.ui_open or GameState.action_busy() or not is_instance_valid(world):_set_presence(false);return
 var outdoor:bool=world.has_method("_world_target_candidates")
 var target:Variant=world.get("selected_world_target" if outdoor else "selected_room_target")
 var player:Variant=world.get("player")
 if not target is Dictionary or target.is_empty() or not is_instance_valid(player):_set_presence(false);return
 var info:Dictionary=DESCRIBE.describe(GameState,target,GameState.selected_tool)
 if info.is_empty():_set_presence(false);return
 var at:Vector2=Vector2(float(target.get("x",0)),float(target.get("top",target.get("y",0)))-10) if bool(target.get("scenery",false)) else player.global_position+Vector2(0,-43)
 update_content(info,GameState.interaction_input_label(),world.get_canvas_transform()*at,get_viewport_rect().size)
func update_content(info:Dictionary,key_label:String,anchor:Vector2,view:Vector2)->void:
 layout_view=view
 var touch:bool=preload("res://scripts/performance_policy.gd").touch_device()
 var width:float=minf(420 if touch else 280,maxf(1,view.x-28))
 input_label.add_theme_font_size_override("font_size",18 if touch else 12)
 heading.add_theme_font_size_override("font_size",18 if touch else 12)
 description.add_theme_font_size_override("font_size",16 if touch else 11)
 input_label.text=key_label
 # Wrapped labels need their usable width before assigning new text. Otherwise
 # their initial one-pixel width leaves a tall stale container minimum.
 description.size.x=maxf(1,width-26)
 heading.size.x=maxf(1,width-26-input_label.get_combined_minimum_size().x-input_label.get_parent().get_theme_constant("separation"))
 available=bool(info.get("ready",false))
 screen_anchor=Vector2(maxf(125,minf(view.x-125,anchor.x)),maxf(110,minf(view.y-145,anchor.y)))
 var content:Dictionary={"title":str(info.get("verb",""))+" · "+str(info.get("name","")),"input":key_label,"body":str(info.get("reason","")) if str(info.get("reason",""))!="" else str(info.get("state","")),"detail":str(info.get("detail","")),"ready":available}
 if content!=last_content:
  last_content=content
  heading.text=content.title
  input_label.text=key_label
  description.text=content.body+("\n"+content.detail if content.detail!="" else "")
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("304232f2") if available else Color("493b32f2")
  style.border_color=Color("beaa75") if available else Color("b99b80")
  style.set_border_width_all(1)
  style.set_corner_radius_all(5)
  style.content_margin_left=13;style.content_margin_right=13
  style.content_margin_top=9;style.content_margin_bottom=9
  add_theme_stylebox_override("panel",style)
  UIArtService.apply_subtree(self)
 custom_minimum_size.x=width
 size=Vector2(width,0)
 _place_prompt()
 call_deferred("_place_prompt")
 _set_presence(true)

func _place_prompt()->void:
 if not is_inside_tree() or is_queued_for_deletion() or not is_node_ready():return
 var measured:float=get_combined_minimum_size().y
 if not is_equal_approx(size.y,measured):size.y=measured
 var view:Vector2=layout_view if layout_view.x > 0 else get_viewport_rect().size
 var reserve:float=preload("res://scripts/hud_dock.gd").reserve(self)+36.0
 if preload("res://scripts/performance_policy.gd").touch_device():
  var actions:Node=get_parent().get("context_actions")
  var row_height:float=actions.rows.get_combined_minimum_size().y if actions != null and actions.rows != null and actions.visible else 64.0
  reserve=preload("res://scripts/hud_dock.gd").reserve(self)+row_height+12.0
 position=Vector2(maxf(0,(view.x-size.x)/2),maxf(0,view.y-reserve-size.y))

func _set_presence(wanted:bool)->void:
 var motion:String=str(GameState.feedback.get("prefs",{}).get("motion","full"))
 if presence_wanted==wanted and last_motion==motion:return
 presence_wanted=wanted;last_motion=motion
 var target:=1.0 if wanted else 0.0
 var active:bool=visibility_tween!=null and visibility_tween.is_valid()
 if active and target==adjusted_start:
  reversing_factor=absf(HINT_RULES.css_ease(fade_progress)*reversing_factor+(1.0-reversing_factor))
  adjusted_start=fade_target
 else:
  reversing_factor=1.0
  adjusted_start=modulate.a
 if active:visibility_tween.kill()
 fade_target=target
 fade_progress=0.0
 tween_duration=0.14*reversing_factor
 if motion=="reduced":
  modulate.a=target;visible=wanted;return
 if wanted:show()
 var start:float=modulate.a
 visibility_tween=create_tween()
 visibility_tween.tween_method(func(progress:float):
  fade_progress=progress
  modulate.a=lerpf(start,target,HINT_RULES.css_ease(progress)),0.0,1.0,tween_duration)
 visibility_tween.finished.connect(func():
  modulate.a=target
  if not presence_wanted:hide())
func advance_visibility(delta:float)->void:
 if visibility_tween!=null and visibility_tween.is_valid():visibility_tween.custom_step(maxf(0,delta))
