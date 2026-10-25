extends SceneTree
func _initialize()->void:
 var receipts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/polish-surfaces-inputs-20261010.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for source in receipts.rows:
  var image:=Image.load_from_file(str(source.master))
  if image==null:quit(1);return
  var box:=Rect2i(Vector2i.ZERO,image.get_size())
  if source.id!="interior_floor":
   if image.detect_alpha()==Image.ALPHA_NONE:printerr("True alpha required: ",source.id);quit(1);return
   var low:=image.get_size();var high:=Vector2i(-1,-1)
   for y in image.get_height():
    for x in image.get_width():
     if image.get_pixel(x,y).a>0.125:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
   if high.x<0 or low.x<2 or low.y<2 or high.x>image.get_width()-3 or high.y>image.get_height()-3:printerr("Clipped source: ",source.id);quit(1);return
   box=Rect2i(low,high-low+Vector2i.ONE).grow(2)
  var packed:=image.get_region(box)
  var key:String={"teaRack":"props/teaRack","lamp":"props/lamp","ui_panel":"ui/panel","ui_button":"ui/button","fx_leaf":"effects/leaves","interior_floor":"interior_surfaces/wood"}[str(source.id)]
  var output:="res://art/world/"+key+".png"
  var width:=64 if source.id=="fx_leaf" else 512 if source.id in ["ui_panel","ui_button","interior_floor"] else 256
  packed.resize(width,maxi(1,roundi(float(width)*box.size.y/box.size.x)),Image.INTERPOLATE_LANCZOS)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
  if packed.save_png(output)!=OK:quit(1);return
  var row:Dictionary=manifest.entries.get(key,{"name":str(source.id),"requiredChecks":["material_detail","in_game_visual_review"]})
  row.merge({"path":output,"status":"partial","baseReady":true,"sourceSha256":source.sha256,"sourceVisibleRect":[box.position.x,box.position.y,box.size.x,box.size.y],"reviewed":["material_detail"],"verifiedChecks":[]},true)
  if source.id in ["teaRack","lamp"]:
   var limit:=Vector2(76,30) if source.id=="teaRack" else Vector2(14,56)
   var ratio:=minf(limit.x/box.size.x,limit.y/box.size.y);var size:=Vector2(box.size)*ratio
   row.worldRect=[-size.x/2,-size.y,size.x,size.y]
  if source.id in ["ui_panel","ui_button"]:row.nineSliceMargin=24 if source.id=="ui_panel" else 44
  manifest.entries[key]=row
  print("POLISH_BASE_IMPORTED: ",key)
 var file:=FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 quit(0)
