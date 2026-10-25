"""Generate the game's original pixel farm icon without external libraries."""
from pathlib import Path
import math, struct, zlib
size=64
pixels=[(0,0,0,0)]*(size*size)
def dot(x,y,c):
 if 0<=x<size and 0<=y<size:pixels[y*size+x]=c
def box(x1,y1,x2,y2,c):
 for y in range(y1,y2):
  for x in range(x1,x2):dot(x,y,c)
def ellipse(cx,cy,rx,ry,c):
 for y in range(int(cy-ry),int(cy+ry)+1):
  for x in range(int(cx-rx),int(cx+rx)+1):
   if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1:dot(x,y,c)
def line(x1,y1,x2,y2,c,width=1):
 n=max(abs(x2-x1),abs(y2-y1),1)
 for i in range(n+1):
  x=round(x1+(x2-x1)*i/n);y=round(y1+(y2-y1)*i/n)
  box(x-width,y-width,x+width+1,y+width+1,c)
ink=(38,62,43,255);sky=(159,207,159,255);cream=(249,231,175,255)
ellipse(32,32,31,31,ink);ellipse(32,32,28,28,sky)
ellipse(46,16,7,7,(255,220,110,255))
box(7,40,57,49,(109,155,72,255));box(10,49,54,56,(113,78,51,255))
for x in [14,22,30,38,46]:line(x,51,x+3,54,(178,121,67,255))
box(13,26,36,45,ink);box(15,27,34,43,cream)
for y in range(15,28):
 half=y-15
 box(24-half,y,25+half+1,y+1,(171,82,51,255))
line(11,28,24,14,ink);line(24,14,38,28,ink)
box(19,34,26,44,(109,78,55,255));box(28,30,32,35,(98,154,170,255))
line(46,46,46,27,ink)
ellipse(40,31,6,3,(64,111,52,255));ellipse(50,26,6,3,(80,130,53,255))
ellipse(46,19,3,7,(231,185,74,255))
for y in [17,21,25]:
 line(46,y,42,y-3,(255,221,121,255))
 line(47,y,51,y-3,(255,221,121,255))
def chunk(kind,data):
 return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
raw=b"".join(b"\x00"+b"".join(bytes(pixels[(y//4)*64+x//4]) for x in range(256)) for y in range(256))
png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",256,256,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(raw))+chunk(b"IEND",b"")
out=Path(__file__).resolve().parents[1]/"art"
out.mkdir(exist_ok=True)
(out/"app_icon.png").write_bytes(png)
(out/"app_icon.ico").write_bytes(struct.pack("<HHH",0,1,1)+struct.pack("<BBBBHHII",0,0,0,0,1,32,len(png),22)+png)
print(out/"app_icon.ico")
