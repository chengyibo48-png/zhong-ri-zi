extends RefCounted
# JSON's decimal parser can move a float by one binary64 unit even with
# full_precision serialization. Store only those values as eight raw bytes.
const FLOAT_KEY := "_float64_roundtrip"
const MAX_FLOAT_ENTRIES := 20000
const JS_STRING = preload("res://scripts/js_string.gd")

static func encode(data: Dictionary) -> String:
 var text:=stringify(data)
 var decoded:Variant=_parse_utf16(text)
 if not decoded is Dictionary: return ""
 var entries:Array=[]
 _collect(data,decoded,[],entries)
 if entries.size() > MAX_FLOAT_ENTRIES: return ""
 for entry: Dictionary in entries:
  if entry.path.size() > 64: return ""
 if entries.is_empty(): return text
 var envelope:=data.duplicate(true)
 envelope[FLOAT_KEY]={"version":1,"entries":entries}
 return stringify(envelope)

static func _contains_raw(value: Variant) -> bool:
 if value is JS_STRING.Raw: return true
 if value is Dictionary:
  for key in value:
   if key is JS_STRING.Raw or _contains_raw(value[key]): return true
 elif value is Array:
  for child in value:
   if _contains_raw(child): return true
 return false

static func stringify(value: Variant) -> String:
 return _stringify_raw(value) if _contains_raw(value) else JS_STRING.standard_json_escapes(JSON.stringify(value,"",false,true))

static func _stringify_raw(value: Variant) -> String:
 if value is JS_STRING.Raw: return JS_STRING.json(value)
 if value is Dictionary:
  var rows:=PackedStringArray()
  for key in value: rows.append(JS_STRING.json(key if JS_STRING.is_string(key) else str(key))+":"+_stringify_raw(value[key]))
  return "{"+",".join(rows)+"}"
 if value is Array:
  var rows:=PackedStringArray()
  for child in value: rows.append(_stringify_raw(child))
  return "["+",".join(rows)+"]"
 return JSON.stringify(value,"",false,true)

static func parse(text: String) -> Variant:
 return decode(_parse_utf16(text))

static func _parse_utf16(text: String) -> Variant:
 if text.find("\\u")<0:
  var plain_parser:=JSON.new()
  return plain_parser.data if plain_parser.parse(text)==OK else null
 # Tokenize before Godot's parser so no unpaired surrogate reaches it.
 # Placeholder strings are chosen against every decoded token, including keys.
 var tokens:Array=[]
 var normal_strings:Dictionary={}
 var i:=0
 while i<text.length():
  if text.unicode_at(i)!=34: i+=1;continue
  var start:=i
  i+=1
  var closed:=false
  while i<text.length():
   var code:=text.unicode_at(i)
   if code==92: i+=2;continue
   if code==34: i+=1;closed=true;break
   i+=1
  if not closed: return null
  var token:=text.substr(start,i-start)
  var decoded:Dictionary=JS_STRING.parse_token(token)
  if not bool(decoded.ok): return null
  tokens.append({"start":start,"end":i,"value":decoded.value})
  if decoded.value is String: normal_strings[decoded.value]=true
 var replacements:Dictionary={}
 var interned:Dictionary={}
 var pieces:=PackedStringArray()
 var cursor:=0
 var serial:=0
 for token in tokens:
  if not token.value is JS_STRING.Raw: continue
  var marker:="__zrz_utf16_%d__" % serial
  while normal_strings.has(marker) or replacements.has(marker):
   serial+=1
   marker="__zrz_utf16_%d__" % serial
  serial+=1
  var identity:=JS_STRING.json(token.value)
  if not interned.has(identity): interned[identity]=token.value
  replacements[marker]=interned[identity]
  pieces.append(text.substr(cursor,int(token.start)-cursor))
  pieces.append(JSON.stringify(marker))
  cursor=int(token.end)
 pieces.append(text.substr(cursor))
 var parser:=JSON.new()
 if parser.parse("".join(pieces))!=OK: return null
 return _restore_utf16(parser.data,replacements) if not replacements.is_empty() else parser.data

static func _restore_utf16(value: Variant,replacements: Dictionary) -> Variant:
 if value is String: return replacements.get(value,value)
 if value is Array:
  var result:Array=[]
  for child in value: result.append(_restore_utf16(child,replacements))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key in value: result[_restore_utf16(key,replacements)]=_restore_utf16(value[key],replacements)
  return result
 return value

static func _matching_key(data: Dictionary,key: Variant) -> Variant:
 if data.has(key): return key
 if JS_STRING.is_string(key):
  for candidate in data:
   if JS_STRING.equal(candidate,key): return candidate
 return null

static func _collect(original: Variant, decoded: Variant, path: Array, entries: Array) -> void:
 if original is Dictionary and decoded is Dictionary:
  for key in original:
   var decoded_key:Variant=_matching_key(decoded,key)
   if decoded_key!=null:
    _collect(original[key], decoded[decoded_key], path + [key], entries)
 elif original is Array and decoded is Array:
  for i in range(mini(original.size(), decoded.size())):
   _collect(original[i], decoded[i], path + [i], entries)
 elif original is float and is_finite(original) and original != decoded:
  var bytes := PackedByteArray()
  bytes.resize(8)
  bytes.encode_double(0, original)
  entries.append({"path": path, "bytes": Marshalls.raw_to_base64(bytes)})

static func decode(data: Variant) -> Variant:
 if not data is Dictionary or not data.has(FLOAT_KEY):
  return data
 var metadata: Variant = data[FLOAT_KEY]
 if not metadata is Dictionary or metadata.get("version") != 1 or not metadata.get("entries") is Array:
  return null
 var entries: Array = metadata.entries
 if entries.size() > MAX_FLOAT_ENTRIES:
  return null
 for entry in entries:
  if not entry is Dictionary or not entry.get("path") is Array or not entry.get("bytes") is String:
   return null
  var path: Array = entry.path
  if path.is_empty() or path.size() > 64 or JS_STRING.equal(path[0],FLOAT_KEY):
   return null
  var bytes := Marshalls.base64_to_raw(entry.bytes)
  if bytes.size() != 8:
   return null
  var exact := bytes.decode_double(0)
  if not is_finite(exact):
   return null
  var parent: Variant = data
  for i in range(path.size()):
   var key: Variant = path[i]
   if parent is Array:
    if not (key is int or key is float) or not is_finite(float(key)) or float(key) != floor(float(key)) or float(key) < 0 or float(key) >= parent.size():
     return null
    key = int(key)
   elif parent is Dictionary:
    if not JS_STRING.is_string(key):
     return null
    key=_matching_key(parent,key)
    if key==null: return null
   else:
    return null
   if i == path.size() - 1:
    var decimal: Variant = parent[key]
    if not (decimal is int or decimal is float) or not is_finite(float(decimal)):
     return null
    # The decimal field remains authoritative; reject stale or corrupt metadata.
    if absf(exact - float(decimal)) > maxf(1.0, absf(exact)) * 0.000000000001:
     return null
    parent[key] = exact
   else:
    parent = parent[key]
 data.erase(FLOAT_KEY)
 return data
