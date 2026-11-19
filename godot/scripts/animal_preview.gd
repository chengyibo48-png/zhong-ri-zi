extends Node2D
var animal:Dictionary={}
func _draw()->void:
	if not animal.is_empty():preload("res://scripts/ranch_visual.gd").animal(self,animal,Vector2.ZERO,GameState.system_catalog.ranch,0)
