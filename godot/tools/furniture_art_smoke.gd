extends SceneTree
const ART := preload("res://scripts/built_furniture_art.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL ", label)
func run() -> void:
	await process_frame
	var state: Node = root.get_node("GameState")
	state.set_process(false)
	var saved: Dictionary = state._make_save_data().duplicate(true)
	for id: String in ART.HEIGHTS:
		var hashes: Array = []
		for direction in range(4):
			var tex: Texture2D = ART.texture_for(id, direction)
			check(tex != null and tex.get_width() > 100 and tex.get_height() > 100, id + " actual direction texture")
			var image := tex.get_image()
			check(image.detect_alpha() != Image.ALPHA_NONE, id + " transparent outline")

			if id in ["well","trellis","flowerbed","stoneLantern"]:
				check(maxi(image.get_width(),image.get_height()) <= 512,id + " bounded runtime texture")
				var low := Vector2(image.get_width(),image.get_height()); var high := Vector2.ZERO
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						if image.get_pixel(x,y).a <= 0.06: continue
						low.x = minf(low.x,x); low.y = minf(low.y,y)
						high.x = maxf(high.x,x+1); high.y = maxf(high.y,y+1)
				var center := (low+high)*0.5
				var centered := absf(center.x-image.get_width()*0.5) < image.get_width()*0.04 and absf(center.y-image.get_height()*0.5) < image.get_height()*0.04
				check(centered and (high.x-low.x)/image.get_width() > 0.9 and (high.y-low.y)/image.get_height() > 0.9,id + " real silhouette tightly centered, faint specks cannot shift anchor")
			var digest := hash(image.get_data())
			check(not hashes.has(digest), id + " view is distinct from all previous directions")
			hashes.append(digest)
			var definition: Dictionary = state.system_catalog.building.defs[id]
			var width := float(definition.w if direction % 2 == 0 else definition.h) * 44.0
			var depth := float(definition.h if direction % 2 == 0 else definition.w) * 44.0
			var footprint := Rect2(-width * 0.5,-depth,width,depth)
			var dest := ART.sprite_rect(id,direction,footprint)
			check(absf(dest.size.aspect() - tex.get_size().aspect()) < 0.001, id + " image aspect preserved")
			check(absf(dest.end.y + 4.0) < 0.001 and absf(dest.get_center().x) < 0.001, id + " floor anchored")
			var preview := preload("res://scripts/furniture_preview.gd").new()
			preview.present(id,direction)
			check(preview.view_rotation == direction and preview.focus_mode == Control.FOCUS_NONE and preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, id + " passive preview")
			preview.free()
		check(ART.texture_for(id,4) == ART.texture_for(id,0), id + " direction wraps")
	check(not ART.supports("greenhouse") and ART.texture_for("greenhouse",0) == null,"Unsupported models retain existing art")
	check(is_zero_approx(ART.lamp_strength(720)),"Lamp glow disabled at midday")
	check(ART.lamp_strength(1260) > 0.99 and ART.lamp_strength(0) > 0.99,"Lamp glow enabled at night and midnight")
	check(ART.lamp_strength(1200) > 0.0 and ART.lamp_strength(1200) < 1.0,"Lamp fades smoothly at dusk")
	check(ART.lamp_strength(1200) < ART.lamp_strength(1260),"Dusk brightness follows the existing game clock")
	check(ART.lamp_strength(1260,2) < ART.lamp_strength(1260,0),"Rear vent emits less light than front window")
	for direction in range(4):
		check(Rect2(0,0,100,100).has_point(ART.lamp_window(direction,Rect2(0,0,100,100))),"Each light origin remains inside the corresponding model")
	check(state._make_save_data() == saved,"Art and previews do not consume stock or change saved progress")
	print("FURNITURE_ART: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
