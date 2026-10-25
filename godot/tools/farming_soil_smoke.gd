extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	var s := root.get_node("GameState")
	s.set_process(false)
	var plot_script: Script = load("res://scripts/farm_plot.gd")
	var nodes: Array[Node2D] = []
	for i in s.plots.size():
		s.plots[i] = s._new_plot(); s.plots[i].tilled = true
		var n := Node2D.new(); n.set_script(plot_script); n.set("index",i)
		root.add_child(n); nodes.append(n)
	await process_frame
	var original: Array = s.plots.duplicate(true)
	for i in nodes.size():
		var soil: Node2D = nodes[i].get_node("CultivatedSoil")
		soil.call("set_state",s.plots[i])
		check(not soil.is_processing() and soil.z_index == -1,"soil is an idle background layer "+str(i))
		check(soil.find_children("*","CollisionShape2D",true,false).is_empty(),"soil adds no collision "+str(i))
		check(nodes[i].position == Vector2.ZERO,"soil does not reposition parent "+str(i))
	var first: Node = nodes[0].get_node("CultivatedSoil")
	var last: Node = nodes[preload("res://scripts/farm_layout.gd").MAIN_COLUMNS-1].get_node("CultivatedSoil")
	var next_row: Node = nodes[preload("res://scripts/farm_layout.gd").MAIN_COLUMNS].get_node("CultivatedSoil")
	check(first.snapshot.joined == Vector2(0,1) and last.snapshot.joined == Vector2(1,0) and next_row.snapshot.joined == Vector2(0,1),"row ends do not wrap across plot indexes")
	s.plots[1].tilled = false
	first.set_state(s.plots[0])
	check(first.snapshot.joined == Vector2.ZERO,"unworked tile opens the adjoining bed end")
	first.set_state({"tilled":false})
	check(not first.visible,"unworked land exposes original grass")
	first.set_state({"tilled":true,"removed":true})
	check(not first.visible,"removed bed exposes original grass")
	s.plots[0].moisture = 500
	s.plots[0].fertility = -50
	s.plots[0].soil_type = "sand"
	first.set_state(s.plots[0])
	check(first.visible and first.snapshot.moisture == 1.0 and first.snapshot.fertility == 0.0,"render uniforms clamp extremes without altering rules")
	check(s.plots[0].moisture == 500 and s.plots[0].fertility == -50,"renderer never writes back clamped values")
	s.visual_fx.motion = "reduced"
	first.set_state(s.plots[0])
	check(first.snapshot.animate_water == 0,"reduced-motion setting also stops water shimmer")
	var texture := preload("res://art/world/terrain/cultivated_earth.png")
	check(texture.get_width() >= 512 and texture.get_height() >= 512,"actual painted soil texture available")
	for i in range(2,s.plots.size()): check(s.plots[i] == original[i],"render leaves plot fields unchanged "+str(i))
	for n in nodes: n.queue_free()
	await process_frame
	print("Farming soil: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit(); quit(1 if failed else 0)
