extends Control
signal feedback_requested
var column:VBoxContainer
var model:RefCounted
var snapshot:Array=[]
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=5
 column=VBoxContainer.new();column.add_theme_constant_override("separation",7)
 column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 column.alignment=BoxContainer.ALIGNMENT_END;add_child(column)
 _fit()
func bind(queue:RefCounted)->void:model=queue;model.expire(Time.get_ticks_msec()/1000.0);refresh()
func _notification(what:int)->void:
 if what==NOTIFICATION_RESIZED and is_instance_valid(column):_fit()
func _fit()->void:
 var viewport:=get_viewport_rect().size
 var width:=minf(420,viewport.x*(0.9 if viewport.x<=760 else 0.8))
 var bottom:=190.0 if viewport.x<=760 else 160.0
 column.position=Vector2((viewport.x-width)/2,0)
 column.size=Vector2(width,maxf(0,viewport.y-bottom))
func _process(_delta:float)->void:
 if model==null:return
 var expired:bool=model.expire(Time.get_ticks_msec()/1000.0)
 if expired or snapshot!=model.rows:refresh()
func refresh()->void:
 if not is_instance_valid(column) or model==null:return
 snapshot=model.rows.duplicate(true)
 for child in column.get_children():
  var present:=false
  for row in model.rows:
   if child.name=="Toast"+str(row.id):present=true;break
  if not present:column.remove_child(child);child.queue_free()
 for index in model.rows.size():
  var row:Dictionary=model.rows[index]
  var existing:=column.get_node_or_null("Toast"+str(row.id))
  if existing!=null:column.move_child(existing,index);continue
  var control:Control
  if bool(row.important):
   var button:=Button.new();button.text=str(row.text);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.alignment=HORIZONTAL_ALIGNMENT_LEFT
   button.add_theme_font_size_override("font_size",16);button.add_theme_color_override("font_color",Color("947047") if bool(row.error) else Color("5e7248"))
   button.tooltip_text=str(row.message)+"，打开回响查看"
   button.icon=preload("res://scripts/detail_art.gd").texture("ui/reward_badge");button.add_theme_constant_override("icon_max_width",16)
   button.pressed.connect(func():feedback_requested.emit());control=button
   button.add_theme_stylebox_override("normal",_style(bool(row.error)));button.add_theme_stylebox_override("hover",_style(bool(row.error)))
  else:
   var panel:=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   panel.add_theme_stylebox_override("panel",_style(bool(row.error)))
   var label:=Label.new();label.text=str(row.text);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",Color("947047") if bool(row.error) else Color("5e7248"))
   label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.set_meta("preserve_notification_style",true)
   var line:=HBoxContainer.new();line.add_theme_constant_override("separation",8);panel.add_child(line)
   var icon:=TextureRect.new();icon.texture=preload("res://scripts/detail_art.gd").texture("ui/notification");icon.custom_minimum_size=Vector2(16,16);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
   line.add_child(icon);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label);control=panel
  control.set_meta("preserve_notification_style",true)
  if control is PanelContainer:control.get_child(0).set_meta("preserve_notification_style",true)
  control.name="Toast"+str(row.id);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(control)
  if str(GameState.feedback.get("prefs",{}).get("motion","full"))!="reduced":
   control.modulate.a=0.0
   var tween:=control.create_tween();tween.tween_property(control,"modulate:a",1.0,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func _style(error:bool)->StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color("fff5dcec")
 style.border_color=Color("c7ab7c") if error else Color("b8ad7d");style.set_border_width_all(1);style.set_corner_radius_all(6);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=11;style.content_margin_bottom=11
 return style
