extends Node2D
## Independent material keeps water and seed colors out of the wardrobe palette mask.
var frame:Dictionary={}
func _draw()->void:
	preload("res://scripts/action_contact.gd").draw_effects(self,frame)
