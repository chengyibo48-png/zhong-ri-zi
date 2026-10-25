extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/item_art_manifest.json"))
	var sheets: Array=[{"path":"freshwater-atlas.png","columns":4,"rows":3,"ids":["carp","grassCarp","silverCarp","bigheadCarp","bream","catfish","yellowCatfish","blackCarp","paleChub","riverSnail","riverMussel"]},{"path":"equipment-atlas.png","columns":4,"rows":2,"ids":["steadyFloat","gentleSinker","fishBell","fishTrap","grainBait","herbBait","shrimpBait"]},{"path":"dishes-atlas.png","columns":2,"rows":1,"ids":["leekSnails","musselRadishSoup"]}]
	for sheet: Dictionary in sheets:
		var image:=Image.load_from_file("res://art/sources/fishing-20261017/"+str(sheet.path))
		if image==null:quit(1);return
		image.convert(Image.FORMAT_RGBA8)
		for index: int in range(sheet.ids.size()):
			var cell:=Rect2i(roundi((index%int(sheet.columns))*image.get_width()/float(sheet.columns)),roundi(int(index/int(sheet.columns))*image.get_height()/float(sheet.rows)),roundi(image.get_width()/float(sheet.columns)),roundi(image.get_height()/float(sheet.rows)))
			cell=cell.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			var crop:=image.get_region(cell)
			var used:=crop.get_used_rect()
			if used.size==Vector2i.ZERO:push_error("Empty atlas cell");quit(1);return
			crop=crop.get_region(used)
			var factor:=minf(112.0/crop.get_width(),112.0/crop.get_height())
			crop.resize(maxi(1,roundi(crop.get_width()*factor)),maxi(1,roundi(crop.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
			var icon:=Image.create(128,128,false,Image.FORMAT_RGBA8)
			icon.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((128-crop.get_width())/2,(128-crop.get_height())/2))
			var id:=str(sheet.ids[index]);var path: String="res://art/icons/items/"+id+".png"
			if icon.save_png(path)!=OK:quit(1);return
			manifest.entries["items/"+id]={"name":root.get_node("GameState").item_catalog[id].name,"path":path,"size":[128,128],"status":"ready","source":"res://art/sources/fishing-20261017/"+str(sheet.path),"cell":index}
	var output:=FileAccess.open("res://data/item_art_manifest.json",FileAccess.WRITE);output.store_string(JSON.stringify(manifest,"  "));output.close()
	print("Imported 20 independent painted inventory icons");quit(0)
