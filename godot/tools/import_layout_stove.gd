extends SceneTree
func _initialize()->void:
 var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/layout-stove-input-20261009.json"))
 var image:=Image.load_from_file(str(receipt.master))
 if image==null or image.detect_alpha()==Image.ALPHA_NONE:quit(1);return
 var size:=image.get_size();var low:=size;var high:=Vector2i(-1,-1)
 for y in size.y:
  for x in size.x:
   if image.get_pixel(x,y).a>.125:
    if x==0 or y==0 or x==size.x-1 or y==size.y-1:quit(1);return
    low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
 if high.x<0:quit(1);return
 var box:=Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,size))
 image=image.get_region(box);image.resize(256,roundi(256.0*box.size.y/box.size.x),Image.INTERPOLATE_LANCZOS)
 if image.save_png("res://art/world/fixtures/kitchen_stove.png")!=OK:quit(1);return
 var path:="res://data/world_art_manifest.json";var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 manifest.entries["fixtures/kitchen_stove"]={"name":"禾溪小灶","path":"res://art/world/fixtures/kitchen_stove.png","baseReady":true,"status":"partial","sourceSha256":receipt.sha256,"sourceVisibleRect":[box.position.x,box.position.y,box.size.x,box.size.y],"requiredChecks":["placement","interaction_alignment","cooking_states"],"reviewed":["material_detail"],"visualReview":"pending_actual_scene"}
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("LAYOUT_STOVE_IMPORT: real bitmap at original kitchen entry; state variants pending");quit(0)
