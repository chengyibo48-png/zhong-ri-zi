extends RefCounted
static func show_message(column:VBoxContainer,text:String,error:bool=false,index:int=2)->void:
 var status:PanelContainer=column.get_node_or_null("ModalStatus")
 if status==null:
  status=PanelContainer.new();status.name="ModalStatus";status.set_meta("preserve_notification_style",true);status.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var label:=Label.new();label.name="Message";label.set_meta("preserve_notification_style",true);label.add_theme_font_size_override("font_size",16);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;status.add_child(label)
  column.add_child(status);column.move_child(status,mini(index,column.get_child_count()-1))
 var style:=StyleBoxFlat.new();style.bg_color=Color("f2e8d9") if error else Color("e3e9d3");style.border_color=Color("dcc6ab") if error else Color("cad5b2");style.set_border_width_all(1);style.set_corner_radius_all(5);style.set_content_margin_all(10)
 status.add_theme_stylebox_override("panel",style)
 status.get_node("Message").add_theme_color_override("font_color",Color("9c7350") if error else Color("576e42"))
 status.set_meta("notification_error",error)
 status.get_node("Message").text=text
static func clear_message(panel:Control)->void:
 if not panel.has_meta("notification_column"):return
 var column:VBoxContainer=panel.get_meta("notification_column")
 if not is_instance_valid(column):return
 var status:=column.get_node_or_null("ModalStatus")
 if status!=null:column.remove_child(status);status.queue_free()
