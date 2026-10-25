extends RefCounted
static var _web_touch := -1

static func touch_device() -> bool:
	if OS.get_environment("ZRZ_FORCE_TOUCH") == "1": return true
	if OS.has_feature("web"):
		if _web_touch < 0:
			# iPad's desktop UA uses MacIntel; Windows touch laptops keep desktop UI.
			_web_touch = 1 if bool(JavaScriptBridge.eval("/Android|iPhone|iPad/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)", true)) else 0
		return _web_touch == 1
	return OS.has_feature("android")

static func integrated_adapter(adapter: String) -> bool:
	var name := adapter.to_lower().replace("(tm)", "")
	if "intel" in name: return true
	if "radeon" not in name: return false
	return "radeon graphics" in name or "radeon(tm) graphics" in name or "vega" in name or RegEx.create_from_string("radeon (?:\\(tm\\) )?[0-9]{3,4}m(?: |$)").search(name) != null

static func frame_cap(adapter: String, touch: bool, profile: String = "auto", forced_light: bool = false) -> int:
	if touch or profile == "light": return 30
	if integrated_adapter(adapter) or forced_light: return 60
	return 0

static func configure(window: Window) -> void:
	var touch := touch_device()
	if touch:
		window.content_scale_size = Vector2i(800, 600)
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var state := window.get_node_or_null("GameState")
	var settings: Variant = state.get("player_settings") if state != null else {}
	var profile: String = settings.get("performance", "auto") if settings is Dictionary else "auto"
	Engine.max_fps = frame_cap(RenderingServer.get_video_adapter_name(),touch,profile,OS.get_environment("ZRZ_LIGHT_PROFILE") == "1")

