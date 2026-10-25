extends Node2D
var slot: Dictionary={}
func _ready() -> void:GameState.changed.connect(queue_redraw)
func _draw() -> void:
	if slot.is_empty():return
	var row: Dictionary=GameState.fishing.traps.get(str(slot.id),{})
	var at:=Vector2(float(slot.waterX),float(slot.waterY))-global_position
	if row.is_empty():
		if FarmWorld.hovered_fish==str(slot.id):draw_arc(at,9,0,TAU,24,Color("c7d8b0"),1)
		return
	var texture: Texture2D=preload("res://scripts/item_art.gd").texture_for("fishTrap","items")
	draw_line(Vector2.ZERO,at,Color("b3a17a"),1.0)
	if texture!=null:draw_texture_rect(texture,Rect2(at+Vector2(-15,-15),Vector2(30,27)),false)
	if not row.get("product",{}).is_empty():
		var fish: Texture2D=preload("res://scripts/item_art.gd").texture_for(str(row.product.fish),"items")
		if fish!=null:draw_texture_rect(fish,Rect2(at+Vector2(-10,-34),Vector2(20,17)),false)
	elif int(row.get("baitedDay",-1))>=0:draw_circle(at+Vector2(9,-10),2,Color("d7c77c"))
