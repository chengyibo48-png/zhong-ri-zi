extends SceneTree
## Import reviewed seasonal PNGs using one shared canvas and foot anchor.
func _initialize() -> void:
 var lease := "res://artifacts/art-import-frozen-until.txt"
 if FileAccess.file_exists(lease) and int(FileAccess.get_file_as_string(lease)) > int(Time.get_unix_time_from_system()):
  printerr("Art import deferred while regression checks frozen production");quit(1);return
 var args := OS.get_cmdline_user_args()
 if args.size() != 1:printerr("Usage: -- <absolute-tree-master-directory>");quit(1);return
 var manifest_path := "res://data/world_art_manifest.json"
 var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 if not manifest is Dictionary or not manifest.entries.has("props/tree"):quit(1);return
 var seasons := ["spring","summer","autumn","winter"]
 var sources: Array[Image] = []
 var source_size := Vector2i.ZERO
 for season in seasons:
  var source := Image.load_from_file(args[0].path_join(str(season)+".png"))
  if source == null or source.is_empty() or source.detect_alpha() == Image.ALPHA_NONE:
   printerr("Missing transparent tree variant: ",season);quit(1);return
  if source_size == Vector2i.ZERO:source_size=source.get_size()
  if source.get_size()!=source_size:printerr("Seasonal tree canvases must share the same foot alignment");quit(1);return
  for corner in [Vector2i.ZERO,Vector2i(source_size.x-1,0),Vector2i(0,source_size.y-1),source_size-Vector2i.ONE]:
   if source.get_pixelv(corner).a>=0.01:printerr("Opaque corner: ",season);quit(1);return
  sources.append(source)
 var paths: Array[String] = []
 var output_dir := "res://art/world/props/tree"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
 for i in sources.size():
  var source: Image = sources[i]
  source.resize(512,roundi(512.0*source_size.y/source_size.x),Image.INTERPOLATE_LANCZOS)
  var path := output_dir.path_join(str(seasons[i])+".png")
  if source.save_png(path)!=OK:quit(1);return
  paths.append(path)
 var row: Dictionary = manifest.entries["props/tree"]
 var height := 56.0
 var width := height*source_size.x/source_size.y
 row.path=paths[0];row.seasons=paths
 row.worldRect=[-width/2.0,-height,width,height]
 row.baseReady=true;row.status="partial"
 row.reviewed=["seasonal_variants","material_detail"]
 row.verifiedChecks=[]
 row.sourceCanvas=[source_size.x,source_size.y]
 var file := FileAccess.open(manifest_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("TREE_SEASONS_IMPORTED: four independent PNG variants; placement checks pending")
 quit(0)
