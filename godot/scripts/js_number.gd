extends RefCounted
# ECMAScript Number::toString radix 10, closest shortest decimal and even ties.
# Work in exact integers so this does not depend on Godot's decimal parser.
const LIMB_BITS:=26
const MASK:=(1<<LIMB_BITS)-1
const FRACTION_MASK:=(1<<52)-1
static var powers5:Array=[PackedInt64Array([1])]
static var powers10:Array=[PackedInt64Array([1])]
static var text_cache:Dictionary={}

static func from_int(value:int) -> PackedInt64Array:
 var result:=PackedInt64Array()
 while value>0:
  result.append(value&MASK)
  value=value>>LIMB_BITS
 if result.is_empty():result.append(0)
 return result

static func trim(value:PackedInt64Array) -> PackedInt64Array:
 while value.size()>1 and value[-1]==0:value.resize(value.size()-1)
 return value

static func multiply(a:PackedInt64Array,b:PackedInt64Array) -> PackedInt64Array:
 var result:=PackedInt64Array();result.resize(a.size()+b.size());result.fill(0)
 for i in range(a.size()):
  var carry:=0
  for j in range(b.size()):
   var at:=i+j
   var product:int=result[at]+a[i]*b[j]+carry
   result[at]=product&MASK
   carry=product>>LIMB_BITS
  result[i+b.size()]+=carry
 return trim(result)

static func shift(value:PackedInt64Array,bits:int) -> PackedInt64Array:
 var words:int=bits/LIMB_BITS
 var remainder:=bits%LIMB_BITS
 var result:=PackedInt64Array();result.resize(words);result.fill(0)
 var carry:=0
 for limb in value:
  var shifted:int=(limb<<remainder)|carry
  result.append(shifted&MASK)
  carry=shifted>>LIMB_BITS
 if carry:result.append(carry)
 return trim(result)

static func compare(a:PackedInt64Array,b:PackedInt64Array) -> int:
 if a.size()!=b.size():return -1 if a.size()<b.size() else 1
 for i in range(a.size()-1,-1,-1):
  if a[i]!=b[i]:return -1 if a[i]<b[i] else 1
 return 0

static func power5(exponent:int) -> PackedInt64Array:
 while powers5.size()<=exponent:powers5.append(multiply(powers5[-1],PackedInt64Array([5])))
 return powers5[exponent]

static func power10(exponent:int) -> PackedInt64Array:
 while powers10.size()<=exponent:powers10.append(multiply(powers10[-1],PackedInt64Array([10])))
 return powers10[exponent]

static func decimal(value:PackedInt64Array) -> String:
 var work:=value.duplicate()
 var chunks:Array[int]=[]
 while work.size()>1 or work[0]!=0:
  var remainder:=0
  for i in range(work.size()-1,-1,-1):
   var current:int=(remainder<<LIMB_BITS)+work[i]
   work[i]=current/1000000000
   remainder=current%1000000000
  chunks.append(remainder)
  work=trim(work)
 if chunks.is_empty():return "0"
 var pieces:=PackedStringArray([str(chunks[-1])])
 for i in range(chunks.size()-2,-1,-1):pieces.append("%09d" % chunks[i])
 return "".join(pieces)

static func binary(bits:int) -> Dictionary:
 var exponent: int=(bits>>52)&0x7ff
 var mantissa:int=bits&FRACTION_MASK
 if exponent==0:return {"mantissa":mantissa,"shift":-1074}
 # Exponent 2047 denotes the virtual finite neighbor 2^1024 for overflow ties.
 return {"mantissa":mantissa+(1<<52),"shift":exponent-1023-52}

static func midpoint(a:Dictionary,b:Dictionary) -> Dictionary:
 var common:=mini(int(a.shift),int(b.shift))
 return {"mantissa":(int(a.mantissa)<<(int(a.shift)-common))+(int(b.mantissa)<<(int(b.shift)-common)),"shift":common-1}

static func compare_binary(numerator:PackedInt64Array,denominator:PackedInt64Array,boundary:Dictionary) -> int:
 var right:=multiply(denominator,from_int(int(boundary.mantissa)))
 var left:=numerator
 var exponent:int=int(boundary.shift)
 if exponent>=0:right=shift(right,exponent)
 else:left=shift(left,-exponent)
 return compare(left,right)

static func inside(coefficient:int,scale:int,low:Dictionary,high:Dictionary,even:bool) -> bool:
 var numerator:=from_int(coefficient)
 var denominator:=PackedInt64Array([1])
 if scale>=0:numerator=multiply(numerator,power10(scale))
 else:denominator=power10(-scale)
 var lower:=compare_binary(numerator,denominator,low)
 var upper:=compare_binary(numerator,denominator,high)
 return (lower>0 or (even and lower==0)) and (upper<0 or (even and upper==0))

static func format_decimal(coefficient:int,scale:int) -> String:
 var digits:=str(coefficient)
 while digits.length()>1 and digits[-1]=="0":digits=digits.left(-1);scale+=1
 var exponent:=digits.length()+scale-1
 if exponent>=-6 and exponent<21:
  var place:=exponent+1
  if place<=0:return "0."+"0".repeat(-place)+digits
  if place>=digits.length():return digits+"0".repeat(place-digits.length())
  return digits.left(place)+"."+digits.substr(place)
 return digits[0]+("."+digits.substr(1) if digits.length()>1 else "")+"e"+("+" if exponent>=0 else "")+str(exponent)

static func positive(bits:int) -> String:
 if text_cache.has(bits):return text_cache[bits]
 var value:=binary(bits)
 var exact:=from_int(int(value.mantissa))
 var scale:int=int(value.shift)
 if scale>=0:exact=shift(exact,scale);scale=0
 else:exact=multiply(exact,power5(-scale))
 var digits:=decimal(exact)
 var exponent:=digits.length()+scale-1
 var low:=midpoint(binary(bits-1),value)
 var high:=midpoint(value,binary(bits+1))
 var even:bool=(bits&1)==0
 for precision in range(1,18):
  var prefix:=digits.left(precision)
  if prefix.length()<precision:prefix+="0".repeat(precision-prefix.length())
  var floor_value:=int(prefix)
  var round_up:=false
  if digits.length()>precision:
   var next:=digits.unicode_at(precision)-48
   if next>5:round_up=true
   elif next==5:
    var tail_nonzero:=false
    for i in range(precision+1,digits.length()):
     if digits[i]!="0":tail_nonzero=true;break
    round_up=tail_nonzero or floor_value%2!=0
  var preferred:=floor_value+1 if round_up else floor_value
  var other:=floor_value if round_up else floor_value+1
  var candidate_scale:=exponent-precision+1
  var chosen:=-1
  if inside(preferred,candidate_scale,low,high,even):chosen=preferred
  elif inside(other,candidate_scale,low,high,even):chosen=other
  if chosen>=0:
   var text:=format_decimal(chosen,candidate_scale)
   if text_cache.size()>=4096:text_cache.clear()
   text_cache[bits]=text
   return text
 push_error("No shortest decimal for binary64 bits "+str(bits))
 return ""

static func text(value:Variant) -> String:
 var number:=float(value)
 if is_nan(number):return "NaN"
 if is_inf(number):return "Infinity" if number>0.0 else "-Infinity"
 if number==0.0:return "0"
 var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,absf(number))
 return ("-" if number<0.0 else "")+positive(bytes.decode_u64(0))
