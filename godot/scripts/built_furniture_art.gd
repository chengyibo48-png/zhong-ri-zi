extends RefCounted
## Shared by room, courtyard and the read-only furnishing preview.
const HEIGHTS := {"bench": 42.0, "teaTable": 34.0, "cabinet": 62.0, "bookshelf": 76.0, "workbench": 42.0, "display": 62.0, "flowerbed": 30.0, "trellis": 96.0, "well": 96.0, "stoneLantern": 72.0,"pot":42.0,"path":0.0,"fence":42.0,"orchard":98.0,"photo":38.0,"waterbed":36.0,"scarecrow":74.0,"greenhouse":94.0,"lantern":42.0,"sign":44.0,"seedrack":56.0,"rug":0.0}
static var _textures: Dictionary = {}
static var _lamp_glow: GradientTexture2D
const LAMP_WINDOWS := [Vector2(0.53,0.51), Vector2(0.44,0.53), Vector2(0.50,0.55), Vector2(0.55,0.53)]
static func lamp_strength(minutes: int, direction := 0, room:String="") -> float:
	# The rear vent is dimmer than an open candle window. No per-frame flicker.
	return load("res://scripts/scene_lighting.gd").strength(minutes,direction,room)
static func lamp_window(direction: int, rectangle: Rect2) -> Vector2:
	return rectangle.position + rectangle.size * LAMP_WINDOWS[posmod(direction,4)]
static func _glow_texture() -> GradientTexture2D:
	return load("res://scripts/scene_lighting.gd").glow_texture()
static func ground_surface(id:String)->bool:return id in ["path","rug"]
static func supports(id: String) -> bool:
	return HEIGHTS.has(id)
static func texture_for(id: String, rotation: int) -> Texture2D:
	if not supports(id): return null
	var path := "res://art/furniture/models/%s_%d.png" % [id, posmod(rotation, 4)]
	if not _textures.has(path): _textures[path] = preload("res://scripts/character_art.gd").texture(path)
	return _textures[path] as Texture2D
static func sprite_rect(id: String, rotation: int, footprint: Rect2) -> Rect2:
	if ground_surface(id):return footprint.grow(-1.5)
	var tex := texture_for(id, rotation)
	if tex == null: return Rect2()
	var max_size := Vector2(maxf(18.0, footprint.size.x - 8.0), float(HEIGHTS[id]) + footprint.size.y * 0.28)
	var ratio := minf(max_size.x / tex.get_width(), max_size.y / tex.get_height())
	var size := tex.get_size() * ratio
	return Rect2(Vector2(footprint.get_center().x - size.x * 0.5, footprint.end.y - 4.0 - size.y), size)
static func draw(canvas: CanvasItem, piece: Dictionary, footprint: Rect2, minutes: int, focused := false) -> bool:
	var id := str(piece.get("type", ""))
	if not supports(id): return false
	var rotation := int(piece.get("rotation", 0))
	var target := sprite_rect(id, rotation, footprint)
	if ground_surface(id):
		canvas.draw_texture_rect(texture_for(id,rotation),target,false,Color.WHITE.lerp(Color("a4abc2"),preload("res://scripts/world_art.gd").night_factor(minutes)*.38))
		return true
	# Ground contact is separate from the source art; no baked rectangle or shadow.
	var projection:Vector2=load("res://scripts/scene_lighting.gd").sun(minutes)
	var shadow := Rect2(footprint.position + Vector2(6, footprint.size.y * 0.56)+projection*.45, Vector2(maxf(8, footprint.size.x - 12), footprint.size.y * 0.38))
	var points := PackedVector2Array()
	for i in range(24):
		points.append(shadow.get_center() + Vector2(cos(i * TAU / 24.0), sin(i * TAU / 24.0)) * shadow.size * 0.5)
	canvas.draw_colored_polygon(points, Color(0.13, 0.17, 0.12, 0.16))
	var night: float = preload("res://scripts/world_art.gd").night_factor(minutes)
	var light := lamp_strength(minutes,rotation,"home" if str(piece.get("zone",""))=="home" else "") if id in ["stoneLantern","lantern"] else 0.0
	if light > 0.0:
		var radius := clampf(target.size.y * 0.42,16.0,34.0)
		canvas.draw_texture_rect(_glow_texture(), Rect2((target.position+target.size*Vector2(.5,.56) if id=="lantern" else lamp_window(rotation,target)) - Vector2.ONE * radius, Vector2.ONE * radius * 2),false,Color(1,1,1,light))
	canvas.draw_texture_rect(texture_for(id, rotation), target, false, Color.WHITE.lerp(Color("a4abc2"), night * 0.38))
	if light > 0.0:
		canvas.draw_circle((target.position+target.size*Vector2(.5,.56) if id=="lantern" else lamp_window(rotation,target)), minf(1.25,target.size.x * 0.035), Color(1.0,0.77,0.35,light * 0.72))
	return true
