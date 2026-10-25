extends Node2D
class_name InteriorWorld

const INTERIOR_ART := preload("res://scripts/interior_art.gd")
const RANCH_VISUAL := preload("res://scripts/ranch_visual.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const NPC_SCRIPT := preload("res://scripts/world_npc.gd")
const NPC_SCHEDULE := preload("res://scripts/npc_schedule.gd")
const WORLD_EFFECTS_SCRIPT := preload("res://scripts/world_effects.gd")

const SELECTION_SCRIPT := preload("res://scripts/interaction_selection.gd")
var interaction_selection := SELECTION_SCRIPT.new()
var selected_room_target: Dictionary = {}
var selection_tool := ""
var pointer_hover: Dictionary = {}
var pointer_screen:Variant=null
signal interaction_presentation_changed
const INTERACTION_DESCRIPTION=preload("res://scripts/interaction_description.gd")
var room_animal_nodes: Dictionary = {}
var painted_floor_active:=false
var home_furniture_stamp := ""
var home_furniture_cache: Array = []

var player: CharacterBody2D
var hud: CanvasLayer
var collision_root: Node2D
var collision_revision := -1
var resident_nodes: Dictionary = {}
var owner_npc: Node2D
var visitor_npc: Node2D
var visitor_id := ""
var owner_activity_stamp := ""
var _furniture_clock := 0.0
var _furniture_redraw_elapsed := 0.0

func _init() -> void:
	y_sort_enabled = true

func _ready() -> void:
	get_viewport().mouse_exited.connect(_pointer_leave)
	var ranch_fixtures := Node2D.new()
	ranch_fixtures.name = "RanchFixtures"
	ranch_fixtures.set_script(preload("res://scripts/ranch_fixture_visual.gd"))
	add_child(ranch_fixtures)
	if GameState.current_interior == "":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	var room := GameState.interior_house()
	if room.is_empty():
		GameState.current_interior = ""
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = GameState.interior_position
	add_child(player)
	collision_root = Node2D.new()
	collision_root.name = "InteriorFurnitureCollisions"
	add_child(collision_root)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	_add_wall_blockers()
	GameState.ranch_positions_changed.connect(queue_redraw)
	GameState.ranch_positions_changed.connect(_sync_room_animals)
	GameState.world_changed.connect(_refresh)
	GameState.clock_changed.connect(queue_redraw)
	GameState.input_mode_changed.connect(func(_mode:String):queue_redraw())
	GameState.action_sequence_changed.connect(func(_snapshot:Dictionary):queue_redraw())
	_sync_museum_visitor()
	_refresh()
	var layout := _room_layout()
	var world_effects := Node2D.new()
	world_effects.name = "WorldEffects"
	world_effects.set_script(WORLD_EFFECTS_SCRIPT)
	add_child(world_effects)
	world_effects.call("configure_room", layout)
	if layout.is_empty():
		_add_blocker(Rect2(185, 231, 122, 57))
		if str(room.get("name", "")) in ["禾溪小灶", "许婶杂货", "禾溪村史馆"]: _add_blocker(Rect2(590, 392, 154, 102))
	else:
		_add_layout_blockers(layout)
	_sync_room_owner(0.0)
	_publish_npc_positions()
	queue_redraw()

func _add_wall_blockers() -> void:
	_add_blocker(Rect2(70, 70, 820, 34))
	_add_blocker(Rect2(70, 70, 34, 500))
	_add_blocker(Rect2(856, 70, 34, 500))
	_add_blocker(Rect2(70, 576, 375, 34))
	_add_blocker(Rect2(515, 576, 375, 34))

func _process(delta: float) -> void:
	if preload("res://scripts/life_presentation.gd").animate():
		_furniture_clock += minf(delta,0.1)
		set_meta("furniture_clock",_furniture_clock)
		_furniture_redraw_elapsed += delta
		if _furniture_redraw_elapsed >= 1.0/24.0:
			_furniture_redraw_elapsed = 0.0
			for job: Dictionary in GameState.kitchen.get("jobs",[]):
				if float(job.get("ready",0)) > GameState._kitchen_now():
					queue_redraw();break
	_sync_room_owner(delta)
	_sync_museum_visitor()
	_publish_npc_positions()
	if not GameState.ui_open:
		_refresh_pointer_hover()
		_refresh_room_target()

func _publish_npc_positions() -> void:
	if GameState.npc_movement != null: GameState.npc_movement.publish(GameState)

func _sync_room_owner(_delta: float) -> void:
	_sync_room_residents()

func _sync_room_residents() -> void:
	var room := current_interior_house_id()
	var house := GameState.interior_house()
	var owner := str(house.get("owner")) if house.get("owner") != null else ""
	var wanted: Dictionary = {}
	owner_npc = null
	visitor_npc = null
	visitor_id = ""
	for person in GameState.npc_catalog:
		var id := str(person.id)
		var p: Dictionary = GameState.npc_residents.get(id, {})
		if p.get("room") == null or str(p.get("room", "")) != room: continue
		wanted[id] = true
		var npc: Node2D = resident_nodes.get(id)
		if npc == null or not is_instance_valid(npc):
			npc = Node2D.new()
			npc.set_script(NPC_SCRIPT)
			npc.set("npc_id", id)
			npc.set("npc_data", person)
			npc.set("npc_index", GameState.npc_catalog.find(person))
			add_child(npc)
			resident_nodes[id] = npc
		npc.call("present_resident", GameState, room)
		if id == owner: owner_npc = npc
		elif visitor_npc == null: visitor_npc = npc; visitor_id = id
	for id in resident_nodes.keys():
		if wanted.has(id): continue
		var npc: Node2D = resident_nodes[id]
		if is_instance_valid(npc): npc.queue_free()
		resident_nodes.erase(id)

func _room_owner_plan(person: Dictionary) -> Dictionary:
	return NPC_SCHEDULE.from_state(GameState, person)

func _room_activity(owner_id: String, plan: Dictionary, npc_index: int, time_slot: int) -> Dictionary:
	var room_points := _room_points()
	var by_kind: Dictionary = {}
	var personal_points: Array[Dictionary] = []
	var point_by_name: Dictionary = {}
	for point in room_points:
		if not point is Dictionary: continue
		var kind := str(point.get("kind", ""))
		if kind == "" or kind == "exit": continue
		var normalized := {
			"kind": kind,
			"position": Vector2(float(point.get("x", 480)), float(point.get("y", 350))),
			"name": str(point.get("name", "")),
			"gesture": str(point.get("gesture", ""))
		}
		by_kind[kind] = normalized
		if kind == "egg":
			var object_name := str(point.get("name", "")).replace("动手看看 · ", "")
			point_by_name[object_name] = normalized
	var interior_profiles: Dictionary = GameState.system_catalog.get("interiors", {}).get("profiles", {})
	var profile_data: Variant = interior_profiles.get(owner_id, [])
	if profile_data is Array:
		for profile_index in [4, 6, 8]:
			if profile_index >= profile_data.size(): continue
			var object_name := str(profile_data[profile_index])
			if point_by_name.has(object_name): personal_points.append(point_by_name[object_name])
	var key := str(plan.get("key", ""))
	var gesture := str(GameState.system_catalog.get("npc", {}).get("profiles", {}).get(owner_id, {}).get("gesture", plan.get("gesture", "read")))
	var selected: Dictionary = {}
	if key == "night":
		selected = by_kind.get("bed-visit", {})
	elif key in ["lunch", "evening"]:
		selected = by_kind.get("tea", {})
	if selected.is_empty() and not personal_points.is_empty():
		var preferred_index := 0 if key in ["morning", "housework", "shelter"] else 1 if key == "lunch" else 2
		var rotation := posmod(GameState.day + time_slot + npc_index, personal_points.size())
		selected = personal_points[posmod(preferred_index + rotation, personal_points.size())]
	if selected.is_empty():
		var fallback_kinds: Array[String] = ["tea", "bed-visit", "egg", "shop", "archive", "kitchen"]
		for kind in fallback_kinds:
			if by_kind.has(kind):
				selected = by_kind[kind]
				break
	if selected.is_empty():
		selected = {"kind": "rest", "position": Vector2(480, 350), "name": "休息角"}
	var kind := str(selected.get("kind", ""))
	var name := str(selected.get("name", "手边的事")).replace("动手看看 · ", "")
	var verbs := {
		"sew": "绣一会儿", "water": "照看一下", "read": "翻看", "hammer": "修整",
		"sort": "整理", "knead": "准备", "fish": "查看", "camera": "擦拭",
		"fan": "练习", "tea": "温一壶", "weave": "编织"
	}
	var action := "歇息" if kind == "bed-visit" else "沏茶" if kind == "tea" else str(verbs.get(gesture, "看看"))
	return {
		"position": selected.get("position", Vector2(480, 350)),
		"label": "%s · %s" % [action, name],
		"gesture": gesture,
		"working": kind == "egg" or kind == "kitchen-station"
	}

func _sync_museum_visitor() -> void:
	_sync_room_residents()

func _add_blocker(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.position = rect.position + rect.size * 0.5
	body.add_child(shape_node)
	add_child(body)

func _draw() -> void:
	var room := GameState.interior_house()
	if room.is_empty(): return
	var home_id := _grandfather_house_id()
	var home_room := str(room.get("id", "")) == home_id
	var layout := _room_layout()
	var styles: Dictionary = GameState.system_catalog.get("building", {}).get("styles", {})
	var style_id := str(GameState.building.get("style", "wood")) if home_room else "wood"
	var palette: Array = styles.get(style_id, styles.get("wood", ["", "#c7b080", "#e1d5b4", "#896a43"]))
	if not layout.is_empty():
		var room_palette: Array = layout.get("pal", [])
		if room_palette.size() >= 3: palette = [room_palette[0], room_palette[1], room_palette[2], room_palette[0]]
	draw_rect(Rect2(68, 68, 824, 542), Color("263a31"), true)
	var independent_room: bool = INTERIOR_ART.draw_room(self, current_interior_house_id(), GameState.minutes)
	painted_floor_active = independent_room
	if not independent_room:
		draw_rect(Rect2(102, 104, 756, 500), Color(str(palette[1])), true)
		draw_rect(Rect2(112, 198, 736, 394), Color(str(palette[2])), true)
		painted_floor_active=_painted_wood_floor(layout,style_id)
		var painted_floor:=painted_floor_active
		if layout.is_empty() and not painted_floor:
			for row in range(14):
				var y := 202 + row * 27
				draw_line(Vector2(114, y), Vector2(846, y), Color("817552", 0.34), 1.0)
				for col in range(12):
					var x := 118 + col * 62 + (row % 2) * 30
					draw_line(Vector2(x, y + 2), Vector2(x, y + 24), Color("817552", 0.20), 1.0)
		elif not painted_floor:
			_draw_room_floor(layout)
		draw_rect(Rect2(102, 104, 756, 95), Color(str(palette[1])), true)
		draw_rect(Rect2(102, 194, 756, 9), Color(str(palette[3])), true)
		draw_rect(Rect2(102, 104, 10, 500), Color(str(palette[3])), true)
		draw_rect(Rect2(848, 104, 10, 500), Color(str(palette[3])), true)
		var window_left := 176
		var window_right := 702
		if not layout.is_empty():
			var room_key := int(layout.get("key", 0))
			window_left = 195 + posmod(room_key, 3) * 23
			window_right = 670 - posmod(room_key, 4) * 24
		for x in [window_left, window_right]:
			draw_rect(Rect2(x, 128, 76, 52), Color("b9cfc0"), true)
			draw_rect(Rect2(x + 35, 128, 5, 52), Color(str(palette[3])), true)
			draw_rect(Rect2(x, 152, 76, 4), Color(str(palette[3])), true)
	var room_title := str(room.get("name", "屋内"))
	var owner := str(room.get("owner")) if room.get("owner") != null else ""
	var owner_profile: Variant = GameState.system_catalog.get("interiors", {}).get("profiles", {}).get(owner, [])
	if owner_profile is Array and owner_profile.size() > 1:
		room_title = "%s · %s" % [str(owner_profile[1]), room_title]
	draw_string(ThemeDB.fallback_font, Vector2(140, 95), room_title, HORIZONTAL_ALIGNMENT_CENTER, 680, 19, Color("f2e5c7"))
	if not layout.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(130, 189), str(layout.get("description", "")), HORIZONTAL_ALIGNMENT_CENTER, 700, 11, Color("efe0bf"))
		_draw_room_layout(layout, palette)
	else:
		_draw_base_furnishings(room, home_room, palette)
		if home_room: _draw_home_layout()
	if not selected_room_target.is_empty() and not GameState.ui_open and not GameState.action_busy():
		var point := Vector2(float(selected_room_target.x),float(selected_room_target.y))
		draw_arc(point,19.0,0.0,TAU,24,Color("f4e7ad"),2.0)

func _draw_base_furnishings(room: Dictionary, home_room: bool, palette: Array) -> void:
	if painted_floor_active:
		_draw_painted_base_furnishings(room, home_room, palette)
		return
	var style_color := Color(str(palette[3]))
	draw_rect(Rect2(155, 253, 144, 64), Color("705941"), true)
	draw_rect(Rect2(163, 260, 128, 46), Color("94a899"), true)
	draw_rect(Rect2(170, 265, 32, 34), Color("eee3c4"), true)
	draw_string(ThemeDB.fallback_font, Vector2(225, 242), "起居與休息", HORIZONTAL_ALIGNMENT_CENTER, 135, 11, style_color)
	draw_rect(Rect2(160, 312, 8, 11), Color("574735"), true)
	draw_rect(Rect2(286, 312, 8, 11), Color("574735"), true)
	if home_room:
		var level := int(GameState.building.get("house", 0))
		if level >= 1:
			draw_rect(Rect2(610, 277, 112, 44), Color("927b5e"), true)
			draw_rect(Rect2(603, 269, 126, 10), Color("c9c5a4"), true)
			draw_circle(Vector2(666, 266), 17, Color("536f67"))
			draw_rect(Rect2(637, 297, 28, 14), Color("bc8256"), true)
			draw_string(ThemeDB.fallback_font, Vector2(666, 249), "備餐角", HORIZONTAL_ALIGNMENT_CENTER, 110, 11, style_color)
		if level >= 2:
			draw_rect(Rect2(179, 422, 132, 71), Color("8b7352"), true)
			for y in [440, 466, 487]: draw_line(Vector2(186, y), Vector2(304, y), Color("d5bc89"), 4.0)
			draw_rect(Rect2(337, 437, 90, 42), Color("ae9565"), true)
			draw_string(ThemeDB.fallback_font, Vector2(300, 413), "儲藏與共餐", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, style_color)
		if level >= 3:
			var use := str(GameState.building.get("roomUse", "display"))
			var names := {"display": "收成展示", "workshop": "工具手作", "nursery": "农事育苗", "storage": "食材储藏"}
			draw_rect(Rect2(574, 422, 178, 76), Color("9a805a"), true)
			draw_rect(Rect2(568, 414, 190, 10), Color("d3bd8d"), true)
			draw_string(ThemeDB.fallback_font, Vector2(664, 402), str(names.get(use, "功能间")), HORIZONTAL_ALIGNMENT_CENTER, 200, 11, style_color)
	else:
		var kind := str(room.get("style", "home"))
		draw_rect(Rect2(590, 399, 154, 88), Color("8e7959"), true)
		draw_rect(Rect2(598, 406, 138, 7), Color("cbb780"), true)
		draw_rect(Rect2(600, 426, 134, 45), Color("647e74"), true)
		if str(room.get("name", "")) == "禾溪小灶":
			draw_rect(Rect2(604, 426, 46, 45), Color("725c44"), true)
			draw_circle(Vector2(627, 428), 17, Color("e9bc69"))
		elif str(room.get("name", "")) == "许婶杂货":
			for i in range(4): draw_rect(Rect2(602 + i * 32, 428, 24, 35), [Color("a86c4e"), Color("d1b673"), Color("839d70"), Color("bf8e67")][i], true)
	draw_string(ThemeDB.fallback_font, Vector2(666, 393), "家常工位", HORIZONTAL_ALIGNMENT_CENTER, 130, 11, style_color)

func _draw_painted_base_furnishings(room: Dictionary, home_room: bool, palette: Array) -> void:
	# Bed feet share the existing fixed blocker; keep the approach at (238,315).
	var rows: Array[Dictionary] = [{"kind":"bed","x":246,"y":279,"w":122,"h":57}]
	if home_room:
		var level := int(GameState.building.get("house",0))
		if level >= 1: rows.append({"kind":"table","x":666,"y":312,"w":126,"h":44})
		if level >= 2: rows.append({"kind":"shelf","x":245,"y":484,"w":132,"h":71})
		if level >= 3: rows.append({"kind":"shelf","x":664,"y":489,"w":178,"h":76})
	else:
		var kind := "table" if str(room.get("name","")) == "禾溪小灶" else "shelf"
		rows.append({"kind":kind,"x":667,"y":478,"w":154,"h":88})
	for row: Dictionary in rows:
		_draw_room_furniture(row,palette,0)

func _room_layout() -> Dictionary:
	var layouts: Dictionary = GameState.system_catalog.get("interiors", {}).get("layouts", {})
	var layout: Variant = layouts.get(current_interior_house_id(), {})
	return layout if layout is Dictionary else {}


func _room_points() -> Array:
	var layout := _room_layout()
	if not layout.is_empty():
		var authored: Variant = layout.get("points",[])
		return authored if authored is Array else []
	if current_interior_house_id() != _grandfather_house_id(): return []
	var points: Array = [
		{"id":"room-exit","kind":"exit","name":"推门回到小院","x":480,"y":590},
		{"id":"home-bed","kind":"sleep","name":"床铺 · 睡个好觉","x":238,"y":315},
		{"id":"home-plan","kind":"build","name":"家的营造簿","x":480,"y":540}]
	var stage := int(GameState.building.get("house",0))
	if stage >= 1: points.append({"id":"home-kitchen","kind":"cook","name":"备餐角 · 翻开菜谱","x":650,"y":376})
	if stage >= 2: points.append({"id":"home-storage","kind":"storage","name":"储藏室 · 收好物产","x":300,"y":376})
	if stage >= 3:
		var use := str(GameState.building.get("roomUse","display"))
		points.append({"id":"home-function","kind":{"display":"catalog","workshop":"tools","nursery":"farmcare","storage":"storage"}.get(use,"catalog"),"name":"功能间 · " + str({"display":"收成展示","workshop":"工具手作","nursery":"农事育苗","storage":"食材储藏"}.get(use,"收成展示")),"x":650,"y":550})
	return points

func _home_furniture_points() -> Array:
	var points: Array = []
	if current_interior_house_id() != _grandfather_house_id(): return points
	var zone: Dictionary = GameState.system_catalog.get("building",{}).get("zones",{}).get("home",{})
	var definitions: Dictionary = GameState.system_catalog.get("building",{}).get("defs",{})
	if zone.is_empty(): return points
	var geometry: Array = []
	for collider in find_children("*","CollisionShape2D",true,false):
		if collider.get_parent() is StaticBody2D and not collider.get_parent().is_queued_for_deletion() and not collider.disabled and collider.shape is RectangleShape2D:
			geometry.append([collider.global_position,collider.shape.size])
	var stamp := str(hash(GameState.building.get("layout",[]))) + "/" + str(hash(geometry))
	if stamp == home_furniture_stamp: return home_furniture_cache
	home_furniture_stamp = stamp
	var cols := int(zone.get("cols",14))
	var size := float(zone.get("size",44))
	for piece in GameState.building.get("layout",[]):
		if str(piece.get("zone","")) != "home": continue
		var definition: Dictionary = definitions.get(str(piece.get("type","")),{})
		if definition.is_empty(): continue
		var rotated := posmod(int(piece.get("rotation",0)),2) != 0
		var width := int(definition.get("h" if rotated else "w",1)) * size
		var height := int(definition.get("w" if rotated else "h",1)) * size
		var cell := int(piece.get("cell",0))
		var at := Vector2(float(zone.x) + cell % cols * size,float(zone.y) + int(cell / cols) * size)
		var candidates: Array[Vector2] = [at + Vector2(width / 2,height + 15),at + Vector2(width / 2,-15),at + Vector2(-15,height / 2),at + Vector2(width + 15,height / 2)]
		for candidate in candidates:
			var route: Dictionary = load("res://scripts/room_navigation.gd").exit_route(self,Vector2(480,580),candidate)
			if not bool(route.get("reachable",false)): continue
			var label := str(GameState.content.get("furniture",{}).get(str(piece.type),{}).get("name",piece.type))
			points.append({"id":"build-piece-" + str(int(piece.key)),"kind":"build-piece","piece":int(piece.key),"type":str(piece.type),"service":str(definition.get("service","")),"name":label + (" · 使用" if str(definition.get("service","")) != "" else " · 看看"),"x":candidate.x,"y":candidate.y})
			break
	home_furniture_cache = points
	return home_furniture_cache

func _draw_room_floor(layout: Dictionary) -> void:
	var floor_name := str(layout.get("floor", "木纹"))
	var key := int(layout.get("key", 0))
	var seam := Color("56604b", 0.19)
	var highlight := Color("f4e3b6", 0.24)
	if floor_name == "木纹":
		for y in range(204, 600, 28):
			var offset := posmod(int(y / 28) + key, 2) * 16
			for x in range(109 + offset, 852, 94):
				draw_line(Vector2(x, y), Vector2(x + 90, y), seam, 1.0)
				draw_line(Vector2(x + 4, y + 3), Vector2(x + 82, y + 3), highlight, 1.0)
	elif floor_name == "青砖":
		for row in range(14):
			var y := 204 + row * 28
			draw_line(Vector2(110, y), Vector2(850, y), seam, 1.0)
			for x in range(110 + posmod(row + key, 2) * 24, 852, 48):
				draw_line(Vector2(x, y), Vector2(x, y + 27), seam, 1.0)
	elif floor_name == "竹席":
		for y in range(204, 600, 14): draw_line(Vector2(110, y), Vector2(850, y), seam, 1.0)
		for x in range(112, 852, 48): draw_line(Vector2(x, 204), Vector2(x, 600), highlight, 1.0)
	else:
		for row in range(15):
			for col in range(24):
				var x := 119 + col * 31 + posmod(row + key, 2) * 12
				var y := 210 + row * 26
				if x < 846: draw_rect(Rect2(x, y, 3, 2), highlight if posmod(row + col + key, 3) == 0 else seam, true)

func _add_layout_blockers(layout: Dictionary) -> void:
	for row in layout.get("rows", []):
		if not row is Dictionary: continue
		var width := float(row.get("w", 80))
		var height := float(row.get("h", 32))
		var y := float(row.get("y", 300))
		_add_blocker(Rect2(float(row.get("x", 480)) - width * 0.5, y - height, width, height + 18.0))

func _draw_room_layout(layout: Dictionary, palette: Array) -> void:
	var rows: Array = layout.get("rows", [])
	for row in rows:
		if row is Dictionary: _draw_room_furniture(row, palette, int(layout.get("key", 0)))

func _draw_room_furniture(row: Dictionary, palette: Array, key: int) -> void:
	if str(row.get("kind","")) in ["草编巢床","ranch-fixture"]: return
	var x := float(row.get("x", 480))
	var y := float(row.get("y", 350))
	var width := float(row.get("w", 100))
	var height := float(row.get("h", 35))
	var kind := str(row.get("kind", "木器"))
	if kind == "bed" and current_interior_house_id() != _grandfather_house_id() and GameState.interior_house().get("owner") == null:
		row = row.duplicate(true)
		row.kind = "bench"
		kind = "bench"
	var point: Dictionary = row.get("point", {}) if row.get("point", {}) is Dictionary else {}
	var point_kind := str(point.get("kind", ""))
	if current_interior_house_id() == "building-river-10":
		var exhibit_slot := int(point.get("index", -1)) if point_kind == "egg" else 3 if kind == "shelf" else -1
		if exhibit_slot >= 0:
			_draw_museum_case(x, y, width, height, exhibit_slot)
			return
	if INTERIOR_ART.draw_furniture(self, row, GameState.minutes, selected_room_target):
		draw_string(ThemeDB.fallback_font, Vector2(x - (width + 20) * 0.5, y + 23), _furniture_label(kind), HORIZONTAL_ALIGNMENT_CENTER, width + 20, 10, Color("fff0d4"))
		if point_kind == "kitchen-station": _draw_station_status(point, Vector2(x, y))
		return
	var accent := Color(str(palette[0]))
	var light := Color(str(palette[1]))
	var wood := Color("806445")
	var shadow := Color("34463d", 0.25)
	_draw_oval(Rect2(x - width * 0.43, y + 9, width * 0.86, 12), shadow)
	if kind == "bed":
		draw_rect(Rect2(x - width * 0.47, y - 13, width * 0.94, height * 0.75), wood, true)
		draw_rect(Rect2(x - width * 0.41, y - 15, width * 0.82, height * 0.68), light, true)
		draw_rect(Rect2(x - width * 0.39, y - 3, width * 0.78, height * 0.40), accent, true)
		draw_rect(Rect2(x - width * 0.34, y - 13, width * 0.21, 10), Color("efe6d2"), true)
	elif kind == "table":
		draw_rect(Rect2(x - width * 0.34, y - 4, 6, 24), wood.darkened(0.12), true)
		draw_rect(Rect2(x + width * 0.29, y - 4, 6, 24), wood.darkened(0.12), true)
		draw_rect(Rect2(x - width * 0.5, y - 14, width, 11), wood, true)
		draw_rect(Rect2(x - width * 0.43, y - 15, width * 0.86, 4), light, true)
		draw_circle(Vector2(x, y - 17), 5, Color("ba9160"))
		draw_circle(Vector2(x + 14, y - 15), 3, Color("e8d9b9"))
	elif kind == "chair":
		draw_rect(Rect2(x - width * 0.40, y - 5, width * 0.80, 8), accent.darkened(0.12), true)
		draw_rect(Rect2(x - width * 0.36, y - 17, width * 0.72, 7), wood, true)
		draw_rect(Rect2(x - width * 0.30, y + 2, 4, 13), wood, true)
		draw_rect(Rect2(x + width * 0.26, y + 2, 4, 13), wood, true)
	elif point_kind == "kitchen-station":
		_draw_kitchen_station(x, y, width, height, str(point.get("station", "stove")), palette, key)
	elif kind == "shelf" or point_kind in ["shop", "storage", "archive", "tools", "mail"]:
		draw_rect(Rect2(x - width * 0.46, y - height, width * 0.92, height + 9), wood, true)
		for shelf_y in [y - height + 9, y - height * 0.47, y + 5]:
			draw_rect(Rect2(x - width * 0.43, shelf_y, width * 0.86, 4), light, true)
		for i in range(5):
			var item_x := x - width * 0.36 + i * width * 0.18
			var item_color := accent if posmod(i + key, 2) == 0 else Color("c89c64")
			draw_rect(Rect2(item_x, y - height + 13, width * 0.12, 11 + posmod(i + key, 3) * 3), item_color, true)
	elif point_kind == "cook" or "蒸" in kind or "面" in kind or "灶" in kind:
		draw_rect(Rect2(x - width * 0.45, y - 15, width * 0.9, 23), wood, true)
		draw_rect(Rect2(x - width * 0.49, y - 19, width * 0.98, 6), light, true)
		draw_rect(Rect2(x - 13, y - 17, 26, 16), Color("56634a"), true)
		draw_circle(Vector2(x, y - 11), 7, Color("e3ac5a"))
		draw_line(Vector2(x - 3, y - 27), Vector2(x, y - 34), Color("fff1cd", 0.75), 2.0)
		draw_line(Vector2(x + 4, y - 27), Vector2(x + 7, y - 35), Color("fff1cd", 0.65), 2.0)
	else:
		draw_rect(Rect2(x - width * 0.44, y - 12, width * 0.88, 20), wood, true)
		draw_rect(Rect2(x - width * 0.48, y - 17, width * 0.96, 7), light, true)
		if "苗" in kind or "花" in kind or "草" in kind:
			for i in range(3):
				var plant_x := x - 16 + i * 16
				draw_line(Vector2(plant_x, y - 17), Vector2(plant_x, y - 30 - posmod(i + key, 2) * 5), Color("668653"), 2.0)
				draw_circle(Vector2(plant_x, y - 30 - posmod(i + key, 2) * 5), 4, accent)
		elif "琴" in kind or "音" in kind or "铃" in kind:
			draw_circle(Vector2(x - 13, y - 17), 5, Color("dfc77f"))
			draw_circle(Vector2(x + 4, y - 18), 4, Color("dfc77f"))
			draw_line(Vector2(x - 8, y - 17), Vector2(x + 3, y - 34), wood.darkened(0.25), 3.0)
		elif "书" in kind or "谱" in kind or "档" in kind or "账" in kind or "相" in kind or "信" in kind:
			draw_rect(Rect2(x - 17, y - 27, 16, 19), Color("d8c391"), true)
			draw_rect(Rect2(x + 2, y - 25, 15, 17), Color("a8b39a"), true)
			draw_line(Vector2(x - 13, y - 21), Vector2(x - 4, y - 21), wood, 1.0)
			draw_line(Vector2(x + 5, y - 19), Vector2(x + 14, y - 19), wood, 1.0)
		elif "轮" in kind or "齿" in kind or "木马" in kind or "风车" in kind:
			draw_circle(Vector2(x, y - 21), 10, Color("bb9a62"))
			draw_circle(Vector2(x, y - 21), 4, Color("6f5c42"))
			for spoke in range(4):
				var angle := spoke * PI * 0.5
				draw_line(Vector2(x, y - 21), Vector2(x + cos(angle) * 9, y - 21 + sin(angle) * 9), wood, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(x - (width + 20) * 0.5, y + 23), _furniture_label(kind), HORIZONTAL_ALIGNMENT_CENTER, width + 20, 10, Color("fff0d4"))
	if point_kind == "kitchen-station":
		_draw_station_status(point, Vector2(x, y))

func _furniture_label(kind: String) -> String:
	return str({"table":"茶桌","chair":"木椅","shelf":"置物架","bed":"床铺","stove":"灶台","mill":"石磨","cabinet":"储物柜","bench":"长凳","desk":"书桌","lamp":"灯"}.get(kind,kind.substr(0,10)))

func _draw_museum_case(x: float, y: float, width: float, _height: float, slot: int) -> void:
	var groups: Array[String] = ["物产", "文物", "民俗", "生物"]
	var group := groups[slot]
	var unlocked := slot <= int(GameState.collection.get("level", 0))
	var key := str(GameState.collection.get("featured", {}).get(group, "")) if unlocked else ""
	var entry := GameState._museum_entry(key)
	var case_width := width * 0.84
	_draw_oval(Rect2(x - case_width * 0.46, y + 5, case_width * 0.92, 12), Color("34463d", 0.3))
	draw_rect(Rect2(x - case_width * 0.50, y - 13, case_width, 13), Color("785a3e"), true)
	draw_rect(Rect2(x - case_width * 0.46, y - 15, case_width * 0.92, 4), Color("d7bd84"), true)
	draw_rect(Rect2(x - case_width * 0.44, y - 48, case_width * 0.88, 31), Color("a9c6bd", 0.62 if unlocked else 0.28), true)
	draw_rect(Rect2(x - case_width * 0.44, y - 48, case_width * 0.88, 31), Color("e6d3a5", 0.9), false, 2.0)
	draw_rect(Rect2(x - case_width * 0.41, y - 18, case_width * 0.82, 3), Color("e7d6ae"), true)
	if not unlocked:
		INTERIOR_ART.draw_furniture(self,{"kind":"shelf","x":x,"y":y,"w":case_width,"h":42,"visualHeight":68},GameState.minutes,{})
		draw_string(ThemeDB.fallback_font, Vector2(x-case_width*0.5, y - 29), "修缮后开放", HORIZONTAL_ALIGNMENT_CENTER, case_width, 9, Color("73684f"))
	elif entry.is_empty():
		draw_circle(Vector2(x, y - 34), 5, Color("c5b98d"))
		draw_string(ThemeDB.fallback_font, Vector2(x, y - 22), "等待入藏", HORIZONTAL_ALIGNMENT_CENTER, case_width, 9, Color("5b695a"))
	else:
		var item_type := str(entry.get("type", ""))
		var art_y := y - 33.0
		if item_type == "archive" or str(entry.get("id", "")).begins_with("archive:"):
			draw_rect(Rect2(x - 13, art_y - 8, 26, 16), Color("c8a96d"), true)
			draw_rect(Rect2(x - 9, art_y - 5, 18, 10), Color("efe1bd"), true)
			draw_line(Vector2(x - 6, art_y - 1), Vector2(x + 6, art_y - 1), Color("8b7650"), 1.0)
			draw_line(Vector2(x - 6, art_y + 3), Vector2(x + 3, art_y + 3), Color("8b7650"), 1.0)
		elif item_type == "npc":
			draw_rect(Rect2(x - 11, art_y - 10, 22, 19), Color("8a7657"), true)
			draw_circle(Vector2(x, art_y - 5), 5, Color("e7c69b"))
			draw_rect(Rect2(x - 7, art_y + 1, 14, 7), Color("6d8a79"), true)
		elif item_type == "wild":
			draw_circle(Vector2(x, art_y), 4, Color("d4b85c"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2, art_y), Vector2(x - 19, art_y - 8), Vector2(x - 13, art_y + 2)]), Color("6d9868"))
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2, art_y), Vector2(x + 19, art_y - 8), Vector2(x + 13, art_y + 2)]), Color("88a977"))
		else:
			var item_id := str(entry.get("id", ""))
			if GameState.system_catalog.get("fishing", {}).get("species", {}).has(item_id):
				_draw_oval(Rect2(x - 13, art_y - 5, 26, 11), Color("84a8a0"))
				draw_colored_polygon(PackedVector2Array([Vector2(x + 12, art_y), Vector2(x + 21, art_y - 7), Vector2(x + 21, art_y + 7)]), Color("d4b26b"))
				draw_circle(Vector2(x - 6, art_y - 1), 1.4, Color("f4edcf"))
			else:
				var crop_color := Color("c66e54") if posmod(item_id.hash(), 3) == 0 else Color("d7b85e") if posmod(item_id.hash(), 3) == 1 else Color("78a16a")
				draw_circle(Vector2(x, art_y), 8, crop_color)
				draw_line(Vector2(x, art_y - 7), Vector2(x + 3, art_y - 13), Color("66864f"), 2.0)
		var item_name := str(entry.get("name", key))
		draw_string(ThemeDB.fallback_font, Vector2(x, y - 17), item_name.substr(0, 8), HORIZONTAL_ALIGNMENT_CENTER, case_width, 8, Color("493d30"))
	var donation: Dictionary = GameState.collection.get("donated", {}).get(key, {})
	var grade := int(donation.get("grade", 0))
	var grade_label: String = " · " + ["普通", "优质", "上品", "珍品"][clampi(grade, 0, 3)] if str(donation.get("mode", "")) == "sample" else " · 资料" if not donation.is_empty() else ""
	draw_string(ThemeDB.fallback_font, Vector2(x, y + 14), group + grade_label, HORIZONTAL_ALIGNMENT_CENTER, width + 12, 9, Color("fff0cd"))
	if unlocked:
		draw_string(ThemeDB.fallback_font, Vector2(x, y + 27), GameState.interaction_input_label()+" · 查看展品", HORIZONTAL_ALIGNMENT_CENTER, width + 12, 8, Color("c7d3ae"))

func _draw_kitchen_station(x: float, y: float, width: float, _height: float, station: String, palette: Array, key: int) -> void:
	var wood := Color("806445")
	var light := Color(str(palette[1]))
	var accent := Color(str(palette[0]))
	var body := Rect2(x - width * 0.44, y - 17, width * 0.88, 25)
	match station:
		"stove", "steam", "preserve":
			draw_rect(body, wood, true)
			draw_rect(Rect2(body.position.x - 4, body.position.y - 5, body.size.x + 8, 6), light, true)
			var burner_count := 3 if station == "steam" else 2
			for i in range(burner_count):
				var burner_x := x - float(burner_count - 1) * 13 + float(i) * 26
				draw_rect(Rect2(burner_x - 9, y - 15, 18, 14), Color("53634f"), true)
				draw_circle(Vector2(burner_x, y - 8), 5, Color("e9af56"))
			if station == "steam":
				for tier in range(3):
					draw_rect(Rect2(x - 29 + tier * 2, y - 50 + tier * 9, 58 - tier * 4, 8), Color("b99660") if tier % 2 == 0 else Color("d0b37b"), true)
			elif station == "preserve":
				draw_circle(Vector2(x, y - 25), 14, Color("ae8050"))
				draw_circle(Vector2(x, y - 25), 9, Color("cfaa66"))
				draw_rect(Rect2(x - 17, y - 41, 34, 5), Color("75583c"), true)
		"mill":
			draw_rect(Rect2(x - 36, y - 14, 72, 24), wood, true)
			draw_rect(Rect2(x - 43, y - 39, 86, 25), Color("8f9b8a"), true)
			draw_circle(Vector2(x, y - 38), 43, Color("bbc0ad"))
			draw_circle(Vector2(x, y - 39), 29, Color("899486"))
			draw_circle(Vector2(x, y - 39), 7, light)
		"press":
			for side in [-1.0, 1.0]: draw_rect(Rect2(x + side * 40 - 4, y - 52, 8, 61), wood, true)
			draw_rect(Rect2(x - 48, y - 55, 96, 8), light.darkened(0.12), true)
			draw_rect(Rect2(x - 5, y - 47, 10, 34), Color("685a41"), true)
			draw_rect(Rect2(x - 31, y - 17, 62, 23), Color("a17d4f"), true)
			draw_circle(Vector2(x + 37, y - 1), 8, Color("c5aa6c"))
		"dry", "dairy":
			for side in [-1.0, 1.0]: draw_rect(Rect2(x + side * 43 - 3, y - 54, 6, 63), wood, true)
			for tier in range(3):
				var shelf_y := y - 42 + tier * 21
				draw_rect(Rect2(x - 48, shelf_y, 96, 4), light, true)
				for item in range(4):
					var item_x := x - 39 + item * 21
					if station == "dry":
						draw_rect(Rect2(item_x, shelf_y - 11, 14, 10), Color("b88b54") if posmod(item + tier, 2) == 0 else accent, true)
					else:
						draw_rect(Rect2(item_x + 2, shelf_y - 13, 10, 12), Color("e7e0ca"), true)
						draw_rect(Rect2(item_x + 1, shelf_y - 14, 12, 3), accent, true)
		"compost":
			draw_rect(Rect2(x - 41, y - 24, 82, 32), Color("78613f"), true)
			for band in range(4): draw_rect(Rect2(x - 45, y - 23 + band * 8, 90, 3), Color("b5975c"), true)
			for sprout in range(5):
				var sx := x - 28 + sprout * 14
				draw_line(Vector2(sx, y - 24), Vector2(sx + 2, y - 34 - posmod(sprout + key, 3) * 3), Color("708b51"), 2)
		"pickle", "ferment":
			for jar in range(3):
				var jar_x := x - 29 + jar * 29
				draw_rect(Rect2(jar_x - 10, y - 32, 20, 37), Color("a87954") if station == "pickle" else Color("9a7547"), true)
				draw_rect(Rect2(jar_x - 12, y - 35, 24, 5), Color("d0b780"), true)
				draw_rect(Rect2(jar_x - 8, y - 17, 16, 3), Color("6b5d41"), true)
				if station == "ferment": draw_circle(Vector2(jar_x, y - 22), 3, Color("c8a954"))
		_:
			draw_rect(body, wood, true)
			draw_rect(Rect2(body.position.x - 3, body.position.y - 5, body.size.x + 6, 6), light, true)
	for leg_x in [x - width * 0.33, x + width * 0.33]: draw_rect(Rect2(leg_x, y + 4, 5, 10), wood.darkened(0.2), true)

func _draw_station_status(point: Dictionary, at: Vector2) -> void:
	var station := str(point.get("station", ""))
	var running := false
	var ready := false
	for job in GameState.kitchen.get("jobs", []):
		if str(job.get("station", "")) != station: continue
		running = true
		if int(job.get("ready", 0)) <= GameState._kitchen_now(): ready = true
	if running:
		draw_rect(Rect2(at.x - 21, at.y - 56, 42, 5), Color("526354"), true)
		draw_rect(Rect2(at.x - 19, at.y - 54, 38, 2), Color("f1ce72") if ready else Color("8db5a0"), true)
		draw_string(ThemeDB.fallback_font, Vector2(at.x, at.y - 59), "可收取" if ready else "加工中", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("fff0cf"))

func _draw_oval(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(Vector2(rect.get_center().x + cos(angle) * rect.size.x * 0.5, rect.get_center().y + sin(angle) * rect.size.y * 0.5))
	draw_colored_polygon(points, color)

func _sync_room_animals() -> void:
	var living: Dictionary = {}
	for index: int in range(GameState.animals.size()):
		var animal: Dictionary = GameState.animals[index]
		var position_data: Dictionary = animal.get("position",{})
		if position_data.get("room") == null or str(position_data.room) != GameState.current_interior: continue
		var id := str(animal.id); living[id] = true
		var node: Node2D = room_animal_nodes.get(id)
		if node == null:
			node = Node2D.new();node.set_script(load("res://scripts/ranch_animal.gd"));node.inside_room=GameState.current_interior
			room_animal_nodes[id]=node;add_child(node)
		node.animal_index=index
		var at: Dictionary=position_data.get("inside",{})
		node.position=Vector2(float(at.get("x",480)),float(at.get("y",490)));node.queue_redraw()
	for id: String in room_animal_nodes.keys():
		if not living.has(id):room_animal_nodes[id].queue_free();room_animal_nodes.erase(id)

func _draw_home_layout() -> void:
	var zone: Dictionary = GameState.system_catalog.get("building", {}).get("zones", {}).get("home", {})
	var cols := int(zone.get("cols", 14))
	var size := float(zone.get("size", 44))
	var furniture: Dictionary = GameState.content.get("furniture", {})
	for piece in GameState.building.get("layout", []):
		if str(piece.get("zone", "")) != "home": continue
		var definitions: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {})
		var definition: Dictionary = definitions.get(str(piece.get("type", "")), {})
		var rotation := posmod(int(piece.get("rotation", 0)), 4)
		var width := int(definition.get("w", 1)) if rotation % 2 == 0 else int(definition.get("h", 1))
		var height := int(definition.get("h", 1)) if rotation % 2 == 0 else int(definition.get("w", 1))
		var cell := int(piece.cell)
		var rect := Rect2(float(zone.x) + (cell % cols) * size, float(zone.y) + int(cell / cols) * size, width * size, height * size)
		var data: Dictionary = furniture.get(str(piece.type), {})
		var color := Color(str(data.get("color", "#a9895d")))
		_draw_furniture(piece, rect, color, str(data.get("name", piece.type)))

func _draw_furniture(piece: Dictionary, rect: Rect2, color: Color, name: String) -> void:
	var type := str(piece.get("type", ""))
	var art_kind: String = {"teaTable":"table","bookshelf":"shelf","cabinet":"shelf","workbench":"table","display":"shelf","seedrack":"育苗盘","pot":"花盆","flowerbed":"花盆","lantern":"lamp","stoneLantern":"lamp"}.get(type, "")
	if art_kind != "":
		var row := {"kind":art_kind,"x":rect.get_center().x,"y":rect.end.y-9.0,"w":rect.size.x-8.0,"h":rect.size.y-18.0,"visualHeight":rect.size.y+12.0}
		if INTERIOR_ART.draw_furniture(self,row,GameState.minutes,selected_room_target):
			draw_string(ThemeDB.fallback_font,Vector2(rect.position.x,rect.end.y+12),name.substr(0,8),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,10,Color("fff0d4"))
			if type == "display" and str(GameState.building.get("showcase","")) != "":
				var label := str(GameState.item_catalog.get(str(GameState.building.showcase),{}).get("name",GameState.building.showcase))
				draw_string(ThemeDB.fallback_font,Vector2(rect.position.x,rect.position.y-4),label.substr(0,8),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,10,Color("fff0bd"))
			return
	var inset := rect.grow(-4.0)
	draw_rect(inset, Color("39493e", 0.3), true)
	if type in ["pot", "flowerbed", "seedrack", "waterbed"]:
		draw_rect(Rect2(inset.position.x, inset.position.y + inset.size.y * 0.55, inset.size.x, inset.size.y * 0.32), color.darkened(0.18), true)
		for i in range(3):
			var px := inset.position.x + inset.size.x * (0.25 + i * 0.25)
			draw_line(Vector2(px, inset.position.y + inset.size.y * 0.68), Vector2(px, inset.position.y + inset.size.y * 0.22), Color("698b55"), 3.0)
			draw_circle(Vector2(px, inset.position.y + inset.size.y * 0.24), 5.0, Color("d69386") if type == "flowerbed" else Color("8eaa68"))
	elif type in ["lantern", "stoneLantern"]:
		draw_rect(Rect2(inset.get_center().x - 3, inset.position.y + 3, 6, inset.size.y - 7), color.darkened(0.3), true)
		draw_rect(Rect2(inset.position.x + 4, inset.position.y + 4, inset.size.x - 8, 15), color, true)
		draw_circle(inset.get_center(), 12, Color("f3d08b", 0.72))
	elif type in ["well", "orchard", "greenhouse"]:
		draw_rect(Rect2(inset.position.x + inset.size.x * 0.12, inset.position.y + inset.size.y * 0.55, inset.size.x * 0.76, inset.size.y * 0.28), color, true)
		draw_rect(Rect2(inset.position.x + inset.size.x * 0.08, inset.position.y + inset.size.y * 0.46, inset.size.x * 0.84, 6), color.lightened(0.24), true)
		draw_arc(inset.get_center(), minf(inset.size.x, inset.size.y) * 0.25, 0, TAU, 32, Color("83a89b"), 3.0)
	else:
		draw_rect(Rect2(inset.position.x + 3, inset.position.y + inset.size.y * 0.22, inset.size.x - 6, inset.size.y * 0.52), color, true)
		draw_rect(Rect2(inset.position.x + 1, inset.position.y + inset.size.y * 0.17, inset.size.x - 2, 5), color.lightened(0.25), true)
		draw_line(Vector2(inset.position.x + 7, inset.end.y - 2), Vector2(inset.position.x + 7, inset.end.y - 8), color.darkened(0.2), 3.0)
		draw_line(Vector2(inset.end.x - 7, inset.end.y - 2), Vector2(inset.end.x - 7, inset.end.y - 8), color.darkened(0.2), 3.0)
	if type == "display" and str(GameState.building.get("showcase", "")) != "":
		var display_id := str(GameState.building.showcase)
		var display_name := str(GameState.item_catalog.get(display_id, {}).get("name", display_id))
		draw_string(ThemeDB.fallback_font, Vector2(rect.get_center().x, rect.position.y + 13), display_name.substr(0, 8), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 10, Color("fff0bd"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.get_center().x, rect.end.y - 5), name.substr(0, 5), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 6, 10, Color("fff2d3"))

func _sync_furniture_collisions() -> void:
	var revision := int(GameState.building.get("revision", 0))
	if revision == collision_revision or not is_instance_valid(collision_root): return
	collision_revision = revision
	for child in collision_root.get_children(): child.queue_free()
	if current_interior_house_id() != _grandfather_house_id(): return
	var zone: Dictionary = GameState.system_catalog.get("building", {}).get("zones", {}).get("home", {})
	var definitions: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {})
	var cols := int(zone.get("cols", 14))
	var size := float(zone.get("size", 44))
	for piece in GameState.building.get("layout", []):
		if str(piece.get("zone", "")) != "home" or not bool(definitions.get(str(piece.type), {}).get("solid", false)): continue
		var def: Dictionary = definitions[str(piece.type)]
		var rotation := posmod(int(piece.get("rotation", 0)), 4)
		var width := int(def.get("w", 1)) if rotation % 2 == 0 else int(def.get("h", 1))
		var height := int(def.get("h", 1)) if rotation % 2 == 0 else int(def.get("w", 1))
		var cell := int(piece.cell)
		var body := StaticBody2D.new()
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width * size - 8, height * size - 8)
		collider.shape = shape
		body.position = Vector2(float(zone.x) + (cell % cols + width * 0.5) * size, float(zone.y) + (int(cell / cols) + height * 0.5) * size)
		body.add_child(collider)
		collision_root.add_child(body)

func _grandfather_house_id() -> String:
	for house in GameState.world_village.get("houses", []):
		if str(house.get("name", "")) == "爷爷的老屋": return str(house.get("id", ""))
	return ""

func current_interior_house_id() -> String:
	return GameState.current_interior

func _refresh() -> void:
	_sync_room_animals()
	_sync_furniture_collisions()
	queue_redraw()
	if not is_instance_valid(player): return
	if owner_npc != null and is_instance_valid(owner_npc): owner_npc.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		hud.call("handle_source_key",event)


func _pointer_leave() -> void:
	pointer_screen=null
	pointer_hover.clear()
	interaction_presentation_changed.emit()
	queue_redraw()

func _refresh_pointer_hover() -> void:
	if pointer_screen==null or GameState.ui_open:return
	if get_viewport().gui_get_hovered_control()!=null:
		_pointer_leave()
		return
	var at:Vector2=get_viewport().get_canvas_transform().affine_inverse()*Vector2(pointer_screen)
	var previous := pointer_hover
	pointer_hover=interaction_selection.hit(at,_room_target_candidates())
	if previous != pointer_hover: interaction_presentation_changed.emit()

func _hover_pointer(at:Vector2) -> void:
	pointer_screen=at
	_hover_at(get_viewport().get_canvas_transform().affine_inverse()*at)
	interaction_presentation_changed.emit()

func _hover_at(at: Vector2) -> void:
	interaction_selection.manual = ""
	pointer_hover = interaction_selection.hit(at,_room_target_candidates())
	_refresh_room_target()

func _click_at(at: Vector2,mode:String="keyboard") -> void:
	GameState.set_source_input_mode(mode)
	if GameState.ui_open or GameState.action_busy(): return
	# Source pointerdown replaces pending work before hit-testing, even a near hit.
	GameState._interrupt_navigation_for_ui()
	GameState.sound_requested.emit("soft")
	var target: Dictionary = interaction_selection.hit(at,_room_target_candidates()).duplicate(true)
	pointer_hover = target.duplicate(true)
	interaction_selection.manual = ""
	if not target.is_empty() and player.global_position.distance_to(Vector2(float(target.x),float(target.y))) < 53.0:
		_activate_walk_target(target)
		return
	if target.is_empty(): target = {"kind":"walk","id":"ground-click","name":"这处落点","x":at.x,"y":at.y}
	target.world_click = true
	target.click_room = GameState.current_interior
	target.auto_interact = str(target.get("kind","")) != "walk"
	player.call("walk_to",target)

func resolve_interaction_target(target: Dictionary) -> Dictionary:
	var identity := interaction_selection.target_key(target)
	for current in _room_target_candidates():
		if interaction_selection.target_key(current) == identity: return current
	return {}

func _activate_walk_target(target: Dictionary) -> void:
	if GameState.ui_open or str(target.get("click_room",GameState.current_interior)) != GameState.current_interior: return
	var current := resolve_interaction_target(target)
	if current.is_empty() or player.global_position.distance_to(Vector2(float(current.x),float(current.y))) >= 53.0:
		GameState.message = "目标已离开手边，请重新走近。"
		GameState.changed.emit()
		return
	_refresh_room_target()
	interaction_selection.manual = interaction_selection.target_key(current)
	pointer_hover = current
	_interact()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_click_at(get_viewport().get_canvas_transform().affine_inverse()*event.position,"touch")
		get_viewport().set_input_as_handled()
		return
	# Godot's emulated mouse event represents the same touch, not a second click.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1:return
	if not GameState.ui_open:
		if event is InputEventMouseMotion:
			_hover_pointer(event.position)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_click_at(get_viewport().get_canvas_transform().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
			return

func _inside_main_kitchen() -> bool:
	return str(GameState.interior_house().get("name", "")) == "禾溪小灶" or bool(GameState.upgrades.get("kitchen", false))

func interact_from_gamepad() -> void:
	if GameState.ui_open or GameState.action_busy():return
	var target:Dictionary=_refresh_room_target()
	if not target.is_empty():_interact_target(target)

func _interact() -> void:
	if GameState.ui_open or GameState.action_busy():return
	if GameState.interior_position!=player.global_position:GameState.interior_position=player.global_position
	var target := _refresh_room_target()
	if target.is_empty():
		GameState.message = "走近屋里的物件或居民，再按 " + OS.get_keycode_string(GameState.bound_key("interact",KEY_E)) + "。"
		GameState.changed.emit()
		return
	_interact_target(target)

func _interact_target(target: Dictionary,performed: bool=false) -> void:
	if GameState.ui_open or GameState.action_busy() or target.is_empty():return
	if not performed and GameState.begin_point_action(target,_interact_target.bind(target.duplicate(true),true)):return
	if str(target.get("kind","")) in ["ranch-box","ranch-product","ranch-trough"]:
		GameState.confirm_operation(GameState.ranch_fixture_action(str(target.kind),str(target.id)))
		return
	match str(target.get("kind","")):
		"exit": GameState.leave_interior()
		"animal":
			var index := GameState.ranch_animal_index(str(target.id))
			var action := GameState.ranch_default_action(index) if GameState.selected_animal_action == "auto" else GameState.selected_animal_action
			GameState.queue_ranch_tasks([{"animalId":str(target.id),"action":action,"arg":str(GameState.ranch.get("feed","feed"))}])
		"npc":
			var actual:=resolve_interaction_target(target)
			if actual.is_empty():return
			if player.global_position.distance_to(Vector2(float(actual.x),float(actual.y)))>70.0:
				actual.world_click=true
				actual.click_room=GameState.current_interior
				actual.auto_interact=true
				player.walk_to(actual)
				return
			GameState.confirm_operation(GameState.talk_to_npc(str(target.get("id",""))),"soft",false)
			hud.call("show_npc_dialogue",str(target.get("id","")))
		_: _use_room_point(target)

func _room_target_candidates() -> Array:
	var points: Array = _room_points().duplicate(true)
	points.append_array(preload("res://scripts/ranch_products.gd").points(GameState,GameState.current_interior))
	for animal in GameState.animals:
		var position_data: Dictionary = animal.get("position",{})
		if position_data.get("room") == null or str(position_data.room) != GameState.current_interior: continue
		var inside: Dictionary = position_data.get("inside",{})
		points.append({"kind":"animal","id":str(animal.id),"name":str(animal.name),"x":float(inside.get("x",480)),"y":float(inside.get("y",490))})
	points.append_array(_home_furniture_points())
	for npc in resident_nodes.values():
		if npc != null and is_instance_valid(npc):
			points.append({"kind":"npc","id":str(npc.get("npc_id")),"name":GameState.npc_name(str(npc.get("npc_id"))),"x":npc.global_position.x,"y":npc.global_position.y})
	return points

func _target_ready(point: Dictionary,tool: String) -> bool:
	return bool(INTERACTION_DESCRIPTION.describe(GameState,point,tool).get("ready",false))

func _refresh_room_target() -> Dictionary:
	if not is_instance_valid(player): return {}
	if selection_tool != GameState.selected_tool:
		interaction_selection.clear()
		selection_tool = GameState.selected_tool
	var facing: Vector2 = {"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(GameState.player_direction,Vector2.DOWN)
	var previous: Dictionary = selected_room_target
	selected_room_target = interaction_selection.choose(player.global_position,facing,_room_target_candidates(),pointer_hover,GameState.selected_tool,current_interior_house_id(),_target_ready)
	if interaction_selection.target_key(previous) != interaction_selection.key or previous.get("x",0) != selected_room_target.get("x",0) or previous.get("y",0) != selected_room_target.get("y",0):
		interaction_presentation_changed.emit()
		queue_redraw()
	return selected_room_target

func _cycle_room_target(direction: int) -> void:
	pointer_screen=null
	pointer_hover.clear()
	_refresh_room_target()
	selected_room_target = interaction_selection.cycle(direction)
	if not selected_room_target.is_empty():
		GameState.message = "当前目标：" + str(selected_room_target.get("name","屋内物件"))
		GameState.changed.emit()
	queue_redraw()

func _nearby_layout_point(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 62.0
	for point in _room_points():
		if not point is Dictionary or str(point.get("kind", "")) == "exit": continue
		var distance := at.distance_to(Vector2(float(point.get("x", 480)), float(point.get("y", 350))))
		if distance < best_distance:
			best_distance = distance
			best = point
	return best

func _use_room_point(point: Dictionary) -> void:
	var kind := str(point.get("kind", ""))
	if current_interior_house_id() == "building-river-10" and kind == "egg":
		GameState.inspect_point_with_sound(point)
		_open_museum_exhibit(int(point.get("index", 0)))
		return
	match kind:
		"egg": GameState.inspect_point_with_sound(point)
		"chore":
			if str(point.get("action", "")) == "churn": GameState.queue_kitchen_task({"op":"process","id":"cream","n":1,"station":"dairy"})
			else: GameState.confirm_operation(GameState.perform_interior_chore(point),"good",false)
		"tea", "bed-visit":
			GameState.sound_requested.emit("soft")
			GameState.stamina = minf(100.0, GameState.stamina + 8.0)
			GameState.message = "倒一杯热茶，暖一暖手。" if kind == "tea" else "把坐垫抚平，再轻轻放回原位。"
			GameState.changed.emit()
		"sleep":
			hud.call("show_sleep")
		"kitchen-station":
			var station := str(point.get("station", "stove"))
			hud.call("show_kitchen", true, "cook" if station in ["stove", "steam"] else "process", station)
		"shop": hud.call("show_market", "buy", true, "shop")
		"cook": hud.call("show_kitchen", true, "cook")
		"mail": _show_room_mail()
		"stories": hud.call("show_neighbors")
		"rest": GameState.confirm_operation(GameState.rest_at_home())
		"tools": hud.call("show_tools", current_interior_house_id() != _grandfather_house_id())
		"storage": hud.call("show_kitchen", false, "pantry")
		"build": _show_building()
		"build-piece": _use_furniture(str(point.get("type","")))
		"animals": hud.call("show_ranch")
		"economy": hud.call("show_market", "business", true, "coop")
		"farmcare": hud.call("show_farm_planner", false, 0)
		"archive": hud.call("show_museum", "donate" if str(GameState.interior_house().get("name", "")).contains("村史馆") else "catalog")
		"catalog": hud.call("show_museum", "catalog")
		_:
			GameState.message = str(point.get("name", "屋里的旧物"))
			GameState.changed.emit()

func _open_museum_exhibit(slot: int) -> void:
	var groups: Array[String] = ["物产", "文物", "民俗", "生物"]
	if slot < 0 or slot >= groups.size(): return
	if slot > int(GameState.collection.get("level", 0)):
		GameState.message = "这组展柜还在修缮中。完成村史馆升级后，可以开放%s展区。" % groups[slot]
		GameState.changed.emit()
		return
	var group := groups[slot]
	var key := str(GameState.collection.get("featured", {}).get(group, ""))
	if key == "":
		GameState.message = "%s展柜暂时空着。先登记同类藏品，再选一件设为常设展品。" % group
		GameState.changed.emit()
		hud.call("show_museum", "donate")
		return
	hud.call("show_museum", "catalog", key)

func _show_room_mail() -> void:
	hud.call("show_mail")

func _show_building() -> void:
	var sites: Dictionary = {}
	for project in GameState.system_catalog.get("building", {}).get("projects", {}).values():
		var house_name := str(project.get("house", ""))
		if house_name != "": sites[house_name] = GameState.is_near_building(house_name)
	sites["农具间"] = GameState.is_near_building("农具间")
	hud.call("show_building", sites, str(GameState.interior_house().get("name", "")) == "爷爷的老屋")

func _nearby_service_piece(at: Vector2) -> Dictionary:
	if current_interior_house_id() != _grandfather_house_id(): return {}
	var zone: Dictionary = GameState.system_catalog.get("building", {}).get("zones", {}).get("home", {})
	var definitions: Dictionary = GameState.system_catalog.get("building", {}).get("defs", {})
	var best: Dictionary = {}
	var best_distance := 80.0
	for piece in GameState.building.get("layout", []):
		if str(piece.get("zone", "")) != "home": continue
		var definition: Dictionary = definitions.get(str(piece.get("type", "")), {})
		if str(definition.get("service", "")) == "": continue
		var cols := int(zone.get("cols", 14))
		var cell := int(piece.cell)
		var size := float(zone.get("size", 44))
		var point := Vector2(float(zone.x) + (cell % cols + float(definition.get("w", 1)) * 0.5) * size, float(zone.y) + (int(cell / cols) + float(definition.get("h", 1)) * 0.5) * size)
		var distance := at.distance_to(point)
		if distance < best_distance: best_distance = distance; best = piece
	return best

func _use_furniture(type: String) -> void:
	var service := str(GameState.system_catalog.get("building", {}).get("defs", {}).get(type, {}).get("service", ""))
	match service:
		"rest": GameState.confirm_operation(GameState.rest_at_home())
		"water": GameState.confirm_operation(GameState.fill_farm_water())
		"tools": hud.call("show_tools", false)
		"storage": hud.call("show_kitchen", false, "pantry")
		"farmcare": hud.call("show_farm_planner", false, 0)
		"archive": hud.call("show_museum", "catalog")
		"catalog": hud.call("show_museum", "catalog")
		_: GameState.message = "你仔细看了看这件家具。"; GameState.sound_requested.emit("soft"); GameState.changed.emit()

func _match_room_use() -> void:
	match str(GameState.building.get("roomUse", "display")):
		"display": hud.call("show_museum", "catalog")
		"workshop": hud.call("show_tools", false)
		"nursery": hud.call("show_farm_planner", false, 0)
		"storage": hud.call("show_kitchen", false, "pantry")

func _painted_wood_floor(layout:Dictionary,style_id:String)->bool:
	if not (layout.is_empty() and style_id=="wood" or str(layout.get("floor",""))=="木纹"):return false
	var entry:Dictionary=preload("res://scripts/world_art.gd").entries().get("interior_surfaces/wood",{})
	if not bool(entry.get("baseReady",false)):return false
	var texture:=preload("res://scripts/character_art.gd").texture(str(entry.get("path","")))
	if texture==null:return false
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	draw_texture_rect(texture,Rect2(112,198,736,394),true,Color(0.82,0.85,0.78))
	return true
