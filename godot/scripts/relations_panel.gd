extends Control
const PORTRAIT = preload("res://scripts/character_portrait.gd")
const FILTERS = ["全部", "画像册", "成年候选人", "主要邻居", "孩子们"]
var panel: PanelContainer
var column: VBoxContainer
var scroll: ScrollContainer
var records: VBoxContainer
var close_button: Button
var tabs: Dictionary = {}
var cards: Dictionary = {}

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 var backdrop := ColorRect.new()
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.color = Color("08100bde")
 add_child(backdrop)
 panel = PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("304232f5")
 style.border_color = Color("beaa75")
 style.set_border_width_all(2)
 style.set_corner_radius_all(8)
 for side in ["left", "right", "top", "bottom"]: style.set_content_margin(SIDE_LEFT if side == "left" else SIDE_RIGHT if side == "right" else SIDE_TOP if side == "top" else SIDE_BOTTOM, 16)
 panel.add_theme_stylebox_override("panel", style)
 add_child(panel)
 column = VBoxContainer.new()
 column.add_theme_constant_override("separation", 10)
 panel.add_child(column)
 set_meta("notification_column", column)
 set_meta("notification_index", 2)
 var title := Label.new()
 title.text = "二十四位邻居，各有自己的日子。"
 column.add_child(title)
 var subtitle := Label.new()
 subtitle.text = "8 位成年候选人、12 位主要支持村民、4 位少年儿童。关系不会衰减，故事可以延后。"
 subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(subtitle)
 var tab_row := HFlowContainer.new()
 column.add_child(tab_row)
 for key in FILTERS:
  var button := Button.new()
  button.text = key
  button.pressed.connect(set_filter.bind(key))
  tab_row.add_child(button)
  tabs[key] = button
 scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 column.add_child(scroll)
 records = VBoxContainer.new()
 records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 records.add_theme_constant_override("separation", 12)
 scroll.add_child(records)
 var footer := HBoxContainer.new()
 column.add_child(footer)
 var book := Button.new()
 book.text = "禾溪邻里簿"
 book.pressed.connect(func():get_parent().show_neighbor_book())
 footer.add_child(book)
 close_button = Button.new()
 close_button.text = "关闭 Esc"
 close_button.pressed.connect(close)
 footer.add_child(close_button)
 resized.connect(_fit)
 GameState.changed.connect(func():if visible:refresh())
 _fit()
 hide()

func _fit() -> void:
 var half := Vector2(minf(430, maxf(140, size.x / 2 - 16)), minf(265, maxf(150, size.y / 2 - 16)))
 panel.offset_left = -half.x
 panel.offset_right = half.x
 panel.offset_top = -half.y
 panel.offset_bottom = half.y

func open_panel() -> void:
 if GameState.action_busy():return
 preload("res://scripts/modal_status.gd").clear_message(self)
 GameState._interrupt_navigation_for_ui()
 refresh()
 show()
 GameState.ui_open = true
 close_button.grab_focus()

func close() -> void:
 hide()
 GameState.ui_open = false

func is_open() -> bool:return visible

func set_filter(value: String) -> void:
 if not value in FILTERS:return
 GameState.relations_ui_filter = value
 scroll.scroll_vertical = 0
 refresh()
 tabs[value].grab_focus()

func people_rows() -> Array:
 var result: Array = []
 var filter := GameState.relations_ui_filter
 var tier := str({"成年候选人":"romance", "主要邻居":"support", "孩子们":"child"}.get(filter, ""))
 for person in GameState.npc_catalog:
  if tier != "" and str(person.get("tier", "")) != tier:continue
  var id := str(person.id)
  var likes: PackedStringArray = []
  for item_id in person.get("likes", []):likes.append(str(GameState.item_catalog.get(str(item_id), {}).get("name", item_id)))
  var points := int(GameState.relations.get(id, {}).get("points", 0))
  var stage := "伴侣" if str(GameState.marriage.get("spouse", "")) == id else "心意相通" if str(GameState.partners.get(id, "")) == "dating" else GameState._relationship_stage(points)
  var birthday := int(person.get("birthday", 1)) - 1
  var place := str(GameState.content.get("scenes", {}).get(GameState.npc_scene_region(id), {}).get("name", ""))
  var profile := "%s · %s 岁 · %s\n%s\n此刻：%s · 生日：%s %d 日\n喜欢：%s" % [str(person.get("role", "")), str(int(person.get("age", 0))), str(person.get("gender", "")), str(person.get("family", "")), place, ["春", "夏", "秋", "冬"][int(birthday / 28)], birthday % 28 + 1, "、".join(likes)]
  var story := "个人故事 %d / %d · %s" % [int(GameState.npc_stories.get(id, {}).get("step", 0)), GameState.content.get("arcs", {}).get(id, []).size(), str(GameState.npc_story_readiness(id).get("message", ""))]
  result.append({"id":id, "name":str(person.name), "role":str(person.get("role", "")), "stage":stage, "points":points, "profile":profile, "story":story})
 return result

func refresh() -> void:
 for child in records.get_children():
  records.remove_child(child)
  child.queue_free()
 cards.clear()
 var gallery := GameState.relations_ui_filter == "画像册"
 for key in tabs:tabs[key].text = ("✓ " if key == GameState.relations_ui_filter else "") + key
 var container: Container = records
 if gallery:
  var grid := GridContainer.new()
  grid.columns = 3 if size.x >= 700 else 2 if size.x >= 460 else 1
  grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  records.add_child(grid)
  container = grid
 for row in people_rows():
  var card := PanelContainer.new()
  card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  container.add_child(card)
  var body: BoxContainer = VBoxContainer.new() if gallery else HBoxContainer.new()
  body.add_theme_constant_override("separation", 12)
  card.add_child(body)
  var portrait := Control.new()
  portrait.set_script(PORTRAIT)
  portrait.custom_minimum_size = Vector2(128, 160) if gallery else Vector2(64, 80)
  body.add_child(portrait)
  var person: Dictionary = {}
  for candidate in GameState.npc_catalog:
   if str(candidate.id) == str(row.id):person = candidate;break
  portrait.call("configure", str(row.id), person, "calm")
  var details := VBoxContainer.new()
  details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  body.add_child(details)
  var name_label := Label.new()
  name_label.text = str(row.name) if gallery else str(row.name) + " · " + str(row.stage)
  details.add_child(name_label)
  var profile := Label.new()
  profile.text = str(row.role) if gallery else str(row.profile)
  profile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  details.add_child(profile)
  if not gallery:
   var progress := ProgressBar.new()
   progress.value = int(row.points)
   progress.show_percentage = false
   progress.custom_minimum_size.y = 8
   details.add_child(progress)
   var story := Label.new()
   story.text = str(row.story)
   story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   details.add_child(story)
  var actions := VBoxContainer.new()
  body.add_child(actions)
  var find := Button.new()
  find.text = "去找" + str(row.name) if gallery else "去找对方"
  find.pressed.connect(func():GameState.find_npc(str(row.id)))
  actions.add_child(find)
  var story_button: Button = null
  if not gallery:
   story_button = Button.new()
   story_button.text = "故事与线索"
   story_button.pressed.connect(func():get_parent().show_npc_story(str(row.id)))
   actions.add_child(story_button)
  cards[str(row.id)] = {"find":find, "story":story_button, "portrait":portrait, "profile":profile}
