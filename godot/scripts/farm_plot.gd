extends Node2D

var index := 0
var growth_pulse_age := -1.0
var crop_presentation:Dictionary={}
func set_crop_presentation(value:Dictionary)->void:
	var next:Dictionary=value.duplicate()
	next.phase=float(index)*.71
	if next==crop_presentation:return
	crop_presentation=next
	queue_redraw()

func _ready() -> void:
	set_process(false)
	var surface := Node2D.new()
	surface.name = "CultivatedSoil"
	surface.set_script(preload("res://scripts/farm_soil_surface.gd"))
	surface.set("index",index)
	surface.z_index = -1
	add_child(surface)

func notify_growth() -> void:
	if str(GameState.visual_fx.get("motion", "full")) == "reduced" or str(GameState.visual_fx.get("density", "standard")) == "off":
		return
	growth_pulse_age = 0.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	growth_pulse_age += delta
	if growth_pulse_age >= 0.85:
		growth_pulse_age = -1.0
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var data: Dictionary = GameState.plots[index]
	var fertility := int(data.get("fertility", 65))
	var soil := Color("8b7654") if data.tilled else Color("536f48")
	if data.tilled and fertility < 30:
		soil = Color("766a55")
	var painted_soil := preload("res://scripts/farm_surface_art.gd").soil(self, data)
	if not painted_soil:
		draw_rect(Rect2(-15, -11, 30, 22), soil, true)
		draw_rect(Rect2(-15, -11, 30, 22), Color("354a37"), false, 1.0)
	if data.tilled:
		var water_alpha := clampf(float(data.get("moisture", 45)) / 100.0, 0.12, 0.8)
		if not painted_soil:
			draw_rect(Rect2(-13, 7, 26, 2), Color(0.5, 0.72, 0.78, water_alpha), true)
		if int(data.get("pests", 0)) >= 25 or int(data.get("disease", 0)) >= 25:
			draw_circle(Vector2(11, -6), 2.2, Color("d78d54"))
		if int(data.get("weeds", 0)) >= 50:
			draw_line(Vector2(-10, -4), Vector2(-7, -8), Color("a7b875"), 1.5)
	if data.crop != "":
		var crop_data := GameState.crop_data(str(data.crop))
		var progress := float(data.growth) / float(GameState.crop_days(str(data.crop)))
		if int(data.get("harvest_count",0)) > 0 and progress < 1.0: progress = maxf(0.72,progress)
		var main_presentation := crop_presentation.duplicate()
		if not data.get("companion",{}).is_empty(): main_presentation.offset = Vector2(-4,0)
		var growth_scale := 1.0
		if growth_pulse_age >= 0.0:
			var ease_progress := clampf(growth_pulse_age / 0.85, 0.0, 1.0)
			growth_scale = 0.92 + 0.08 * (1.0 - pow(1.0 - ease_progress, 3.0))
		if not preload("res://scripts/farm_surface_art.gd").crop(self, str(data.crop), progress, growth_scale, data, main_presentation):
			var height := (5.0 + progress * 12.0) * growth_scale
			var product_color := Color.from_string(str(crop_data.get("color", "#71935a")), Color("71935a"))
			var leaf := Color("71935a")
			draw_rect(Rect2(-2, 7.0 - height, 4, height), Color("557147"), true)
			draw_circle(Vector2(-5, 5.0 - height), (5.0 + progress * 1.5) * growth_scale, leaf.lightened(0.08))
			draw_circle(Vector2(5, 5.0 - height), (5.0 + progress * 1.5) * growth_scale, leaf)
			if progress >= 0.7:
				draw_circle(Vector2(0, 1.0 - height), 3.5 * growth_scale, product_color)
			if progress >= 1.0:
				draw_circle(Vector2(-5, 3.0 - height), 2.0 * growth_scale, product_color.lightened(0.18))
		if progress>=1.0 and growth_pulse_age>=0.0:
			var alpha:=sin(clampf(growth_pulse_age/.85,0,1)*PI)*.7
			var top:=Vector2(0,-20)
			draw_line(top+Vector2(-2,0),top+Vector2(2,0),Color(1,.88,.53,alpha),1)
			draw_line(top+Vector2(0,-2),top+Vector2(0,2),Color(1,.88,.53,alpha),1)
	var companion: Dictionary = data.get("companion",{})
	if not companion.is_empty():
		var companion_id := str(companion.get("crop",""))
		var companion_presentation := crop_presentation.duplicate()
		companion_presentation.offset = Vector2(9,5)
		companion_presentation.scale = 0.62
		preload("res://scripts/farm_surface_art.gd").crop(self,companion_id,float(companion.get("growth",0))/maxi(1,GameState.crop_days(companion_id)),1.0,data,companion_presentation)
	if str(data.get("crop","")) != "":
		var ripe := float(data.growth) >= GameState.crop_days(str(data.crop))
		var dry := float(data.get("moisture",45)) < float(GameState.crop_profile(str(data.crop)).low)
		if ripe:
			var point := Vector2(14,5)
			draw_colored_polygon(PackedVector2Array([point+Vector2(0,-2.2),point+Vector2(1.7,0),point+Vector2(0,2.2),point+Vector2(-1.7,0)]),Color("f2d68b"))
		elif dry:
			var point := Vector2(14,5)
			draw_circle(point,1.5,Color("91b9bd"))
			draw_colored_polygon(PackedVector2Array([point+Vector2(-1.2,-0.5),point+Vector2(0,-3.5),point+Vector2(1.2,-0.5)]),Color("91b9bd"))
	for facility in GameState.farm.get("facilities", []):
		if int(facility.get("anchor", -1)) == index:
			var kind := str(facility.get("type", ""))
			var glyph: String = {"sprinkler": "水", "greenhouse": "棚", "scarecrow": "稻", "shade": "荫", "fence": "篱", "trellis": "架", "drain": "沟"}.get(kind, "设")
			var tint: Color = Color("b7d6c1") if bool(facility.get("enabled", true)) and float(facility.get("durability", 0.0)) > 0 else Color("877e67")
			draw_circle(Vector2(12, -10), 7, Color("28392e"))
			draw_string(ThemeDB.fallback_font, Vector2(8, -7), glyph, HORIZONTAL_ALIGNMENT_LEFT, 12, 9, tint)
	if index == FarmWorld.hovered_plot:
		var corners := [Vector2(-21,-10),Vector2(21,-10),Vector2(-21,16),Vector2(21,16)]
		for corner: Vector2 in corners:
			var inward := Vector2(1 if corner.x < 0 else -1,1 if corner.y < 0 else -1)
			draw_line(corner,corner+Vector2(inward.x*5,0),Color("f5e7a5"),1.3,true)
			draw_line(corner,corner+Vector2(0,inward.y*4),Color("f5e7a5"),1.3,true)
		if data.tilled:
			draw_string(ThemeDB.fallback_font, Vector2(-20, 25), "肥%d 湿%d" % [fertility, int(data.get("moisture", 45))], HORIZONTAL_ALIGNMENT_LEFT, 64, 9, Color("f7edcf"))
