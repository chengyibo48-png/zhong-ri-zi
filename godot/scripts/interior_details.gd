extends RefCounted
## Decorative pieces share existing anchors, without adding interactable blockers.
static var regions: Dictionary={}
static func draw(target: CanvasItem, kind: String, box: Rect2, night: float=0.0) -> bool:
	var path:="res://art/world/interior_details/v2/"+kind+".png"
	var texture: Texture2D=preload("res://scripts/character_art.gd").texture(path)
	if texture==null:return false
	if not regions.has(path):regions[path]=Rect2(texture.get_image().get_used_rect())
	var source: Rect2=regions[path]
	if not source.has_area():return false
	var factor:=minf(box.size.x/source.size.x,box.size.y/source.size.y)
	var size:=source.size*factor
	var destination:=Rect2(box.position+Vector2((box.size.x-size.x)*.5,box.size.y-size.y),size)
	var tint:=Color.WHITE.lerp(Color(.72,.75,.78),night*.65) if kind!="lantern" else Color.WHITE
	target.draw_texture_rect_region(texture,destination,source,tint)
	return true
