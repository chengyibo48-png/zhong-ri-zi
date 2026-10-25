extends RefCounted
# Adapted from fdlibm / V8 13.6.233 ieee754.cc (atan and atan2).
# Copyright (C) 1993 Sun Microsystems, Inc. All rights reserved.
# Developed at SunSoft, a Sun Microsystems, Inc. business.
# Permission to use, copy, modify, and distribute this software is freely
# granted, provided that this notice is preserved.
# Modifications: Copyright 2016 the V8 project authors. All rights reserved.
const HIGH=[4.63647609000806093515e-01,7.85398163397448278999e-01,9.82793723247329054082e-01,1.57079632679489655800e+00]
const LOW=[2.26987774529616870924e-17,3.06161699786838301793e-17,1.39033110312309984516e-17,6.12323399573676603587e-17]
const A=[3.33333333333329318027e-01,-1.99999999998764832476e-01,1.42857142725034663711e-01,-1.11111104054623557880e-01,9.09088713343650656196e-02,-7.69187620504482999495e-02,6.66107313738753120669e-02,-5.83357013379057348645e-02,4.97687799461593236017e-02,-3.65315727442169155270e-02,1.62858201153657823623e-02]
static func words(value:float)->PackedInt64Array:
 var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
 return PackedInt64Array([bytes.decode_u32(4),bytes.decode_u32(0)])
static func arctan(value:float)->float:
 var bits:=words(value)
 var high:int=bits[0]&0x7fffffff
 if high>=0x44100000:
  if is_nan(value):return value
  return -HIGH[3]-LOW[3] if value<0 else HIGH[3]+LOW[3]
 var id:=-1
 var x:=value
 if high<0x3fdc0000:
  if high<0x3e400000:return x
 else:
  x=absf(x)
  if high<0x3ff30000:
   if high<0x3fe60000:id=0;x=(2.0*x-1.0)/(2.0+x)
   else:id=1;x=(x-1.0)/(x+1.0)
  elif high<0x40038000:id=2;x=(x-1.5)/(1.0+1.5*x)
  else:id=3;x=-1.0/x
 var z:=x*x
 var w:=z*z
 var s1:float=z*(A[0]+w*(A[2]+w*(A[4]+w*(A[6]+w*(A[8]+w*A[10])))))
 var s2:float=w*(A[1]+w*(A[3]+w*(A[5]+w*(A[7]+w*A[9]))))
 if id<0:return x-x*(s1+s2)
 z=HIGH[id]-((x*(s1+s2)-LOW[id])-x)
 return -z if value<0 else z
static func negative_zero()->float:
 return PackedByteArray([0,0,0,0,0,0,0,128]).decode_double(0)
static func angle(y:float,x:float)->float:
 if is_nan(x) or is_nan(y):return x+y
 if x==1.0:return arctan(y)
 var xb:=words(x);var yb:=words(y)
 var sx:=int(xb[0]>>31);var sy:=int(yb[0]>>31)
 var mode:=sx*2+sy
 if y==0.0:return y if sx==0 else (-PI if sy else PI)
 if x==0.0:return -PI/2.0 if sy else PI/2.0
 if is_inf(x):
  if is_inf(y):return (-1.0 if sy else 1.0)*(3.0*PI/4.0 if sx else PI/4.0)
  return (-PI if sy else PI) if sx else (negative_zero() if sy else 0.0)
 if is_inf(y):return -PI/2.0 if sy else PI/2.0
 var exponent:=int(((yb[0]&0x7fffffff)-(xb[0]&0x7fffffff))>>20)
 var z:float
 const PI_LOW=1.2246467991473531772e-16
 if exponent>60:z=PI/2.0+0.5*PI_LOW;mode&=1
 elif sx and exponent< -60:z=0.0
 else:z=arctan(absf(y/x))
 match mode:
  0:return z
  1:return -z
  2:return PI-(z-PI_LOW)
 return (z-PI_LOW)-PI
