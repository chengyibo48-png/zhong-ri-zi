extends SceneTree
func _initialize() -> void:
 var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://art/sources/ranch-20261016/fixtures.png"))
 var names := ["trough","box","bed","shallow"]
 for i: int in range(4):
  var cuts := [0,590,1055,1600,2172]
  var cell := atlas.get_region(Rect2i(cuts[i],0,cuts[i+1]-cuts[i],atlas.get_height()))
  var low:=Vector2i(cell.get_width(),cell.get_height());var high:=Vector2i.ZERO
  for y: int in range(cell.get_height()):
   for x: int in range(cell.get_width()):
    if cell.get_pixel(x,y).a>0.15:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  var image := cell.get_region(Rect2i(low,(high-low)+Vector2i.ONE))
  print(names[i]," bounds ",low," ",high)
  image.save_png("res://art/world/ranch/"+names[i]+".png")
 print("RANCH_FIXTURES_PACKED")
 quit()
