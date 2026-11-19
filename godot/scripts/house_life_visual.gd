extends Node2D
## Wall details have no collision; tabletop details are drawn by their own support.
const L=preload("res://scripts/house_life.gd")
var world:Node2D
var room:String=""
var config:Dictionary={}
func _ready()->void:
	room=GameState.current_interior;config=preload("res://scripts/house_geometry.gd").profile(room)
	show_behind_parent=true
	GameState.clock_changed.connect(queue_redraw)
	GameState.domain_changed.connect(func(domain:String):
		if domain in ["household","world"]:queue_redraw())
func _draw()->void:
	if config.is_empty() or not L.enabled(GameState,room):return
	var night:float=preload("res://scripts/world_art.gd").night_factor(GameState.minutes)
	var wood:=Color("896340").darkened(night*.15);var cloth:=Color(str(config.accent)).lerp(Color("d7c9a6"),.48).darkened(night*.12)
	var paper:=Color("eadcbb").darkened(night*.13)
	# A connected rail, hanging cloth and three hooks sit on the upper wall.
	var left:float=145 if int(config.lifeStyle.variant)%2==0 else 470
	draw_rect(Rect2(left,151,76,7),wood);draw_line(Vector2(left,151),Vector2(left+76,151),wood.lightened(.3),1.4,true)
	for i:int in 3:
		var x:float=left+13+i*24;draw_line(Vector2(x,156),Vector2(x,164),wood.darkened(.35),2,true)
		if i==1:draw_colored_polygon(PackedVector2Array([Vector2(x-9,164),Vector2(x+9,164),Vector2(x+11,188),Vector2(x-8,190)]),cloth)
		else:draw_arc(Vector2(x,170),6,0,TAU,14,Color("b39b67"),2,true)
	# A useful pinboard: folded note, calendar leaf and two small keepsakes.
	var x:float=385 if left<300 else 570
	draw_rect(Rect2(x,141,50,48),wood.darkened(.1));draw_rect(Rect2(x+3,144,44,42),paper)
	for i:int in 4:draw_line(Vector2(x+8,153+i*7),Vector2(x+39-(i%2)*9,153+i*7),wood.lightened(.1),.8,true)
	draw_circle(Vector2(x+24,147),1.6,wood.darkened(.3))
	# Curtains cover only the matching window and never darken the whole room.
	for f:Dictionary in config.get("fixtures",[]):
		if str(f.type)!="curtain" or not L.state(GameState,room,str(f.id)):continue
		var center:float=715 if int(f.get("window",1))==1 else 230
		for side:int in 2:
			var rect:=Rect2(center-35+side*35,117,35,79);draw_rect(rect,cloth)
			for fold:int in 4:draw_line(rect.position+Vector2(4+fold*8,0),rect.position+Vector2(6+fold*8,79),cloth.darkened(.14),1.2,true)
	draw_line(Vector2(398,565),Vector2(434,565),Color(wood,.28),2,true)
	# Small scrapes stay next to frequently used edges, not random walking cells.
	for i:int in 3:draw_line(Vector2(140+i*8,540+i*2),Vector2(145+i*8,541+i*2),Color(wood,.14),1,true)
	var registry:Script=preload("res://scripts/scene_lighting.gd");registry.refresh(GameState)
	for lamp:Dictionary in registry.sources:
		if str(lamp.room)!=room or str(lamp.kind)!="house-lamp":continue
		draw_texture_rect(registry.glow_texture(),Rect2(Vector2(lamp.ground)-Vector2(66,21),Vector2(132,42)),false,Color(1,1,1,.28+.4*night))
static func tabletop(target:CanvasItem,row:Dictionary)->void:
	for item:Dictionary in row.get("domesticTop",[]):
		var entry:Dictionary=preload("res://scripts/world_art.gd").entries().get("interior_props/"+str(item.kind),{})
		if "/fine/" not in str(entry.get("path","")):continue
		var texture:Texture2D=preload("res://scripts/character_art.gd").texture(str(entry.path))
		if texture==null:continue
		var at:=Vector2(float(row.x)+float(item.dx),float(row.y)+float(item.dy));var size:float=float(item.get("size",14))
		# Existing fine art carries transparent padding. Use the cached trim rect.
		var art:Script=preload("res://scripts/interior_art.gd");var path:String=str(entry.path)
		if not art._furniture_regions.has(path):art._furniture_regions[path]=Rect2(texture.get_image().get_used_rect())
		var source:Rect2=art._furniture_regions[path];var extent:Vector2=source.size*minf(size/source.size.x,size/source.size.y)
		var support_kind:String=str(row.get("visualKind",row.kind))
		var support:Dictionary=preload("res://scripts/world_art.gd").entries().get("interior_props/"+support_kind,{})
		var support_path:String=str(support.get("path",""))
		if art._furniture_regions.has(support_path):
			var bounds:Rect2=art._furniture_regions[support_path]
			var actual:Vector2=bounds.size*minf(float(row.w)*1.02/bounds.size.x,float(row.get("visualHeight",72))/bounds.size.y)
			var plane:float=.45 if support_kind=="domestic-sideboard" else .62 if str(row.kind)=="table" else .94
			at.y=float(row.y)+9-actual.y*plane
		target.draw_texture_rect_region(texture,Rect2(at-Vector2(extent.x*.5,extent.y),extent),source,art.lighting(GameState.minutes))
	if bool(row.get("domesticWear",false)):
		var at:=Vector2(float(row.x)-float(row.w)*.3,float(row.y)-3)
		target.draw_line(at,at+Vector2(8,-1),Color(.94,.83,.61,.22),.8,true)
static func fixture_overlay(_target:CanvasItem,_row:Dictionary)->void:
	pass
