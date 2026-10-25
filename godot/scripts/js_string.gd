extends RefCounted
# Immutable UTF-16 values only for strings Godot cannot represent losslessly.
class Raw extends RefCounted:
 var _units: PackedInt32Array
 var _display: String
 func _init(units_value: PackedInt32Array,display_value: String) -> void:
  _units=units_value.duplicate()
  _display=display_value
 func units() -> PackedInt32Array: return _units.duplicate()
 func _to_string() -> String: return _display

static func is_string(value: Variant) -> bool:
 return value is String or value is Raw

static func units(value: Variant) -> PackedInt32Array:
 if value is Raw: return value.units()
 var result:=PackedInt32Array()
 if not value is String: return result
 for i in range(value.length()):
  var code:int=value.unicode_at(i)
  if code>0xffff:
   code-=0x10000
   result.append(0xd800+(code>>10))
   result.append(0xdc00+(code&0x3ff))
  else: result.append(code)
 return result

static func from_units(value: PackedInt32Array) -> Variant:
 var display:=PackedStringArray()
 var unusual:=false
 var i:=0
 while i<value.size():
  var code:int=value[i]
  if code>=0xd800 and code<=0xdbff and i+1<value.size() and value[i+1]>=0xdc00 and value[i+1]<=0xdfff:
   display.append(String.chr(0x10000+((code-0xd800)<<10)+(value[i+1]-0xdc00)))
   i+=2
   continue
  if code==0 or (code>=0xd800 and code<=0xdfff):
   unusual=true
   display.append(String.chr(0xfffd))
  else: display.append(String.chr(code))
  i+=1
 var text:="".join(display)
 return Raw.new(value,text) if unusual else text

static func length(value: Variant) -> int:
 return units(value).size()

static func equal(a: Variant,b: Variant) -> bool:
 return is_string(a) and is_string(b) and units(a)==units(b)

static func whitespace(unit: int) -> bool:
 return (unit>=9 and unit<=13) or unit in [32,160,5760,8232,8233,8239,8287,12288,65279] or (unit>=8192 and unit<=8202)

static func trim(value: Variant) -> Variant:
 var data:=units(value)
 var start:=0
 var end:=data.size()
 while start<end and whitespace(data[start]): start+=1
 while end>start and whitespace(data[end-1]): end-=1
 return from_units(data.slice(start,end))

static func prefix(value: Variant,count: int) -> Variant:
 var data:=units(value)
 return from_units(data.slice(0,clampi(count,0,data.size())))

static func html_input_default(value: Variant,count: int) -> Variant:
 # Original HTML attribute parsing replaces NUL; text inputs strip CR and LF.
 # The source applies slice before inserting the attribute.
 var result:=PackedInt32Array()
 for unit in units(prefix(value,count)):
  if unit==10 or unit==13: continue
  result.append(0xfffd if unit==0 else unit)
 return from_units(result)

static func json(value: Variant) -> String:
 if not value is Raw: return standard_json_escapes(JSON.stringify(value,"",false,true))
 var pieces:=PackedStringArray()
 pieces.append('"')
 for unit in value.units(): pieces.append("\\u%04x" % unit)
 pieces.append('"')
 return "".join(pieces)

static func parse_token(token: String) -> Dictionary:
 var data:=PackedInt32Array()
 if token.length()<2 or token[0]!='"' or token[-1]!='"': return {"ok":false}
 var i:=1
 while i<token.length()-1:
  var code:int=token.unicode_at(i)
  if code<32: return {"ok":false}
  if code==92:
   i+=1
   if i>=token.length()-1: return {"ok":false}
   var escaped:int=token.unicode_at(i)
   if escaped==117:
    if i+4>=token.length()-1: return {"ok":false}
    var hex:=token.substr(i+1,4)
    var unit:=0
    for k in range(4):
     var c:=hex.unicode_at(k)
     var digit:=c-48 if c>=48 and c<=57 else c-87 if c>=97 and c<=102 else c-55 if c>=65 and c<=70 else -1
     if digit<0: return {"ok":false}
     unit=unit*16+digit
    data.append(unit)
    i+=5
    continue
   var escapes:Dictionary={34:34,92:92,47:47,98:8,102:12,110:10,114:13,116:9}
   if not escapes.has(escaped): return {"ok":false}
   code=int(escapes[escaped])
  elif code==34: return {"ok":false}
  if code>0xffff:
   code-=0x10000
   data.append(0xd800+(code>>10))
   data.append(0xdc00+(code&0x3ff))
  else: data.append(code)
  i+=1
 return {"ok":true,"value":from_units(data)}

static func number_text(value: Variant) -> String:
 return preload("res://scripts/js_number.gd").text(value)

static func coerce(value: Variant) -> Variant:
 if is_string(value): return value
 if value==null: return "null"
 if value is bool: return "true" if value else "false"
 if value is int or value is float: return number_text(value)
 if value is Array:
  var result:=PackedInt32Array()
  for i in range(value.size()):
   if i>0: result.append(44)
   if value[i]!=null: result.append_array(units(coerce(value[i])))
  return from_units(result)
 return "[object Object]"

static func standard_json_escapes(text: String) -> String:
 # Godot emits \v; ECMAScript JSON uses \u000b. Preserve literal "\\v".
 if text.find("\\v")<0: return text
 var pieces:=PackedStringArray()
 var quoted:=false
 var i:=0
 while i<text.length():
  var char_value:=text[i]
  if char_value=='"': quoted=not quoted;pieces.append(char_value);i+=1;continue
  if quoted and char_value=="\\" and i+1<text.length():
   pieces.append("\\u000b" if text[i+1]=="v" else text.substr(i,2))
   i+=2
   continue
  pieces.append(char_value)
  i+=1
 return "".join(pieces)

static func concat(values: Array) -> Variant:
 var result := PackedInt32Array()
 for value in values:result.append_array(units(coerce(value)))
 return from_units(result)

static func includes(values: Array, value: Variant) -> bool:
 for candidate in values:
  if equal(candidate, value):return true
 return false
