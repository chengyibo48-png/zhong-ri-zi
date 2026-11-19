extends Node2D
## Grouping, readable scale and persistent keepsakes use existing whole artwork.
var world:Node2D
var config:Dictionary={}
var clock:float=0
var elapsed:float=0
func _ready()->void:
	config=preload("res://scripts/house_geometry.gd").profile(GameState.current_interior)
	show_behind_parent=true
	GameState.domain_changed.connect(func(domain:String):
		if domain in ["household","world"]:queue_redraw())
	GameState.clock_changed.connect(queue_redraw)
	set_process(str(config.get("owner",""))=="bao")
func _process(delta:float)->void:
	if not preload("res://scripts/life_presentation.gd").animate():return
	clock+=delta;elapsed+=delta
	if elapsed>=1.0/24:elapsed=0;queue_redraw()
func _draw()->void:
	if config.is_empty():return
	var tint:=Color(str(config.accent));var night:float=preload("res://scripts/world_art.gd").night_factor(GameState.minutes)
	var rug:Texture2D=preload("res://scripts/character_art.gd").texture("res://art/world/interior_surfaces/bedside-rug-v2.png")
	for area:Dictionary in config.areas:
		var r:Array=area.rect;var rect:=Rect2(r[0],r[1],r[2],r[3])
		if rug!=null and not bool(config.barn) and str(area.kind)!="rest":
			var fitted:=Rect2(rect.position+Vector2(18,30),Vector2(rect.size.x-36,rect.size.y*.52))
			draw_texture_rect(rug,fitted,false,Color.WHITE.lerp(tint,.25).darkened(night*.18)*Color(1,1,1,.72))
		elif bool(config.barn):
			for i:int in 9:
				var at:Vector2=rect.position+Vector2(16+i*17,rect.size.y*.6+sin(i*2.3)*14)
				draw_line(at,at+Vector2(17,-4),Color("c7ab6b",.32),2,true)
	# Wall-mounted functional detail is attached to the wall instead of scattered
	# across walking cells. Short labels remain in interaction UI.
	var wood:=Color("715a41").darkened(night*.16)
	draw_line(Vector2(122,201),Vector2(838,201),Color(wood,.23),3,true)
	var receipt:Dictionary=GameState.interior_state.get("household",{}).get("receipts",{}).get(GameState.current_interior+":theme",{})
	if receipt.is_empty():return
	var position:Vector2=Vector2(620,181) if int(receipt.choices[2])==0 else Vector2(715,181)
	if str(config.owner)=="bao":
		draw_line(position,position+Vector2(0,24),wood,2,true)
		for i:int in 4:
			var angle:float=i*PI*.5+clock*.65;var p:Vector2=position+Vector2(cos(angle),sin(angle))*14
			draw_colored_polygon(PackedVector2Array([position,p,p+Vector2(cos(angle+.8),sin(angle+.8))*12]),tint.lightened(.25))
