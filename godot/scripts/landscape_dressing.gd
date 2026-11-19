extends Node2D
## Deterministic small bank/path accents, drawn below actors and never collidable.
var accents: Array[Dictionary] = []
func configure(layer: TileMapLayer) -> void:
	z_index = -8
	var directions := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
	for cell: Vector2i in layer.get_used_cells():
		var column := preload("res://scripts/world_layout.gd").ground_column(cell, layer.get_cell_atlas_coords(cell).x)
		if column==7:
			for side: Vector2i in directions:
				var adjacent:=layer.get_cell_atlas_coords(cell+side)
				if adjacent.x!=8:continue
				var vertical:=side.x!=0
				if (cell.y if vertical else cell.x)%2!=0:continue
				var rail:=preload("res://scripts/ranch_fence_segment.gd").new()
				rail.vertical=vertical;rail.span=64
				rail.position=Vector2(cell)*32+Vector2(16,32 if vertical else 16)+Vector2(side)*15
				get_parent().add_child.call_deferred(rail)
		if column not in [2,3,4,5,6]: continue
		var seed_value := posmod(cell.x*73+cell.y*137, 997)
		if seed_value % 7 != 0: continue
		for direction: Vector2i in directions:
			var other := cell+direction
			var near := layer.get_cell_atlas_coords(other)
			if near == Vector2i(-1,-1): continue
			var neighbor := preload("res://scripts/world_layout.gd").ground_column(other, near.x)
			if neighbor not in [0,1,7,8] or neighbor == column: continue
			var at := Vector2(cell)*32.0+Vector2(16,16)+Vector2(direction)*10.0
			accents.append({"at":at,"shore":neighbor==8,"seed":seed_value})
			break
	GameState.world_changed.connect(queue_redraw)
	queue_redraw()
func _draw() -> void:
	var art := preload("res://scripts/character_art.gd")
	var manifest := preload("res://scripts/world_art.gd").entries()
	var plant: Texture2D = art.texture(str(manifest.get("props/plants",{}).get("path","")))
	var stone: Texture2D = art.texture(str(manifest.get("props/stones",{}).get("path","")))
	var view := preload("res://scripts/life_presentation.gd").visible_rect(self, 40)
	var season := GameState.season_index()
	var tint: Color = [Color(.84,.94,.77,.77),Color(.85,.93,.73,.77),Color(.94,.82,.61,.72),Color(.84,.87,.82,.65)][season]
	for accent: Dictionary in accents:
		var at: Vector2 = accent.at
		if not view.has_point(at): continue
		var texture: Texture2D = plant if bool(accent.shore) or int(accent.seed)%3!=0 else stone
		if texture == null: continue
		var height := 15.0 if bool(accent.shore) else 8.0
		var width := height*float(texture.get_width())/float(texture.get_height())
		draw_texture_rect(texture,Rect2(at-Vector2(width*.5,height),Vector2(width,height)),false,tint)
