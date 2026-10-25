extends Control
const ICON=preload("res://scripts/item_icon.gd")
var npc_id:=""
var panel:PanelContainer
var title:Label
var items:VBoxContainer
var close_button:Button
var scroll:ScrollContainer
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new()
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.color=Color("08100bde")
 add_child(backdrop)
 panel=PanelContainer.new()
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("304232f5");style.border_color=Color("beaa75")
 style.set_border_width_all(2);style.set_corner_radius_all(8)
 panel.add_theme_stylebox_override("panel",style)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left=-300;panel.offset_right=300;panel.offset_top=-210;panel.offset_bottom=210
 add_child(panel)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 panel.add_child(margin)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
 set_meta("notification_column",column);set_meta("notification_index",1)
 var header:=HBoxContainer.new();column.add_child(header)
 title=Label.new();title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
 close_button=Button.new();close_button.text="关闭 Esc";close_button.pressed.connect(close);header.add_child(close_button)
 var help:=Label.new();help.text="每天收一份礼物就足够。送来喜欢的菜，能让对方多开心一点。";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(help)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
 items=VBoxContainer.new();items.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(items)
 _fit_panel()
 hide()
func _notification(what:int)->void:
 if what==NOTIFICATION_RESIZED and is_instance_valid(panel):_fit_panel()
func _fit_panel()->void:
 var half:Vector2=Vector2(minf(300,maxf(1,(get_viewport_rect().size.x-24)/2)),minf(210,maxf(1,(get_viewport_rect().size.y-24)/2)))
 panel.offset_left=-half.x;panel.offset_right=half.x;panel.offset_top=-half.y;panel.offset_bottom=half.y
func open_panel(id:String)->void:
 if GameState.action_busy():return
 preload("res://scripts/modal_status.gd").clear_message(self)
 npc_id=id;show();GameState.ui_open=true;refresh();close_button.grab_focus()
func close()->void:hide();GameState.ui_open=false
func is_open()->bool:return visible
func refresh()->void:
 title.text="给"+GameState.npc_name(npc_id)+"的一份心意"
 for child in items.get_children():child.hide();child.queue_free()
 var likes:Array=[]
 for person in GameState.npc_catalog:
  if str(person.id)==npc_id:likes=person.get("likes",[]);break
 var count:=0
 for id in GameState.inventory:
  var item:Dictionary=GameState.item_catalog.get(id,{})
  if int(GameState.inventory[id])<=0 or str(item.get("kind",""))!="料理":continue
  count+=1
  var row:=HBoxContainer.new();items.add_child(row)
  var icon:=ICON.new();icon.custom_minimum_size=Vector2(40,40);icon.configure(str(id));row.add_child(icon)
  var label:=Label.new()
  label.text=str(item.get("name",id))+" ×"+str(int(GameState.inventory[id]))+"\n"+("是对方喜欢的口味。" if id in likes else "亲手做的菜，就是好心意。")
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
  var button:=Button.new();button.text="送一份";button.set_meta("item_id",str(id));button.pressed.connect(send.bind(str(id)));row.add_child(button)
 if count==0:
  var empty:=Label.new();empty.text="还没有做好的料理。先去小厨房点起灶火吧。";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;items.add_child(empty)
func send(item_id:String)->void:
 if GameState.action_busy():return
 var starting_npc:=npc_id
 var starting_day:=GameState.day
 var starting_room:=GameState.current_interior
 var starting_scroll:=scroll.scroll_vertical
 var point:Vector2=GameState.interior_npc_positions.get(npc_id,GameState.interior_position) if starting_room!="" else GameState.npc_positions.get(npc_id,GameState.player_position)
 var target:Dictionary={"kind":"npc","id":npc_id,"npcId":npc_id,"x":point.x,"y":point.y}
 var restore:=func():
  if is_instance_valid(self) and GameState.day==starting_day and GameState.current_interior==starting_room:
   open_panel(starting_npc);scroll.scroll_vertical=starting_scroll
 var commit:=func():
  if GameState.day!=starting_day or GameState.current_interior!=starting_room:return
  GameState.confirm_operation(GameState.gift_npc(starting_npc,item_id))
  restore.call()
 close()
 GameState._interrupt_navigation_for_ui()
 if not GameState.begin_action(GameState.ACTION_RULES.spec("trade","送一份",item_id),target,commit,restore):restore.call()
