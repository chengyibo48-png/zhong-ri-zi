extends Control
var snapshot: Dictionary={}
func _ready() -> void:
	custom_minimum_size=Vector2(170,120 if preload("res://scripts/performance_policy.gd").touch_device() else 205)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func update_session(value: Dictionary) -> void:
	snapshot=value;queue_redraw()
func _draw() -> void:
	var rect:=Rect2(42,8,62,size.y-18)
	draw_style_box(_style(Color("354f48"),Color("9a8157")),rect.grow(3))
	if snapshot.is_empty():return
	var g:=snapshot
	if str(g.get("stage",""))=="charge":
		draw_rect(Rect2(rect.position+Vector2(5,rect.size.y*(1.0-float(g.charge))),Vector2(rect.size.x-10,rect.size.y*float(g.charge))),Color("d1ba77"))
		return
	var height:=float(g.get("barSize",0.3))*rect.size.y
	var center:=rect.position.y+(1.0-float(g.get("barPos",0.5)))*rect.size.y
	draw_style_box(_style(Color("99b77a"),Color("dfd4a0")),Rect2(rect.position.x+5,center-height*0.5,rect.size.x-10,height))
	var fish_y:=rect.position.y+(1.0-float(g.get("fishPos",0.5)))*rect.size.y
	var icon: Texture2D=preload("res://scripts/item_art.gd").texture_for(str(g.get("plan",{}).get("fish","fish")),"items")
	if icon!=null:draw_texture_rect(icon,Rect2(rect.position.x+9,fish_y-12,44,24),false)
	else:draw_circle(Vector2(rect.get_center().x,fish_y),6,Color("ecd3a0"))
	var progress:=float(g.get("progress",0))
	draw_rect(Rect2(119,8,12,rect.size.y),Color("42574a"))
	draw_rect(Rect2(119,8+rect.size.y*(1.0-progress),12,rect.size.y*progress),Color("d1bd79"))
	if bool(g.get("warn",false)):draw_circle(Vector2(22,fish_y),5,Color("d79867"))
func _style(background: Color, border: Color) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new();result.bg_color=background;result.border_color=border
	result.set_corner_radius_all(6);result.set_border_width_all(2);return result
