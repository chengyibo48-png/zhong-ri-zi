extends Node
## Presentation-only framing. Pausing never advances this or the session.
var actor:Node2D
var state:Node
var engaged:=false
var base_zoom:=Vector2.ONE
var saved_offset:=Vector2.ZERO
func _ready()->void:
	actor=get_parent();state=get_tree().root.get_node("GameState")
func _process(delta:float)->void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.camera):return
	var camera:Camera2D=actor.camera;var active:bool=state.fishing_active()
	if not active and not engaged:return
	if active and not engaged:base_zoom=camera.zoom;saved_offset=camera.offset;engaged=true
	if active and (state.ui_open or state.fishing_focus_paused):return
	var target_zoom:Vector2=base_zoom;var target_offset:Vector2=saved_offset
	var reduced:bool=str(state.visual_fx.get("motion","full"))=="reduced"
	if active and not reduced:
		var landing:Dictionary=state.fishing_session.game.get("landing",{})
		if landing.has("x"):
			var water:=Vector2(float(landing.x),float(landing.y));var span:Vector2=(water-actor.global_position).abs()+Vector2(110,115)
			var available:Vector2=get_viewport().get_visible_rect().size-Vector2(300,150)
			var zoom:float=minf(base_zoom.x*1.12,minf(available.x/span.x,available.y/span.y))
			target_zoom=Vector2.ONE*maxf(.65,zoom)
			target_offset=(water-actor.global_position)*.5+Vector2(120/target_zoom.x,0)
	var weight:float=1.0 if reduced else 1.0-exp(-4.0*minf(delta,.1))
	camera.zoom=camera.zoom.lerp(target_zoom,weight);camera.offset=camera.offset.lerp(target_offset,weight)
	if not active and camera.zoom.distance_to(base_zoom)<.002 and camera.offset.distance_to(saved_offset)<.05:
		camera.zoom=base_zoom;camera.offset=saved_offset;engaged=false
func _exit_tree()->void:
	if engaged and is_instance_valid(actor) and is_instance_valid(actor.camera):actor.camera.zoom=base_zoom;actor.camera.offset=saved_offset
