extends Node2D
const VISUAL := preload("res://scripts/ranch_visual.gd")
var animal_index := 0
var inside_room := ""
var painted_active := false
func _draw() -> void:
	painted_active = false
	if animal_index<0 or animal_index>=GameState.animals.size(): return
	var a: Dictionary = GameState.animals[animal_index]
	painted_active = VISUAL.animal(self,a,Vector2.ZERO,GameState.system_catalog.get("ranch",{}),GameState.ranch_actor_clock,GameState.ranch_actor_poses.get(str(a.id),{}))
	VISUAL.action(self,a,Vector2.ZERO,GameState.ranch_actor_action,inside_room,GameState.ranch_actor_clock,Vector2(float(a.position.x),float(a.position.y)))
	if (animal_index == FarmWorld.hovered_animal if inside_room=="" else str(get_parent().get("selected_room_target").get("id",""))==str(a.id)):
		draw_arc(Vector2.ZERO,24,0,TAU,24,Color("#fff0b2"),2)
		draw_string(ThemeDB.fallback_font,Vector2(-36,17),str(a.name),HORIZONTAL_ALIGNMENT_CENTER,72,11,Color("#fff0d2"))
		draw_string(ThemeDB.fallback_font,Vector2(-46,29),"饱%d 心%d 健%d" % [int(a.hunger),int(a.mood),int(a.health)],HORIZONTAL_ALIGNMENT_CENTER,92,9,Color("#e5d5ad"))
