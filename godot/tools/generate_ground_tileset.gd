extends SceneTree

const OUTPUT_PATH := "res://art/ground_tileset.tres"
const GROUND_TEXTURE := preload("res://art/ground_tiles.svg")
const TILE_SIZE := Vector2i(32, 32)
const SURFACE_KINDS: Array[String] = [
	"mountain_gravel", "town_stone", "river_sand", "bamboo_ground", "farm_grass",
	"pasture_grass", "earth_path", "stone_path", "water", "wood_path"
]

func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "surface_kind")
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, "season_index")
	tile_set.set_custom_data_layer_type(1, TYPE_INT)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(2, "variant")
	tile_set.set_custom_data_layer_type(2, TYPE_INT)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = GROUND_TEXTURE
	atlas.texture_region_size = TILE_SIZE
	tile_set.add_source(atlas, 0)
	for season in range(4):
		for variant in range(4):
			for kind_index in range(SURFACE_KINDS.size()):
				var atlas_coords := Vector2i(kind_index, season * 4 + variant)
				atlas.create_tile(atlas_coords)
				var tile_data := atlas.get_tile_data(atlas_coords, 0)
				tile_data.set_custom_data("surface_kind", SURFACE_KINDS[kind_index])
				tile_data.set_custom_data("season_index", season)
				tile_data.set_custom_data("variant", variant)
	var error := ResourceSaver.save(tile_set, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save ground TileSet: %s" % error_string(error))
		quit(1)
		return
	print("Saved 160 seasonal ground tiles to %s" % OUTPUT_PATH)
	quit(0)
