extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 var art=load("res://scripts/character_art.gd")
 var count:=0
 var max_horizontal:=0.0
 var expected:=24
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--expected-frames="):expected=int(arg.get_slice("=",1))
 check(art.has_clip("lin","greet"),"baseline greeting clip is actually present")
 for actor in art.data().actors:
  for clip in art.data().actors[actor].clips:
   var spec:Dictionary=art.data().actors[actor].clips[clip]
   if not art.has_clip(str(actor),str(clip)):continue
   if not bool(spec.get("footAnchorReviewed",false)) and not (str(actor)=="lin" and str(clip)=="greet"):continue
   var texture:Texture2D=art.texture(str(spec.path))
   check(texture!=null,"foot-checked clip has actual bitmap")
   if texture==null:continue
   var image:=texture.get_image()
   for row in range(spec.directions.size()):
    for column in range(int(spec.frames)):
     var frame:=image.get_region(Rect2i(column*128,row*128,128,128))
     var shoes:Array[Vector2i]=[]
     var sole:=-1
     for y in range(98,124):
      for x in range(128):
       var c:=frame.get_pixel(x,y)
       var red:=roundi(c.r*255);var green:=roundi(c.g*255);var blue:=roundi(c.b*255)
       if c.a>=0.5 and red<155 and green<145 and blue<130 and red>=green-8 and green>=blue-5:
        shoes.append(Vector2i(x,y));sole=maxi(sole,y)
     var label:="%s/%s/%d/%d"%[actor,clip,row,column]
     check(not shoes.is_empty(),"actual dark shoe soles "+label)
     if shoes.is_empty():continue
     var low:=128;var high:=-1
     for p in shoes:
      if p.y<sole-3:continue
      low=mini(low,p.x);high=maxi(high,p.x)
     var center:=(low+high+1)/2.0
     max_horizontal=maxf(max_horizontal,absf(center-64.0))
     check(absf(center-64.0)<=2.0,"planted shoe center within two pixels "+label)
     check(absi(sole+1-116)<=2,"planted sole height within two pixels "+label)
     count+=1
 check(count==expected,"all expected foot-anchor frames checked")
 print("FOOT_ANCHOR_FRAMES: ",count,"; maximum horizontal offset: ",max_horizontal)
 print("CHARACTER_FEET_CHECK: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)

