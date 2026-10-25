extends SceneTree
func _initialize()->void:
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/continuation-inputs-20261010.json"))
 for input in receipt.rows:
  if input.kind!="action":continue
  if not pack_action(input):quit(1);return
 quit(0)
func pack_action(input:Dictionary)->bool:
 var source:=Image.load_from_file(str(input.master))
 if source==null or source.detect_alpha()==Image.ALPHA_NONE:return false
 var atlas:=Image.create(768,512,false,Image.FORMAT_RGBA8)
 var ratio:=108.0/float(input.bodyHeight)
 var frames:Array=[]
 for row in 4:
  for col in 6:
   var v:Array=input.sourceBounds[row][col]
   var box:=Rect2i(int(v[0]),int(v[1]),int(v[2]),int(v[3])).grow(2)
   if not Rect2i(Vector2i.ZERO,source.get_size()).encloses(box):return false
   var tile:=source.get_region(box)
   var dims:=Vector2i(roundi(box.size.x*ratio),roundi(box.size.y*ratio))
   tile.resize(dims.x,dims.y,Image.INTERPOLATE_LANCZOS)
   var left:=dims.x;var right:=-1;var bottom:=-1
   for y in range(maxi(0,dims.y-23),dims.y):
    for x in dims.x:
     var c:=tile.get_pixel(x,y)
     if c.a>=.5 and c.r>=c.g+8.0/255 and c.g>=c.b+8.0/255 and (c.r+c.g+c.b)/3<160.0/255:
      left=mini(left,x);right=maxi(right,x);bottom=maxi(bottom,y)
   if right<0:return false
   var offset:=Vector2i(64-roundi((left+right+1)/2.0),116-bottom-1)
   if not Rect2i(1,1,126,126).encloses(Rect2i(offset,dims)):return false
   atlas.blit_rect(tile,Rect2i(Vector2i.ZERO,dims),Vector2i(col*128,row*128)+offset)
   frames.append({"row":row,"column":col,"sourceRect":[box.position.x,box.position.y,box.size.x,box.size.y],"packedSize":[dims.x,dims.y],"packedPosition":[offset.x,offset.y],"ratio":ratio})
 var id:=str(input.id);var path:="res://art/characters/player/"+id+".png"
 if atlas.save_png(path)!=OK:return false
 var mpath:="res://data/character_art_manifest.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(mpath));var spec:Dictionary=manifest.actors.player.clips[id]
 spec.merge({"ready":true,"path":path,"frameSize":[128,128],"anchor":[64,116],"frames":6,"directions":["down","left","right","up"],"sourceSha256":input.sha256,"sourceFrames":frames,"visualReview":"pending_actual_gpu"},true)
 var file:=FileAccess.open(mpath,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("ACTION_IMPORT: ",id," 24 independently anchored poses")
 return true
