extends SceneTree
func _initialize() -> void:
 var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/seasonal-tree-inputs-20261010.json"))
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for kind in ["blossom", "orchard"]:
  var shared := Vector2i.ZERO
  var crops: Array[Image] = []
  var jobs: Array = []
  for job in input.rows:
   if job.kind != kind: continue
   var source := Image.load_from_file(str(job.master))
   if source == null or source.detect_alpha() == Image.ALPHA_NONE:
    push_error("Missing alpha " + str(job.master)); quit(1); return
   var low := source.get_size(); var high := Vector2i(-1, -1)
   for y in source.get_height():
    for x in source.get_width():
     if source.get_pixel(x,y).a > .125:
      if x==0 or y==0 or x==source.get_width()-1 or y==source.get_height()-1:
       push_error("Clipped source " + str(job.master)); quit(1); return
      low=low.min(Vector2i(x,y)); high=high.max(Vector2i(x,y))
   if high.x<0: quit(1); return
   var crop := source.get_region(Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,source.get_size())))
   shared=shared.max(crop.get_size()); crops.append(crop); jobs.append(job)
  if crops.size()!=4: quit(1); return
  var paths: Array = []
  var hashes: Array = []
  for i in 4:
   var canvas := Image.create(shared.x,shared.y,false,Image.FORMAT_RGBA8)
   canvas.blit_rect(crops[i],Rect2i(Vector2i.ZERO,crops[i].get_size()),Vector2i((shared.x-crops[i].get_width())/2,shared.y-crops[i].get_height()))
   canvas.resize(256,maxi(1,roundi(256.0*shared.y/shared.x)),Image.INTERPOLATE_LANCZOS)
   var path: String = "res://art/world/props/" + str(kind) + "/" + str(jobs[i].season) + ".png"
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
   if canvas.save_png(path)!=OK: quit(1); return
   paths.append(path); hashes.append(jobs[i].sha256)
  var factor := minf(48.0/shared.x,56.0/shared.y)
  var bounds := Vector2(shared)*factor
  var row: Dictionary = manifest.entries["props/"+kind]
  row.path=paths[0];row.seasons=paths;row.baseReady=true;row.status="partial"
  row.sourceSha256=hashes;row.worldRect=[-bounds.x/2,-bounds.y,bounds.x,bounds.y]
  row.reviewed=["material_detail","seasonal_variants"];row.verifiedChecks=[]
 var file := FileAccess.open("res://data/world_art_manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("SEASONAL_TREE_IMPORT: eight independent seasonal sources, two shared canvases with stable bottom anchors")
 quit(0)
