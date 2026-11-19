extends Node2D
func _draw()->void:
	preload("res://scripts/world_art.gd").draw_prop(self,{"kind":"board","x":0,"y":0,"_visual_rect":[-24,-48,48,48]},GameState.season_index(),GameState.minutes)
	draw_string(preload("res://art/fonts/NotoSansCJKsc-Regular.otf"),Vector2(-45,-53),"东坡大牧野",HORIZONTAL_ALIGNMENT_CENTER,90,13,Color("354b36"))
