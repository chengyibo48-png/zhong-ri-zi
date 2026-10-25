extends Control
const VIEW=preload("res://scripts/separation_view.gd")
var npc_id:=""
var panel:PanelContainer
var column:VBoxContainer
var scroll:ScrollContainer
var close_button:Button
var confirm_button:Button
var cancel_button:Button
var last_view:Dictionary={}
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.color=Color("08100bde");add_child(backdrop)
 panel=PanelContainer.new()
 var style:=StyleBoxFlat.new();style.bg_color=Color("304232f5");style.border_color=Color("beaa75");style.set_border_width_all(2);style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);add_child(panel)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 panel.add_child(margin)
 var layout:=VBoxContainer.new();margin.add_child(layout)
 close_button=Button.new();close_button.text="关闭 Esc";close_button.pressed.connect(close);layout.add_child(close_button)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
 column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",16);scroll.add_child(column)
 confirm_button=Button.new();confirm_button.pressed.connect(confirm)
 cancel_button=Button.new();cancel_button.pressed.connect(_home)
 column.add_child(confirm_button);column.add_child(cancel_button)
 _fit_panel();hide()
func _notification(what:int)->void:
 if what==NOTIFICATION_RESIZED and is_instance_valid(panel):_fit_panel()
func _fit_panel()->void:
 var half:=Vector2(minf(340,maxf(1,(get_viewport_rect().size.x-24)/2)),minf(260,maxf(1,(get_viewport_rect().size.y-24)/2)))
 panel.offset_left=-half.x;panel.offset_right=half.x;panel.offset_top=-half.y;panel.offset_bottom=half.y
func open_panel(id:String="")->void:
 if GameState.action_busy():return
 npc_id=id;refresh();show();GameState.ui_open=true;cancel_button.grab_focus()
func close()->void:hide();GameState.ui_open=false
func is_open()->bool:return visible
func refresh()->void:
 for button in [confirm_button,cancel_button]:
  if button.get_parent()!=null:button.get_parent().remove_child(button)
 for child in column.get_children():column.remove_child(child);child.queue_free()
 last_view=VIEW.describe()
 for field in ["title","subtitle","quote"]:
  var label:=Label.new();label.text=str(last_view[field]);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(label)
 confirm_button.text=str(last_view.confirm);cancel_button.text=str(last_view.cancel)
 column.add_child(confirm_button);column.add_child(cancel_button)
func confirm()->void:get_parent().begin_relationship_action("e-separate","",self,confirm_button)
func _home()->void:close();get_parent().show_home()

func show_status_message(text:String,error:bool=false)->void:
 preload("res://scripts/modal_status.gd").show_message(column,text,error)
