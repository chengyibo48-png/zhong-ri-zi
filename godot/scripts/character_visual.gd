extends Node2D

var character_key := ""
var painted_active := false
var character_data: Dictionary = {}
var appearance: Dictionary = {}
var facing := Vector2.DOWN
var walking := false
var riding := false
var working := false
var walk_clock := 0.0
var last_step := 0
var last_animation_frame := -1
var redraw_count := 0
var fishing_state := "idle"
var fishing_tension := 0.0
var action_state := ""
var action_elapsed := 0.0
var action_duration := 0.8
var sequence_managed := false
var sequence_snapshot: Dictionary = {}
const PAINTED_ART := preload("res://scripts/character_art.gd")
const ACTION_ART := preload("res://scripts/action_art.gd")
const ITEM_ICON_SCRIPT := preload("res://scripts/item_icon.gd")
var action_icon: Control
var wardrobe: Node2D

func _ready() -> void:
 action_icon = ITEM_ICON_SCRIPT.new()
 action_icon.hide()
 add_child(action_icon)
 wardrobe = preload("res://scripts/painted_wardrobe.gd").new()
 wardrobe.hide()
 add_child(wardrobe)


const ACTION_DURATIONS := {
 "chop": 1.9, "dig": 1.65, "cut": 1.45, "hoe": 1.25, "water": 1.25,
 "seed": 1.15, "harvest": 1.3, "gather": 1.3, "feed": 1.25, "brush": 1.3,
 "pet": 1.1, "greet": 1.1, "steam": 1.6, "trade": 1.6, "pack": 1.2,
 "build": 1.7, "care": 1.0, "rest": 1.5
}

func configure(key: String, data: Dictionary = {}) -> void:
 character_key = key
 character_data = data.duplicate(true)
 var styles: Dictionary = GameState.system_catalog.get("art", {}).get("characters", {})
 appearance = styles.get(character_key, {}).duplicate(true)
 if appearance.is_empty():
  appearance = {
   "shirt": str(data.get("color", "#648974")),
   "accent": "#dfc18d",
   "skin": "#e3b991",
   "hair": "short",
   "hairColor": "#394337",
   "prop": ""
  }
 if bool(appearance.get("child", false)):
  scale = Vector2(0.86, 0.86)
 queue_redraw()

func configure_player() -> void:
 character_key = "player"
 character_data = {"color": "#648974"}
 if not GameState.changed.is_connected(_refresh_player_appearance):
  GameState.changed.connect(_refresh_player_appearance)
 _refresh_player_appearance()

func _refresh_player_appearance() -> void:
 var source: Dictionary = GameState.appearance
 var shirt_colors := ["#427660", "#506c93", "#a76755", "#a38b48"]
 var accent_colors := ["#dfc18d", "#d8c8a1", "#ecc6a7", "#e2dabb"]
 var skin_colors := ["#e3b991", "#c69b74", "#a87e5d"]
 var hair_colors := ["#394337", "#674c3b", "#80634a", "#a6a79a"]
 var shirt_index := clampi(int(source.get("shirt", 0)), 0, 3)
 var outfit := str(source.get("outfit", "field"))
 var today: Dictionary = GameState.weather_profile()
 var outdoor := GameState.current_interior == ""
 appearance = {
  "shirt": shirt_colors[shirt_index],
  "accent": accent_colors[shirt_index],
  "skin": skin_colors[clampi(int(source.get("skin", 0)), 0, 2)],
  "hair": ["short", "bob", "bun", "wave"][clampi(int(source.get("hair", 0)), 0, 3)],
  "hairColor": hair_colors[clampi(int(source.get("hairColor", 0)), 0, 3)],
  "hat": bool(source.get("hat", true)),
  "apron": outfit == "apron",
  "vest": outfit in ["traveler", "festival"],
  "festival": outfit == "festival" or posmod(GameState.day, 28) == 13,
  "bag": bool(source.get("bag", false)),
  "rain": outdoor and int(today.get("rain", 0)) > 0 and bool(source.get("weatherDress", true)),
  "cold": outdoor and GameState.season_index() == 3 and bool(source.get("weatherDress", true))
 }
 queue_redraw()

func set_riding(is_riding: bool) -> void:
 if riding == is_riding: return
 riding = is_riding
 queue_redraw()

func set_pose(direction: Vector2, is_walking: bool) -> void:
 var previous_direction := facing
 var previous_walking := walking
 if direction.length_squared() > 0.01:
  if absf(direction.x) > absf(direction.y):
   facing = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
  else:
   facing = Vector2.DOWN if direction.y > 0.0 else Vector2.UP
 walking = is_walking
 set_process(walking or fishing_state != "idle" or action_state != "" or PAINTED_ART.has_clip(character_key, "idle"))
 if previous_direction != facing or previous_walking != walking:
  queue_redraw()

func set_fishing_pose(state: String, tension: float = 0.0) -> void:
 fishing_state = "idle" if state == "cancel" else state
 fishing_tension = clampf(tension, 0.0, 1.0)
 set_process(walking or fishing_state != "idle" or action_state != "" or PAINTED_ART.has_clip(character_key, "idle"))
 queue_redraw()

func set_sequence_snapshot(snapshot: Dictionary) -> void:
 if snapshot.is_empty():
  if not sequence_managed:return
  sequence_managed=false
  sequence_snapshot={}
  action_state=""
 else:
  sequence_managed=true
  sequence_snapshot=snapshot.duplicate(true)
  action_state=str(snapshot.kind)
  action_duration=float(snapshot.duration)
  action_elapsed=float(snapshot.progress)*action_duration
 set_process(walking or fishing_state!="idle" or action_state!="" or PAINTED_ART.has_clip(character_key, "idle"))
 queue_redraw()

func play_action(kind: String) -> void:
 if GameState.action_commit_in_progress or sequence_managed:return
 if kind == "fish":
  return
 action_state = kind
 action_elapsed = 0.0
 action_duration = float(ACTION_DURATIONS.get(kind, 0.8))
 set_process(true)
 queue_redraw()

func set_working(is_working: bool) -> void:
 if working == is_working:
  return
 working = is_working
 queue_redraw()

func _process(delta: float) -> void:
 if not is_visible_in_tree() or GameState.simulation_hidden(): return
 if GameState.ui_open and action_state.is_empty(): return
 walk_clock += delta
 if action_state != "":
  action_elapsed += 0.0 if sequence_managed else delta
  if action_elapsed >= action_duration: action_state = ""
 var animated := preload("res://scripts/life_presentation.gd").animate()
 var frame := floori(walk_clock * (12.0 if action_state != "" or riding else 8.0)) if animated else 0
 if frame != last_animation_frame:
  last_animation_frame = frame
  last_step = roundi(sin(walk_clock * 13.0) * 2.0) if animated else 0
  redraw_count += 1
  queue_redraw()
 if not walking and fishing_state == "idle" and action_state == "" and not PAINTED_ART.has_clip(character_key, "idle"):
  set_process(false)

func _color(key: String, fallback: String) -> Color:
 return Color.from_string(str(appearance.get(key, fallback)), Color(fallback))

func _pixel(x: float, y: float, width: float, height: float, color: Color) -> void:
 draw_rect(Rect2(roundf(x), roundf(y), maxi(1, roundi(width)), maxi(1, roundi(height))), color, true)

func _polygon(points: Array, color: Color) -> void:
 draw_colored_polygon(PackedVector2Array(points), color)

func _ellipse(cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
 var points := PackedVector2Array()
 for i in range(16):
  var angle := TAU * float(i) / 16.0
  points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
 draw_colored_polygon(points, color)

func _draw_hair(hair_color: Color, x: int, y: int, width: int, height: int, back: bool) -> void:
 _pixel(x - 1, y, width + 2, 4, hair_color)
 _pixel(x, y - 2, width, 4, hair_color)
 _pixel(x - 2, y + 3, 3, height * 0.65, hair_color)
 _pixel(x + width - 1, y + 3, 3, height * 0.62, hair_color)
 if back:
  _pixel(x, y, width, height - 2, hair_color)
 var hair_kind := str(appearance.get("hair", "short"))
 if hair_kind in ["bob", "braid", "pony"]:
  _pixel(x - 3, y + 4, 4, height + 3, hair_color)
  _pixel(x + width - 1, y + 3, 4, height + 3, hair_color)
 if hair_kind == "bun":
  _pixel(x + width - 4, y - 6, 7, 6, hair_color)
 elif hair_kind == "pony":
  _pixel(x + width, y, 5, height + 7, hair_color)
 elif hair_kind == "pigtail":
  _pixel(x - 6, y + 4, 5, 10, hair_color)
  _pixel(x + width + 1, y + 4, 5, 10, hair_color)
  _pixel(x - 6, y + 4, 5, 2, Color("#c97165"))
  _pixel(x + width + 1, y + 4, 5, 2, Color("#c97165"))
 elif hair_kind == "wave":
  _pixel(x - 2, y - 2, 5, 6, hair_color)
  _pixel(x + 4, y - 3, 5, 6, hair_color)
  _pixel(x + width - 6, y - 1, 7, 6, hair_color)
 _pixel(x + 2, y + 1, maxi(3, width - 6), 1, Color(1.0, 1.0, 1.0, 0.12))

func _draw_accessory(kind: String, at: Vector2, factor: float) -> void:
 if kind == "":
  return
 draw_set_transform(at, 0.0, Vector2.ONE * factor)
 match kind:
  "book", "mail", "seedbag", "medical":
   var color := Color("#e0c486") if kind == "book" else Color("#dde1bd") if kind == "mail" else Color("#f1ecda") if kind == "medical" else Color("#b89859")
   _pixel(-5, -8, 10, 14, color)
   _pixel(-4, -6, 2, 10, Color("#847249") if kind == "book" else Color("#79917b"))
   _pixel(-1, -4, 4, 2, Color("#fff1c4"))
   if kind == "medical":
    _pixel(-1, -3, 2, 7, Color("#7caaa0"))
    _pixel(-3, -1, 6, 2, Color("#7caaa0"))
  "camera":
   _pixel(-7, -6, 14, 9, Color("#374950"))
   _pixel(-3, -8, 6, 3, Color("#596971"))
   _pixel(-3, -5, 7, 7, Color("#b1bdb1"))
   _pixel(-1, -3, 3, 3, Color("#34484c"))
  "hammer", "wrench":
   _pixel(-1, -9, 2, 21, Color("#ab8150"))
   _pixel(-5, -10, 10, 5, Color("#586e70") if kind == "hammer" else Color("#849b9b"))
   if kind == "wrench":
    _pixel(-2, -10, 4, 3, Color("#cfba8b"))
  "basket", "tea":
   _pixel(-7, -6, 14, 12, Color("#b69559"))
   for i in range(3):
    _pixel(-6, -4 + i * 3, 12, 1, Color("#ddc584"))
   _pixel(-5, -10, 10, 2, Color("#a98c52"))
   if kind == "tea":
    _pixel(-4, -9, 7, 4, Color("#64975e"))
  "net":
   _pixel(0, -12, 2, 27, Color("#a08958"))
   draw_rect(Rect2(-6, -13, 14, 12), Color("#b9ccb2"), false, 1.0)
   for i in range(3):
    _pixel(-4 + i * 4, -12, 1, 10, Color("#d1d9b6"))
  "tray", "bowl":
   _pixel(-8, -2, 17, 4, Color("#ddd8b8"))
   for i in range(3):
    _pixel(-6 + i * 5, -6, 4, 4, Color("#96a16a") if kind == "bowl" else Color("#f1dfaf"))
  "fan":
   _polygon([Vector2(-9, -6), Vector2(0, -12), Vector2(10, -5), Vector2(1, 4)], Color("#d9c695"))
   _pixel(0, 1, 2, 9, Color("#a28756"))
  "pinwheel":
   _pixel(0, -6, 1, 20, Color("#a38452"))
   _polygon([Vector2(0, -5), Vector2(-7, -12), Vector2(-7, -3)], Color("#d09559"))
   _polygon([Vector2(0, -5), Vector2(7, -12), Vector2(6, -3)], Color("#d09559"))
   _polygon([Vector2(0, -5), Vector2(7, 3), Vector2(-1, 2)], Color("#d09559"))
   _polygon([Vector2(0, -5), Vector2(-7, 3), Vector2(-7, -3)], Color("#d09559"))
   _pixel(0, -5, 2, 2, Color("#f3d499"))
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
 painted_active = false
 var painted_clip := action_state if action_state != "" else ("walk" if walking else "care" if working else "idle")
 if fishing_state != "idle": painted_clip = {"cast":"fish_cast","waiting":"fish_wait","bite":"fish_wait","fight":"fish_reel","caught":"fish_catch","released":"fish_catch","miss":"fish"}.get(fishing_state,"fish_wait")
 if riding: painted_clip = "bike"
 var painted_direction := "left" if facing.x < 0 else "right" if facing.x > 0 else "up" if facing.y < 0 else "down"
 var painted_progress := clampf(action_elapsed / maxf(action_duration, 0.001), 0.0, 1.0) if action_state != "" else -1.0
 var painted_allowed := true
 if wardrobe != null: wardrobe.hide()
 if character_key == "player" and wardrobe != null and (riding or wardrobe.needs_layers(GameState.appearance, appearance)):
  painted_allowed = false
  if wardrobe.present(GameState.appearance, appearance, painted_clip, painted_direction, walk_clock, painted_progress):
   preload("res://scripts/ground_style.gd").shadow(self, Vector2(0,.6), 20.0, 5.4)
   painted_active = true
   return
 if painted_allowed and PAINTED_ART.draw_actor(self, character_key, painted_clip, painted_direction, walk_clock, painted_progress, GameState.appearance):
  painted_active = true
  return
 var step := last_step if walking and not riding else 0
 var shirt := Color("#677f70") if bool(appearance.get("rain", false)) else _color("shirt", str(character_data.get("color", "#648974")))
 var accent := _color("accent", "#dfc18d")
 var skin := _color("skin", "#e3b991")
 var hair_color := _color("hairColor", "#394337")
 var prop := str(appearance.get("prop", ""))
 var side := facing.x != 0.0
 var offset := -2 if facing.x < 0.0 else 2 if facing.x > 0.0 else 0

 if sequence_managed and facing.y<0.0:_draw_source_action()
 _ellipse(5, 2, 11, 3.5, Color(0.15, 0.24, 0.20, 0.24))
 if riding: _draw_bicycle()
 _pixel(-6, -7 + step, 5, 8, Color("#3e5050"))
 _pixel(2, -7 - step, 5, 8, Color("#3e5050"))
 _pixel(-7, step, 7, 3, Color("#303e39"))
 _pixel(2, -step, 7, 3, Color("#303e39"))
 _pixel(-7, step, 5, 1, Color("#a2a58b"))

 if sequence_managed:
  var pose:=source_action_pose()
  draw_set_transform(Vector2(float(pose.ux)*float(pose.reach)*3.0,float(pose.reach)*3.0 if bool(pose.low) else 0.0))
 _polygon([Vector2(-7, -19), Vector2(7, -19), Vector2(9, -7), Vector2(-9, -7)], Color("#344b43"))
 _pixel(-6, -19, 13, 13, shirt)
 _pixel(-5, -18, 4, 11, Color(1.0, 1.0, 1.0, 0.07))
 if not working and not sequence_managed:
  _pixel(-9, -17 - step, 3, 9, shirt)
  _pixel(8, -17 + step, 3, 9, shirt)
  _pixel(-9, -9 - step, 3, 4, skin)
  _pixel(8, -9 + step, 3, 4, skin)
 _pixel(-3, -20, 6, 3, skin)
 if bool(appearance.get("skirt", false)):
  _polygon([Vector2(-6, -10), Vector2(6, -10), Vector2(9, -4), Vector2(-9, -4)], shirt)
 if bool(appearance.get("apron", false)):
  _pixel(-4, -15, 9, 10, accent)
  _pixel(-5, -9, 10, 2, Color(1.0, 1.0, 1.0, 0.12))
 elif bool(appearance.get("vest", false)):
  _pixel(-6, -18, 4, 11, accent)
  _pixel(3, -18, 4, 11, accent)
 else:
  _pixel(0, -15, 1, 8, accent)
  _pixel(-4, -17, 8, 2, accent)
 if bool(appearance.get("bag", false)):
  if facing.y < 0.0:
   _pixel(-6, -19, 12, 11, Color("#8d7049"))
   _pixel(-5, -18, 10, 2, Color("#c4a56b"))
   _pixel(-1, -13, 3, 3, Color("#7e6746"))
  else:
   _pixel(5 if facing.x >= 0.0 else -7, -18, 2, 10, Color("#c4a56b"))
   _pixel(8 if facing.x >= 0.0 else -11, -10, 5, 7, Color("#a98b59"))
 if bool(appearance.get("cold", false)):
  _pixel(-7, -21, 14, 4, accent)
  _pixel(3, -18, 3, 8, accent)
 if bool(appearance.get("festival", false)):
  _pixel(-6, -10, 13, 2, Color("#c5a65c"))

 if facing.y < 0.0 and prop != "":
  _draw_accessory(prop, Vector2(0, -11), 0.75)
 _pixel(-6, -29, 13, 12, Color("#5b4b38"))
 _pixel(-5, -28, 11, 11, skin)
 _pixel(-5, -28, 3, 7, Color(1.0, 0.86, 0.70, 0.20))
 _pixel(-6 + offset, -28, 1, 8, Color(0.64, 0.43, 0.32, 0.16))
 _draw_hair(hair_color, -6, -31, 13, 12, facing.y < 0.0)
 if facing.y >= 0.0:
  _pixel(-3 + offset, -24, 2, 2, Color("#29372e"))
  if not side:
   _pixel(3, -24, 2, 2, Color("#29372e"))
  _pixel(1 + offset, -20, 2, 1, Color("#b07356"))
  if str(character_data.get("emotion", "")) == "happy":
   _pixel(offset, -20, 4, 1, Color("#a66751"))
   _pixel(1 + offset, -19, 2, 1, Color("#a66751"))
  if bool(appearance.get("glasses", false)):
   draw_rect(Rect2(-5, -26, 5, 4), Color("#514c3e"), false, 1.0)
   draw_rect(Rect2(2, -26, 5, 4), Color("#514c3e"), false, 1.0)
   _pixel(0, -25, 2, 1, Color("#514c3e"))
 if bool(appearance.get("rain", false)):
  _pixel(-10, -32, 21, 5, accent)
  _pixel(-7, -35, 15, 4, Color("#8b9d84"))
 elif bool(appearance.get("hat", false)):
  _pixel(-11, -31, 23, 3, Color("#b98f4b"))
  _pixel(-7, -36, 15, 5, Color("#dabe77"))
  _pixel(-6, -36, 12, 1, Color("#ebd597"))
  _pixel(-7, -32, 15, 2, Color("#8d6e3e"))
 elif bool(appearance.get("cap", false)):
  _pixel(-7, -32, 15, 4, accent)
  _pixel(-3 + offset, -29, 12, 2, accent)
 if facing.y >= 0.0:
  _draw_accessory(prop, Vector2(-9 if facing.x < 0.0 else 10 if facing.x > 0.0 else 8, -8), 0.65)
 draw_set_transform(Vector2.ZERO)
 if sequence_managed:
  if facing.y>=0.0:_draw_source_action()
 elif fishing_state != "idle":
  _draw_fishing_pose(skin)
 elif action_state != "":
  _draw_action_pose(skin)

func _draw_bicycle() -> void:
 var frame := Color("829e90")
 var rim := Color("304d49")
 for x in [-15.0, 16.0]:
  _ellipse(x, 3.0, 8.0, 8.0, rim)
  _ellipse(x, 3.0, 5.0, 5.0, Color("c2d3bf"))
  _ellipse(x, 3.0, 2.0, 2.0, rim)
 draw_line(Vector2(-15, 3), Vector2(-3, -9), frame, 2.0)
 draw_line(Vector2(-3, -9), Vector2(16, 3), frame, 2.0)
 draw_line(Vector2(16, 3), Vector2(-15, 3), frame, 2.0)
 draw_line(Vector2(11, -13), Vector2(16, 3), frame, 2.0)
 draw_line(Vector2(7, -13), Vector2(16, -13), rim, 2.0)
 draw_line(Vector2(-9, -11), Vector2(-1, -11), Color("7a573e"), 3.0)

func _draw_fishing_pose(skin: Color) -> void:
 var direction := facing.normalized()
 if direction == Vector2.ZERO:
  direction = Vector2.DOWN
 var shoulder := Vector2(-5.0 if facing.x < 0.0 else 5.0, -15.0)
 var hand := shoulder + Vector2(direction.x * 7.0, direction.y * 6.0)
 var rod_tip := hand + direction * 24.0 + Vector2(0.0, -13.0)
 if fishing_state == "fight":
  rod_tip += Vector2(-direction.y, direction.x) * (2.0 + fishing_tension * 8.0)
 var cast_end := rod_tip + direction * 29.0 + Vector2(0.0, 15.0)
 draw_line(shoulder, hand, skin, 3.0, true)
 draw_line(hand, rod_tip, Color("b89c69"), 2.0, true)
 draw_line(rod_tip, Vector2(lerpf(rod_tip.x, cast_end.x, 0.5), cast_end.y - 6.0), Color("d8e3ce", 0.8), 1.0, true)
 draw_line(Vector2(lerpf(rod_tip.x, cast_end.x, 0.5), cast_end.y - 6.0), cast_end, Color("d8e3ce", 0.8), 1.0, true)
 draw_rect(Rect2(roundf(cast_end.x - 1.5), roundf(cast_end.y - 4.0), 3.0, 4.0), Color("c66c53"), true)
 draw_rect(Rect2(roundf(cast_end.x - 1.5), roundf(cast_end.y), 3.0, 3.0), Color("f4e8c1"), true)
 if fishing_state == "caught":
  draw_ellipse(cast_end + Vector2(7.0, -7.0), 4.0, 2.0, Color("d8e9d7", 0.9))
  draw_colored_polygon(PackedVector2Array([cast_end + Vector2(10.0, -7.0), cast_end + Vector2(14.0, -10.0), cast_end + Vector2(14.0, -4.0)]), Color("d8e9d7", 0.9))

func _draw_action_pose(skin: Color) -> void:
 var reduced_motion := str(GameState.visual_fx.get("motion", "full")) == "reduced"
 var progress := 0.5 if reduced_motion else clampf(action_elapsed / maxf(0.01, action_duration), 0.0, 1.0)
 var reach := 0.5 if reduced_motion else sin(progress * PI)
 var direction := facing.normalized()
 if direction == Vector2.ZERO:
  direction = Vector2.DOWN
 var side := -1.0 if facing.x < 0.0 else 1.0
 var shoulder := Vector2(side * 6.0, -16.0)
 var sway := 0.0 if reduced_motion else sin(progress * TAU * 2.0) * reach
 var hand := shoulder + direction * (7.0 + reach * 7.0) + Vector2(side * sway * 2.0, reach * 2.0)
 draw_line(shoulder, hand, Color("3d5146", 0.62), 4.0, true)
 draw_line(shoulder, hand, skin, 2.5, true)
 draw_circle(hand, 2.0, skin)
 if action_state in ["hoe", "chop", "dig", "cut", "build"]:
  var impact := sin(progress * PI)
  var head := hand + direction * (8.0 + impact * 6.0) + Vector2(side * (8.0 - impact * 13.0), -15.0 + impact * 17.0)
  draw_line(hand, head, Color("a97f4c"), 2.0, true)
  var blade := head + Vector2(-5.0 * side, -1.0) if action_state != "chop" else head + Vector2(7.0 * side, 0.0)
  draw_line(head, blade, Color("829c95") if action_state != "build" else Color("ceb77d"), 3.0, true)
 elif action_state == "water":
  var can := hand + Vector2(side * 3.0, 1.0)
  draw_rect(Rect2(can + Vector2(-4.0, -4.0), Vector2(9.0, 7.0)), Color("6f9b9b"), true)
  draw_line(can + Vector2(side * 4.0, -1.0), can + Vector2(side * 9.0, -4.0), Color("90b4b1"), 2.0, true)
  if not reduced_motion and progress > 0.28 and progress < 0.84:
   for index in range(3):
    var drop := hand + direction * (12.0 + float(index) * 3.0) + Vector2(0.0, 7.0 + float(index) * 2.0 + sin(progress * 12.0 + index) * 2.0)
    draw_rect(Rect2(drop, Vector2(2.0, 3.0)), Color("b9e4df"), true)
 elif action_state in ["seed", "feed"]:
  for index in range(4):
   var scatter := hand + direction * (7.0 + float(index) * 2.0) + Vector2(float(index - 2) * 3.0, 5.0 + reach * 5.0)
   draw_rect(Rect2(scatter, Vector2(2.0, 2.0)), Color("dfc180"), true)
 elif action_state in ["pet", "greet", "brush", "care"]:
  var wave := 0.0 if reduced_motion else sin(progress * TAU * 2.0) * 3.0 * reach
  draw_line(hand, hand + Vector2(side * wave, -5.0 - reach * 4.0), skin, 2.0, true)
  if action_state in ["pet", "care"] and progress > 0.42 and progress < 0.72:
   draw_circle(hand + Vector2(side * 10.0, -10.0), 1.5, Color("e8d89d"))
 elif action_state in ["harvest", "gather", "pack", "trade"]:
  var basket := Vector2(-side * 12.0, -2.0)
  draw_rect(Rect2(basket + Vector2(-6.0, -4.0), Vector2(12.0, 6.0)), Color("947043"), true)
  draw_line(basket + Vector2(-5.0, -5.0), basket + Vector2(5.0, -5.0), Color("d1b27b"), 2.0, true)
  if progress > 0.58:
   draw_rect(Rect2(hand + Vector2(2.0 * side, -7.0), Vector2(3.0, 3.0)), Color("d4cc83"), true)
 elif action_state in ["steam", "rest"]:
  draw_rect(Rect2(hand + Vector2(-5.0, -3.0), Vector2(11.0, 4.0)), Color("e5d6b5"), true)
  draw_arc(hand + Vector2(0.0, -7.0), 3.0 + reach * 2.0, PI, TAU, 8, Color("f5ead4", 0.66), 1.0)



func local_action_snapshot() -> Dictionary:
 var snapshot:=sequence_snapshot.duplicate(true)
 if snapshot.is_empty():return snapshot
 var target:=to_local(Vector2(float(snapshot.get("x",global_position.x)),float(snapshot.get("y",global_position.y))))
 snapshot.x=target.x
 snapshot.y=target.y
 if snapshot.has("waterX") and snapshot.has("waterY"):
  var water:=to_local(Vector2(float(snapshot.waterX),float(snapshot.waterY)))
  snapshot.waterX=water.x
  snapshot.waterY=water.y
 return snapshot

func source_action_pose() -> Dictionary:
 return ACTION_ART.pose(Vector2.ZERO,facing,local_action_snapshot())

func source_action_frame() -> Array:
 var snapshot:=local_action_snapshot()
 return ACTION_ART.frame(Vector2.ZERO,facing,snapshot,str(appearance.get("skin","#e3b991")),walk_clock,GameState.item_catalog.has(str(snapshot.get("item",""))),GameState.fishing_snapshot())

func _draw_source_action() -> void:
 for row in source_action_frame():
  var origin:Vector2=ACTION_ART.vec(row.origin)
  draw_set_transform(origin,float(row.angle))
  var color:=Color.from_string(str(row.get("color","#ffffff")),Color.WHITE)
  match str(row.op):
   "rect":draw_rect(Rect2(float(row.x),float(row.y),float(row.w),float(row.h)),color)
   "oval":_ellipse(float(row.x),float(row.y),float(row.rx),float(row.ry),color)
   "line":
    var points:=PackedVector2Array()
    for at in row.points:points.append(ACTION_ART.vec(at))
    draw_polyline(points,color,float(row.width),true)
    # Canvas round caps and round joins.
    for at in points:draw_circle(at,float(row.width)/2.0,color,true,-1,true)
   "arc":
    var points:=PackedVector2Array()
    var sweep:=minf(TAU,float(row.end)-float(row.start))
    var center:=Vector2(float(row.x),float(row.y))
    for i in range(33):
     var angle:=float(row.start)+sweep*float(i)/32.0
     points.append(center+Vector2(cos(angle),sin(angle))*float(row.radius))
    draw_polyline(points,color,float(row.width),true)
    draw_circle(points[0],float(row.width)/2.0,color,true,-1,true)
    draw_circle(points[points.size()-1],float(row.width)/2.0,color,true,-1,true)
   "quad":
    var from:Vector2=ACTION_ART.vec(row.points[0])
    var control:Vector2=ACTION_ART.vec(row.points[1])
    var to:Vector2=ACTION_ART.vec(row.points[2])
    var points:=PackedVector2Array()
    for i in range(25):
     var t:=float(i)/24.0
     points.append(from*(1.0-t)*(1.0-t)+control*2.0*(1.0-t)*t+to*t*t)
    draw_polyline(points,color,float(row.width),true)
    draw_circle(from,float(row.width)/2.0,color,true,-1,true)
    draw_circle(to,float(row.width)/2.0,color,true,-1,true)
   "text":draw_string(ThemeDB.fallback_font,Vector2(float(row.x),float(row.y)),str(row.text),HORIZONTAL_ALIGNMENT_LEFT,-1.0,11,color)
   "item":
    draw_set_transform(origin+Vector2(float(row.x),float(row.y)),float(row.angle),Vector2.ONE*float(row.scale))
    action_icon.render_to(self,str(row.id))
 draw_set_transform(Vector2.ZERO)


