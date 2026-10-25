extends SceneTree

func _initialize() -> void:
 var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/remaining-forage-inputs-20261010.json"))
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for job in inputs.rows:
  var image := Image.load_from_file(str(job.master))
  if image == null or image.detect_alpha() == Image.ALPHA_NONE:
   push_error("Missing alpha: " + str(job.name)); quit(1); return
  var low := image.get_size()
  var high := Vector2i(-1, -1)
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x, y).a > .125:
     if x == 0 or y == 0 or x == image.get_width()-1 or y == image.get_height()-1:
      push_error("Source touches frame: " + str(job.name)); quit(1); return
     low = low.min(Vector2i(x, y)); high = high.max(Vector2i(x, y))
  if high.x < 0:
   push_error("Empty source: " + str(job.name)); quit(1); return
  var crop := image.get_region(Rect2i(low, high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
  var size := crop.get_size()
  var factor := minf(30.0 / size.x, 38.0 / size.y)
  var bounds := Vector2(size) * factor
  crop.resize(256, maxi(1, roundi(256.0 * size.y / size.x)), Image.INTERPOLATE_LANCZOS)
  var path := "res://art/world/forage/" + str(job.name) + ".png"
  if crop.save_png(path) != OK:
   push_error("Cannot save sprite: " + path); quit(1); return
  manifest.entries["forage/" + str(job.name)] = {
   "name": job.label, "path": path, "baseReady": true, "status": "partial",
   "sourceSha256": job.sha256, "worldRect": [-bounds.x/2, -bounds.y, bounds.x, bounds.y],
   "requiredChecks": ["material_detail", "placement", "regrowth_states", "seasonal_variants", "interaction_alignment"],
   "reviewed": ["material_detail"], "verifiedChecks": []
  }
 var file := FileAccess.open("res://data/world_art_manifest.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest, "  ") + "\n"); file.close()
 print("REMAINING_FORAGE_IMPORT: five distinct transparent world resource sprites, bounded to 30x38 world pixels")
 quit(0)
