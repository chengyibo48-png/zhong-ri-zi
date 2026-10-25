extends RefCounted
static func frame(pet_data:Dictionary,companion:Dictionary,minutes:float)->Dictionary:
	var row:Dictionary=preload("res://scripts/world_art.gd").entries().get("pets/"+str(companion.get("type","cat")),{})
	if not bool(row.get("baseReady",false)):return {}
	var texture:=preload("res://scripts/character_art.gd").texture(str(row.get("path","")))
	if texture==null or texture.get_size()!=Vector2(1024,128):return {}
	var direction:int=row.directions.find(str(pet_data.get("position",{}).get("direction","down")))
	if direction<0:return {}
	var scale_factor:=float(row.worldHeight)/float(row.get("spriteHeight",108.0))
	var anchor:Array=row.get("anchor",[128,116])
	return {"texture":texture,"source":Rect2(direction*256,0,256,128),"destination":Rect2(Vector2(-float(anchor[0]),-float(anchor[1]))*scale_factor,Vector2(256,128)*scale_factor),"direction":direction}
const POSES := ["idle", "walk_a", "walk_b", "feeding", "petting", "sleeping"]
static func pose(pet: Dictionary, minutes: float, clock: float, action: Dictionary, motion: bool = true) -> String:
	var active := clock < float(action.get("until", -1.0)) and clock >= float(action.get("at", 0.0))
	var kind := str(action.get("kind", "")) if active else ""
	if kind == "feed": return "feeding"
	if kind == "pet": return "petting"
	if int(pet.get("energy", 100)) < 15 or minutes >= 1140: return "sleeping"
	if bool(pet.get("position", {}).get("walking", false)) or kind == "train":
		return "walk_a" if not motion or posmod(floori(clock * 8.0), 2) == 0 else "walk_b"
	return "idle"

static func action_frame(pet: Dictionary, companion: Dictionary, minutes: float, clock: float) -> Dictionary:
	var row: Dictionary = preload("res://scripts/world_art.gd").entries().get("pets/" + str(companion.get("type", "cat")), {})
	var texture: Texture2D = preload("res://scripts/character_art.gd").texture(str(row.get("actionAtlas", "")))
	var directions: Array = row.get("directions", ["down", "left", "right", "up"])
	var direction: int = directions.find(str(pet.get("position", {}).get("direction", "down")))
	if texture == null or direction < 0 or texture.get_size() != Vector2(1024, 960): return {}
	var state := pose(pet, minutes, clock, GameState.pet_visual_action, preload("res://scripts/life_presentation.gd").animate())
	var index: int = POSES.find(state)
	var ratio := float(row.get("worldHeight", 30.0)) / 144.0
	return {"texture":texture, "source":Rect2(direction * 256, index * 160, 256, 160), "destination":Rect2(Vector2(-128, -154) * ratio, Vector2(256, 160) * ratio), "state":state}

static func draw(target: CanvasItem, pet: Dictionary, companion: Dictionary, at: Vector2, minutes: float, clock: float = 0.0) -> bool:
	var descriptor := action_frame(pet, companion, minutes, clock)
	if descriptor.is_empty(): descriptor = frame(pet, companion, minutes)
	if descriptor.is_empty(): return false
	var moving := preload("res://scripts/life_presentation.gd").animate()
	var state := str(descriptor.get("state", pose(pet, minutes, clock, GameState.pet_visual_action, moving)))
	var phase := clock if moving else 0.0
	var walking := state in ["walk_a", "walk_b"]
	var sleeping := state == "sleeping"
	var bounce := -absf(sin(phase * 8.0)) * 0.65 if walking else 0.0
	var breath := 1.0 + sin(phase * (1.1 if sleeping else 2.0)) * 0.009
	var lean := sin(phase * 4.5) * 0.018 if state == "petting" else sin(phase * 6.0) * 0.009 if walking else 0.0
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preload("res://scripts/ground_style.gd").shadow(target, at + Vector2(0, 0.5), 17, 4)
	target.draw_set_transform(at + Vector2(0, bounce), lean, Vector2(1.0, breath))
	target.draw_texture_rect_region(descriptor.texture, descriptor.destination, descriptor.source)
	target.draw_set_transform(Vector2.ZERO)
	if state == "feeding":
		target.draw_ellipse(at + Vector2(5, 1), 6.0, 2.0, Color("#8f744d"))
		target.draw_ellipse(at + Vector2(5, 0), 4.5, 1.0, Color("#d8c17b"))
	elif sleeping:
		target.draw_string(ThemeDB.fallback_font, at + Vector2(8, -15 - sin(phase) * 1.2), "z", HORIZONTAL_ALIGNMENT_CENTER, 8, 8, Color("#e5dfc9"))
	elif state == "petting":
		var heart := at + Vector2(10, -21 - sin(phase * 2.0))
		target.draw_circle(heart, 1.8, Color("#e98f92"))
		target.draw_circle(heart + Vector2(3, 1), 1.5, Color("#e98f92"))
	elif clock < float(GameState.pet_visual_action.get("until", -1.0)) and str(GameState.pet_visual_action.get("kind", "")) == "train":
		target.draw_arc(at + Vector2(sin(phase * 4.0) * 8, -7), 3, 0, TAU, 12, Color("#e1b75f"), 1.2)
	return true
