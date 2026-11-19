extends Control
var snapshot:Dictionary={}
var paper:StyleBoxFlat
func _ready()->void:
	custom_minimum_size=Vector2(198,190);mouse_filter=Control.MOUSE_FILTER_IGNORE
	paper=StyleBoxFlat.new();paper.bg_color=Color("e8dfc5");paper.border_color=Color("9d8760");paper.set_corner_radius_all(5);paper.set_border_width_all(1)
func update_session(value:Dictionary)->void:snapshot=value;queue_redraw()
func _text(at:Vector2,value:String,color:Color=Color("354b40"),font_size:int=14)->void:
	draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _bar(y:float,label:String,value:float,color:Color)->void:
	_text(Vector2(8,y),label,Color("59644f"),12)
	var rect:=Rect2(58,y-9,maxf(80,size.x-68),9)
	draw_style_box(paper,rect);draw_rect(Rect2(rect.position+Vector2(2,2),Vector2((rect.size.x-4)*clampf(value,0,1),5)),color)
func _draw()->void:
	if snapshot.is_empty() or paper==null:return
	var g:Dictionary=snapshot;var stage:String=str(g.stage);var width:float=maxf(170,size.x-16)
	if stage in ["wait","cast","bite"]:
		_text(Vector2(8,24),"浮漂明确下沉时提竿" if stage=="bite" else "鱼在试探，先别急" if bool(g.get("nibble",false)) else "留意水面与咬钩声")
		var y:float=70.0+sin(float(g.get("phaseTime",0))*2)*2
		draw_line(Vector2(16,y),Vector2(width,y),Color("a0b6a1"),1,true)
		draw_line(Vector2(width*.5,y-20),Vector2(width*.5,y+5),Color("a95844"),4,true)
		draw_circle(Vector2(width*.5,y-21),3,Color("e1bd70"))
		_text(Vector2(8,112),"提竿！" if stage=="bite" else "试探 ≠ 咬钩",Color("855b3c"))
		return
	var charge:bool=stage=="charge"
	var value:float=float(g.get("charge",0))*100.0 if charge else float(g.get("tension",35))
	_text(Vector2(8,21),"蓄力 %d%%"%roundi(value) if charge else "鱼线张力 %d"%roundi(value),Color("354b40"),15)
	var rect:=Rect2(8,35,width,22);draw_style_box(paper,rect)
	var zones:Array=[0.0,.333,.666,1.0] if charge else [0.0,.2,.8,1.0]
	var colors:Array[Color]=[Color("a4b9b1"),Color("87aa7c"),Color("c47d59")]
	for i:int in 3:draw_rect(Rect2(rect.position+Vector2(rect.size.x*float(zones[i])+2,2),Vector2(rect.size.x*(float(zones[i+1])-float(zones[i]))-3,18)),colors[i])
	var x:float=rect.position.x+rect.size.x*clampf(value/100,0,1)
	draw_line(Vector2(x,30),Vector2(x,62),Color("354738"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(x,34),Vector2(x-5,27),Vector2(x+5,27)]),Color("354738"))
	_text(Vector2(8,77),"近岸" if charge else "偏松",Color("687c70"),12)
	_text(Vector2(width*.43,77),"中段" if charge else "稳妥",Color("496744"),12)
	_text(Vector2(width-25,77),"远水" if charge else "危险",Color("a25e42"),12)
	if charge:
		_text(Vector2(8,108),"当前落点："+["近岸","中段","远水"][clampi(int(g.get("previewDepth",1)),0,2)])
		_text(Vector2(8,136),"再按一次才会抛出" if str(g.plan.get("inputStyle","hold"))=="toggle" else "满蓄力后仍等你松开",Color("6d715a"),12);return
	var cue:String=str({"cruise":"游动 · 可以稳稳收线","charge":"蓄力 · 准备卸力","surge":"突进 · 留意张力","recover":"恢复 · 适合拉近"}.get(str(g.get("fishPhase","cruise")),"观察鱼势"))
	_text(Vector2(8,104),cue,Color("976640") if bool(g.get("warn",false)) else Color("476444"),13)
	var scale:float=clampf(size.y/190.0,.84,1.2)
	_bar(132*scale,"拉近",1-float(g.get("distance",1)),Color("9a8754"))
	_bar(160*scale,"鱼力",float(g.get("stamina",100))/100.0,Color("6f9995"))
	_text(Vector2(8,187*scale),"收线中" if bool(g.get("holding",false)) else "卸力中",Color("7c6043"),13)
