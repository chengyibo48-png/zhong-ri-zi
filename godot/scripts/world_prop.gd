extends Node2D
class_name WorldProp

## Procedural pixel-style renderer for the legacy village prop catalogue.
## Props are data-driven so the same scene can render both the village map
## and the smaller scenic objects stored in world.json/tiles.

const RAPID_BUILDING_ART := preload("res://scripts/rapid_building_art.gd")
var data: Dictionary = {}
var painted_active := false
var _painted_night_factor := -1.0
var _season: int = 0
var _palette: Dictionary = {}
var _tree_animation_elapsed := 0.0
var _foliage_clock := 0.0
var _visibility_elapsed := 1.0
var _on_screen := false
var _occlusion_rect := Rect2()
var _foliage_material: ShaderMaterial


const PALETTES: Array[Dictionary] = [
	{"grass": "#88a960", "light": "#a8bd76", "dark": "#77994e", "leaf": "#568348", "tip": "#9eba69", "deep": "#345e3b", "earth": "#c8b488", "wood": "#8a6243", "roof": "#9b5847"},
	{"grass": "#7fa159", "light": "#9eb870", "dark": "#6c904c", "leaf": "#3f784b", "tip": "#82ab5a", "deep": "#28503d", "earth": "#cbb68a", "wood": "#80583c", "roof": "#a35240"},
	{"grass": "#a5a161", "light": "#bdb378", "dark": "#8f914f", "leaf": "#9a8847", "tip": "#d0af63", "deep": "#646b39", "earth": "#c4aa7f", "wood": "#79593d", "roof": "#98533f"},
	{"grass": "#a4b6a0", "light": "#c3cdb5", "dark": "#8b9e8b", "leaf": "#698673", "tip": "#a1b69b", "deep": "#476653", "earth": "#c4c1a7", "wood": "#786451", "roof": "#687a79"}
]

func _ready() -> void:
	var kind := String(data.get("kind", data.get("type", "")))
	set_process(kind in ["tree", "willow", "orchard", "blossom"] and bool(preload("res://scripts/world_art.gd").entries().get("props/" + kind, {}).get("baseReady", false)))
	var tree_row: Dictionary = preload("res://scripts/world_art.gd").entries().get("props/" + kind, {})
	var bounds: Array = tree_row.get("worldRect", [])
	if is_processing() and bounds.size() == 4:
		_occlusion_rect = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_foliage_material = ShaderMaterial.new()
		_foliage_material.shader = preload("res://art/shaders/foliage_wind.gdshader")
		_foliage_material.set_shader_parameter("height", maxf(1.0, _occlusion_rect.size.y))
		_foliage_material.set_shader_parameter("phase", float(abs(hash(str(position))) % 997) * 0.017)
		_foliage_material.set_shader_parameter("softness", 1.6 if kind == "willow" else 1.0)
		material = _foliage_material
	_refresh_palette()
	var art_row: Dictionary = preload("res://scripts/world_art.gd").entries().get(preload("res://scripts/world_art.gd").key_for(data), {})
	if bool(art_row.get("rapidSeasonMaterial", false)) or not art_row.get("states", {}).is_empty():
		GameState.world_changed.connect(_refresh_rapid_art)
		GameState.clock_changed.connect(_refresh_rapid_art)
	queue_redraw()


## Keep the player legible behind painted foliage without touching solid geometry.
var _occlusion_player: Node2D
var _occlusion_tween: Tween
var _occlusion_goal := 1.0

func _process(delta: float) -> void:
	var presentation := preload("res://scripts/life_presentation.gd")
	_visibility_elapsed += delta
	if _visibility_elapsed >= 0.2:
		_visibility_elapsed = fmod(_visibility_elapsed, 0.2)
		_on_screen = presentation.visible_rect(self, 96.0).has_point(global_position)
	if not _on_screen:
		return
	if presentation.animate():
		_foliage_clock += minf(delta, 0.1)
	_tree_animation_elapsed += delta
	if _tree_animation_elapsed < 1.0 / 24.0:
		return
	_tree_animation_elapsed = fmod(_tree_animation_elapsed, 1.0 / 24.0)
	if _foliage_material != null:
		var strength := clampf(float(GameState.weather_profile().get("wind", 4)) / 5.0, 0.6, 5.0) if presentation.animate() else 0.0
		_foliage_material.set_shader_parameter("wind", strength)
		_foliage_material.set_shader_parameter("clock", _foliage_clock)
	if not is_instance_valid(_occlusion_player):
		_occlusion_player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_occlusion_player) or not _occlusion_rect.has_area():
		_set_occlusion_alpha(1.0)
		return
	var feet := _occlusion_player.global_position
	var overlaps := false
	if feet.distance_squared_to(global_position) < 160.0 * 160.0:
		var bounds := Rect2(global_position + _occlusion_rect.position, _occlusion_rect.size)
		var actor_area := Rect2(feet + Vector2(-10.0, -42.0), Vector2(20.0, 42.0))
		overlaps = global_position.y > feet.y and bounds.intersects(actor_area)
	_set_occlusion_alpha(0.42 if overlaps else 1.0)

func _set_occlusion_alpha(next_alpha: float) -> void:
	if is_equal_approx(_occlusion_goal, next_alpha):
		return
	_occlusion_goal = next_alpha
	if _occlusion_tween != null:
		_occlusion_tween.kill()
	_occlusion_tween = create_tween()
	_occlusion_tween.tween_property(self, "modulate:a", next_alpha, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func refresh_season() -> void:
	_refresh_palette()
	queue_redraw()

func _refresh_palette() -> void:
	_season = GameState.season_index()
	_palette = PALETTES[_season]
	_refresh_rapid_art()

func _refresh_rapid_art() -> void:
	RAPID_BUILDING_ART.configure(self, data, GameState.season_index(), GameState.minutes)
	var next_night_factor: float = preload("res://scripts/world_art.gd").night_factor(GameState.minutes)
	if not is_equal_approx(next_night_factor, _painted_night_factor):
		_painted_night_factor = next_night_factor
		queue_redraw()

func _draw() -> void:
	painted_active = false
	if data.is_empty():
		return
	if _palette.is_empty():
		_refresh_palette()
	if preload("res://scripts/world_art.gd").draw_prop(self, data, _season, GameState.minutes):
		painted_active = true
		return
	var kind := String(data.get("kind", data.get("type", "prop")))
	var size := Vector2(float(data.get("w", 48)), float(data.get("h", 56)))
	if size.x <= 0.0:
		size.x = 48.0
	if size.y <= 0.0:
		size.y = 56.0
	match kind:
		"house", "brick", "home", "kitchen", "shop", "clinic", "school", "hall", "store", "shed":
			_draw_house(size)
		"tree", "orchard", "willow", "blossom":
			_draw_tree(kind, size)
		"bamboo":
			_draw_bamboo(size)
		"bench":
			_draw_bench(size)
		"stone", "stones":
			_draw_stones(size)
		"board", "mailbox", "weather", "scale":
			_draw_sign(kind, size)
		"drying", "grainMat", "hayrack", "seedTray":
			_draw_drying(kind, size)
		"basket", "bambooBundle", "netCoil":
			_draw_basket(kind, size)
		"shrub", "flowers", "plants":
			_draw_plants(kind, size)
		"pot", "jar", "jars":
			_draw_jar(size, kind == "pot")
		"laundry":
			_draw_laundry(size)
		"rack", "teaRack", "loom":
			_draw_rack(kind, size)
		"table", "teaCrate":
			_draw_table(kind, size)
		"bike":
			_draw_bike(size)
		"pavilion":
			_draw_pavilion(size)
		"gate", "fence", "wall":
			_draw_fence(kind, size)
		"boat":
			_draw_boat(size)
		"well", "washstone":
			_draw_well(kind, size)
		"mill":
			_draw_mill(size)
		"haystack", "haybale", "woodpile", "cart", "scarecrow", "lamp":
			_draw_misc(kind, size)
		_:
			_draw_misc(kind, size)

func _c(key: String, fallback: String = "#ffffff") -> Color:
	return Color(String(_palette.get(key, fallback)))

func _shadow(rect: Rect2, alpha: float = 0.20) -> void:
	_draw_oval(rect, Color(0.16, 0.19, 0.13, alpha))

func _draw_oval(rect: Rect2, color: Color) -> void:
	var center := rect.position + rect.size * 0.5
	var points := PackedVector2Array()
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		points.append(center + Vector2(cos(angle) * rect.size.x * 0.5, sin(angle) * rect.size.y * 0.5))
	draw_colored_polygon(points, color)

func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(round(x), round(y), round(w), round(h)), color)

func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(a.round(), b.round(), color, width, false)

func _draw_house(size: Vector2) -> void:
	var w := clampf(size.x, 34.0, 150.0)
	var h := clampf(size.y, 34.0, 116.0)
	var x := -w * 0.5
	var y := -h
	_shadow(Rect2(x + 4, -8, w - 8, 12), 0.24)
	var wall := Color("#e7d4a7")
	var wall_shadow := Color("#c7ac7c")
	var roof := Color(String(data.get("roof_color", _palette.get("roof", "#98533f"))))
	var trim := Color("#503d34")
	# Eaves, roof plane and layered tile rows.
	_poly([Vector2(x - 5, y + h * 0.34), Vector2(0, y + 2), Vector2(w + 5, y + h * 0.34), Vector2(w - 2, y + h * 0.44), Vector2(2, y + h * 0.44)], roof)
	_line(Vector2(x - 3, y + h * 0.36), Vector2(w + 3, y + h * 0.36), Color("#d28b65"), 2)
	for row in range(3):
		var yy := y + h * (0.20 + float(row) * 0.065)
		_line(Vector2(x + 5 + row, yy), Vector2(w - 5 - row, yy), Color(0.23, 0.17, 0.15, 0.45), 1)
	_rect(x + 2, y + h * 0.40, w - 4, h * 0.58, wall)
	_rect(x + 2, y + h * 0.40, w - 4, 3, Color("#f3e3bd"))
	_rect(x + 2, y + h * 0.91, w - 4, h * 0.07, wall_shadow)
	# Timber framing and two readable windows.
	_rect(x + 2, y + h * 0.40, 3, h * 0.58, trim)
	_rect(w - 5, y + h * 0.40, 3, h * 0.58, trim)
	_rect(0, y + h * 0.40, 2, h * 0.58, Color("#896749"))
	var win_y := y + h * 0.54
	for wx in [x + w * 0.17, x + w * 0.64]:
		_rect(wx, win_y, w * 0.19, h * 0.22, trim)
		_rect(wx + 2, win_y + 2, w * 0.19 - 4, h * 0.22 - 4, Color("#9cc8c2"))
		_rect(wx + w * 0.095 - 1, win_y + 2, 2, h * 0.22 - 4, Color("#f0dfb5"))
		_rect(wx + 2, win_y + h * 0.11, w * 0.19 - 4, 2, Color("#f0dfb5"))
	# Door and threshold.
	var door_x := -w * 0.07
	_rect(door_x, y + h * 0.67, w * 0.20, h * 0.31, Color("#714c36"))
	_rect(door_x + 3, y + h * 0.69, w * 0.20 - 6, h * 0.29, Color("#a4764d"))
	draw_circle(Vector2(door_x + w * 0.15, y + h * 0.83), 1.5, Color("#e5c46d"))
	_rect(door_x - 3, y + h * 0.97, w * 0.27, 3, Color("#665044"))
	# Signboards distinguish civic and commercial buildings.
	var label := String(data.get("name", data.get("style", "")))
	if label.contains("店") or label.contains("铺") or label.contains("屋") or label.contains("站"):
		_rect(w * 0.24, y + h * 0.43, w * 0.52, 6, Color("#e8cb83"))
		_line(Vector2(w * 0.26, y + h * 0.44), Vector2(w * 0.74, y + h * 0.44), Color("#744b34"), 1)

func _draw_tree(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 24.0, 94.0)
	var h := clampf(size.y, 36.0, 110.0)
	_shadow(Rect2(-w * 0.42, -9, w * 0.84, 12))
	var trunk_w := maxf(5.0, w * 0.15)
	_rect(-trunk_w * 0.5, -h * 0.50, trunk_w, h * 0.50, Color("#76543a"))
	_rect(-trunk_w * 0.18, -h * 0.49, maxf(2, trunk_w * 0.25), h * 0.45, Color("#a17a4b"))
	_line(Vector2(0, -h * 0.40), Vector2(-w * 0.25, -h * 0.74), Color("#76543a"), maxf(2, trunk_w * 0.35))
	_line(Vector2(0, -h * 0.37), Vector2(w * 0.25, -h * 0.68), Color("#76543a"), maxf(2, trunk_w * 0.35))
	var leaf := _c("leaf")
	var deep := _c("deep")
	var light := _c("tip")
	var crown_y := -h * 0.62
	for i in range(7):
		var angle := TAU * float(i) / 7.0
		var center := Vector2(cos(angle) * w * 0.24, crown_y + sin(angle) * h * 0.14)
		draw_circle(center + Vector2(2, 2), w * 0.22, deep)
		draw_circle(center, w * 0.22, leaf)
		draw_circle(center + Vector2(-w * 0.05, -h * 0.035), w * 0.10, light)
	if kind == "orchard":
		for fruit_pos in [Vector2(-w * 0.25, crown_y), Vector2(w * 0.18, crown_y - h * 0.06), Vector2(w * 0.02, crown_y + h * 0.13)]:
			draw_circle(fruit_pos, 3.0, Color("#d75c43"))
	if kind == "blossom":
		for flower_pos in [Vector2(-w * 0.22, crown_y), Vector2(w * 0.19, crown_y - h * 0.04), Vector2(0, crown_y + h * 0.12)]:
			draw_circle(flower_pos, 3.0, Color("#ffe0e1"))
	if _season == 3:
		for snow_pos in [Vector2(-w * 0.24, crown_y - 4), Vector2(w * 0.18, crown_y - 8), Vector2(0, crown_y + h * 0.05)]:
			draw_circle(snow_pos, 4.0, Color("#e6eee5"))
	if kind == "willow":
		for side in [-1.0, 1.0]:
			for strand in range(3):
				var sx: float = side * w * (0.19 + float(strand) * 0.08)
				_line(Vector2(sx, crown_y + 4), Vector2(sx + side * 3, crown_y + h * 0.30), leaf, 2)

func _draw_bamboo(size: Vector2) -> void:
	var w := clampf(size.x, 28.0, 96.0)
	var h := clampf(size.y, 42.0, 116.0)
	_shadow(Rect2(-w * 0.43, -8, w * 0.86, 10))
	for stalk in range(5):
		var x := -w * 0.38 + float(stalk) * w * 0.19
		var top := -h * (0.62 + float((stalk * 7) % 4) * 0.08)
		_rect(x, top, 5, -top - 3, Color("#66884c"))
		_rect(x + 1, top + 3, 2, -top - 8, Color("#a2b65d"))
		for node_y in range(1, 5):
			var yy := top + float(node_y) * ((-top) / 5.0)
			_rect(x - 1, yy, 7, 2, Color("#c2bb70"))
		for side in [-1.0, 1.0]:
			var leaf_y := top + h * (0.24 + float(stalk % 3) * 0.04)
			_line(Vector2(x + 2, leaf_y), Vector2(x + side * 13, leaf_y - 7), _c("leaf"), 2)
			_line(Vector2(x + 2, leaf_y + 4), Vector2(x + side * 11, leaf_y + 9), _c("tip"), 2)

func _draw_bench(size: Vector2) -> void:
	var w := clampf(size.x, 24.0, 68.0)
	_shadow(Rect2(-w * 0.48, -5, w * 0.96, 9))
	_rect(-w * 0.45, -18, w * 0.9, 6, Color("#81583b"))
	_rect(-w * 0.45, -12, w * 0.9, 5, Color("#a77549"))
	_rect(-w * 0.36, -7, 4, 7, Color("#634834"))
	_rect(w * 0.30, -7, 4, 7, Color("#634834"))
	_rect(-w * 0.42, -28, w * 0.84, 5, Color("#8a6040"))
	_rect(-w * 0.42, -23, 4, 11, Color("#604633"))
	_rect(w * 0.38, -23, 4, 11, Color("#604633"))

func _draw_stones(size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("seed", int(position.x * 7 + position.y * 11)))
	var count := 3 + int(size.x / 18.0)
	for i in range(count):
		var x := rng.randf_range(-size.x * 0.42, size.x * 0.42)
		var y := rng.randf_range(-13.0, -4.0)
		var r := rng.randf_range(3.0, 7.0)
		draw_circle(Vector2(x + 1, y + 2), r, Color("#655f54"))
		draw_circle(Vector2(x, y), r, Color("#aaa394"))
		draw_circle(Vector2(x - 1, y - 1), r * 0.42, Color("#d0c8b5"))

func _draw_sign(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 22.0, 46.0)
	var h := clampf(size.y, 28.0, 60.0)
	_shadow(Rect2(-w * 0.43, -5, w * 0.86, 8))
	if kind == "mailbox":
		_rect(-2, -h * 0.6, 4, h * 0.6, Color("#79563a"))
		_rect(-w * 0.38, -h * 0.72, w * 0.76, h * 0.27, Color("#c55445"))
		_rect(-w * 0.31, -h * 0.68, w * 0.62, h * 0.15, Color("#e5bd76"))
		_rect(w * 0.2, -h * 0.82, 3, 10, Color("#e3d3a5"))
	else:
		_rect(-3, -h * 0.65, 6, h * 0.65, Color("#785539"))
		_rect(-w * 0.48, -h * 0.88, w * 0.96, h * 0.37, Color("#80573b"))
		_rect(-w * 0.42, -h * 0.83, w * 0.84, h * 0.26, Color("#e0c780"))
		_line(Vector2(-w * 0.34, -h * 0.76), Vector2(w * 0.30, -h * 0.76), Color("#795441"), 1)
		_line(Vector2(-w * 0.30, -h * 0.67), Vector2(w * 0.20, -h * 0.67), Color("#795441"), 1)

func _draw_drying(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 30.0, 76.0)
	var h := clampf(size.y, 22.0, 54.0)
	_shadow(Rect2(-w * 0.48, -4, w * 0.96, 8))
	if kind == "grainMat" or kind == "seedTray":
		_rect(-w * 0.46, -h * 0.34, w * 0.92, h * 0.34, Color("#8b6340"))
		_rect(-w * 0.42, -h * 0.31, w * 0.84, h * 0.22, Color("#d7b66e"))
		for i in range(9):
			var xx := -w * 0.38 + float(i) * w * 0.095
			_line(Vector2(xx, -h * 0.28), Vector2(xx + 4, -h * 0.12), Color("#f0d38a"), 1)
	else:
		for x in [-w * 0.42, w * 0.38]:
			_rect(x, -h, 3, h, Color("#765236"))
		_rect(-w * 0.45, -h, w * 0.9, 3, Color("#8d6542"))
		for i in range(5):
			var xx := -w * 0.38 + float(i) * w * 0.18
			_line(Vector2(xx, -h + 3), Vector2(xx + 3, -h * 0.20), Color("#b87846"), 4)
			_line(Vector2(xx + 1, -h * 0.55), Vector2(xx + 5, -h * 0.52), Color("#ddbd73"), 1)

func _draw_basket(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 22.0, 48.0)
	var h := clampf(size.y, 18.0, 40.0)
	_shadow(Rect2(-w * 0.48, -4, w * 0.96, 7))
	if kind == "netCoil":
		for ring in range(4):
			draw_arc(Vector2(0, -6 - ring * 2), w * (0.32 - ring * 0.035), 0, TAU, 18, Color("#b9a274"), 2)
		return
	if kind == "bambooBundle":
		for i in range(6):
			var yy := -h * 0.20 - float(i % 3) * 3
			_line(Vector2(-w * 0.4, yy), Vector2(w * 0.4, yy - 4), Color("#879653"), 4)
		_rect(-3, -h * 0.22, 6, 4, Color("#b59454"))
		return
	_poly([Vector2(-w * 0.42, -h * 0.62), Vector2(w * 0.42, -h * 0.62), Vector2(w * 0.30, -4), Vector2(-w * 0.30, -4)], Color("#a97743"))
	_line(Vector2(-w * 0.40, -h * 0.62), Vector2(w * 0.40, -h * 0.62), Color("#e0bd75"), 3)
	for i in range(5):
		var xx := -w * 0.31 + float(i) * w * 0.155
		_line(Vector2(xx, -h * 0.57), Vector2(xx * 0.78, -6), Color("#d0a560"), 1)
	if kind == "basket":
		_line(Vector2(-w * 0.30, -h * 0.62), Vector2(-w * 0.18, -h * 0.96), Color("#805a37"), 2)
		_line(Vector2(w * 0.30, -h * 0.62), Vector2(w * 0.18, -h * 0.96), Color("#805a37"), 2)
		_line(Vector2(-w * 0.18, -h * 0.96), Vector2(w * 0.18, -h * 0.96), Color("#805a37"), 2)

func _draw_plants(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 18.0, 56.0)
	var h := clampf(size.y, 18.0, 55.0)
	_shadow(Rect2(-w * 0.46, -3, w * 0.92, 7))
	if kind == "flowers":
		for i in range(7):
			var x := -w * 0.40 + float(i) * w * 0.13
			var stem_h := h * (0.45 + float((i * 3) % 4) * 0.10)
			_line(Vector2(x, -2), Vector2(x, -stem_h), _c("leaf"), 2)
			var petal: Color = [Color("#e8c56c"), Color("#e88d9d"), Color("#f0e5ce"), Color("#d692ba")][i % 4]
			for p in range(5):
				var a := TAU * float(p) / 5.0
				draw_circle(Vector2(x + cos(a) * 3, -stem_h + sin(a) * 3), 2.3, petal)
			draw_circle(Vector2(x, -stem_h), 1.4, Color("#eabf59"))
	else:
		var leaf := _c("leaf") if kind == "shrub" else _c("tip")
		for i in range(9):
			var x := -w * 0.40 + float(i) * w * 0.10
			var y := -h * (0.28 + float((i * 5) % 4) * 0.10)
			draw_circle(Vector2(x, y), w * 0.12, leaf if i % 2 == 0 else _c("deep"))
		if kind == "shrub":
			for i in range(3):
				draw_circle(Vector2(-w * 0.2 + i * w * 0.18, -h * 0.4), 2.4, Color("#bf4f43"))

func _draw_jar(size: Vector2, is_pot: bool) -> void:
	var w := clampf(size.x, 16.0, 36.0)
	var h := clampf(size.y, 18.0, 42.0)
	_shadow(Rect2(-w * 0.48, -3, w * 0.96, 7))
	var body := Color("#b65f48") if is_pot else Color("#9d6849")
	_poly([Vector2(-w * 0.26, -h * 0.85), Vector2(w * 0.26, -h * 0.85), Vector2(w * 0.45, -h * 0.56), Vector2(w * 0.37, -5), Vector2(-w * 0.37, -5), Vector2(-w * 0.45, -h * 0.56)], body)
	_rect(-w * 0.27, -h * 0.92, w * 0.54, 4, Color("#6f493b"))
	_rect(-w * 0.36, -h * 0.44, w * 0.72, 3, Color("#d09165"))
	_rect(-w * 0.12, -h * 0.68, 3, h * 0.38, Color(1, 0.85, 0.66, 0.34))
	if not is_pot:
		_rect(-w * 0.24, -h * 0.12, w * 0.48, 3, Color("#e2c27e"))

func _draw_laundry(size: Vector2) -> void:
	var w := clampf(size.x, 32.0, 76.0)
	var h := clampf(size.y, 32.0, 66.0)
	_shadow(Rect2(-w * 0.47, -4, w * 0.94, 7))
	_rect(-2, -h, 4, h, Color("#79563b"))
	_rect(-w * 0.45, -h, w * 0.9, 2, Color("#6b5540"))
	for i in range(4):
		var x := -w * 0.36 + i * w * 0.23
		var cloth: Color = [Color("#e9ddc2"), Color("#b8d0c4"), Color("#cf8379"), Color("#e0c06e")][i]
		_rect(x, -h + 2, w * 0.18, h * (0.34 + float(i % 2) * 0.12), cloth)
		_line(Vector2(x + 2, -h + 4), Vector2(x + 2, -h * 0.62), Color(1, 1, 1, 0.28), 1)

func _draw_rack(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 30.0, 76.0)
	var h := clampf(size.y, 30.0, 72.0)
	_shadow(Rect2(-w * 0.45, -4, w * 0.9, 7))
	for x in [-w * 0.4, w * 0.36]:
		_rect(x, -h, 4, h, Color("#795538"))
	for row in range(3):
		var y := -h + row * h * 0.32
		_rect(-w * 0.43, y, w * 0.86, 4, Color("#9e7048"))
		if kind == "loom":
			for thread in range(8):
				var xx := -w * 0.36 + thread * w * 0.10
				_line(Vector2(xx, y + 4), Vector2(xx, y + h * 0.29), Color("#ddc486"), 1)
		else:
			for item in range(3):
				var xx := -w * 0.30 + item * w * 0.27
				_rect(xx, y - 9, w * 0.18, 9, Color("#b27a50") if item % 2 == 0 else Color("#879252"))
	if kind == "teaRack":
		_rect(-w * 0.28, -h * 0.72, w * 0.56, 10, Color("#70824e"))
		for i in range(5):
			draw_circle(Vector2(-w * 0.20 + i * w * 0.10, -h * 0.66), 2, Color("#a4b765"))

func _draw_table(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 28.0, 70.0)
	var h := clampf(size.y, 24.0, 56.0)
	_shadow(Rect2(-w * 0.48, -4, w * 0.96, 8))
	_rect(-w * 0.46, -h * 0.52, w * 0.92, 6, Color("#a87549"))
	_rect(-w * 0.36, -h * 0.42, 4, h * 0.40, Color("#694a34"))
	_rect(w * 0.31, -h * 0.42, 4, h * 0.40, Color("#694a34"))
	_line(Vector2(-w * 0.38, -h * 0.49), Vector2(w * 0.38, -h * 0.49), Color("#d3a86a"), 1)
	if kind == "teaCrate":
		for i in range(3):
			_rect(-w * 0.32 + i * w * 0.22, -h * 0.78, w * 0.18, h * 0.24, Color("#899653"))
			_rect(-w * 0.30 + i * w * 0.22, -h * 0.74, w * 0.14, 2, Color("#c9bd73"))
	else:
		_rect(-w * 0.14, -h * 0.72, w * 0.28, h * 0.18, Color("#e4d4ad"))
		_rect(-w * 0.05, -h * 0.82, w * 0.10, h * 0.11, Color("#b45f48"))

func _draw_bike(size: Vector2) -> void:
	var w := clampf(size.x, 32.0, 56.0)
	_shadow(Rect2(-w * 0.48, -4, w * 0.96, 7))
	draw_arc(Vector2(-w * 0.30, -10), 8, 0, TAU, 20, Color("#514d45"), 2)
	draw_arc(Vector2(w * 0.30, -10), 8, 0, TAU, 20, Color("#514d45"), 2)
	var metal := Color("#648b83")
	_line(Vector2(-w * 0.30, -10), Vector2(-2, -19), metal, 2)
	_line(Vector2(-2, -19), Vector2(w * 0.30, -10), metal, 2)
	_line(Vector2(w * 0.30, -10), Vector2(-w * 0.10, -10), metal, 2)
	_line(Vector2(-w * 0.10, -10), Vector2(-w * 0.30, -10), metal, 2)
	_line(Vector2(-2, -19), Vector2(-w * 0.08, -24), metal, 2)
	_line(Vector2(w * 0.22, -22), Vector2(w * 0.36, -22), metal, 2)
	_rect(-w * 0.18, -26, 10, 2, Color("#755840"))

func _draw_pavilion(size: Vector2) -> void:
	var w := clampf(size.x, 48.0, 104.0)
	var h := clampf(size.y, 46.0, 100.0)
	_shadow(Rect2(-w * 0.48, -5, w * 0.96, 10), 0.25)
	for x in [-w * 0.38, -w * 0.13, w * 0.13, w * 0.38]:
		_rect(x, -h * 0.72, 4, h * 0.72, Color("#79543a"))
	_poly([Vector2(-w * 0.54, -h * 0.68), Vector2(0, -h), Vector2(w * 0.54, -h * 0.68), Vector2(w * 0.44, -h * 0.58), Vector2(-w * 0.44, -h * 0.58)], _c("roof"))
	_line(Vector2(-w * 0.52, -h * 0.66), Vector2(w * 0.52, -h * 0.66), Color("#ddb378"), 2)
	_rect(-w * 0.43, -h * 0.16, w * 0.86, 5, Color("#8a6242"))

func _draw_fence(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 28.0, 88.0)
	var h := clampf(size.y, 16.0, 48.0)
	_shadow(Rect2(-w * 0.48, -3, w * 0.96, 6))
	if kind == "gate":
		for x in [-w * 0.42, w * 0.32]:
			_rect(x, -h, 6, h, Color("#694c35"))
		_rect(-w * 0.40, -h * 0.74, w * 0.76, 5, Color("#9a7046"))
		_rect(-w * 0.40, -h * 0.32, w * 0.76, 5, Color("#9a7046"))
		_line(Vector2(-w * 0.35, -h * 0.70), Vector2(w * 0.28, -h * 0.34), Color("#775538"), 3)
	else:
		var rail := Color("#9a7046") if kind != "wall" else Color("#837c68")
		_rect(-w * 0.48, -h * 0.70, w * 0.96, 5, rail)
		_rect(-w * 0.48, -h * 0.28, w * 0.96, 5, rail)
		for i in range(5):
			var x := -w * 0.44 + i * w * 0.22
			_rect(x, -h, 4, h, Color("#77553a") if kind != "wall" else Color("#96907b"))

func _draw_boat(size: Vector2) -> void:
	var w := clampf(size.x, 38.0, 88.0)
	var h := clampf(size.y, 22.0, 54.0)
	_shadow(Rect2(-w * 0.48, -7, w * 0.96, 10), 0.25)
	_poly([Vector2(-w * 0.48, -h * 0.36), Vector2(w * 0.48, -h * 0.36), Vector2(w * 0.30, -4), Vector2(-w * 0.34, -4)], Color("#79573d"))
	_rect(-w * 0.40, -h * 0.44, w * 0.78, 3, Color("#bd9161"))
	_line(Vector2(0, -h * 0.4), Vector2(0, -h), Color("#765238"), 2)
	_poly([Vector2(2, -h * 0.92), Vector2(w * 0.27, -h * 0.48), Vector2(2, -h * 0.48)], Color("#e8dfc4"))

func _draw_well(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 28.0, 58.0)
	var h := clampf(size.y, 30.0, 66.0)
	_shadow(Rect2(-w * 0.47, -5, w * 0.94, 9))
	if kind == "washstone":
		_rect(-w * 0.43, -h * 0.36, w * 0.86, h * 0.30, Color("#8f8d7b"))
		_rect(-w * 0.36, -h * 0.42, w * 0.72, 5, Color("#c0bda9"))
		_rect(-w * 0.30, -h * 0.30, w * 0.60, 3, Color("#789c9a"))
		return
	_rect(-w * 0.38, -h * 0.46, w * 0.76, h * 0.42, Color("#888270"))
	_rect(-w * 0.43, -h * 0.50, w * 0.86, 6, Color("#bbb49c"))
	_rect(-w * 0.33, -h * 0.38, w * 0.66, 3, Color("#60929a"))
	_rect(-w * 0.32, -h * 0.62, 4, h * 0.24, Color("#76543b"))
	_rect(w * 0.28, -h * 0.62, 4, h * 0.24, Color("#76543b"))
	_rect(-w * 0.36, -h * 0.68, w * 0.72, 4, Color("#76543b"))

func _draw_mill(size: Vector2) -> void:
	var w := clampf(size.x, 42.0, 78.0)
	var h := clampf(size.y, 44.0, 84.0)
	_shadow(Rect2(-w * 0.45, -4, w * 0.90, 8))
	_rect(-w * 0.28, -h * 0.58, w * 0.56, h * 0.55, Color("#ad8a59"))
	_poly([Vector2(-w * 0.36, -h * 0.56), Vector2(0, -h * 0.86), Vector2(w * 0.36, -h * 0.56)], Color("#8c4e3c"))
	draw_circle(Vector2(0, -h * 0.42), w * 0.22, Color("#bd9d66"))
	draw_circle(Vector2(0, -h * 0.42), w * 0.13, Color("#796345"))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		_line(Vector2(cos(a) * w * 0.12, -h * 0.42 + sin(a) * w * 0.12), Vector2(cos(a) * w * 0.22, -h * 0.42 + sin(a) * w * 0.22), Color("#705840"), 2)
	_rect(-w * 0.09, -h * 0.32, w * 0.18, h * 0.29, Color("#694b35"))

func _draw_misc(kind: String, size: Vector2) -> void:
	var w := clampf(size.x, 18.0, 64.0)
	var h := clampf(size.y, 18.0, 70.0)
	_shadow(Rect2(-w * 0.46, -4, w * 0.92, 8))
	match kind:
		"haystack", "haybale":
			_poly([Vector2(-w * 0.43, -4), Vector2(-w * 0.39, -h * 0.42), Vector2(-w * 0.22, -h * 0.72), Vector2(w * 0.22, -h * 0.72), Vector2(w * 0.42, -h * 0.38), Vector2(w * 0.43, -4)], Color("#c89d50"))
			_line(Vector2(-w * 0.36, -h * 0.37), Vector2(w * 0.36, -h * 0.37), Color("#e6c46c"), 2)
			_line(Vector2(-w * 0.28, -h * 0.23), Vector2(w * 0.28, -h * 0.23), Color("#a8793f"), 1)
		"woodpile":
			for i in range(4):
				var yy := -5.0 - float(i % 2) * 7.0
				_line(Vector2(-w * 0.40, yy), Vector2(w * 0.37, yy - 2), Color("#80583b"), 6)
				_line(Vector2(-w * 0.34, yy - 2), Vector2(-w * 0.20, yy - 2), Color("#d0a46e"), 2)
		"cart":
			_rect(-w * 0.40, -h * 0.56, w * 0.75, h * 0.36, Color("#a67749"))
			_rect(-w * 0.42, -h * 0.63, w * 0.80, 4, Color("#765338"))
			draw_circle(Vector2(-w * 0.24, -5), 5, Color("#58483a"))
			draw_circle(Vector2(w * 0.18, -5), 5, Color("#58483a"))
			_line(Vector2(w * 0.32, -h * 0.22), Vector2(w * 0.52, -h * 0.06), Color("#765338"), 3)
		"scarecrow":
			_rect(-2, -h * 0.84, 4, h * 0.78, Color("#795637"))
			_line(Vector2(-w * 0.40, -h * 0.62), Vector2(w * 0.40, -h * 0.62), Color("#795637"), 4)
			_rect(-w * 0.18, -h * 0.94, w * 0.36, h * 0.19, Color("#d5b86e"))
			_rect(-w * 0.24, -h * 0.72, w * 0.48, h * 0.29, Color("#6f8c70"))
			_rect(-w * 0.12, -h * 0.91, w * 0.24, h * 0.11, Color("#d9c59a"))
		"lamp":
			_rect(-2, -h * 0.84, 4, h * 0.84, Color("#52473d"))
			_rect(-w * 0.24, -h, w * 0.48, h * 0.24, Color("#725b41"))
			_rect(-w * 0.18, -h * 0.96, w * 0.36, h * 0.14, Color("#f3d993"))
			_rect(-w * 0.28, -h * 0.76, w * 0.56, 3, Color("#52473d"))
		_:
			# Distinct default marker for unrecognized content, kept decorative and legible.
			_rect(-w * 0.28, -h * 0.42, w * 0.56, h * 0.38, Color("#9b7650"))
			_rect(-w * 0.20, -h * 0.34, w * 0.40, 3, Color("#d7bb7c"))
