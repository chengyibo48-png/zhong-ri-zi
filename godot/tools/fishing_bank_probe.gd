extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var s: Node=root.get_node("GameState");s.set_process(false);s.current_interior="";s.player_position=Vector2(2690,2000)
	var nav: RefCounted=s.npc_movement.navigation;nav.refresh(s)
	for at: Vector2 in [Vector2(3560,1940),Vector2(3560,1920),Vector2(3560,2185),Vector2(1664,750),Vector2(1664,760),Vector2(1664,930)]:
		var target: Dictionary={"id":null,"kind":"walk","name":"probe","x":at.x,"y":at.y}
		var route: Dictionary=s.atlas_preview(target)
		print(at," blocked=",nav.blocked(s,"",at.x,at.y)," reachable=",route.get("reachable",false))
	await root.get_node("AudioService").prepare_exit();quit()
