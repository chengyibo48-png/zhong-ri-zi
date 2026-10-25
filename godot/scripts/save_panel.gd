extends Control
class_name SavePanel

const SLOT_PATHS := {
	"auto": "user://zhenrizhi_godot_save.json",
	"one": "user://zhenrizhi_godot_slot_1.json",
	"two": "user://zhenrizhi_godot_slot_2.json",
	"three": "user://zhenrizhi_godot_slot_3.json",
	"backup": "user://zhenrizhi_godot_backup.json",
	"recovery": "user://zhenrizhi_godot_recovery.json"
}
const SLOT_NAMES := {"auto": "每日自动档", "one": "手动存档一", "two": "手动存档二", "three": "手动存档三", "backup": "操作前备份", "recovery": "读取前回退档"}

var list: VBoxContainer
var notice: Label
var file_dialog: FileDialog
var confirm_dialog: ConfirmationDialog
var pending_save_slot := ""
var new_game_confirmation: Control
var new_game_button: Button
var browser_bridge: RefCounted

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.08, 0.06, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -270
	panel.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303a30")
	style.border_color = Color("c5b184")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "存档与读档"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var hint := Label.new()
	hint.text = "手动档覆盖前会再次确认；读档和导入会先保留当前进度。浏览器版 v1–v3 JSON 可以直接带入。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	list = VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	var slot_scroll := ScrollContainer.new()
	slot_scroll.name = "SaveSlotScroll"
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(slot_scroll)
	slot_scroll.add_child(list)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var import_button := Button.new()
	import_button.text = "导入存档 JSON"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(_choose_import)
	actions.add_child(import_button)
	var export_button := Button.new()
	export_button.text = "导出当前存档"
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_choose_export)
	actions.add_child(export_button)
	new_game_button = Button.new()
	new_game_button.text = "重新开始生活"
	new_game_button.pressed.connect(_request_new_game)
	column.add_child(new_game_button)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = OS.has_feature("android")
	file_dialog.filters = PackedStringArray(["*.json ; JSON 存档 ; application/json"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "覆盖手动存档？"
	confirm_dialog.dialog_text = "此位置已有进度。新存档会替换它，其他手动档不会改变。"
	confirm_dialog.ok_button_text = "覆盖并保存"
	confirm_dialog.confirmed.connect(_confirm_save_slot)
	add_child(confirm_dialog)
	new_game_confirmation = load("res://scripts/relationship_confirmation.gd").new()
	add_child(new_game_confirmation)
	new_game_confirmation.connect("confirmed", _confirm_new_game)
	new_game_confirmation.connect("cancelled", func(): new_game_button.grab_focus())
	new_game_confirmation.connect("extra_requested", _choose_export)
	GameState.changed.connect(refresh)
	visible = false

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	notice.text = ""
	refresh()

func close() -> void:
	new_game_confirmation.call("close")
	confirm_dialog.hide()
	file_dialog.hide()
	pending_save_slot = ""
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or not is_instance_valid(list):
		return
	for child in list.get_children():
		child.queue_free()
	for slot in ["auto", "one", "two", "three", "backup", "recovery"]:
		var row := HBoxContainer.new()
		list.add_child(row)
		var detail := Label.new()
		detail.text = "%s · %s" % [SLOT_NAMES[slot], _summary(str(SLOT_PATHS[slot]))]
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(detail)
		if slot in ["one", "two", "three"]:
			var save_button := Button.new()
			save_button.text = "保存"
			save_button.pressed.connect(_save_slot.bind(slot))
			row.add_child(save_button)
		var load_button := Button.new()
		load_button.text = "读取"
		load_button.disabled = not FileAccess.file_exists(str(SLOT_PATHS[slot]))
		load_button.pressed.connect(_load_slot.bind(slot))
		row.add_child(load_button)

func _summary(path: String) -> String:
	if not FileAccess.file_exists(path): return "尚无记录"
	var data: Variant = preload("res://scripts/save_repository.gd").read(path)
	if not data is Dictionary: return "文件损坏或超过 16 MiB"
	var save_day := int(data.get("day", 0))
	var year := floori(float(save_day) / 112.0) + 1
	var season := str(["春", "夏", "秋", "冬"][posmod(floori(float(save_day) / 28.0), 4)])
	return "%s · 第 %d 年 %s %d 日 · %d 元" % [str(data.get("player_name", data.get("name", "小满"))), year, season, save_day % 28 + 1, int(data.get("money", 0))]

func _save_slot(slot: String) -> void:
	var path := str(SLOT_PATHS.get(slot, ""))
	if path == "": return
	if FileAccess.file_exists(path):
		pending_save_slot = slot
		confirm_dialog.dialog_text = "%s已有记录：%s。覆盖后，其他存档位置保持不变。" % [str(SLOT_NAMES.get(slot, "手动存档")), _summary(path)]
		confirm_dialog.popup_centered()
		return
	_write_save_slot(slot)

func _confirm_save_slot() -> void:
	if pending_save_slot != "": _write_save_slot(pending_save_slot)
	pending_save_slot = ""

func _write_save_slot(slot: String) -> void:
	var path := str(SLOT_PATHS.get(slot, ""))
	var saved: bool = GameState.save_game(path)
	notice.text = "%s" % (str(SLOT_NAMES.get(slot, "存档")) + ("已保存。" if saved else "保存失败，原有记录仍保留。"))
	refresh()
func _load_slot(slot: String) -> void:
	var path := str(SLOT_PATHS.get(slot, ""))
	if path.is_empty(): return
	var result := preload("res://scripts/save_session.gd").restore(GameState,path)
	notice.text = str(result.message)
	if not result.ok:
		refresh()
		return
	GameState.message = str(result.message)
	GameState.changed.emit()
	_reload_world_scene()
	close()

func _choose_import() -> void:
	if OS.has_feature("web"):
		browser_bridge = preload("res://scripts/browser_save_bridge.gd").new()
		browser_bridge.choose(_import_text)
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "导入浏览器或 Godot JSON 存档"
	file_dialog.current_file = ""
	file_dialog.popup_centered(Vector2i(900, 600))

func _choose_export() -> void:
	if OS.has_feature("web"):
		browser_bridge = preload("res://scripts/browser_save_bridge.gd").new()
		var encoded := preload("res://scripts/save_json.gd").encode(GameState._make_save_data())
		if not browser_bridge.download(encoded, "种日子-%d.json" % GameState.day):
			notice.text = "导出失败：存档编码无效或超过 16 MiB，当前进度未改动。"
			return
		notice.text = "存档已交给浏览器下载，请保留一份备份。"
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "导出 Godot 存档"
	file_dialog.current_file = "种日子-Godot-%d.json" % GameState.day
	file_dialog.popup_centered(Vector2i(900, 600))

func _file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var ok := preload("res://scripts/save_repository.gd").write(path,GameState._make_save_data())
		notice.text = "存档已导出到所选位置。" if ok else "导出失败，原文件和当前进度仍保留。"
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		notice.text = "无法打开这份存档。"
		return
	if file.get_length() > preload("res://scripts/native_save_schema.gd").MAX_BYTES:
		file.close()
		notice.text = "文件超过 16 MiB，当前进度未修改。"
		return
	var text := file.get_as_text()
	file.close()
	_import_text(text)

func _import_text(text: String) -> void:
	if text == "__ZRZ_TOO_LARGE__" or text.to_utf8_buffer().size() > preload("res://scripts/native_save_schema.gd").MAX_BYTES:
		notice.text = "文件超过 16 MiB，请选择有效的存档 JSON。"
		return
	var parsed: Variant = preload("res://scripts/save_json.gd").parse(text)
	if not parsed is Dictionary:
		notice.text = "JSON 内容无效；当前进度未修改。"
		return
	if GameState.import_external_save(parsed):
		notice.text = GameState.message
		_reload_world_scene()
		close()
	else:
		notice.text = GameState.message
		refresh()

func _reload_world_scene() -> void:
	var scene := "res://scenes/interior.tscn" if GameState.current_interior != "" and not GameState.interior_house().is_empty() else "res://scenes/main.tscn"
	get_tree().call_deferred("change_scene_to_file", scene)


func _request_new_game() -> void:
	new_game_confirmation.call("open", "重新推开院门",
		"建议先导出当前存档，或保存到手动档。\n\n新生活会替换每日自动存档，手动档仍会保留。当前这段日子会先写入备份，可从存档簿重新读回。",
		"开始新的生活", "留在现在的日子")
	new_game_confirmation.call("show_extra", "先导出当前存档")

func _confirm_new_game() -> void:
	new_game_confirmation.call("close")
	if GameState.start_new_game():
		close()
		_reload_world_scene()
	else:
		notice.text = GameState.message
		new_game_button.grab_focus()
