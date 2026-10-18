class_name TileGrid
extends RefCounted

# Hexagon-shaped board of tiles, ported from Unity's TileExplore.TileGridManager. Starts all
# Empty; TileGridGenerator fills in resource types.

enum TileType {
	EMPTY,
	GOLD_ORE,
	WATER_SPRING,
	IRON_DEPOSIT,
	TIMBER,
	STONE_OUTCROP,
}

var radius: int
var tiles: Dictionary[Vector2i, TileType] = {}


func _init(p_radius: int = 5) -> void:
	radius = p_radius
	for coord in Hex.hexagon(radius):
		tiles[coord] = TileType.EMPTY


func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)


func get_tile(coord: Vector2i) -> TileType:
	return tiles[coord]


func set_tile(coord: Vector2i, type: TileType) -> void:
	assert(tiles.has(coord), "Coord %s is not on the grid" % coord)
	tiles[coord] = type
