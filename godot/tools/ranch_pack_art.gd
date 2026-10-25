extends SceneTree
func _initialize() -> void:
 for animal: String in ["goat","rabbit"]:
  var image := Image.load_from_file(ProjectSettings.globalize_path("res://art/sources/ranch-20261016/"+animal+".png"))
  image.resize(1536,512,Image.INTERPOLATE_LANCZOS)
  image.save_png("res://art/world/animals/"+animal+".png")
 var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://art/sources/ranch-20261016/products.png"))
 var names := ["goatMilk","goatCheese","rabbitFur","fineYarn"]
 for i: int in range(4):
  var icon := atlas.get_region(Rect2i(i*atlas.get_width()/4,0,atlas.get_width()/4,atlas.get_height()))
  icon.resize(128,128,Image.INTERPOLATE_LANCZOS)
  icon.save_png("res://art/icons/items/"+names[i]+".png")
 print("RANCH_ART_PACKED")
 quit()
