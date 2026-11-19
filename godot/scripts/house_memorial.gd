extends Node2D
## Small keepsakes are complete code-native objects, not miniature furniture.
var config:Dictionary={}
func _ready()->void:
	config=preload("res://scripts/house_geometry.gd").profile(GameState.current_interior)
	var at:Array=config.get("memorialPoint",[620,480]);position=Vector2(float(at[0]),float(at[1]))
	if str(config.get("id",""))=="building-farm-12":position=Vector2(550,194)
	GameState.domain_changed.connect(func(domain:String):
		if domain in ["household","world"]:queue_redraw())
	GameState.clock_changed.connect(queue_redraw)
func _draw()->void:
	var r:Dictionary=GameState.interior_state.get("household",{}).get("receipts",{}).get(GameState.current_interior+":theme",{})
	if r.is_empty() or str(config.get("owner",""))=="bao":return
	var offset:float=-9 if int(r.choices[2])==0 else 9
	draw_set_transform(Vector2(offset,-54))
	var night:float=preload("res://scripts/world_art.gd").night_factor(GameState.minutes)
	var wood:=Color("ad885b").darkened(night*.22);var paper:=Color("eee0bf").darkened(night*.18);var ink:=Color("5b6b4c").darkened(night*.15)
	var id:String=str(config.get("owner",""))
	if id in ["granny","luSenior"]:
		draw_colored_polygon(PackedVector2Array([Vector2(-18,-9),Vector2(17,-10),Vector2(19,10),Vector2(-16,11)]),Color(str(config.accent)).lerp(paper,.4))
		for i:int in 6:draw_line(Vector2(-15+i*6,-7),Vector2(-14+i*6,9),paper,1,true)
		for i:int in 3:draw_line(Vector2(-15,-5+i*6),Vector2(16,-5+i*6),ink,1,true)
	elif id in ["chen","wu","xiaohe"]:
		draw_colored_polygon(PackedVector2Array([Vector2(-17,-7),Vector2(3,-7),Vector2(3,-13),Vector2(10,-13),Vector2(10,7),Vector2(-17,7)]),wood)
		draw_line(Vector2(-14,-3),Vector2(6,-3),wood.lightened(.35),1.3,true)
		if id!="chen":draw_circle(Vector2(12,4),6,wood.darkened(.25));draw_circle(Vector2(12,4),2,paper)
	elif id=="song":
		draw_circle(Vector2.ZERO,11,wood);draw_circle(Vector2.ZERO,4,paper)
		for i:int in 8:
			var a:float=i*PI*.25;draw_line(Vector2(cos(a),sin(a))*8,Vector2(cos(a),sin(a))*14,wood.darkened(.2),3,true)
	elif id=="yu":
		for i:int in 5:
			draw_line(Vector2(-16+i*8,-10),Vector2(-16+i*8,10),wood,1.2,true)
			draw_line(Vector2(-16,-10+i*5),Vector2(16,-10+i*5),wood,1.2,true)
	elif id=="mei":
		draw_circle(Vector2.ZERO,11,wood);draw_circle(Vector2.ZERO,8,paper)
		for i:int in 5:draw_circle(Vector2(cos(i*TAU/5),sin(i*TAU/5))*4,2.5,ink)
	elif id in ["lin","liang","lan"]:
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-16),Vector2(7,-16),Vector2(7,14),Vector2(0,10),Vector2(-7,14)]),paper)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(6,-3),Vector2(0,7),Vector2(-5,-2)]),ink)
		draw_line(Vector2(0,-8),Vector2(0,9),wood,1,true)
	elif id=="yan":
		for i:int in 2:
			var x:float=-18+i*18;draw_rect(Rect2(x,-11,16,22),wood);draw_rect(Rect2(x+2,-9,12,15),paper)
			draw_colored_polygon(PackedVector2Array([Vector2(x+2,4),Vector2(x+7,-4),Vector2(x+14,4)]),ink)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-18,-11),Vector2(15,-11),Vector2(18,-8),Vector2(18,11),Vector2(-18,11)]),paper)
		draw_line(Vector2(-18,11),Vector2(18,11),wood,1.5,true)
		for i:int in 3:draw_line(Vector2(-13,-6+i*6),Vector2(12-i*4,-6+i*6),ink,1,true)
		if id in ["an","tao","luo"]:draw_circle(Vector2(12,-5),3,wood)
	draw_set_transform(Vector2.ZERO)
