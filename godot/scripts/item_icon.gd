extends Control
class_name ItemIcon

const ITEM_ART := preload("res://scripts/item_art.gd")

const INK := Color("#425647")
const CREAM := Color("#eee1b7")
const LEAF := Color("#709755")

var drawing_target: CanvasItem
var item_id := ""
var painted_key := ""

func configure(next_item_id: String) -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 item_id = next_item_id
 queue_redraw()

func render_to(target: CanvasItem,id: String) -> void:
 drawing_target = target
 _draw_icon(id)
 drawing_target = null

func _target() -> CanvasItem:
 return self if drawing_target==null else drawing_target

func _pixel(x: float, y: float, width: float, height: float, color: Color) -> void:
 _target().draw_rect(Rect2(roundf(x), roundf(y), maxi(1, roundi(width)), maxi(1, roundi(height))), color, true)

func _poly(points: Array, color: Color) -> void:
 _target().draw_colored_polygon(PackedVector2Array(points), color)

func _ellipse(cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
 var points := PackedVector2Array()
 for index in range(16):
  var angle := TAU * float(index) / 16.0
  points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
 _target().draw_colored_polygon(points, color)

func _draw() -> void:
 if has_meta("guide_texture"):
  var texture: Texture2D=get_meta("guide_texture")
  if texture!=null:
   var ratio:=minf(size.x/texture.get_width(),size.y/texture.get_height())
   var extent:=Vector2(texture.get_size())*ratio
   draw_texture_rect(texture,Rect2((size-extent)*.5,extent),false)
  return
 if size.x <= 0.0 or size.y <= 0.0 or item_id == "":
  return
 var pixel_scale := minf(size.x, size.y) / 32.0
 var margin := (size - Vector2.ONE * minf(size.x, size.y)) * 0.5
 draw_set_transform(margin, 0.0, Vector2.ONE * pixel_scale)
 _draw_icon(item_id)
 if GameState.item_catalog.has(item_id):
  var stock: Array = GameState._quality_counts(item_id)
  var grade:=0
  for i in range(stock.size()):
   if int(stock[i])>0:grade=i
  if grade>0:
   var tint:Color=[Color.WHITE,Color("#a7c792"),Color("#eed49b"),Color("#eeb899")][mini(3,grade)]
   preload("res://scripts/detail_art.gd").draw(self,"ui/quality_badge",Rect2(23,23,9,9),tint)
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_icon(id: String) -> void:
 painted_key = ""
 var illustration: Texture2D = ITEM_ART.texture_for(id)
 if illustration != null:
  painted_key = ITEM_ART.key_for(id)
  _target().draw_texture_rect(illustration, Rect2(0, 0, 32, 32), false)
  return
 if id.contains("/"):
  id = id.get_slice("/", 1)
 var rules: Dictionary = GameState.system_catalog.get("itemIcons", {})
 var seed_map: Dictionary = rules.get("seedMap", {})
 var seeds: Dictionary = seed_map.get(id, {})
 if not seeds.is_empty():
  _draw_seed(id, seeds)
  return
 var tool_defs: Dictionary = GameState.system_catalog.get("tools", {}).get("defs", {})
 if tool_defs.has(id):
  _draw_legacy_item(id)
  return
 var vegetables: Dictionary = rules.get("vegetables", {})
 if vegetables.has(id):
  _draw_vegetable(id, vegetables[id])
  return
 var materials: Dictionary = rules.get("materials", {})
 if materials.has(id):
  _draw_material(id, materials[id])
  return
 var data: Dictionary = GameState.item_catalog.get(id, {})
 if str(data.get("kind", "")) == "料理":
  _draw_dish(id, data)
  return
 _draw_legacy_item(id)

func _draw_seed(id: String, seed: Dictionary) -> void:
 _draw_vessel("sack", Color("#c4ad78"))
 _pixel(8, 12, 16, 13, Color("#efe1b8"))
 var crop_id := str(seed.get("crop", "cabbage"))
 var crop: Dictionary = GameState.crop_catalog.get(crop_id, {})
 var color := Color.from_string(str(crop.get("color", "#7b9b60")), LEAF)
 var kind := str(crop.get("group", "蔬菜"))
 if kind == "叶菜":
  _ellipse(15, 17, 5, 4, color)
  _ellipse(19, 19, 4, 3, color.lightened(0.13))
 elif kind == "谷物":
  for index in range(4): _pixel(11 + index * 3, 15 + index % 2 * 2, 2, 6, color)
 else:
  _ellipse(16, 18, 5, 5, color)
  _pixel(15, 11, 3, 4, LEAF)
 var seed_kind := str(seed.get("kind", "normal"))
 if seed_kind != "normal":
  var badge_x := 8 if seed_kind == "heirloom" else 21
  _pixel(badge_x, 4, 4, 5, Color("#b77854") if seed_kind == "heirloom" else Color("#72957c"))
  _pixel(badge_x + 1, 5, 2, 2 if seed_kind == "heirloom" else 3, CREAM)

func _draw_vessel(kind: String, color: Color) -> void:
 if kind == "sack":
  _poly([Vector2(8, 5), Vector2(24, 5), Vector2(21, 10), Vector2(26, 15), Vector2(26, 27), Vector2(6, 27), Vector2(6, 15), Vector2(11, 10)], INK)
  _poly([Vector2(10, 6), Vector2(22, 6), Vector2(19, 11), Vector2(24, 16), Vector2(24, 25), Vector2(8, 25), Vector2(8, 16), Vector2(13, 11)], color)
  _pixel(10, 9, 12, 2, Color("#8d7249"))
  _pixel(11, 15, 10, 7, CREAM)
 elif kind == "bottle":
  _pixel(12, 3, 8, 4, INK)
  _pixel(11, 4, 10, 2, Color("#a68757"))
  _pixel(12, 7, 8, 4, color)
  _poly([Vector2(12, 10), Vector2(20, 10), Vector2(24, 14), Vector2(24, 28), Vector2(8, 28), Vector2(8, 14)], INK)
  _pixel(10, 14, 12, 12, color)
  _pixel(11, 15, 2, 8, Color("#f6edc9"))
  _pixel(10, 19, 12, 5, CREAM)
 else:
  _poly([Vector2(7, 10), Vector2(25, 10), Vector2(27, 15), Vector2(25, 27), Vector2(7, 27), Vector2(5, 15)], INK)
  _pixel(8, 12, 16, 13, color)
  _pixel(9, 5, 14, 6, Color("#a6885d"))
  _pixel(7, 7, 18, 3, Color("#c2ab79"))
  _pixel(11, 16, 10, 7, CREAM)

func _draw_vegetable(id: String, raw: Variant) -> void:
 var definition: Array = raw
 if definition.size() < 3: return
 var kind := str(definition[0])
 var color := Color.from_string(str(definition[1]), LEAF)
 var count := int(definition[2])
 match kind:
  "pod":
   _poly([Vector2(4, 11), Vector2(9, 7), Vector2(27, 17), Vector2(28, 21), Vector2(22, 25), Vector2(6, 17)], INK)
   _poly([Vector2(6, 11), Vector2(10, 9), Vector2(26, 18), Vector2(25, 22), Vector2(22, 23), Vector2(7, 16)], color)
   for index in range(count): _pixel(9 + index * 3, 12 + index * 2, 3, 3, Color("#c1ce8c"))
  "leaf":
   for index in range(count):
    var x := 4 + index * 4
    var y := 6 + (index % 2) * 5
    _poly([Vector2(x, 24), Vector2(x - 1, y + 5), Vector2(x + 2, y), Vector2(x + 6, y + 2), Vector2(x + 5, 23), Vector2(17, 28)], color)
    _pixel(x + 2, y + 4, 1, 14, CREAM)
   _pixel(13, 25, 7, 3, Color("#d8d5a6"))
  "leek":
   for index in range(5):
    _poly([Vector2(12 + index, 28), Vector2(4 + index * 5, 4 + index % 2 * 3), Vector2(7 + index * 5, 5), Vector2(16 + index, 28)], LEAF if index % 2 == 1 else color)
   _pixel(10, 22, 12, 2, Color("#bfa46f"))
  "root":
   for index in range(2):
    var x := 4 + index * 11
    var y := 10 + index * 5
    _poly([Vector2(x, y + 4), Vector2(x + 4, y), Vector2(x + 12, y + 1), Vector2(x + 15, y + 8), Vector2(x + 10, y + 13), Vector2(x + 2, y + 12)], INK)
    _poly([Vector2(x + 1, y + 4), Vector2(x + 4, y + 1), Vector2(x + 11, y + 2), Vector2(x + 13, y + 8), Vector2(x + 9, y + 11), Vector2(x + 2, y + 10)], color)
    for mark in range(count): _pixel(x + 3 + mark * 3, y + 3 + mark % 2 * 3, 2, 1, Color("#dac39b"))
  "peanut":
   for index in range(2):
    var x := 5 + index * 12
    _poly([Vector2(x + 3, 5), Vector2(x + 8, 7), Vector2(x + 7, 14), Vector2(x + 10, 19), Vector2(x + 8, 26), Vector2(x + 2, 27), Vector2(x, 21), Vector2(x + 2, 14), Vector2(x, 9)], color)
    for y in range(9, 25, 4): _pixel(x + 3, y, 4, 1, Color("#e3c48a"))
  "grain":
   for index in range(count):
    var x := 5 + index * 4
    _pixel(x, 5 + index % 2 * 3, 1, 22, color)
    for y in range(8, 20, 4):
     _pixel(x - 2, y, 2, 3, CREAM)
     _pixel(x + 1, y + 2, 2, 3, color)
   _pixel(9, 23, 14, 2, Color("#967449"))
  "pepper":
   _poly([Vector2(7, 11), Vector2(11, 8), Vector2(15, 10), Vector2(20, 8), Vector2(26, 12), Vector2(25, 23), Vector2(20, 28), Vector2(15, 26), Vector2(10, 28), Vector2(6, 23)], INK)
   _poly([Vector2(8, 12), Vector2(11, 10), Vector2(16, 12), Vector2(21, 10), Vector2(24, 13), Vector2(23, 23), Vector2(19, 26), Vector2(15, 24), Vector2(10, 25)], color)
   _pixel(10, 13, 2, 9, Color("#a1b778"))
   _pixel(16, 5, 3, 6, LEAF)
  "berry":
   for point in [Vector2(6, 15), Vector2(15, 10), Vector2(20, 20), Vector2(9, 23), Vector2(24, 12)]:
    _pixel(point.x - 2, point.y, 7, 6, color)
    _pixel(point.x, point.y - 2, 3, 2, color)
    _pixel(point.x - 1, point.y, 2, 2, Color("#dca280"))
   _poly([Vector2(14, 10), Vector2(9, 3), Vector2(18, 7), Vector2(24, 3), Vector2(23, 8)], LEAF)
  "tea":
   for index in range(3):
    _poly([Vector2(7, 25), Vector2(5 + index * 7, 10 - index % 2 * 4), Vector2(9 + index * 7, 5), Vector2(13 + index * 7, 11), Vector2(16, 24)], color)
   _pixel(10, 22, 15, 2, Color("#bda774"))
  "melon":
   _poly([Vector2(4, 12), Vector2(9, 7), Vector2(23, 7), Vector2(28, 12), Vector2(28, 22), Vector2(23, 27), Vector2(9, 27), Vector2(4, 22)], INK)
   _pixel(6, 12, 20, 10, color)
   _pixel(9, 9, 14, 16, color)
   _pixel(10, 10, 2, 14, Color("#d1d8b1"))
   _pixel(22, 12, 2, 10, Color("#748663"))
   _pixel(15, 4, 3, 4, LEAF)

func _draw_material(id: String, raw: Variant) -> void:
 var definition: Array = raw
 if definition.size() < 2: return
 var kind := str(definition[0])
 var color := Color.from_string(str(definition[1]), CREAM)
 if kind in ["sack", "bottle", "jar"]:
  _draw_vessel(kind, color)
  if id in ["bioCare", "healthFeed"]:
   _poly([Vector2(13, 21), Vector2(12, 17), Vector2(17, 19), Vector2(20, 16), Vector2(19, 21)], LEAF)
  elif id in ["plantCare", "animalMedicine"]:
   var mark := Color("#588870") if id == "plantCare" else Color("#a86e51")
   _pixel(15, 18, 2, 7, mark)
   _pixel(13, 20, 6, 2, mark)
  elif id == "flour": _pixel(13, 18, 7, 3, Color("#fff3cf"))
  elif id == "grainFeed":
   for index in range(3): _pixel(12 + index * 3, 17 + index % 2, 2, 3, Color("#b19145"))
  else: _pixel(14, 18, 4, 3, color)
  return
 match kind:
  "straw":
   for index in range(8): _poly([Vector2(4 + index * 3, 8 + index % 3), Vector2(7 + index * 3, 9), Vector2(9 + index * 2, 27), Vector2(4 + index * 3, 27)], color)
   _pixel(6, 17, 22, 3, Color("#8d744f")); _pixel(8, 18, 18, 1, Color("#d8c89a"))
  "heap", "truffle":
   _poly([Vector2(4, 25), Vector2(7, 16), Vector2(12, 14), Vector2(14, 9), Vector2(22, 11), Vector2(26, 17), Vector2(28, 25)], INK)
   _poly([Vector2(6, 23), Vector2(9, 17), Vector2(14, 16), Vector2(15, 11), Vector2(21, 13), Vector2(25, 18), Vector2(26, 24)], color)
   for index in range(6): _pixel(9 + index % 3 * 6, 17 + int(index / 3) * 4, 3, 2, Color("#b2986c"))
  "wool":
   for point in [Vector2(8, 17), Vector2(13, 10), Vector2(20, 12), Vector2(24, 19), Vector2(16, 23)]:
    _pixel(point.x - 4, point.y - 4, 9, 9, Color("#a9aa92")); _pixel(point.x - 4, point.y - 5, 8, 8, color); _pixel(point.x - 3, point.y - 5, 5, 2, Color("#faf0d2"))
  "yarn":
   _poly([Vector2(6, 13), Vector2(11, 7), Vector2(23, 8), Vector2(28, 15), Vector2(26, 24), Vector2(20, 28), Vector2(9, 25), Vector2(5, 19)], color)
   for index in range(5): _poly([Vector2(8 + index * 3, 10), Vector2(10 + index * 3, 9), Vector2(23, 22 - index * 2), Vector2(22, 24 - index * 2)], Color("#607a70"))
   _pixel(4, 27, 13, 2, color); _pixel(3, 24, 2, 4, color)
  "cloth":
   _pixel(6, 9, 21, 19, INK); _pixel(8, 7, 17, 19, color); _pixel(9, 9, 3, 14, Color("#c6cfbd")); _pixel(8, 23, 17, 2, Color("#60786e"))
   for index in range(4): _pixel(10 + index * 4, 26, 1, 3, color)
  "feather":
   _poly([Vector2(5, 25), Vector2(9, 9), Vector2(18, 4), Vector2(25, 6), Vector2(25, 13), Vector2(14, 24)], color)
   _poly([Vector2(8, 28), Vector2(21, 8), Vector2(23, 8), Vector2(10, 28)], Color("#8b987e"))
   for index in range(3): _pixel(10 + index * 3, 12 + index * 3, 5, 1, Color("#b5bba0"))
  "egg", "fertile":
   _poly([Vector2(10, 26), Vector2(6, 21), Vector2(8, 12), Vector2(13, 5), Vector2(19, 5), Vector2(24, 13), Vector2(26, 21), Vector2(22, 26)], INK)
   _poly([Vector2(11, 24), Vector2(8, 20), Vector2(10, 12), Vector2(14, 7), Vector2(18, 7), Vector2(22, 13), Vector2(24, 20), Vector2(21, 24)], color)
   _pixel(12, 10, 3, 7, Color("#f8efd2"))
   if kind == "fertile": _pixel(22, 22, 7, 7, Color("#72935c")); _pixel(24, 24, 3, 3, CREAM)
  "cream", "cup":
   _poly([Vector2(6, 13), Vector2(26, 13), Vector2(23, 28), Vector2(9, 28)], Color("#779a90")); _pixel(8, 11, 16, 4, CREAM); _pixel(11, 15, 10, 9, color)
   if kind == "cream": _poly([Vector2(9, 11), Vector2(13, 7), Vector2(19, 7), Vector2(23, 11)], color)
   else: _pixel(25, 16, 4, 6, Color("#779a90"))
  "cheese":
   _poly([Vector2(5, 14), Vector2(21, 7), Vector2(28, 16), Vector2(28, 26), Vector2(5, 26)], Color("#ac8a46")); _poly([Vector2(6, 14), Vector2(21, 9), Vector2(26, 16), Vector2(6, 17)], CREAM); _pixel(7, 18, 19, 6, color); _pixel(11, 19, 3, 3, Color("#b18d44")); _pixel(21, 20, 2, 2, Color("#b18d44"))
  "tea", "dry":
   _pixel(4, 11, 24, 17, Color("#a18455"))
   for y in range(12, 27, 3): _pixel(5, y, 22, 1, Color("#cfb678"))
   for index in range(5):
    if kind == "tea": _poly([Vector2(6 + index * 4, 19), Vector2(8 + index * 4, 13), Vector2(11 + index * 4, 18)], color)
    else: _pixel(6 + index * 4, 14 + index % 2 * 6, 5, 3, color); _pixel(8 + index * 4, 17 + index % 2 * 6, 2, 3, CREAM)
  "fishdry":
   _draw_fish(Color("#7f9c99")); _pixel(3, 8, 26, 1, Color("#ab8c59"))
   for index in range(4): _pixel(11 + index * 3, 16, 1, 8, Color("#9c7e57"))

func _draw_dish(id: String, data: Dictionary) -> void:
 var icon_kind := str(data.get("icon", "dish"))
 if icon_kind == "jar":
  _draw_vessel("jar", Color("#9a825b")); _poly([Vector2(13, 21), Vector2(12, 17), Vector2(20, 17), Vector2(18, 22)], LEAF); return
 if id.to_lower().contains("drink") or icon_kind == "milk":
  _draw_vessel("bottle", Color("#e8dec0")); return
 if id == "riceDumpling":
  _poly([Vector2(4, 25), Vector2(14, 5), Vector2(29, 25)], INK); _poly([Vector2(7, 23), Vector2(14, 8), Vector2(25, 23)], LEAF); _pixel(9, 18, 15, 2, CREAM); _poly([Vector2(15, 8), Vector2(17, 9), Vector2(18, 25), Vector2(16, 25)], CREAM); return
 var soup := icon_kind in ["soup", "riceBowl"] or id.to_lower().contains("soup") or id.to_lower().contains("bowl") or id.to_lower().contains("laba")
 var cake := id.to_lower().contains("cake") or id.to_lower().contains("toast") or id.to_lower().contains("pudding") or id.to_lower().contains("dumpling")
 _poly([Vector2(3, 19), Vector2(29, 19), Vector2(25, 27), Vector2(7, 27)], Color("#6a8b83") if soup else Color("#a8b8a5")); _pixel(4, 16, 24, 6, CREAM); _pixel(7, 14, 18, 5, Color("#c4aa68") if soup else Color("#e1ce98")); _pixel(9, 27, 14, 1, INK)
 if soup:
  for x in [10, 20]: _pixel(x, 4, 1, 3, Color("#a1aaa0")); _pixel(x + 1, 7, 1, 3, Color("#a1aaa0"))
 if id == "milkPudding":
  _poly([Vector2(8, 14), Vector2(24, 14), Vector2(22, 26), Vector2(10, 26)], Color("#7d9b90")); _poly([Vector2(10, 13), Vector2(12, 8), Vector2(21, 8), Vector2(23, 13)], CREAM); _pixel(12, 11, 9, 2, Color("#f9efcc")); _pixel(16, 7, 3, 2, Color("#bd9560")); return
 if id == "autumnToast":
  _pixel(6, 10, 21, 14, Color("#8a683e")); _pixel(8, 9, 17, 13, Color("#c89c5a")); _pixel(11, 12, 5, 5, CREAM); _pixel(17, 17, 6, 3, Color("#e1b767")); return
 if cake:
  for x in [7, 17]:
   _poly([Vector2(x, 13), Vector2(x + 3, 10), Vector2(x + 9, 12), Vector2(x + 10, 21), Vector2(x, 21)], Color("#8aa06a") if id == "greensDumpling" else Color("#b48a4e")); _pixel(x + 1, 13, 8, 5, Color("#a5bb80") if id == "greensDumpling" else Color("#e2bf79"))
   if id == "sweetpotatoCake": _pixel(x + 2, 12, 2, 8, Color("#b27658")); _pixel(x + 6, 12, 2, 8, Color("#f3d59d"))
   if id == "sesameCake":
    for index in range(3): _pixel(x + 2 + index * 2, 14 + index % 2, 1, 1, INK)
  return
 if id == "spinachNoodle":
  for index in range(4): _pixel(8 + index * 4, 12, 2, 9, Color("#e4dca7")); _pixel(8 + index * 4, 12, 4, 1, Color("#f2e6bf"))
  _pixel(7, 16, 3, 3, LEAF); return
 var seed := absi(hash(id))
 for index in range(7):
  var x := 8 + posmod(seed + index * 11, 17)
  var y := 13 + posmod(seed / 7 + index * 5, 7)
  _pixel(x, y, 2 + index % 3, 2, [Color("#6f9455"), Color("#a95b3d"), Color("#f4e6be"), Color("#e2b647")][index % 4])

func _draw_legacy_item(id: String) -> void:
 var item: Dictionary = GameState.item_catalog.get(id, {})
 var icon_kind := str(item.get("icon", id))
 if GameState.crop_catalog.has(id) and not id in ["cabbage", "radish", "bean", "tomato", "rice", "mustard"]:
  var crop: Dictionary = GameState.crop_catalog[id]
  var color := Color.from_string(str(crop.get("color", "#8ca767")), Color("#8ca767"))
  _pixel(12, 5, 3, 9, Color("#6e8d54")); _pixel(9, 6, 11, 3, Color("#94ac70"))
  if str(crop.get("group", "")) == "叶菜":
   _pixel(5, 12, 22, 12, color); _pixel(9, 7, 14, 20, color); _pixel(15, 10, 2, 16, Color("#d5dcb0"))
  elif str(crop.get("group", "")) == "谷物":
   for index in range(4): _pixel(7 + index * 5, 9, 3, 19, color); _pixel(5 + index * 5, 12, 5, 3, Color("#e1d1a0"))
  else:
   _pixel(6, 13, 21, 11, color); _pixel(9, 10, 14, 18, color); _pixel(10, 13, 5, 3, Color(1.0, 0.87, 0.74, 0.33))
   if id == "watermelon":
    for index in range(3): _pixel(10 + index * 5, 12, 2, 13, Color("#517954"))
  return
 match icon_kind:
  "axe", "sickle", "build":
   _pixel(14, 7, 3, 21, Color("#9b8059")); _pixel(7, 4, 17, 6, Color("#8a9d9a")); _pixel(7, 9, 7, 6, Color("#7b918d"))
   if icon_kind == "sickle": _pixel(23, 7, 3, 8, Color("#8a9d9a"))
  "hoe":
   _pixel(12, 4, 3, 21, Color("#9b8059")); _pixel(5, 4, 16, 5, Color("#788d89")); _pixel(5, 5, 4, 8, Color("#819991"))
  "water":
   _pixel(7, 10, 14, 13, Color("#8ca8a2")); _pixel(8, 10, 13, 3, Color("#b3c9bc")); _pixel(20, 14, 5, 5, Color("#86a5a0")); _pixel(23, 10, 3, 5, Color("#91b4a9")); _pixel(3, 13, 5, 7, Color("#72968f")); _pixel(5, 11, 3, 3, Color("#a7bab0")); _pixel(12, 6, 4, 4, Color("#9eb8ad"))
  "hand", "care":
   _pixel(10, 10, 11, 14, Color("#d6b58b")); _pixel(10, 5, 3, 11, Color("#e1c294")); _pixel(14, 4, 3, 13, Color("#e1c294")); _pixel(18, 7, 3, 10, Color("#e1c294")); _pixel(6, 13, 5, 8, Color("#e1c294")); _pixel(9, 23, 13, 3, Color("#728b62"))
  "rod":
   _pixel(8, 7, 3, 20, Color("#9b8657")); _pixel(11, 4, 8, 3, Color("#9b8657")); _target().draw_line(Vector2(19, 6), Vector2(19, 22), Color("#bac5a6"), 1.0); _pixel(18, 20, 4, 5, Color("#b86f50"))
  "seed":
   _pixel(6, 6, 18, 20, Color("#bdab75")); _pixel(7, 7, 16, 4, Color("#dac99a")); _pixel(8, 12, 14, 12, Color("#ddd4a9")); _pixel(13, 18, 3, 5, Color("#748d56")); _pixel(10, 15, 5, 4, Color("#8da568")); _pixel(15, 13, 5, 5, Color("#829b5e"))
  "cabbage", "mustard", "tea", "bean":
   _pixel(13, 17, 4, 10, Color("#d2d3a0")); _pixel(6, 11, 8, 13, Color("#6c9257")); _pixel(17, 10, 8, 14, Color("#71965b")); _pixel(11, 5, 9, 18, Color("#8eaf69")); _pixel(7, 9, 5, 7, Color("#acc081")); _pixel(14, 9, 3, 13, Color("#bdd198"))
  "radish":
   _pixel(10, 12, 13, 12, Color("#e2e0bd")); _pixel(13, 23, 7, 4, Color("#d6d6b4")); _pixel(15, 27, 2, 2, Color("#c7c6a6")); _pixel(13, 5, 4, 10, Color("#86a765")); _pixel(6, 5, 8, 5, Color("#93ad6a")); _pixel(17, 2, 6, 8, Color("#6e965c"))
  "tomato", "berry":
   _pixel(6, 11, 20, 12, Color("#bb7050")); _pixel(9, 8, 14, 18, Color("#ca8059")); _pixel(9, 10, 6, 5, Color("#d69969")); _pixel(13, 5, 4, 7, Color("#77925a")); _pixel(9, 8, 13, 3, Color("#82995c"))
  "rice", "feed":
   _pixel(7, 13, 18, 14, Color("#c2ad79")); _pixel(7, 12, 18, 4, Color("#dbc697"))
   for index in range(5): _pixel(9 + index * 3, 7 - index % 2 * 3, 2, 8, Color("#d9bd72")); _pixel(9 + index * 3, 16, 2, 3, Color("#eee0b0"))
  "egg":
   _poly([Vector2(10, 26), Vector2(6, 21), Vector2(8, 12), Vector2(13, 5), Vector2(19, 5), Vector2(24, 13), Vector2(26, 21), Vector2(22, 26)], Color("#e0d3a3")); _pixel(12, 10, 8, 12, Color("#fff2cd"))
  "milk":
   _pixel(10, 8, 13, 19, Color("#e6e3c7")); _pixel(13, 4, 7, 5, Color("#9aa99a")); _pixel(10, 15, 13, 7, Color("#94b7af")); _pixel(12, 10, 3, 4, Color("#faf2d6"))
  "wood", "bamboo":
   _pixel(6, 9, 22, 8, Color("#a78e60") if icon_kind == "wood" else Color("#8ba76a")); _pixel(7, 19, 21, 7, Color("#ad9569") if icon_kind == "wood" else Color("#8da96a")); _pixel(4, 8, 6, 10, Color("#d2ba86") if icon_kind == "wood" else Color("#c5cf95")); _pixel(5, 18, 6, 9, Color("#d5be91") if icon_kind == "wood" else Color("#c8cf94")); _pixel(15, 9, 2, 17, Color(0.49, 0.50, 0.32, 0.12))
  "shoot":
   _poly([Vector2(7, 26), Vector2(11, 13), Vector2(16, 4), Vector2(21, 13), Vector2(25, 26)], Color("#b1a474")); _pixel(11, 16, 10, 3, Color("#d2c79d")); _pixel(9, 22, 15, 3, Color("#daceaa")); _pixel(15, 7, 4, 5, Color("#789057"))
  "mushroom":
   _pixel(13, 16, 7, 12, Color("#e2d4ac")); _pixel(6, 12, 22, 8, Color("#ad8967")); _pixel(10, 8, 15, 8, Color("#ba9b75")); _pixel(14, 5, 6, 5, Color("#b0926b")); _pixel(10, 13, 4, 3, Color("#e3c69b")); _pixel(21, 14, 3, 2, Color("#e3c69b"))
  "fish":
   _draw_fish(Color("#7f9c99"))
  "dish", "riceBowl", "soup":
   _draw_dish(id, item)
  "jar":
   _draw_vessel("jar", Color("#9a825b"))
  _:
   _draw_generic(id)
 if id == "eggplant": _ellipse(16, 19, 10, 8, Color("#574b78")); _pixel(9, 14, 3, 9, Color("#9883ae"))
 elif id == "carrot": _poly([Vector2(8, 10), Vector2(21, 11), Vector2(13, 28)], Color("#dd9246")); _pixel(11, 12, 3, 6, Color("#eec278"))
 elif id == "pumpkin": _ellipse(16, 19, 12, 10, Color("#d99541")); _pixel(14, 5, 4, 6, Color("#648250"))
 elif id == "pepper": _ellipse(16, 19, 9, 10, Color("#4c8654")); _pixel(16, 5, 3, 6, LEAF)
 elif id == "corn":
  _pixel(10, 8, 13, 20, Color("#e0be5a"))
  for y in range(9, 26, 4):
   for x in range(11, 23, 4): _pixel(x, y, 2, 2, Color("#f0d886"))
  _poly([Vector2(7, 15), Vector2(12, 21), Vector2(15, 30), Vector2(8, 24)], Color("#698d4c"))

func _draw_fish(color: Color) -> void:
 _poly([Vector2(4, 17), Vector2(9, 12), Vector2(21, 12), Vector2(26, 16), Vector2(21, 21), Vector2(9, 21)], color)
 _poly([Vector2(5, 16), Vector2(1, 11), Vector2(1, 22)], Color("#92ada2"))
 _pixel(13, 13, 9, 6, Color("#b2c4b3")); _pixel(22, 15, 2, 2, Color("#506d5e"))

func _draw_generic(id: String) -> void:
 var value := absi(hash(id))
 var colors := [Color("#ad9771"), Color("#80795e"), Color("#869b77"), Color("#ae7c5c"), Color("#8d9da0")]
 var color: Color = colors[value % colors.size()]
 _poly([Vector2(7, 10), Vector2(11, 6), Vector2(23, 6), Vector2(27, 10), Vector2(26, 27), Vector2(6, 27)], INK)
 _pixel(8, 10, 16, 15, color); _pixel(10, 11, 3, 11, color.lightened(0.18)); _pixel(12, 16, 8, 5, CREAM)
 _pixel(15, 17, 2, 3, INK)
