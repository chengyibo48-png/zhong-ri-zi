extends Node2D
## A short upright bay, sorted at its ground contact instead of one giant line.
var vertical := false
var span := 64.0
func _draw() -> void:
	var path := "res://art/world/ranch/fence-v2/"+("vertical" if vertical else "horizontal")+".png"
	var texture: Texture2D=preload("res://scripts/character_art.gd").texture(path)
	if texture==null:return
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var pixels:=texture.get_image()
	var region:=Rect2(pixels.get_used_rect())
	if not region.has_area():return
	var size:=Vector2(13.0,span+25.0) if vertical else Vector2(span+5.0,25.0)
	var rect:=Rect2(Vector2(-size.x*.5,-size.y+2),size)
	preload("res://scripts/ground_style.gd").shadow(self,Vector2(2,0),size.x,4.0)
	draw_texture_rect_region(texture,rect,region)
