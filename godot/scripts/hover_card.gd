extends PanelContainer
const DESCRIBE=preload("res://scripts/interaction_description.gd")
const RULES=preload("res://scripts/interaction_hint_rules.gd")
var heading:Label
var description:Label
var last_content:Dictionary={}
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 focus_mode=Control.FOCUS_NONE
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("304232f5");style.border_color=Color("beaa75")
 style.set_border_width_all(1);style.set_corner_radius_all(5)
 style.content_margin_left=15;style.content_margin_right=15
 style.content_margin_top=11;style.content_margin_bottom=11
 add_theme_stylebox_override("panel",style)
 var rows:=VBoxContainer.new();rows.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rows)
 heading=Label.new();heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(heading)
 description=Label.new();description.mouse_filter=Control.MOUSE_FILTER_IGNORE
 description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(description)
 hide()
func refresh_world()->void:
 var world:Node=get_parent().get_parent()
 if GameState.ui_open or GameState.action_busy() or not is_instance_valid(world):hide();return
 var target:Variant=world.get("pointer_hover")
 var pointer:Variant=world.get("pointer_screen")
 if not target is Dictionary or target.is_empty() or pointer==null:hide();return
 var info:Dictionary=DESCRIBE.describe(GameState,target,GameState.selected_tool)
 if info.is_empty():hide();return
 # The source hover hint always names the keyboard binding, independent of mode.
 var key:String=str(GameState.player_settings.get("bindings",{}).get("interact","e")).to_upper()
 update_content(info,key,Vector2(pointer),get_viewport_rect().size)
func update_content(info:Dictionary,key:String,pointer:Vector2,view:Vector2)->void:
 var content:Dictionary=RULES.hover_content(info,key)
 if content!=last_content:
  last_content=content
  heading.text=content.name;description.text=content.body
 var width:float=minf(190,maxf(1,view.x-20))
 custom_minimum_size.x=width
 size=Vector2(width,0)
 position=RULES.hover_position(pointer,size,view)
 show()
