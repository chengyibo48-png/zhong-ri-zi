extends SceneTree
func _initialize()->void:
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/polish-hoe-input-20261010.json"))
 var source:=Image.load_from_file(str(receipt.row.master))
 if source==null:quit(1);return
 var atlas:=Image.create(1152,768,false,Image.FORMAT_RGBA8)
 var frames:Array=[]
 var feet:Dictionary=receipt.row.feet
 for row in range(4):
  var target_row:int=["down","left","right","up"].find(feet.sourceDirections[row])
  var ratio:=108.0/float(feet.bodyHeights[row])
  for col in range(6):
   var values:Array=feet.sourceBounds[row][col]
   var box:=Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3])).grow(2)
   if not Rect2i(Vector2i.ZERO,source.get_size()).encloses(box):quit(1);return
   var tile:=source.get_region(box)
   tile.resize(maxi(1,roundi(box.size.x*ratio)),maxi(1,roundi(box.size.y*ratio)),Image.INTERPOLATE_LANCZOS)
   var point:Array=feet.frames[row][col]
   var foot:=Vector2i(roundi((float(point[0])-box.position.x)*ratio),roundi((float(point[1])-box.position.y)*ratio))
   var shoe:Array=feet.shoeRegions[row][col]
   var left:=tile.get_width();var right:=-1;var bottom:=-1
   for y in tile.get_height():
    for x in tile.get_width():
     var original:=Vector2(float(x)/ratio+box.position.x,float(y)/ratio+box.position.y)
     if not Rect2(float(shoe[0]),float(shoe[1]),float(shoe[2]),float(shoe[3])).has_point(original):continue
     var c:=tile.get_pixel(x,y)
     if c.a>=0.5 and c.r>=c.g+8.0/255 and c.g>=c.b+8.0/255 and (c.r+c.g+c.b)/3<160.0/255:
      left=mini(left,x);right=maxi(right,x);bottom=maxi(bottom,y)
   if right<0:printerr("No real boots in authored shoe area");quit(1);return
   foot=Vector2i(roundi((left+right+1)/2.0),bottom+1)
   var offset:=Vector2i(96,168)-foot
   if not Rect2i(0,0,192,192).encloses(Rect2i(offset,tile.get_size())):printerr("Tool pose clipped: ",row,"/",col);quit(1);return
   atlas.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(col*192,target_row*192)+offset)
   frames.append({"row":target_row,"column":col,"sourceRect":[box.position.x,box.position.y,box.size.x,box.size.y],"packedSize":[tile.get_width(),tile.get_height()],"packedPosition":[offset.x,offset.y],"ratio":ratio})
 if atlas.save_png("res://art/characters/player/hoe.png")!=OK:quit(1);return
 var path:="res://data/character_art_manifest.json"
 var m:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var entry:Dictionary=m.actors.player.clips.hoe
 entry.merge({"ready":true,"sourceFrames":frames,"sourceSha256":receipt.row.sha256,"review":"pending_actual_gpu","bodyScaleReviewed":false},true)
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(m,"  ")+"\n");f.close()
 print("HOE_IMPORT: 24 whole poses, body-based shared scales, shoe anchors and tool clearance")
 quit(0)
