extends Node2D
## Door/hearth pools consume the same registry as actors and furniture.
func _ready()->void:
	z_index=28
	var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
	GameState.clock_changed.connect(queue_redraw)
	GameState.domain_changed.connect(func(domain:String):
		if domain in ["world","settings"]:queue_redraw())
func _draw()->void:
	var registry:Script=preload("res://scripts/scene_lighting.gd");registry.refresh(GameState)
	var night:float=registry.strength(GameState.minutes)
	if night<=.01:return
	var view:=preload("res://scripts/life_presentation.gd").visible_rect(self,130)
	for lamp:Dictionary in registry.sources:
		if lamp.room!="" or lamp.kind not in ["house","hearth"] or not view.has_point(lamp.ground):continue
		var at:Vector2=lamp.ground
		draw_texture_rect(registry.glow_texture(),Rect2(at-Vector2(72,36),Vector2(144,64)),false,Color(1,1,1,night*.34))
		draw_texture_rect(registry.glow_texture(),Rect2(Vector2(lamp.position)-Vector2(13,13),Vector2(26,26)),false,Color(1,1,1,night*.28))
