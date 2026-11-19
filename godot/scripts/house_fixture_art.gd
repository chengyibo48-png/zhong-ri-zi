extends RefCounted
## Whole painted bodies and textured hinge panels; hands and emitters stay independent.
const TEXTURES=preload("res://scripts/character_art.gd")
static var regions:Dictionary={}
static func draw(c:CanvasItem,row:Dictionary,minutes:float)->bool:
	var kind:String=str(row.get("visualKind",row.get("kind","")))
	if kind not in ["domestic-sideboard","domestic-bedside"]:return false
	var fixture:Dictionary={}
	for f:Dictionary in preload("res://scripts/house_geometry.gd").profile(GameState.current_interior).get("fixtures",[]):
		if str(f.get("furniture",""))==str(row.get("id","")):fixture=f;break
	if fixture.is_empty():return false
	var lit:bool=preload("res://scripts/house_life.gd").state(GameState,GameState.current_interior,str(fixture.id))
	var path:String="res://data/village_media/sideboard-interior.png" if kind=="domestic-sideboard" else "res://art/world/domestic/bedside.png" if lit else "res://data/village_media/bedside-off.png"
	var texture:Texture2D=TEXTURES.texture(path)
	if texture==null:return false
	if not regions.has(path):regions[path]=Rect2(texture.get_image().get_used_rect())
	var region:Rect2=regions[path]
	var canonical:String="res://art/world/domestic/sideboard.png" if kind=="domestic-sideboard" else "res://art/world/domestic/bedside.png"
	if not regions.has(canonical):regions[canonical]=Rect2(TEXTURES.texture(canonical).get_image().get_used_rect())
	var reference:Rect2=regions[canonical];var size:Vector2=reference.size*minf(float(row.w)*1.02/reference.size.x,float(row.visualHeight)/reference.size.y)
	var bottom:=Vector2(float(row.x),float(row.y)+9);var rect:=Rect2(bottom-Vector2(size.x*.5,size.y),size)
	var tint:Color=load("res://scripts/interior_art.gd").lighting(minutes)
	preload("res://scripts/ground_style.gd").shadow(c,bottom,size.x*.82,minf(5,size.x*.055))
	c.draw_texture_rect_region(texture,rect,region,tint)
	if kind=="domestic-sideboard":
		var original:Texture2D=TEXTURES.texture("res://art/world/domestic/sideboard.png")
		if original!=null:
			var opening:float=clampf(float(c.get_meta("life_open",1.0 if lit else 0.0)),0,1)
			_door(c,original,rect,[Vector2(100,139),Vector2(209,143),Vector2(210,248),Vector2(100,237)],opening,false,tint)
			_door(c,original,rect,[Vector2(214,143),Vector2(331,144),Vector2(331,252),Vector2(214,248)],opening,true,tint)
	return true
static func _door(c:CanvasItem,image:Texture2D,rect:Rect2,source:Array,opening:float,right:bool,tint:Color)->void:
	var points:=PackedVector2Array();var uv:=PackedVector2Array();var angle:float=opening*1.72
	var hinge:float=331.0 if right else 100.0
	for q:Vector2 in source:
		var dx:float=q.x-hinge
		var x:float=hinge+dx*cos(angle)
		var y:float=q.y+absf(dx)*sin(angle)*.13
		points.append(rect.position+Vector2((x-65)/337.0,(y-17)/275.0)*rect.size)
		uv.append(q/image.get_size())
	c.draw_polygon(points,PackedColorArray([tint]),uv,image)
