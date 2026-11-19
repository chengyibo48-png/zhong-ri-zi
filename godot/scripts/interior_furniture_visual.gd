extends Node2D
## A single floor anchor gives each furnishing real Y sorting against residents.
const INTERIOR_ART := preload("res://scripts/interior_art.gd")
var world: Node2D
var row: Dictionary = {}
var palette: Array = []
var layout_key := 0
var custom_piece: Dictionary = {}
var custom_rect := Rect2()
var custom_name := ""
var life_tween:Tween
var life_redraw_at:int=0
var selected_room_target: Dictionary:
	get: return world.selected_room_target if is_instance_valid(world) else {}
func configure(owner_world: Node2D, source: Dictionary, colors: Array, key: int) -> void:
	world=owner_world;row=source.duplicate(true);palette=colors;layout_key=key
	position=Vector2(float(row.get("x",480)),float(row.get("sortY",float(row.get("y",350))+9)))
	row.x=0.0;row.y=float(source.get("y",350))-position.y
	set_meta("floor_anchor",position)
	queue_redraw()
func _ready() -> void:
	_life_refresh(false)
	GameState.domain_changed.connect(func(domain:String):
		if domain=="household":_life_refresh(true))
	GameState.clock_changed.connect(queue_redraw)
	GameState.world_changed.connect(queue_redraw)
	world.interaction_presentation_changed.connect(queue_redraw)
	GameState.action_sequence_changed.connect(func(_value: Dictionary):queue_redraw())
func _life_refresh(animate:bool)->void:
	var room:String=GameState.current_interior
	for fixture:Dictionary in preload("res://scripts/house_geometry.gd").profile(room).get("fixtures",[]):
		if str(fixture.get("furniture",""))!=str(row.get("id","")) or str(fixture.type)!="cupboard":continue
		var goal:float=1.0 if preload("res://scripts/house_life.gd").state(GameState,room,str(fixture.id)) else 0.0
		if is_instance_valid(life_tween):life_tween.kill()
		if animate and preload("res://scripts/life_presentation.gd").animate():
			life_tween=create_tween();life_tween.tween_method(_life_tick,float(get_meta("life_open",goal)),goal,.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);life_tween.finished.connect(queue_redraw)
		else:set_meta("life_open",goal);queue_redraw()
func _life_tick(value:float)->void:
	set_meta("life_open",value)
	if Time.get_ticks_msec()-life_redraw_at>=42:life_redraw_at=Time.get_ticks_msec();queue_redraw()
func current_interior_house_id() -> String: return world.current_interior_house_id()
func _grandfather_house_id() -> String: return world._grandfather_house_id()
func _draw() -> void:
	if custom_piece.is_empty():
		_draw_room_furniture(row,palette,layout_key)
	else: _draw_furniture(custom_piece,custom_rect,Color("a9895d"),custom_name)
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
	var visual_row:Dictionary=row
	if bool(row.get("supportSurface",false)):
		_draw_support_surface(row)
		visual_row=row.duplicate(true);visual_row.y=float(row.y)-20;visual_row.visualHeight=48.0
	if INTERIOR_ART.draw_furniture(self, visual_row, GameState.minutes, selected_room_target):
		preload("res://scripts/house_life_visual.gd").tabletop(self,row)
		preload("res://scripts/house_life_visual.gd").fixture_overlay(self,row)
		if _focused(row): draw_string(ThemeDB.fallback_font, Vector2(x - (width + 20) * 0.5, y + 23), _furniture_label(kind), HORIZONTAL_ALIGNMENT_CENTER, width + 20, 10, Color("fff0d4"))
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
	if _focused(row): draw_string(ThemeDB.fallback_font, Vector2(x - (width + 20) * 0.5, y + 23), _furniture_label(kind), HORIZONTAL_ALIGNMENT_CENTER, width + 20, 10, Color("fff0d4"))
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


func _draw_furniture(piece: Dictionary, rect: Rect2, color: Color, name: String) -> void:
	if preload("res://scripts/built_furniture_art.gd").draw(self, piece, rect, GameState.minutes, int(selected_room_target.get("piece", -1)) == int(piece.get("key", 0))): return
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


func _focused(value: Dictionary) -> bool:
	var point: Dictionary=value.get("point",{})
	return not point.is_empty() and str(point.get("id",""))==str(selected_room_target.get("id","!"))

func _draw_support_surface(source:Dictionary)->void:
	var x:float=float(source.x);var y:float=float(source.y);var w:float=float(source.w)*.92
	var wood:Color=Color("a07d51").lerp(Color("675640"),preload("res://scripts/world_art.gd").night_factor(GameState.minutes)*.35)
	for sign:float in [-1,1]:
		var leg:float=x+sign*w*.36
		draw_colored_polygon(PackedVector2Array([Vector2(leg-3,y-9),Vector2(leg+3,y-9),Vector2(leg+2,y+9),Vector2(leg-3,y+9)]),wood.darkened(.22))
	draw_colored_polygon(PackedVector2Array([Vector2(x-w*.5,y-20),Vector2(x+w*.5,y-20),Vector2(x+w*.53,y-12),Vector2(x-w*.53,y-12)]),wood.lightened(.16))
	draw_rect(Rect2(x-w*.53,y-12,w*1.06,5),wood.darkened(.12))
	draw_line(Vector2(x-w*.45,y-17),Vector2(x+w*.43,y-17),wood.lightened(.27),1,true)
