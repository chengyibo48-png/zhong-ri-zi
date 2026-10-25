extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("_run")
func check(ok: bool, label: String):
 if ok: passed += 1
 else: failed += 1; push_error(label)
func _run():
 var codec = load("res://scripts/save_json.gd")
 var samples: Array = [1.7234899999999997, 0.1, -0.1, 1319.875, 0.0, -0.0, 1.0e-200, 1.0e200]
 for i in range(400):
  samples.append(sin(float(i) * 0.17) * 100.0)
 var data := {"nested": {"growth": samples[0]}, "samples": samples, "empty": [], "text": "一年又一年", "count": 17}
 var text: String = codec.encode(data)
 var raw: Variant = JSON.parse_string(text)
 check(raw is Dictionary and raw.has(codec.FLOAT_KEY), "精度附加数据仅存在于文件")
 var restored: Variant = codec.decode(raw)
 check(restored is Dictionary and not restored.has(codec.FLOAT_KEY), "回读移除文件元数据")
 check(restored.nested.growth == data.nested.growth, "原失败生长值严格还原")
 for i in range(samples.size()):
  check(restored.samples[i] == samples[i], "全部 binary64 严格还原 " + str(i))
 check(restored.text == data.text and restored.count == 17 and restored.empty == [], "文本整数字段保持兼容")
 var old: Dictionary = codec.decode(JSON.parse_string(codec.encode({"version": 31, "x": 0.5})))
 check(old.size() == 2 and old.version == 31 and old.x == 0.5, "不需要附加数据的旧文件")
 check(codec.decode({"version": 31, "x": 0.5}) == {"version": 31, "x": 0.5}, "没有精度数据的旧文件")
 for mutation in ["version", "entries", "path", "index", "bytes", "stale", "infinite", "type"]:
  var invalid: Dictionary = JSON.parse_string(text)
  var entry: Dictionary = invalid[codec.FLOAT_KEY].entries[0]
  match mutation:
   "version": invalid[codec.FLOAT_KEY].version = 9
   "entries": invalid[codec.FLOAT_KEY].entries = {}
   "path": entry.path = ["missing"]
   "index": entry.path = ["samples", -1]
   "bytes": entry.bytes = "AA=="
   "stale":
    var parent: Variant = invalid
    for i in range(entry.path.size() - 1):
     var key: Variant = entry.path[i]
     parent = parent[int(key) if parent is Array else key]
    var last: Variant = entry.path.back()
    parent[int(last) if parent is Array else last] = 50
   "infinite":
    var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, INF)
    entry.bytes = Marshalls.raw_to_base64(bytes)
   "type": entry.path = ["text"]
  check(codec.decode(invalid) == null, "损坏精度数据拒绝 " + mutation)
 var state = root.get_node("GameState")
 state.set_process(false)
 var value: float = 0.0
 for i in range(400):
  var candidate := absf(sin(float(i) * 0.17) * 2.0)
  if JSON.parse_string(JSON.stringify({"v": candidate}, "", false, true)).v != candidate:
   value = candidate
   break
 check(value > 0.0, "构造原生入口的实际十进制差异")
 state.plots[0].growth = value
 var raw_save: Dictionary = JSON.parse_string(codec.encode(state._make_save_data()))
 var copy = load("res://scripts/game_state.gd").new()
 copy._load_content()
 check(copy.load_game_data(raw_save) and copy.plots[0].growth == value, "直接原生读档入口保持严格精度")
 check(copy.load_game_data(copy.convert_external_save(raw_save)) and copy.plots[0].growth == value, "Godot JSON 导入入口保持严格精度")
 check(raw_save.has(codec.FLOAT_KEY), "读档不修改调用方文件数据")
 var invalid_save := raw_save.duplicate(true)
 invalid_save[codec.FLOAT_KEY].version = 8
 var before_day: int = copy.day
 check(not copy.load_game_data(invalid_save) and copy.day == before_day, "直接入口拒绝损坏数据且保留原进度")
 check(copy.convert_external_save(invalid_save).is_empty(), "原生导入转换拒绝损坏精度数据")
 copy.free()
 print("SAVE_PRECISION_SMOKE: %d passed, %d failed" % [passed, failed])
 await root.get_node("AudioService").prepare_exit()
 quit(0 if failed == 0 else 1)
