extends RefCounted
# The source atlas validator operates on JavaScript numbers and UTF-16 strings.
const JS_STRING = preload("res://scripts/js_string.gd")
const LAYERS := ["all","homes","neighbors","services","harvest","water","animals","resources","pins"]
const ERROR_MESSAGE := "地图手记存档无效，请使用备份。"

static func truthy(value: Variant) -> bool:
 if value == null: return false
 if value is bool: return value
 if value is int or value is float: return float(value) != 0.0 and not is_nan(float(value))
 if value is String: return value != ""
 return true

static func number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func utf16_length(value: Variant) -> int:
 return JS_STRING.length(value)

static func coordinates(value: Variant) -> bool:
 return value is Dictionary and number(value.get("x")) and number(value.get("y")) and float(value.x)>=24.0 and float(value.x)<=3816.0 and float(value.y)>=38.0 and float(value.y)<=3816.0

static func valid(value: Variant, offsets: Dictionary) -> bool:
 if not value is Dictionary: return false
 if not number(value.get("version")) or float(value.version)!=1.0: return false
 if not value.get("layer") is String or not LAYERS.has(value.layer): return false
 if not value.get("minimap") is bool: return false
 if not number(value.get("nextId")): return false
 var next := float(value.nextId)
 if next != floor(next) or next < 1.0 or next > 1000000000.0: return false
 if not value.get("visited") is Array or value.visited.size()>6: return false
 var visited := {}
 for region in value.visited:
  # V.offsets is a plain JS object. Its inherited truthy keys are accepted too.
  var key := str(region) if region is String else ""
  if not offsets.has(key) and key not in ["constructor","__proto__","__defineGetter__","__defineSetter__","hasOwnProperty","__lookupGetter__","__lookupSetter__","isPrototypeOf","propertyIsEnumerable","toString","valueOf","toLocaleString"]: return false
  if visited.has(region): return false
  visited[region]=true
 if not value.get("pins") is Array or value.pins.size()>12: return false
 var ids := {}
 for pin in value.pins:
  if not pin is Dictionary or not pin.get("id") is String: return false
  var id: String = pin.id
  if not id.begins_with("pin-"): return false
  var digits := id.substr(4)
  if digits.is_empty(): return false
  for i in range(digits.length()):
   if digits.unicode_at(i)<48 or digits.unicode_at(i)>57: return false
  # Avoid integer overflow; JS Number converts arbitrarily long decimal IDs.
  if digits.to_float()>=next or ids.has(id): return false
  if not coordinates(pin) or not JS_STRING.is_string(pin.get("label")) or utf16_length(pin.label)>18: return false
  ids[id]=true
 var tracking: Variant = value.get("tracking")
 if truthy(tracking):
  if not coordinates(tracking) or not JS_STRING.is_string(tracking.get("name")) or utf16_length(tracking.name)>100: return false
  if not tracking.has("id") or (tracking.id!=null and not JS_STRING.is_string(tracking.id)): return false
 return true
