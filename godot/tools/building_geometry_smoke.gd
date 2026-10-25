extends SceneTree
var passed:int=0
var failed:int=0
const RULES=preload("res://scripts/building_geometry.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 await process_frame
 var state:Node=root.get_node("GameState");state.set_process(false)
 var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BUILDING_GEOMETRY_FIXTURE")))
 if not raw is Dictionary:quit(1);return
 state.upgrades.yard=true;state.building.land.orchard=true;state.building.house=3
 for row in raw.placements:
  state.building.house=row.house;state.building.land.orchard=row.orchard;state.upgrades.yard=row.yard
  state.legacy_systems.layouts=row.legacy
  var got:Dictionary=state.building_placement_valid(row.piece,row.others)
  check(got.ok==row.expected.ok and got.message==row.expected.msg,"placement "+str(row.piece)+" "+row.label+" "+JSON.stringify(got)+" expected "+JSON.stringify(row.expected))
 state.building.house=3;state.building.land.orchard=true;state.upgrades.yard=true;state.legacy_systems.layouts=[]
 for row in raw.layouts:
  state.building.house=row.house
  var got:Dictionary=state.check_building_layout(row.layout)
  check(got.ok==row.expected.ok and got.message==row.expected.msg,"layout "+row.label+" "+JSON.stringify(got)+" expected "+JSON.stringify(row.expected))
 for row in raw.commits:
  state.building=row.before.building.duplicate(true);state.upgrades=row.before.upgrades.duplicate(true)
  state.furniture=row.before.furniture.duplicate(true);state.legacy_systems.layouts=row.before.layouts.duplicate(true)
  state.current_interior=str(row.before.village.interior) if row.before.village.interior!=null else ""
  state.player_position=Vector2(float(row.before.player.x),float(row.before.player.y));state.interior_position=state.player_position
  state.set_player_navigation_position(row.before.player)
  var ok:bool=state.apply_building_layout(row.layout,int(row.base))
  var got:Dictionary={"ok":ok,"message":state.message}
  check(got.ok==row.expected.ok and got.message==row.expected.msg,"commit result "+row.label+" "+JSON.stringify(got)+" expected "+JSON.stringify(row.expected))
  check(JSON.parse_string(JSON.stringify(state.building))==row.building,"commit building "+row.label)
  check(JSON.parse_string(JSON.stringify(state.furniture))==row.furniture,"commit furniture "+row.label)
 print("Building geometry: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
