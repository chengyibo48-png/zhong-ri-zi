extends RefCounted
## O(1) world/layout identity checks; small upgrade flags retain legacy direct edits.
static func sample(state:Node)->Dictionary:
	var old:Dictionary=state.get_meta("navigation_revision_cache",{})
	var layout:Array=state.building.get("layout",[])
	var world_changed:=old.is_empty() or not is_same(old.get("world_ref"),state.world_village)
	var changed:=world_changed or not is_same(old.get("building_ref"),state.building) or not is_same(old.get("layout_ref"),layout)
	var world_serial:int=int(old.get("world_serial",0))+(1 if world_changed else 0)
	var layout_serial:int=int(old.get("layout_serial",0))+(1 if changed else 0)
	var world_stamp:="%d/%d"%[state.get_instance_id(),world_serial]
	var scope:="%s/%d/%s/%s/%s/%s/%s"%[world_stamp,layout_serial,state.building.get("revision",0),state.building.get("house",0),hash(state.upgrades),hash(state.building.get("land",{})),state.collection.get("level",0)]+"/house-layout-2/"+str(state.interior_state.get("household",{}).get("homePreset",false))
	if changed or old.get("scope")!=scope:
		old={"world_ref":state.world_village,"building_ref":state.building,"layout_ref":layout,"world_serial":world_serial,"layout_serial":layout_serial,"world":world_stamp,"scope":scope}
		state.set_meta("navigation_revision_cache",old)
	return old
