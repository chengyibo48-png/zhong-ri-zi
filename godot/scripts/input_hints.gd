extends RefCounted
static func touch() -> bool:
	return preload("res://scripts/performance_policy.gd").touch_device() or GameState.source_input_mode == "touch"
static func text(source: String) -> String:
	if not touch(): return source
	var result := source
	for row: Array in [["按 E","点按互动"],["E ·","点按 ·"],["[ / ]","点按切换"],["[/]","点按切换"],["Enter 起锅, Esc 取消","点按起锅或取消"],["Esc / B","返回"],["Tab / Esc","菜单"],["Esc 合上 · Tab 切换焦点 · 手柄 B / Start 返回","点按选择，关闭返回村庄"],["按 Q","点按种子"]]: result = result.replace(str(row[0]),str(row[1]))
	result = RegEx.create_from_string("\\b(?:[A-Z]|Esc|Enter|Tab|Shift|Space|Start|L3)\\b").sub(result,"",true)
	return result.strip_edges().trim_suffix(" ·").strip_edges()
