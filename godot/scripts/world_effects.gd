extends Node2D
class_name WorldEffects

## Short-lived pixel particles and restrained village ambience. This node only
## changes visuals; gameplay state and collisions remain owned by GameState.

const BURSTS := {
	"water": {"material": "water", "life": 1.0, "count": 12},
	"hoe": {"material": "soil", "life": 0.8, "count": 8},
	"seed": {"material": "soil", "life": 0.8, "count": 5},
	"dig": {"material": "soil", "life": 0.9, "count": 8},
	"chop": {"material": "wood", "life": 0.9, "count": 9},
	"build": {"material": "wood", "life": 1.2, "count": 10},
	"harvest": {"material": "leaf", "life": 1.0, "count": 8},
	"gather": {"material": "leaf", "life": 1.0, "count": 7},
	"cut": {"material": "leaf", "life": 0.9, "count": 7},
	"feed": {"material": "soil", "life": 0.8, "count": 6},
	"brush": {"material": "care", "life": 0.9, "count": 5},
	"pet": {"material": "care", "life": 1.0, "count": 4},
	"greet": {"material": "care", "life": 1.0, "count": 3},
	"steam": {"material": "steam", "life": 1.4, "count": 5},
	"fish": {"material": "water", "life": 1.1, "count": 9},
	"pack": {"material": "leaf", "life": 0.9, "count": 4},
	"trade": {"material": "wood", "life": 0.8, "count": 4}
}
const COLORS := {
	"water": ["#9fd2d2", "#d2ebe0"],
	"soil": ["#a98252", "#d3b17b"],
	"leaf": ["#93ad65", "#d4cc83"],
	"wood": ["#b08b58", "#e1c18a"],
	"care": ["#d69c86", "#eac8a2"],
	"steam": ["#e6e2c8", "#faf0d6"]
}

var world_data: Dictionary = {}
var bursts: Array[Dictionary] = []
var footprints: Array[Dictionary] = []
var float_rows: Array[Dictionary] = []
var ambient_props: Array[Dictionary] = []
var visible_ambient_props: Array[Dictionary] = []
var water_rects: Array[Dictionary] = []
var houses: Array[Dictionary] = []
var visible_houses: Array[Dictionary] = []
var festival_market := Vector2.ZERO
var indoor_home_doors: Array[Vector2] = []
var plot_nodes: Array[Node2D] = []
var crop_stages: Array[Dictionary] = []
var interior_stations: Array[Dictionary] = []
var clock := 0.0
var _scan_clock := 0.0
var _crop_clock:=0.0
var _crop_draw_scan:=0.0
var _serial := 0
var _last_foot_position := Vector2.ZERO
var _last_foot_clock := -1.0

func _ready() -> void:
	z_index = 24
	GameState.player_moved.connect(_on_player_moved)
	set_process(true)

func configure(data: Dictionary) -> void:
	world_data = data
	interior_stations.clear()
	ambient_props.clear()
	water_rects.clear()
	houses.clear()
	var village: Dictionary = world_data.get("village", {})
	for prop in village.get("allProps", []):
		if str(prop.get("kind", "")) in ["tree", "willow", "blossom", "orchard", "bamboo"]:
			ambient_props.append(prop)
	for prop in world_data.get("tiles", {}).get("objects", []):
		if str(prop.get("kind", "")) in ["plants", "stones"]:
			ambient_props.append(prop)
	for house in village.get("houses", []):
		if house is Dictionary:
			houses.append(house)
			if str(house.get("name", "")) == "许婶杂货":
				var door: Dictionary = house.get("door", {})
				festival_market = Vector2(float(door.get("x", 0.0)), float(door.get("y", 0.0)))
	var maps: Dictionary = village.get("maps", {})
	var offsets: Dictionary = village.get("offsets", {})
	for region_id in maps:
		var region: Dictionary = maps[region_id]
		var offset: Dictionary = offsets.get(region_id, {})
		for water in region.get("water", []):
			water_rects.append({
				"rect": Rect2(float(water.x) + float(offset.get("x", 0)), float(water.y) + float(offset.get("y", 0)), float(water.w), float(water.h)),
				"speed": 12.0 if str(region_id) == "river" else 3.0
			})
	_scan_ambient_props()
	queue_redraw()

func configure_plots(nodes: Array[Node2D]) -> void:
	plot_nodes = nodes
	crop_stages.clear()
	for plot in GameState.plots:
		crop_stages.append(_crop_stage(plot))

func configure_room(layout: Dictionary) -> void:
	interior_stations.clear()
	for row in layout.get("rows", []):
		if not row is Dictionary:
			continue
		var point: Dictionary = row.get("point", {}) if row.get("point", {}) is Dictionary else {}
		if str(point.get("kind", "")) != "kitchen-station":
			continue
		interior_stations.append({
			"station": str(point.get("station", "")),
			"position": Vector2(float(point.get("x", row.get("x", 0))), float(point.get("y", row.get("y", 0))))
		})
	queue_redraw()

func clear_action_bursts() -> void:
	bursts.clear()
	queue_redraw()

func burst(kind: String, at: Vector2, rare: bool = false) -> void:
	if not BURSTS.has(kind):
		return
	var definition: Dictionary = BURSTS[kind]
	var pace := str(GameState.feedback.get("prefs", {}).get("pace", "normal"))
	for existing in bursts:
		if str(existing.kind) == kind and clock - float(existing.at) < 0.18 and Vector2(existing.position).distance_to(at) < 34.0:
			existing.rare = bool(existing.rare) or rare
			return
	var policy := _policy()
	bursts.append({
		"position": at,
		"kind": kind,
		"material": str(definition.material),
		"life": maxf(0.45, float(definition.life) * (0.65 if pace == "brisk" else 1.0)),
		"count": mini(int(definition.count), int(policy.count)),
		"rare": rare,
		"at": clock,
		"seed": _serial + 1
	})
	_serial += 1
	while bursts.size() > 8 or _particle_total() > int(policy.cap) and bursts.size() > 1:
		var remove_at := -1
		for index in range(bursts.size()):
			if not bool(bursts[index].rare):
				remove_at = index
				break
		if remove_at < 0:
			remove_at = 0
		bursts.remove_at(remove_at)
	queue_redraw()


func active_burst_count() -> int:
	return bursts.size()

func _policy() -> Dictionary:
	var density := str(GameState.visual_fx.get("density", "standard"))
	var reduced := str(GameState.visual_fx.get("motion", "full")) == "reduced"
	var disabled := density == "off"
	return {
		"count": 0 if disabled else 3 if density == "quiet" or reduced else 12,
		"cap": 0 if disabled else 18 if density == "quiet" or reduced else 72,
		"ambient": not disabled and not reduced and bool(GameState.visual_fx.get("ambient", true)),
		"reduced": reduced or disabled,
		"weather": "gentle" if disabled or reduced or str(GameState.visual_fx.get("weather", "standard")) == "gentle" else "standard"
	}

func _particle_total() -> int:
	var count := 0
	for burst_data in bursts:
		count += int(burst_data.count)
	return count

func _process(delta: float) -> void:
	_update_crop_presentation(delta)
	clock += clampf(delta, 0.0, 0.1)
	bursts = bursts.filter(func(row: Dictionary) -> bool: return clock - float(row.at) < float(row.life))
	footprints = footprints.filter(func(row: Dictionary) -> bool: return clock - float(row.at) < 4.0)
	var had_floats: bool = not float_rows.is_empty() or not GameState.feedback_action_runtime.get("stories", []).is_empty()
	GameState.tick_feedback_floats(0.0 if GameState.ui_open or GameState.simulation_hidden() else delta)
	float_rows.clear()
	for row in GameState.feedback_action_runtime.floats:
		var text: String = "+" + str(int(row.qty)) + " " + ["普通","优质","上品","珍品"][int(row.grade)] + str(GameState.item_catalog[row.item].name) if row.has("item") else str(row.get("text",""))
		float_rows.append({"text":text,"position":Vector2(float(row.x),float(row.y)),"at":float(row.at)})
	var cap := 1 if str(GameState.feedback.prefs.floating)=="compact" else 3
	float_rows.assign(float_rows.slice(-cap))
	_scan_clock += delta
	if _scan_clock >= 0.25:
		_scan_clock = 0.0
		_scan_ambient_props()
		_scan_crop_growth()
	if had_floats or not bursts.is_empty() or not footprints.is_empty() or not float_rows.is_empty() or bool(_policy().ambient) and (not visible_ambient_props.is_empty() or not interior_stations.is_empty() or not visible_houses.is_empty()):
		queue_redraw()

func _update_crop_presentation(delta:float)->void:
	if plot_nodes.is_empty():return
	var animate:=str(GameState.visual_fx.get("motion","full"))=="full" and str(GameState.visual_fx.get("density","standard"))!="off" and not GameState.ui_open and not GameState.simulation_hidden()
	if animate:_crop_clock+=clampf(delta,0,.1)
	_crop_draw_scan+=delta
	if _crop_draw_scan<.08:return
	_crop_draw_scan=0.0
	var weather:Dictionary=GameState.weather_profile()
	var presentation:Dictionary={"season":int(weather.season),"wind":float(weather.wind),"clock":_crop_clock if animate else 0.0,"motion":animate}
	var visible:=_visible_world_rect().grow(64)
	for i in range(mini(plot_nodes.size(),GameState.plots.size())):
		var node:=plot_nodes[i]
		if is_instance_valid(node) and str(GameState.plots[i].get("crop",""))!="" and visible.has_point(node.global_position):
			node.call("set_crop_presentation",presentation)

func _crop_stage(plot: Dictionary) -> Dictionary:
	var crop := str(plot.get("crop", ""))
	if crop == "" or GameState.crop_days(crop) <= 0:
		return {"crop": crop, "stage": -1}
	var progress := float(plot.get("growth", 0)) / float(GameState.crop_days(crop))
	var stage := preload("res://scripts/farm_surface_art.gd").crop_stage(progress)
	return {"crop": crop, "stage": stage}

func _scan_crop_growth() -> void:
	if plot_nodes.is_empty() or crop_stages.size() != GameState.plots.size():
		return
	for index in range(GameState.plots.size()):
		var next := _crop_stage(GameState.plots[index])
		var prior := crop_stages[index]
		if str(prior.crop) == str(next.crop) and int(next.stage) > int(prior.stage) and int(next.stage) >= 1:
			if index < plot_nodes.size() and is_instance_valid(plot_nodes[index]):
				plot_nodes[index].call("notify_growth")
		crop_stages[index] = next

func _visible_world_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(-100000, -100000, 200000, 200000)
	var viewport := get_viewport_rect().size
	var world_size := Vector2(viewport.x / maxf(camera.zoom.x, 0.01), viewport.y / maxf(camera.zoom.y, 0.01))
	return Rect2(camera.global_position - world_size * 0.5, world_size).grow(100.0)

func _scan_ambient_props() -> void:
	visible_ambient_props.clear()
	visible_houses.clear()
	indoor_home_doors.clear()
	if not bool(_policy().ambient):
		return
	var view := _visible_world_rect()
	for prop in ambient_props:
		var point := Vector2(float(prop.get("x", 0)), float(prop.get("y", 0)))
		if view.has_point(point):
			visible_ambient_props.append(prop)
			if visible_ambient_props.size() >= 12:
				break
	for house in houses:
		var point := Vector2(float(house.get("x", 0)), float(house.get("y", 0)))
		if view.has_point(point + Vector2(float(house.get("w", 0)) * 0.73, 12.0)):
			visible_houses.append(house)
	for npc in get_tree().get_nodes_in_group("village_npc"):
		if bool(npc.get("indoor_activity")):
			indoor_home_doors.append(npc.get("home_target"))

func _on_player_moved(at: Vector2) -> void:
	if not bool(_policy().ambient) or GameState.current_interior != "" or GameState.riding:
		_last_foot_position = Vector2.ZERO
		return
	var conditions := GameState.ground_conditions()
	var snow := float(conditions.get("snow", 0.0)) > 0.0
	var wet := float(conditions.get("wet", 0.0)) > 0.0
	if not snow and not wet:
		_last_foot_position = at
		return
	if _last_foot_position == Vector2.ZERO or at.distance_to(_last_foot_position) > 120.0:
		_last_foot_position = at
		return
	if at.distance_to(_last_foot_position) >= 18.0 and clock - _last_foot_clock >= 0.18:
		var direction := at - _last_foot_position
		footprints.append({"position": at + Vector2(3.0 if _serial % 2 == 0 else -3.0, 0), "at": clock, "snow": snow, "horizontal": absf(direction.x) > absf(direction.y)})
		if footprints.size() > 18:
			footprints.pop_front()
		_last_foot_position = at
		_last_foot_clock = clock
		_serial += 1
		queue_redraw()

func _draw() -> void:
	_draw_bursts()
	_draw_footprints()
	_draw_floats()
	_draw_interior_stories()
	if bool(_policy().ambient):
		_draw_ambient()

func _draw_floats() -> void:
	if str(GameState.feedback.get("prefs", {}).get("floating", "normal")) == "off":
		return
	var view := _visible_world_rect()
	for index in range(float_rows.size()):
		var row: Dictionary = float_rows[index]
		var at: Vector2 = row.position
		var age := float(GameState.feedback_action_runtime.clock) - float(row.at)
		var lift := 0.0 if str(GameState.feedback.get("prefs", {}).get("motion", "full")) == "reduced" else minf(10.0, age * 4.0)
		var side := -120.0 if at.x + 120.0 > view.end.x - 90.0 else 120.0
		var center_x := clampf(at.x + side, view.position.x + 90.0, view.end.x - 90.0)
		var y := maxf(view.position.y + 30.0, at.y - 15.0 - float(index) * 19.0 - lift)
		var alpha := minf(1.0, (4.5 - age) * 2.0)
		var text := str(row.text)
		if text=="":continue
		var max_width := maxf(90.0,minf(260.0,view.size.x-24.0))
		while ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x>max_width and text.length()>8:
			text=text.left(text.length()-2)+"…"
		var width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+16.0
		draw_rect(Rect2(floorf(center_x-width*0.5+0.5),floorf(y-12.0+0.5),ceilf(width),17.0),Color("#f9edcf",alpha*236.0/255.0),true)
		draw_string(ThemeDB.fallback_font, Vector2(center_x, y), text, HORIZONTAL_ALIGNMENT_CENTER, width - 8.0, 11, Color("#385844",alpha))

func _draw_interior_stories() -> void:
	var view := _visible_world_rect()
	var font := ThemeDB.fallback_font
	var max_width := minf(300.0, view.size.x - 32.0)
	for row in GameState.feedback_action_runtime.get("stories", []):
		var lines: Array[String] = []
		var line := ""
		for character in str(row.text):
			if character == "\n" or font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > max_width:
				lines.append(line)
				line = "" if character == "\n" else character
			else: line += character
		if line != "": lines.append(line)
		if lines.is_empty(): continue
		var width := 0.0
		for text in lines: width = maxf(width, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		var box := Rect2(Vector2(float(row.x) - width * 0.5 - 8.0, float(row.y) - lines.size() * 15.0), Vector2(width + 16.0, lines.size() * 15.0 + 10.0))
		box.position.x = clampf(box.position.x, view.position.x + 8.0, view.end.x - box.size.x - 8.0)
		box.position.y = clampf(box.position.y, view.position.y + 8.0, view.end.y - box.size.y - 8.0)
		var alpha := clampf((float(row.duration) - (float(GameState.feedback_action_runtime.clock) - float(row.at))) * 2.0, 0.0, 1.0)
		draw_rect(box, Color("f9edcf", alpha * 0.95))
		for index in range(lines.size()):
			draw_string(font, box.position + Vector2(8.0, 15.0 + index * 15.0), lines[index], HORIZONTAL_ALIGNMENT_LEFT, width, 11, Color("385844", alpha))

func _draw_bursts() -> void:
	var policy := _policy()
	for burst_data in bursts:
		var age := clock - float(burst_data.at)
		var life := float(burst_data.life)
		var alpha := clampf((life - age) * 3.0, 0.0, 1.0)
		var base_colors: Array = COLORS[str(burst_data.material)]
		for index in range(int(burst_data.count)):
			var particle := _particle_position(burst_data, index, age)
			var particle_alpha := float(particle.alpha) * 0.9
			if bool(particle.landed) and str(burst_data.material) == "water":
				_draw_ring(Vector2(particle.x, particle.ground), 2.0 + age / life * 4.0, Color("#b7d9d1", particle_alpha))
			else:
				var color := Color(String(base_colors[index % 2]))
				color.a = particle_alpha
				var leaf: Texture2D = preload("res://scripts/detail_art.gd").texture("effects/harvest") if str(burst_data.kind) in ["harvest", "gather"] else preload("res://scripts/character_art.gd").texture("res://art/world/effects/leaves.png") if str(burst_data.material)=="leaf" else null
				if leaf!=null:
					texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
					draw_texture_rect(leaf,Rect2(Vector2(float(particle.x)-2.5,float(particle.y)-3.5),Vector2(5,7)),false,Color(1,1,1,particle_alpha))
				else:
					var key: String = {"water":"watering", "wood":"building", "leaf":"harvest"}.get(str(burst_data.material), "")
					if not key.is_empty():
						preload("res://scripts/detail_art.gd").draw(self, "effects/" + key, Rect2(float(particle.x) - 2, float(particle.y) - 2, 4, 4), Color(1, 1, 1, particle_alpha))
					else: draw_rect(Rect2(roundf(float(particle.x)), roundf(float(particle.y)), int(particle.size), int(particle.size)), color)
		if int(policy.count) == 0 or bool(policy.reduced):
			_draw_ring(Vector2(burst_data.position), 12.0, Color("#e3c875" if bool(burst_data.rare) else "#d4dab3", alpha))
		if bool(burst_data.rare):
			var rise := 0.0 if bool(policy.reduced) else age / life * 5.0
			draw_rect(Rect2(Vector2(burst_data.position) + Vector2(-13, -36 - rise), Vector2(26, 18)), Color("#dcc478", alpha), false, 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(burst_data.position) + Vector2(-5, -23 - rise), "珍", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#fff0bc", alpha))

func _particle_position(burst_data: Dictionary, index: int, age: float) -> Dictionary:
	var seed := int(burst_data.seed) * 17 + index * 31
	var angle := float(seed) * 2.399
	var velocity_x := cos(angle) * float(12 + seed % 18)
	var velocity_y := sin(angle) * 8.0
	var base_height := 5.0 if str(burst_data.material) == "water" else 3.0
	var velocity_z := -float(18 + seed % 16)
	var gravity := 100.0
	var landing_time := (-velocity_z + sqrt(velocity_z * velocity_z + 2.0 * gravity * base_height)) / gravity
	var t := minf(age, landing_time)
	var rising := str(burst_data.material) in ["steam", "care"]
	var origin: Vector2 = burst_data.position
	var x := origin.x + velocity_x * (0.15 * age if rising else t)
	var y := origin.y - 12.0 - age * 19.0 if rising else origin.y + velocity_y * t - base_height + velocity_z * t + 0.5 * gravity * t * t
	return {"x": x, "y": y, "ground": origin.y + velocity_y * t, "landed": not rising and age >= landing_time, "alpha": clampf((float(burst_data.life) - age) * 3.0, 0.0, 1.0), "size": 1 + seed % 2}

func _draw_ring(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(19):
		var angle := TAU * float(index % 18) / 18.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.35))
	draw_polyline(points, color, 1.0, false)

func _draw_footprints() -> void:
	for footprint in footprints:
		var age := clock - float(footprint.at)
		var color := Color("#819998" if bool(footprint.snow) else "#4a685d", (1.0 - age / 4.0) * 0.48)
		var size := Vector2(6, 3) if bool(footprint.horizontal) else Vector2(3, 6)
		draw_rect(Rect2(Vector2(footprint.position) - size * 0.5, size), color)

func _draw_ambient() -> void:
	if not interior_stations.is_empty():
		_draw_indoor_ambience()
		return
	var season := GameState.season_index()
	var weather: Dictionary = GameState.weather_profile()
	var wind := float(weather.get("wind", 0.0))
	_draw_festival_dressing(season)
	_draw_house_chimneys(wind)
	for prop in visible_ambient_props:
		var kind := str(prop.get("kind", ""))
		var point := Vector2(float(prop.get("x", 0)), float(prop.get("y", 0)))
		var seed := absi(int(point.x * 7.0 + point.y * 13.0))
		var phase := fposmod(clock * 0.13 + float(seed) * 0.017, 1.0)
		if season == 0 and kind == "blossom" or season == 2:
			var petal := point + Vector2(-23.0 + phase * wind * 2.0 + sin(phase * 9.0 + float(seed)) * 8.0, -75.0 + phase * 70.0)
			var tint := Color("#ecc0b7" if season == 0 else "#bf985e", sin(phase * PI) * 0.65)
			draw_rect(Rect2(petal, Vector2(3, 2)), tint)
			draw_rect(Rect2(petal + Vector2(1, 2), Vector2(2, 1)), Color("#f3dcc4" if season == 0 else "#d8bc7e", sin(phase * PI) * 0.65))
		elif season == 1 and int(weather.get("rain", 0)) == 0 and GameState.minutes >= 1050:
			var glint := point + Vector2(sin(clock * 0.7 + float(seed)) * 18.0, -17.0 + sin(clock * 0.4 + float(seed)) * 8.0)
			draw_rect(Rect2(glint, Vector2(2, 2)), Color("#dece82", 0.35 + 0.3 * pow(sin(clock + float(seed)), 2.0)))
	var drawn := 0
	var view := _visible_world_rect()
	for water in water_rects:
		var area: Rect2 = water.rect
		if not view.intersects(area):
			continue
		for index in range(8):
			var x := area.position.x + fposmod(clock * float(water.speed) + float(index * 109), area.size.x)
			var y := area.position.y + fposmod(float(index * 47), area.size.y)
			draw_rect(Rect2(x, y, 9 + index % 3 * 3, 1), Color("#c0ded0", 0.4))
			drawn += 1
			if drawn >= 16:
				return

func festival_dressing_active() -> bool:
	var weather: Dictionary = GameState.weather_profile()
	return festival_market != Vector2.ZERO and posmod(GameState.day, 28) == 13 and GameState.minutes >= 660 and GameState.minutes < 1080 and not bool(weather.get("shelter", false))

func _draw_festival_dressing(season: int) -> void:
	if not festival_dressing_active():
		return
	var view := _visible_world_rect()
	if not view.grow(40.0).has_point(festival_market):
		return
	var reduced := bool(_policy().reduced)
	var sway := 0.0 if reduced else sin(clock * 1.7) * 2.0
	var start := festival_market + Vector2(-76.0, -38.0)
	var finish := festival_market + Vector2(76.0, -38.0)
	var palette: Array[Color] = [
		Color("d9877a"), Color("80aaa1"), Color("d3a758"), Color("a76560")
	]
	var banner_line := Color("8e704e")
	draw_line(start, finish, banner_line, 2.0)
	var titles: Array = GameState.content.get("festivals", ["春日飯桌", "夏日飯桌", "秋日飯桌", "冬日飯桌"])
	var title := str(titles[season]) if season >= 0 and season < titles.size() else "四季飯桌"
	draw_string(ThemeDB.fallback_font, festival_market + Vector2(-48.0, -48.0), title, HORIZONTAL_ALIGNMENT_CENTER, 96.0, 12, Color("fff0c7"))
	for index in range(7):
		var amount := float(index) / 6.0
		var point := start.lerp(finish, amount)
		var drop := point + Vector2(0.0, 13.0 + (0.0 if reduced else sway * sin(amount * PI)))
		var color := palette[posmod(index + season, palette.size())]
		var pennant := PackedVector2Array([point, point + Vector2(12.0, 1.0), drop + Vector2(6.0, 0.0)])
		draw_colored_polygon(pennant, color)
		draw_circle(drop + Vector2(6.0, 2.0), 1.5, Color("f7dfa0", 0.9))
	for index in range(3):
		var lantern := festival_market + Vector2(-51.0 + index * 51.0, -17.0)
		draw_line(lantern + Vector2(0.0, -10.0), lantern + Vector2(0.0, -3.0), banner_line, 1.0)
		draw_rect(Rect2(lantern + Vector2(-4.0, -3.0), Vector2(8.0, 10.0)), Color("d9877a") if index == 1 else Color("e8c978"), true)
		draw_rect(Rect2(lantern + Vector2(-5.0, -2.0), Vector2(10.0, 2.0)), Color("fff0c7"), true)
		draw_rect(Rect2(lantern + Vector2(-2.0, 7.0), Vector2(4.0, 2.0)), Color("9b704e"), true)

func _draw_house_chimneys(wind: float) -> void:
	var meal_time := GameState.minutes >= 660 and GameState.minutes < 780 or GameState.minutes >= 1020 and GameState.minutes < 1140
	var now := GameState._kitchen_now()
	var kitchen_working := false
	for job in GameState.kitchen.get("jobs", []):
		if str(job.get("station", "")) in ["stove", "steam"] and int(job.get("ready", 0)) > now:
			kitchen_working = true
			break
	for house in visible_houses:
		var house_name := str(house.get("name", ""))
		var at_home := false
		if meal_time:
			var door: Dictionary = house.get("door", {})
			var door_position := Vector2(float(door.get("x", 0)), float(door.get("y", 0)))
			for home in indoor_home_doors:
				if home.distance_to(door_position) < 4.0:
					at_home = true
					break
		if not (house_name == "禾溪小灶" and kitchen_working or meal_time and at_home):
			continue
		var point := Vector2(float(house.x) + float(house.w) * 0.73, float(house.y) + 12.0)
		draw_rect(Rect2(point.x - 3, point.y - 12, 9, 18), Color("767568"), true)
		draw_rect(Rect2(point.x - 5, point.y - 13, 13, 3), Color("a19c85"), true)
		for index in range(4):
			var phase := fposmod(clock * 0.23 + float(index) / 4.0, 1.0)
			var drift := phase * wind * 1.1
			var alpha := (1.0 - phase) * 0.35
			preload("res://scripts/detail_art.gd").draw(self, "effects/chimney_smoke", Rect2(point.x + drift + sin(phase * 6.0) * 3.0, point.y - 16.0 - phase * 46.0, 7.0 + phase * 8.0, 9.0 + phase * 8.0), Color(1, 1, 1, alpha))

func _draw_indoor_ambience() -> void:
	var now := GameState._kitchen_now()
	for station_row in interior_stations:
		var station := str(station_row.station)
		var running := false
		for job in GameState.kitchen.get("jobs", []):
			if str(job.get("station", "")) == station and int(job.get("ready", 0)) > now:
				running = true
				break
		if not running:
			continue
		var point: Vector2 = station_row.position
		if station in ["stove", "steam"]:
			for index in range(3):
				var phase := fposmod(clock * 0.5 + float(index) / 3.0, 1.0)
				var alpha := (1.0 - phase) * 0.6
				draw_rect(Rect2(point.x + sin(clock + float(index)) * 3.0, point.y - 24.0 - phase * 23.0, 2, 5), Color(0.96, 0.93, 0.84, alpha), true)
		elif station in ["mill", "press"]:
			draw_rect(Rect2(point.x + sin(clock * 3.0) * 7.0 - 4.0, point.y - 34.0, 9, 3), Color("d2b989"), true)
