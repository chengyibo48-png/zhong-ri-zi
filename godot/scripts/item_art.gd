extends RefCounted
## Shared access to real inventory illustrations. Missing art is tracked, never
## replaced by a generic generated image and counted as completed.
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_art_manifest.json"))
		if raw is Dictionary: _manifest = raw.get("entries", {})
	return _manifest

static func key_for(id: String, category: String = "") -> String:
	if id.contains("/"):
		if not manifest().has(id): return ""
		if category != "" and id.get_slice("/", 0) != category: return ""
		return id
	if category != "":
		var explicit_key := category + "/" + id
		return explicit_key if manifest().has(explicit_key) else ""
	for group in ["items", "tools", "furniture", "archives", "achievements", "stations", "facilities"]:
		var key: String = group + "/" + id
		if manifest().has(key): return key
	return ""

static func texture_for(id: String, category: String = "") -> Texture2D:
	var key := key_for(id, category)
	if _textures.has(key): return _textures[key]
	var entry: Dictionary = manifest().get(key, {})
	var path := str(entry.get("path", ""))
	if path == "" or (not ResourceLoader.exists(path) and not FileAccess.file_exists(path)): return null
	var texture: Texture2D
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	else:
		# Editor previews can consume a newly copied image before first import.
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty(): return null
		texture = ImageTexture.create_from_image(image)
	if texture != null: _textures[key] = texture
	return texture

static func fit_list(list: ItemList) -> void:
	list.fixed_icon_size = Vector2i(48, 48)
	list.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	list.add_theme_constant_override("icon_margin", 10)
