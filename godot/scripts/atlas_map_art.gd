extends RefCounted

static func rectangles(state: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var world: Dictionary = state.world_village
	for id in world.get("offsets", {}):
		var region: Dictionary = world.offsets[id]
		var height := 1536.0 if float(region.y)==2304.0 else 1152.0
		out.append({"x":float(region.x),"y":float(region.y),"w":1920.0,"h":height,"color":str(region.color),"alpha":0.72})
		for water in world.get("maps",{}).get(id,{}).get("water",[]):
			out.append({"x":float(region.x)+float(water.x),"y":float(region.y)+float(water.y),"w":float(water.w),"h":float(water.h),"color":"#73aaa8","alpha":1.0})
	for road in world.get("corridors", []):
		out.append({"x":float(road.x),"y":float(road.y),"w":float(road.w),"h":float(road.h),"color":"#efe0ae","alpha":1.0})
	for house in world.get("houses", []):
		out.append({"x":float(house.x),"y":float(house.y),"w":float(house.w),"h":float(house.h),"color":"#b58161" if house.get("owner") != null and str(house.get("owner",""))!="" else "#486f61","alpha":1.0})
		out.append({"x":float(house.door.x)-12.0,"y":float(house.door.y)-8.0,"w":24.0,"h":16.0,"color":"#f4dbaa","alpha":1.0})
	for index in range(state.plots.size()):
		var p:Vector2=state.farm_plot_position(index)
		out.append({"x":float(p.x)-19.0,"y":float(p.y)-16.0,"w":38.0,"h":32.0,"color":"#647d39" if str(state.plots[index].get("crop",""))!="" else "#ab895a","alpha":1.0})
	for piece in state.building.get("layout", []):
		if str(piece.get("zone",""))=="home":continue
		var zone:Dictionary=state.system_catalog.get("building",{}).get("zones",{}).get(str(piece.zone),{})
		var definition:Dictionary=state.system_catalog.get("building",{}).get("defs",{}).get(str(piece.type),{})
		if zone.is_empty() or definition.is_empty():continue
		var rotated:=int(piece.get("rotation",0))%2!=0
		var width:=float(definition.get("h",1)) if rotated else float(definition.get("w",1))
		var height:=float(definition.get("w",1)) if rotated else float(definition.get("h",1))
		var cell:=int(piece.get("cell",0))
		var cols:=int(zone.get("cols",1))
		var size:=float(zone.get("size",48))
		out.append({"x":float(zone.x)+float(cell%cols)*size,"y":float(zone.y)+float(int(cell/cols))*size,"w":width*size,"h":height*size,"color":"#88674e","alpha":1.0})
	return out
